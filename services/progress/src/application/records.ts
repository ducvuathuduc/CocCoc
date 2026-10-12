// Row identities, loaders and owner-safe projections shared by Progress use cases.
// Row IDs are deterministic hashes of the table's unique key (DATA_MODEL), so a unique index
// violation and a duplicate row ID are the same conflict on every adapter.
import { ServiceError } from '../../../shared/src/errors.js';
import { rowId } from '../persistence/core.js';
import type { ProgressTx, Row } from '../persistence/port.js';
import { displayStreak, type StreakState } from '../domain/streak.js';
import { zonedDay } from '../domain/time.js';

export const DEFAULT_ZONE = 'UTC';
export const ZONE_EPOCH = '1970-01-01T00:00:00.000Z';
export const INITIAL_GEMS = 20;

export const ids = {
  profile: (userId: string) => rowId('p_profiles', userId),
  rewards: (userId: string) => rowId('p_rewards', userId),
  preferences: (userId: string) => rowId('p_preferences', userId),
  leagueProfile: (userId: string) => rowId('p_league_profiles', userId),
  entitlement: (userId: string) => rowId('p_entitlements', userId),
  deletion: (userId: string) => rowId('p_deletions', userId),
  zone: (userId: string, effectiveAt: string) => rowId('p_zone_history', userId, effectiveAt),
  ledger: (userId: string, completionId: string, kind: string) =>
    rowId('p_reward_ledger', userId, completionId, kind),
  firstReward: (userId: string, rewardIdentity: string) =>
    rowId('p_first_rewards', userId, rewardIdentity),
  day: (userId: string, day: string) => rowId('p_day_activity', userId, day),
  freeze: (userId: string, operationId: string) => rowId('p_freeze_ledger', userId, operationId),
  quest: (userId: string, period: string, periodKey: string, questId: string) =>
    rowId('p_quests', userId, period, periodKey, questId),
  follow: (fromUserId: string, toUserId: string) => rowId('p_follows', fromUserId, toUserId),
  block: (blockerId: string, blockedId: string) => rowId('p_blocks', blockerId, blockedId),
  friendQuest: (weekId: string, pairId: string) => rowId('p_friend_quests', weekId, pairId),
  leagueMember: (weekId: string, userId: string) => rowId('p_league_members', weekId, userId),
  leagueRun: (weekId: string, cohortId: string) => rowId('p_league_runs', weekId, cohortId),
  achievement: (userId: string, achievementId: string, tier: number) =>
    rowId('p_achievements', userId, achievementId, tier),
  notification: (userId: string, completionId: string) =>
    rowId('p_notifications', userId, completionId),
  activity: (eventId: string) => rowId('p_activity', eventId),
  outbox: (eventId: string) => rowId('p_outbox', eventId),
};

/** Deterministic 32-hex event/operation identity for non-lesson ledger rows. */
export const operationId = (...parts: string[]) => rowId('operation', ...parts);

export function emptyRewards(userId: string): Row {
  return {
    userId,
    studyXp: 0,
    leagueXpLifetime: 0,
    gems: 0,
    freezeSlots: 0,
    currentStreak: 0,
    bestStreak: 0,
    streakStartDay: null,
    lastQualifiedDay: null,
    lostStreak: 0,
    lostStreakDay: null,
    streakGoal: 0,
    streakGoalStartDay: null,
  };
}

/** Strip adapter-stamped fields before rewriting a row (the core restamps them). */
export function editable(row: Readonly<Row>): Row {
  const { revision: _r, createdAt: _c, updatedAt: _u, ...rest } = row as Row;
  void _r;
  void _c;
  void _u;
  return { ...rest };
}

export async function isDeleted(tx: ProgressTx, userId: string): Promise<boolean> {
  return Boolean(await tx.get('p_deletions', ids.deletion(userId)));
}

/** Active profile or PROFILE_UNAVAILABLE (missing, tombstoned or deleted). */
export async function requireProfile(tx: ProgressTx, userId: string): Promise<Row> {
  const [profile, deleted] = await Promise.all([
    tx.get('p_profiles', ids.profile(userId)),
    isDeleted(tx, userId),
  ]);
  if (!profile || deleted || profile['deletedAt']) throw new ServiceError('PROFILE_UNAVAILABLE');
  return promoteZone(profile, tx.nowIso);
}

