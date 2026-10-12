// Settings and social extensions: preferences + feedback (P3-AUTH-002 proposed ops), blocks,
// user reports, friend streaks, interactions, classrooms, year in review (P9-SOCIAL-002) and the
// one-time league result screen (P9-LEAGUE-002). Social rules from PERMISSIONS: blocks hide
// both directions and end pair features; CHILD accounts make no social writes; interactions use
// server message keys only.
import { createHash } from 'node:crypto';
import { ServiceError } from '../../../shared/src/errors.js';
import { rowId } from '../persistence/core.js';
import type { ProgressTx, Row } from '../persistence/port.js';
import {
  FRIEND_STREAK_LIMIT,
  INTERACTION_GIFT_BOOST_GEMS,
  INTERACTION_MESSAGE_KEYS,
  normalizeCode,
} from '../domain/commerce.js';
import { addDays } from '../domain/time.js';
import { zonedDay } from '../domain/time.js';
import { creditGems } from './commerce.js';
import { DEFAULT_ZONE, editable, ids, operationId, requireProfile } from './records.js';
import { isBlockedPair, mutualFriendIds, visibleProfile } from './social.js';

// ---------------------------------------------------------------- preferences / feedback

const PREF_KEYS = [
  'smartScheduling',
  'reminderMinute',
  'soundEffects',
  'haptics',
  'motivationalMessages',
  'listeningExercises',
  'speakingExercises',
  'friendStreakInvites',
] as const;

export function defaultPreferences(userId: string): Row {
  return {
    userId,
    notificationsOffJson: '[]',
    smartScheduling: true,
    reminderMinute: 1200,
    soundEffects: true,
    haptics: true,
    motivationalMessages: true,
    listeningExercises: true,
    speakingExercises: true,
    friendStreakInvites: true,
  };
}

function preferencesView(row: Readonly<Row>, nowIso: string) {
  const view: Record<string, unknown> = {
    notificationsOff: JSON.parse(String(row['notificationsOffJson'] ?? '[]')) as string[],
  };
  for (const key of PREF_KEYS) view[key] = row[key];
  view['revision'] = Number(row['revision'] ?? 0);
  view['asOf'] = nowIso;
  return view;
}

export async function getPreferences(tx: ProgressTx, userId: string) {
  await requireProfile(tx, userId);
  const row =
    (await tx.get('p_preferences', ids.preferences(userId))) ?? defaultPreferences(userId);
  return preferencesView(row, tx.nowIso);
}

export async function updatePreferences(
  tx: ProgressTx,
  userId: string,
  patch: Record<string, unknown> & { expectedRevision: number },
) {
  await requireProfile(tx, userId);
  const id = ids.preferences(userId);
  const stored = await tx.get('p_preferences', id);
  const current = Number(stored?.['revision'] ?? 0);
  if (patch.expectedRevision !== current) {
    throw new ServiceError('REVISION_CONFLICT', { details: { currentRevision: current } });
  }
  const next = stored ? editable(stored) : defaultPreferences(userId);
  if (patch['notificationsOff'] !== undefined) {
    next['notificationsOffJson'] = JSON.stringify(patch['notificationsOff']);
  }
  for (const key of PREF_KEYS) if (patch[key] !== undefined) next[key] = patch[key];
  tx.put('p_preferences', id, next);
  return preferencesView({ ...next, revision: stored ? current + 1 : 0 }, tx.nowIso);
}

export async function sendFeedback(
  tx: ProgressTx,
  userId: string,
  request: { topic: string; message: string; appVersion: string; platform: string },
  key: string,
) {
  await requireProfile(tx, userId);
  tx.put('p_feedback', rowId('p_feedback', userId, key), {
    userId,
    topic: request.topic,
    message: request.message,
    appVersion: request.appVersion,
    platform: request.platform,
    status: 'OPEN',
  });
  return 'completed' as const;
}

// ---------------------------------------------------------------- blocks / reports

async function socialWriter(tx: ProgressTx, userId: string): Promise<Row> {
  const profile = await requireProfile(tx, userId);
  if (profile['ageBand'] === 'CHILD') throw new ServiceError('FORBIDDEN');
  return profile;
}

