// P9-SOCIAL-001 (FR-SOCIAL-001, FR-QUEST-002): public profile, follow/unfollow, friends,
// activity feed and friend-quest opt-in. Authorization is evaluated on every read and write
// (PERMISSIONS): blocks hide both directions, CHILD accounts are never public and cannot make
// social writes, private (non opt-in) targets are unavailable and email is never projected.
import { ServiceError } from '../../../shared/src/errors.js';
import type { ProgressTx, Row } from '../persistence/port.js';
import { FRIEND_QUEST, FRIEND_QUEST_PREFIX } from '../domain/catalog.js';
import { leagueWeek } from '../domain/time.js';
import {
  achievementIds,
  editable,
  ids,
  isDeleted,
  operationId,
  publicProfileView,
  requireProfile,
} from './records.js';

export const MAX_FOLLOWING = 1000;

export async function isBlockedPair(tx: ProgressTx, a: string, b: string): Promise<boolean> {
  const [ab, ba] = await Promise.all([
    tx.get('p_blocks', ids.block(a, b)),
    tx.get('p_blocks', ids.block(b, a)),
  ]);
  return Boolean(ab || ba);
}

/** Target profile when the viewer may see it, otherwise null (never reveals why). */
export async function visibleProfile(
  tx: ProgressTx,
  viewerId: string,
  targetId: string,
): Promise<Row | null> {
  const profile = await tx.get('p_profiles', ids.profile(targetId));
  if (!profile || profile['deletedAt'] || (await isDeleted(tx, targetId))) return null;
  if (viewerId === targetId) return profile;
  if (!profile['publicOptIn'] || profile['ageBand'] === 'CHILD') return null;
  if (await isBlockedPair(tx, viewerId, targetId)) return null;
  return profile;
}

async function activeFollow(tx: ProgressTx, from: string, to: string): Promise<boolean> {
  return (await tx.get('p_follows', ids.follow(from, to)))?.['status'] === 'ACTIVE';
}

export async function followStatus(tx: ProgressTx, viewerId: string, targetId: string) {
  if (viewerId === targetId) return 'none' as const;
  const [out, back] = await Promise.all([
    activeFollow(tx, viewerId, targetId),
    activeFollow(tx, targetId, viewerId),
  ]);
  return out ? (back ? ('friend' as const) : ('following' as const)) : ('none' as const);
}

async function projection(tx: ProgressTx, viewerId: string, profile: Readonly<Row>) {
  const targetId = String(profile['userId']);
  return publicProfileView(
    profile,
    await tx.get('p_rewards', ids.rewards(targetId)),
    await achievementIds(tx, targetId),
    await followStatus(tx, viewerId, targetId),
    tx.nowIso,
  );
}

export async function getPublicProfile(tx: ProgressTx, viewerId: string, targetId: string) {
  await requireProfile(tx, viewerId);
  const profile = await visibleProfile(tx, viewerId, targetId);
  if (!profile) throw new ServiceError('PROFILE_UNAVAILABLE');
  return projection(tx, viewerId, profile);
}

async function requireSocialWriter(tx: ProgressTx, userId: string): Promise<Row> {
  const profile = await requireProfile(tx, userId);
  if (profile['ageBand'] === 'CHILD') throw new ServiceError('FORBIDDEN');
  return profile;
}

export async function followUser(tx: ProgressTx, userId: string, targetId: string) {
  await requireSocialWriter(tx, userId);
  if (targetId === userId) {
    throw new ServiceError('VALIDATION_ERROR', { details: { field: 'targetUserId' } });
  }
  if (!(await visibleProfile(tx, userId, targetId))) throw new ServiceError('PROFILE_UNAVAILABLE');
  const id = ids.follow(userId, targetId);
  const existing = await tx.get('p_follows', id);
  if (existing?.['status'] === 'ACTIVE') return 'replayed' as const;
  if ((await tx.count('p_follows', { fromUserId: userId, status: 'ACTIVE' })) >= MAX_FOLLOWING) {
    throw new ServiceError('VALIDATION_ERROR', { details: { reason: 'FOLLOW_LIMIT' } });
  }
  tx.put('p_follows', id, {
    ...(existing ? editable(existing) : {}),
    fromUserId: userId,
    toUserId: targetId,
    status: 'ACTIVE',
  });
  return 'completed' as const;
}

/** Idempotent; unknown or private targets are accepted silently (no existence oracle). */
export async function unfollowUser(tx: ProgressTx, userId: string, targetId: string) {
  await requireProfile(tx, userId);
  const id = ids.follow(userId, targetId);
  const existing = await tx.get('p_follows', id);
  if (existing?.['status'] !== 'ACTIVE') return 'replayed' as const;
  tx.put('p_follows', id, { ...editable(existing), status: 'REMOVED' });
  return 'completed' as const;
}

/** Mutual ACTIVE follows (friends), sorted by user ID. */
export async function mutualFriendIds(tx: ProgressTx, userId: string): Promise<string[]> {
  const [following, followers] = await Promise.all([
    tx.list('p_follows', { where: { fromUserId: userId, status: 'ACTIVE' }, limit: 500 }),
    tx.list('p_follows', { where: { toUserId: userId, status: 'ACTIVE' }, limit: 500 }),
  ]);
  const back = new Set(followers.map(({ row }) => String(row['fromUserId'])));
  return following
    .map(({ row }) => String(row['toUserId']))
    .filter((id) => back.has(id))
    .sort();
}