/** Apply a scheduled timezone once its effectiveAt passed (read-time projection). */
export function promoteZone(profile: Readonly<Row>, nowIso: string): Row {
  const pending = profile['pendingZone'];
  const effective = profile['zoneEffectiveAt'];
  if (typeof pending === 'string' && typeof effective === 'string' && effective <= nowIso) {
    return { ...profile, learningZone: pending, pendingZone: null, zoneEffectiveAt: null };
  }
  return { ...profile };
}

/** Zone from immutable history: latest row with effectiveAt <= instant (SRS timezone rule). */
export async function zoneAt(tx: ProgressTx, userId: string, instant: string): Promise<string> {
  const history = await tx.list('p_zone_history', {
    where: { userId },
    orderBy: [['effectiveAt', 'desc']],
    limit: 50,
  });
  const match = history.find((entry) => String(entry.row['effectiveAt']) <= instant);
  return match ? String(match.row['zone']) : DEFAULT_ZONE;
}

export async function achievementIds(tx: ProgressTx, userId: string): Promise<string[]> {
  const rows = await tx.list('p_achievements', {
    where: { userId },
    orderBy: [['earnedAt', 'asc']],
    limit: 200,
  });
  const out: string[] = [];
  for (const { row } of rows) {
    const id = String(row['achievementId']);
    if (!out.includes(id)) out.push(id);
  }
  return out.slice(0, 30);
}

export function streakState(rewards: Readonly<Row>): StreakState {
  return {
    currentStreak: Number(rewards['currentStreak'] ?? 0),
    streakStartDay: (rewards['streakStartDay'] as string | null) ?? null,
    lastQualifiedDay: (rewards['lastQualifiedDay'] as string | null) ?? null,
  };
}

export function shownStreak(rewards: Readonly<Row>, zone: string, nowIso: string): number {
  return displayStreak(
    streakState(rewards),
    zonedDay(nowIso, zone),
    Number(rewards['freezeSlots'] ?? 0),
  );
}

export function profileView(profile: Readonly<Row>, achievements: string[]) {
  return {
    userId: String(profile['userId']),
    nickname: String(profile['nickname']),
    avatarId: (profile['avatarId'] as string | null) ?? null,
    publicOptIn: Boolean(profile['publicOptIn']),
    dailyGoal: Number(profile['dailyGoal']),
    learningZone: String(profile['learningZone']),
    pendingZone: (profile['pendingZone'] as string | null) ?? null,
    zoneEffectiveAt: (profile['zoneEffectiveAt'] as string | null) ?? null,
    revision: Number(profile['revision'] ?? 0),
    achievementIds: achievements,
  };
}

export interface RewardsView {
  completionId: string | null;
  status: 'pending' | 'credited' | 'capped';
  studyXp: number;
  leagueXp: number;
  gems: number;
  freezeSlots: number;
  currentStreak: number;
  awardXp: number | null;
  revision: number;
  asOf: string;
}

export function rewardsView(
  rewards: Readonly<Row>,
  zone: string,
  nowIso: string,
  completion: { completionId: string | null; ledger: Readonly<Row> | null } = {
    completionId: null,
    ledger: null,
  },
): RewardsView {
  const ledger = completion.ledger;
  return {
    completionId: completion.completionId,
    status: !completion.completionId
      ? 'credited'
      : !ledger
        ? 'pending'
        : ledger['capped']
          ? 'capped'
          : 'credited',
    studyXp: Number(rewards['studyXp'] ?? 0),
    leagueXp: Number(rewards['leagueXpLifetime'] ?? 0),
    gems: Number(rewards['gems'] ?? 0),
    freezeSlots: Number(rewards['freezeSlots'] ?? 0),
    currentStreak: shownStreak(rewards, zone, nowIso),
    awardXp: ledger ? Number(ledger['studyXpDelta'] ?? 0) : null,
    revision: Number(rewards['revision'] ?? 0),
    asOf: nowIso,
  };
}

/** Public projection: opt-in nickname/avatar/stats only; never credentials or private fields. */
export function publicProfileView(
  profile: Readonly<Row>,
  rewards: Readonly<Row> | null,
  achievements: string[],
  followStatus: 'none' | 'following' | 'friend',
  nowIso: string,
) {
  const zone = String(profile['learningZone'] ?? DEFAULT_ZONE);
  return {
    userId: String(profile['userId']),
    nickname: String(profile['nickname']),
    avatarId: (profile['avatarId'] as string | null) ?? null,
    studyXp: Number(rewards?.['studyXp'] ?? 0),
    streak: Math.min(365, rewards ? shownStreak(rewards, zone, nowIso) : 0),
    achievementIds: achievements,
    followStatus,
  };
}