/** Block hides both directions, removes both follows and ends the pair's friend streak. */
export async function blockUser(tx: ProgressTx, userId: string, targetId: string) {
  await requireProfile(tx, userId);
  if (targetId === userId)
    throw new ServiceError('VALIDATION_ERROR', { details: { field: 'targetUserId' } });
  const id = ids.block(userId, targetId);
  if (await tx.get('p_blocks', id)) return 'replayed' as const;
  tx.put('p_blocks', id, { blockerId: userId, blockedId: targetId });
  for (const [from, to] of [
    [userId, targetId],
    [targetId, userId],
  ] as const) {
    const followId = ids.follow(from, to);
    const follow = await tx.get('p_follows', followId);
    if (follow?.['status'] === 'ACTIVE')
      tx.put('p_follows', followId, { ...editable(follow), status: 'REMOVED' });
  }
  const pairId = friendPairId(userId, targetId);
  const streak = await tx.get('p_friend_streaks', rowId('p_friend_streaks', pairId));
  if (streak && (streak['status'] === 'ACTIVE' || streak['status'] === 'PENDING')) {
    tx.put('p_friend_streaks', rowId('p_friend_streaks', pairId), {
      ...editable(streak),
      status: 'ENDED',
      endedAt: tx.nowIso,
    });
  }
  return 'completed' as const;
}

export async function unblockUser(tx: ProgressTx, userId: string, targetId: string) {
  await requireProfile(tx, userId);
  const id = ids.block(userId, targetId);
  if (!(await tx.get('p_blocks', id))) return 'replayed' as const;
  tx.delete('p_blocks', id);
  return 'completed' as const;
}

export async function reportUser(
  tx: ProgressTx,
  userId: string,
  request: { targetUserId: string; reason: string; note: string | null },
) {
  await requireProfile(tx, userId);
  if (request.targetUserId === userId) {
    throw new ServiceError('VALIDATION_ERROR', { details: { field: 'targetUserId' } });
  }
  const id = rowId('p_user_reports', userId, request.targetUserId, request.reason);
  if (await tx.get('p_user_reports', id)) return 'replayed' as const;
  tx.put('p_user_reports', id, {
    reporterId: userId,
    targetUserId: request.targetUserId,
    reason: request.reason,
    note: request.note,
    status: 'OPEN',
  });
  return 'completed' as const;
}

// ---------------------------------------------------------------- friend streaks

export function friendPairId(a: string, b: string): string {
  return operationId('friend-streak', ...[a, b].sort());
}

async function openStreakCount(tx: ProgressTx, userId: string): Promise<number> {
  let total = 0;
  for (const column of ['userAId', 'userBId']) {
    for (const status of ['PENDING', 'ACTIVE'])
      total += await tx.count('p_friend_streaks', { [column]: userId, status });
  }
  return total;
}

async function streakView(tx: ProgressTx, viewerId: string, row: Readonly<Row>, today: string) {
  const friendId = row['userAId'] === viewerId ? String(row['userBId']) : String(row['userAId']);
  const friend = await tx.get('p_profiles', ids.profile(friendId));
  return {
    pairId: String(row['pairId']),
    friendUserId: friendId,
    friendNickname: String(friend?.['nickname'] ?? 'Learner').slice(0, 40),
    inviterId: String(row['inviterId']),
    status: String(row['status']) as 'PENDING',
    length: Number(row['length'] ?? 0),
    startDay: (row['startDay'] as string | null) ?? null,
    lastExtendedDay: (row['lastExtendedDay'] as string | null) ?? null,
    extendedToday: row['lastExtendedDay'] === today,
  };
}

export async function listFriendStreaks(tx: ProgressTx, userId: string) {
  const profile = await requireProfile(tx, userId);
  const today = zonedDay(tx.nowIso, String(profile['learningZone'] ?? DEFAULT_ZONE));
  const rows = [
    ...(await tx.list('p_friend_streaks', { where: { userAId: userId }, limit: 50 })),
    ...(await tx.list('p_friend_streaks', { where: { userBId: userId }, limit: 50 })),
  ].filter(({ row }) => row['status'] === 'PENDING' || row['status'] === 'ACTIVE');
  const items = [];
  for (const { row } of rows.slice(0, 20)) items.push(await streakView(tx, userId, row, today));
  return { items, nextCursor: null, asOf: tx.nowIso };
}