export interface Page<T> {
  items: T[];
  nextCursor: string | null;
  asOf: string;
}

export function decodeCursor(cursor: string | undefined): number {
  if (!cursor) return 0;
  try {
    const value = JSON.parse(Buffer.from(cursor, 'base64url').toString('utf8')) as { o?: unknown };
    if (Number.isInteger(value.o) && (value.o as number) >= 0 && (value.o as number) < 100000) {
      return value.o as number;
    }
  } catch {
    // fall through
  }
  throw new ServiceError('VALIDATION_ERROR', { details: { field: 'cursor' } });
}
export function encodeCursor(offset: number): string {
  return Buffer.from(JSON.stringify({ o: offset }), 'utf8').toString('base64url');
}

export async function listFriends(tx: ProgressTx, userId: string, offset: number, limit: number) {
  await requireProfile(tx, userId);
  const friends = await mutualFriendIds(tx, userId);
  const items = [];
  let index = offset;
  for (; index < friends.length && items.length < limit; index++) {
    const profile = await visibleProfile(tx, userId, friends[index] as string);
    if (profile) items.push(await projection(tx, userId, profile));
  }
  return {
    items,
    nextCursor: index < friends.length ? encodeCursor(index) : null,
    asOf: tx.nowIso,
  };
}

/** Own activity plus visible activity of followed, non-blocked, opted-in users. */
export async function listActivity(tx: ProgressTx, userId: string, offset: number, limit: number) {
  await requireProfile(tx, userId);
  const following = await tx.list('p_follows', {
    where: { fromUserId: userId, status: 'ACTIVE' },
    limit: 99,
  });
  const authors = [userId];
  for (const { row } of following) {
    const target = String(row['toUserId']);
    if (await visibleProfile(tx, userId, target)) authors.push(target);
  }
  const rows = await tx.list('p_activity', {
    anyOf: { userId: authors },
    orderBy: [['createdAt', 'desc']],
    limit: Math.min(500, offset + limit + 1),
  });
  const visible = rows.filter(
    ({ row }) =>
      (row['userId'] === userId || row['visible']) &&
      ['MILESTONE', 'QUEST', 'STREAK'].includes(String(row['kind'])),
  );
  const items = visible.slice(offset, offset + limit).map(({ row }) => ({
    eventId: String(row['eventId']),
    userId: String(row['userId']),
    kind: String(row['kind']) as 'MILESTONE' | 'QUEST' | 'STREAK',
    summary: String(row['publicSummary']),
    createdAt: String(row['createdAt']),
  }));
  return {
    items,
    nextCursor: visible.length > offset + limit ? encodeCursor(offset + limit) : null,
    asOf: tx.nowIso,
  };
}

/**
 * FR-QUEST-002 opt-in for the current UTC week. Pairs deterministically with the
 * lowest-ID reciprocal friend who opted in and is still unpaired (their solo progress carries
 * over); without a partner the learner gets the individual quest. Membership is frozen at
 * pairing, so a later unfollow never changes the current pair.
 */
export async function optInFriendQuest(tx: ProgressTx, userId: string) {
  await requireSocialWriter(tx, userId);
  const week = leagueWeek(tx.nowIso);
  const mine = await tx.list('p_quests', {
    where: { userId, period: 'WEEK', periodKey: week },
    limit: 10,
  });
  if (mine.some(({ row }) => String(row['questId']).startsWith(FRIEND_QUEST_PREFIX))) {
    return 'replayed' as const;
  }
  const soloQuestId = `${FRIEND_QUEST_PREFIX}solo`;
  for (const friendId of await mutualFriendIds(tx, userId)) {
    if (!(await visibleProfile(tx, userId, friendId))) continue;
    const soloId = ids.quest(friendId, 'WEEK', week, soloQuestId);
    const solo = await tx.get('p_quests', soloId);
    if (!solo || solo['claimed']) continue;
    const members = [userId, friendId].sort();
    const pairId = operationId('friend-pair', week, ...members).slice(0, 28);
    const questId = `${FRIEND_QUEST_PREFIX}${pairId}`;
    const count = Number(solo['metricValue'] ?? 0);
    tx.put('p_friend_quests', ids.friendQuest(week, pairId), {
      weekId: week,
      pairId,
      templateId: FRIEND_QUEST.templateId,
      userIdsJson: JSON.stringify(members),
      target: FRIEND_QUEST.target,
      count,
      claimedUserIdsJson: '[]',
      membershipFrozenAt: tx.nowIso,
    });
    tx.delete('p_quests', soloId);
    for (const member of members) {
      tx.put('p_quests', ids.quest(member, 'WEEK', week, questId), {
        userId: member,
        period: 'WEEK',
        periodKey: week,
        questId,
        metricValue: count,
        target: FRIEND_QUEST.target,
        claimed: false,
        claimOperationId: null,
      });
    }
    return 'completed' as const;
  }
  tx.put('p_quests', ids.quest(userId, 'WEEK', week, soloQuestId), {
    userId,
    period: 'WEEK',
    periodKey: week,
    questId: soloQuestId,
    metricValue: 0,
    target: FRIEND_QUEST.target,
    claimed: false,
    claimOperationId: null,
  });
  return 'completed' as const;
}