export async function inviteFriendStreak(tx: ProgressTx, userId: string, targetId: string) {
  const profile = await socialWriter(tx, userId);
  const today = zonedDay(tx.nowIso, String(profile['learningZone'] ?? DEFAULT_ZONE));
  if (targetId === userId)
    throw new ServiceError('VALIDATION_ERROR', { details: { field: 'targetUserId' } });
  if (await isBlockedPair(tx, userId, targetId)) throw new ServiceError('USER_BLOCKED');
  if (!(await mutualFriendIds(tx, userId)).includes(targetId))
    throw new ServiceError('PROFILE_UNAVAILABLE');
  const target = await tx.get('p_profiles', ids.profile(targetId));
  const prefs = await tx.get('p_preferences', ids.preferences(targetId));
  if (!target || target['ageBand'] === 'CHILD' || prefs?.['friendStreakInvites'] === false) {
    throw new ServiceError('PROFILE_UNAVAILABLE');
  }
  const pairId = friendPairId(userId, targetId);
  const id = rowId('p_friend_streaks', pairId);
  const existing = await tx.get('p_friend_streaks', id);
  if (existing && (existing['status'] === 'PENDING' || existing['status'] === 'ACTIVE')) {
    return streakView(tx, userId, existing, today);
  }
  if (
    (await openStreakCount(tx, userId)) >= FRIEND_STREAK_LIMIT ||
    (await openStreakCount(tx, targetId)) >= FRIEND_STREAK_LIMIT
  ) {
    throw new ServiceError('FRIEND_STREAK_LIMIT');
  }
  const [a, b] = [userId, targetId].sort() as [string, string];
  const row: Row = {
    ...(existing ? editable(existing) : {}),
    pairId,
    userAId: a,
    userBId: b,
    inviterId: userId,
    status: 'PENDING',
    startDay: null,
    length: 0,
    lastExtendedDay: null,
    endedAt: null,
  };
  tx.put('p_friend_streaks', id, row);
  return streakView(tx, userId, row, today);
}

export async function respondFriendStreak(
  tx: ProgressTx,
  userId: string,
  pairId: string,
  accept: boolean,
) {
  const profile = await socialWriter(tx, userId);
  const today = zonedDay(tx.nowIso, String(profile['learningZone'] ?? DEFAULT_ZONE));
  const id = rowId('p_friend_streaks', pairId);
  const row = await tx.get('p_friend_streaks', id);
  if (!row || (row['userAId'] !== userId && row['userBId'] !== userId))
    throw new ServiceError('NOT_FOUND');
  if (row['status'] !== 'PENDING' || row['inviterId'] === userId) {
    if (row['status'] === (accept ? 'ACTIVE' : 'DECLINED'))
      return streakView(tx, userId, row, today);
    throw new ServiceError('REVISION_CONFLICT', { details: { status: row['status'] } });
  }
  const other = row['userAId'] === userId ? String(row['userBId']) : String(row['userAId']);
  if (await isBlockedPair(tx, userId, other)) throw new ServiceError('USER_BLOCKED');
  if (accept && (await openStreakCount(tx, userId)) > FRIEND_STREAK_LIMIT) {
    throw new ServiceError('FRIEND_STREAK_LIMIT');
  }
  const next = {
    ...editable(row),
    status: accept ? 'ACTIVE' : 'DECLINED',
    startDay: accept ? today : null,
  };
  tx.put('p_friend_streaks', id, next);
  return streakView(tx, userId, next, today);
}

/** Called from the completion transaction when `day` became active for `userId`. */
export async function extendFriendStreaks(
  tx: ProgressTx,
  userId: string,
  day: string,
): Promise<void> {
  const rows = [
    ...(await tx.list('p_friend_streaks', {
      where: { userAId: userId, status: 'ACTIVE' },
      limit: 10,
    })),
    ...(await tx.list('p_friend_streaks', {
      where: { userBId: userId, status: 'ACTIVE' },
      limit: 10,
    })),
  ];
  for (const { id, row } of rows) {
    if (row['lastExtendedDay'] === day) continue;
    const partner = row['userAId'] === userId ? String(row['userBId']) : String(row['userAId']);
    const partnerDay = await tx.get('p_day_activity', ids.day(partner, day));
    if (!partnerDay?.['active']) continue;
    const consecutive = row['lastExtendedDay'] === addDays(day, -1);
    tx.put('p_friend_streaks', id, {
      ...editable(row),
      length: consecutive ? Number(row['length'] ?? 0) + 1 : 1,
      startDay: consecutive ? row['startDay'] : day,
      lastExtendedDay: day,
    });
  }
}

// ---------------------------------------------------------------- interactions

export async function sendInteraction(
  tx: ProgressTx,
  userId: string,
  request: { targetUserId: string; kind: string; contextId: string; messageKey: string },
  key: string,
) {
  const profile = await socialWriter(tx, userId);
  const zone = String(profile['learningZone'] ?? DEFAULT_ZONE);
  const day = zonedDay(tx.nowIso, zone);
  if (!INTERACTION_MESSAGE_KEYS[request.kind]?.includes(request.messageKey)) {
    throw new ServiceError('VALIDATION_ERROR', { details: { field: 'messageKey' } });
  }
  if (request.targetUserId === userId)
    throw new ServiceError('VALIDATION_ERROR', { details: { field: 'targetUserId' } });
  if (await isBlockedPair(tx, userId, request.targetUserId)) throw new ServiceError('USER_BLOCKED');
  if (!(await visibleProfile(tx, userId, request.targetUserId)))
    throw new ServiceError('PROFILE_UNAVAILABLE');
  const id = rowId(
    'p_interactions',
    userId,
    request.targetUserId,
    request.kind,
    request.contextId,
    day,
  );
  const existing = await tx.get('p_interactions', id);
  const rewards = await tx.get('p_rewards', ids.rewards(userId));
  if (existing) {
    return interactionView(existing, Number(rewards?.['gems'] ?? 0));
  }
  const opId = operationId('interaction', userId, key);
  const gemsCost = request.kind === 'GIFT_BOOST' ? INTERACTION_GIFT_BOOST_GEMS : 0;
  let gems = Number(rewards?.['gems'] ?? 0);
  if (gemsCost) {
    gems = await creditGems(tx, userId, -gemsCost, 'GIFT', opId, 'gift_boost', zone);
    const endsAt = new Date(tx.nowMs + 15 * 60_000).toISOString();
    tx.put('p_boosts', rowId('p_boosts', request.targetUserId, opId), {
      userId: request.targetUserId,
      boostId: opId,
      kind: 'XP_BOOST',
      multiplier: 2,
      startsAt: tx.nowIso,
      endsAt,
      sourceOperationId: opId,
    });
  }
  const row: Row = {
    operationId: opId,
    fromUserId: userId,
    toUserId: request.targetUserId,
    kind: request.kind,
    contextId: request.contextId,
    day,
    messageKey: request.messageKey,
    gemsCost,
  };
  tx.put('p_interactions', id, row);
  return interactionView(row, gems);
}

function interactionView(row: Readonly<Row>, gems: number) {
  return {
    operationId: String(row['operationId']),
    toUserId: String(row['toUserId']),
    kind: String(row['kind']) as 'NUDGE',
    contextId: String(row['contextId']),
    day: String(row['day']),
    gemsCost: Number(row['gemsCost']),
    gems,
  };
}

// ---------------------------------------------------------------- classrooms

export function classroomCodeHash(code: string): string {
  return createHash('sha256').update(normalizeCode(code), 'utf8').digest('hex');
}

export async function joinClassroom(tx: ProgressTx, userId: string, joinCode: string) {
  await requireProfile(tx, userId);
  const found = await tx.list('p_classrooms', {
    where: { joinCodeHash: classroomCodeHash(joinCode), status: 'ACTIVE' },
    limit: 1,
  });
  const classroom = found[0]?.row;
  if (!classroom) throw new ServiceError('CLASSROOM_CODE_INVALID');
  const classroomId = String(classroom['classroomId']);
  const id = rowId('p_classroom_members', classroomId, userId);
  const member = await tx.get('p_classroom_members', id);
  const joinedAt = member?.['status'] === 'ACTIVE' ? String(member['joinedAt']) : tx.nowIso;
  if (member?.['status'] !== 'ACTIVE') {
    tx.put('p_classroom_members', id, {
      ...(member ? editable(member) : {}),
      classroomId,
      userId,
      joinedAt,
      status: 'ACTIVE',
    });
  }
  return {
    classroomId,
    name: String(classroom['name']),
    courseId: String(classroom['courseId']),
    status: 'ACTIVE' as const,
    joinedAt,
  };
}

export async function leaveClassroom(tx: ProgressTx, userId: string, classroomId: string) {
  await requireProfile(tx, userId);
  const id = rowId('p_classroom_members', classroomId, userId);
  const member = await tx.get('p_classroom_members', id);
  if (member?.['status'] !== 'ACTIVE') return 'replayed' as const;
  tx.put('p_classroom_members', id, { ...editable(member), status: 'LEFT' });
  return 'completed' as const;
}

// ---------------------------------------------------------------- year in review

export async function getYearReview(tx: ProgressTx, userId: string, year: number) {
  const profile = await requireProfile(tx, userId);
  const today = zonedDay(tx.nowIso, String(profile['learningZone'] ?? DEFAULT_ZONE));
  const currentYear = Number(today.slice(0, 4));
  if (!Number.isInteger(year) || year < 2020 || year > currentYear)
    throw new ServiceError('NOT_FOUND');
  const storedId = rowId('p_year_reviews', userId, year);
  const stored = await tx.get('p_year_reviews', storedId);
  if (stored)
    return {
      year,
      generatedAt: String(stored['generatedAt']),
      ...JSON.parse(String(stored['snapshotJson'])),
    };
  const days = await tx.list('p_day_activity', {
    where: { userId },
    gte: { day: `${year}-01-01` },
    lt: { day: `${year + 1}-01-01` },
    orderBy: [['day', 'asc']],
    limit: 366,
  });
  let longest = 0;
  let run = 0;
  let previous: string | null = null;
  let totalXp = 0;
  let activeDays = 0;
  let lessons = 0;
  let minutes = 0;
  for (const { row } of days) {
    totalXp += Number(row['studyXp'] ?? 0);
    lessons += Number(row['completedLessons'] ?? 0);
    minutes += Number(row['minutesSpent'] ?? 0);
    if (row['active']) activeDays++;
    if (row['active'] || row['protected']) {
      const day = String(row['day']);
      run = previous && addDays(previous, 1) === day ? run + 1 : 1;
      previous = day;
      longest = Math.max(longest, run);
    }
  }
  const achievements = (await tx.list('p_achievements', { where: { userId }, limit: 200 })).filter(
    ({ row }) => String(row['earnedAt']).startsWith(String(year)),
  ).length;
  const league = await tx.get('p_league_profiles', ids.leagueProfile(userId));
  const snapshot = {
    totalXp,
    activeDays,
    longestStreak: longest,
    lessonsCompleted: lessons,
    wordsLearned: 0, // vocabulary lives in Learning (l_review_items); not projected to Progress
    minutesSpent: minutes,
    achievementsEarned: achievements,
    topLeagueTier:
      league && Number(league['weeksParticipated'] ?? 0) > 0 ? Number(league['tier']) : null,
    courseIds: [] as string[],
  };
  if (year < currentYear) {
    // A finished year is frozen once (before the 365-day window rolls past it).
    tx.put('p_year_reviews', storedId, {
      userId,
      year,
      snapshotJson: JSON.stringify(snapshot),
      generatedAt: tx.nowIso,
    });
  }
  return { year, generatedAt: tx.nowIso, ...snapshot };
}

// ---------------------------------------------------------------- league result (LEAGUE-002)

export async function getLeagueResult(tx: ProgressTx, userId: string) {
  await requireProfile(tx, userId);
  const row = await tx.get('p_league_profiles', ids.leagueProfile(userId));
  const last = row?.['lastResultJson'] ? (JSON.parse(String(row['lastResultJson'])) as Row) : null;
  return {
    tier: Number(row?.['tier'] ?? 0),
    stage: String(row?.['stage'] ?? 'LEAGUE') as 'LEAGUE',
    weeksParticipated: Number(row?.['weeksParticipated'] ?? 0),
    topThreeFinishes: Number(row?.['topThreeFinishes'] ?? 0),
    diamondWeeks: Number(row?.['diamondWeeks'] ?? 0),
    lastResult: last
      ? {
          weekId: String(last['weekId']),
          previousTier: Number(last['previousTier']),
          tier: Number(last['tier']),
          stage: 'LEAGUE' as const,
          rank: (last['rank'] as number | null) ?? null,
          outcome: String(last['outcome'] ?? 'STAYED') as 'STAYED',
          gemsAwarded: Number(last['gemsAwarded'] ?? 0),
        }
      : null,
    unseen:
      Boolean(row?.['lastSettledWeekId']) &&
      row?.['resultSeenWeekId'] !== row?.['lastSettledWeekId'],
    asOf: tx.nowIso,
  };
}

export async function markLeagueResultSeen(tx: ProgressTx, userId: string, weekId: string) {
  await requireProfile(tx, userId);
  const id = ids.leagueProfile(userId);
  const row = await tx.get('p_league_profiles', id);
  if (!row || row['lastSettledWeekId'] !== weekId) throw new ServiceError('NOT_FOUND');
  if (row['resultSeenWeekId'] === weekId) return 'replayed' as const;
  tx.put('p_league_profiles', id, { ...editable(row), resultSeenWeekId: weekId });
  return 'completed' as const;
}
