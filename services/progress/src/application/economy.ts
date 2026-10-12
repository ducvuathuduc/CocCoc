// Quests (FR-QUEST-001), rewards read model (getRewards), freeze purchase (FR-GAME-003) and the
// missed-day freeze worker (P6-GAME-002). Wallet changes always write a ledger row in the same
// transaction as the aggregate; no client clock or client totals are accepted.
import { ServiceError } from '../../../shared/src/errors.js';
import type { ProgressTx, Row } from '../persistence/port.js';
import { FRIEND_QUEST, FRIEND_QUEST_PREFIX, QUESTS } from '../domain/catalog.js';
import { FREEZE_PRICE_GEMS, freezeCapacity } from '../domain/streak.js';
import { addDays, leagueWeek, monthKey, zonedDay } from '../domain/time.js';
import { putActivity } from './rewards.js';
import {
  DEFAULT_ZONE,
  editable,
  emptyRewards,
  ids,
  operationId,
  requireProfile,
  rewardsView,
  type RewardsView,
} from './records.js';

export async function getRewards(
  tx: ProgressTx,
  userId: string,
  completionId: string | null,
): Promise<RewardsView> {
  const profile = await requireProfile(tx, userId);
  const rewards = (await tx.get('p_rewards', ids.rewards(userId))) ?? emptyRewards(userId);
  let ledger: Readonly<Row> | null = null;
  if (completionId) {
    ledger =
      (await tx.get('p_reward_ledger', ids.ledger(userId, completionId, 'FIRST'))) ??
      (await tx.get('p_reward_ledger', ids.ledger(userId, completionId, 'REPLAY'))) ??
      (await tx.get('p_reward_ledger', ids.ledger(userId, completionId, 'PRACTICE')));
  }
  return rewardsView(rewards, String(profile['learningZone'] ?? DEFAULT_ZONE), tx.nowIso, {
    completionId,
    ledger,
  });
}

export interface QuestView {
  questId: string;
  period: 'DAY' | 'MONTH' | 'WEEK';
  periodKey: string;
  target: number;
  metricValue: number;
  claimed: boolean;
  rewardGems: number;
}

/** Current daily/monthly quests (profile zone day) plus this week's friend quest, if any. */
export async function listQuests(tx: ProgressTx, userId: string): Promise<QuestView[]> {
  const profile = await requireProfile(tx, userId);
  const today = zonedDay(tx.nowIso, String(profile['learningZone'] ?? DEFAULT_ZONE));
  const out: QuestView[] = [];
  for (const quest of QUESTS) {
    const periodKey = quest.period === 'DAY' ? today : monthKey(today);
    const row = await tx.get('p_quests', ids.quest(userId, quest.period, periodKey, quest.questId));
    out.push({
      questId: quest.questId,
      period: quest.period,
      periodKey,
      target: quest.target,
      metricValue: Number(row?.['metricValue'] ?? 0),
      claimed: Boolean(row?.['claimed']),
      rewardGems: quest.rewardGems,
    });
  }
  const week = leagueWeek(tx.nowIso);
  const weekly = await tx.list('p_quests', {
    where: { userId, period: 'WEEK', periodKey: week },
    limit: 10,
  });
  for (const { row } of weekly) {
    if (!String(row['questId']).startsWith(FRIEND_QUEST_PREFIX)) continue;
    out.push({
      questId: String(row['questId']),
      period: 'WEEK',
      periodKey: week,
      target: Number(row['target']),
      metricValue: Number(row['metricValue']),
      claimed: Boolean(row['claimed']),
      rewardGems: FRIEND_QUEST.rewardGems,
    });
  }
  return out;
}

/** Claim once after the metric is satisfied; a repeated claim returns current rewards. */
export async function claimQuest(
  tx: ProgressTx,
  userId: string,
  questId: string,
  periodKey: string,
): Promise<RewardsView> {
  const profile = await requireProfile(tx, userId);
  const zone = String(profile['learningZone'] ?? DEFAULT_ZONE);
  const quest = QUESTS.find((q) => q.questId === questId);
  if (!quest) throw new ServiceError('NOT_FOUND');
  const keyOk = quest.period === 'DAY' ? /^\d{4}-\d{2}-\d{2}$/ : /^\d{4}-\d{2}$/;
  if (!keyOk.test(periodKey)) {
    throw new ServiceError('VALIDATION_ERROR', { details: { field: 'periodKey' } });
  }
  const id = ids.quest(userId, quest.period, periodKey, questId);
  const row = await tx.get('p_quests', id);
  const rewardsId = ids.rewards(userId);
  const stored = (await tx.get('p_rewards', rewardsId)) ?? emptyRewards(userId);
  if (row?.['claimed']) return rewardsView(stored, zone, tx.nowIso);
  if (!row || Number(row['metricValue']) < quest.target) {
    throw new ServiceError('VALIDATION_ERROR', {
      details: { reason: 'QUEST_NOT_COMPLETE', questId, periodKey },
    });
  }
  const opId = operationId('quest-claim', userId, quest.period, periodKey, questId);
  tx.put('p_quests', id, { ...editable(row), claimed: true, claimOperationId: opId });
  const rewards = editable(stored);
  if (quest.rewardGems > 0) {
    tx.put('p_reward_ledger', ids.ledger(userId, opId, 'QUEST'), {
      eventId: opId,
      completionId: opId,
      userId,
      rewardIdentity: questId,
      kind: 'QUEST',
      studyXpDelta: 0,
      leagueXpDelta: 0,
      gemsDelta: quest.rewardGems,
      learningDay: zonedDay(tx.nowIso, zone),
      leagueWeek: leagueWeek(tx.nowIso),
      occurredAt: tx.nowIso,
      capped: false,
    });
    rewards['gems'] = Number(rewards['gems']) + quest.rewardGems;
  }
  if (quest.badge) {
    const badgeId = `monthly_${periodKey.replace('-', '_')}`;
    const achievementRow = ids.achievement(userId, badgeId, 0);
    if (!(await tx.get('p_achievements', achievementRow))) {
      tx.put('p_achievements', achievementRow, {
        userId,
        achievementId: badgeId,
        tier: 0,
        earnedAt: tx.nowIso,
        sourceEventId: opId,
      });
    }
  }
  const visible = Boolean(profile['publicOptIn']) && profile['ageBand'] !== 'CHILD';
  putActivity(
    tx,
    opId,
    userId,
    'QUEST',
    `Completed the ${questId.replace(/_/g, ' ')} quest`,
    visible,
  );
  tx.put('p_rewards', rewardsId, rewards);
  return rewardsView(
    { ...rewards, revision: Number(stored['revision'] ?? -1) + 1 },
    zone,
    tx.nowIso,
  );
}

/** FR-GAME-003: debit 20 gems, add one equipped freeze, within capacity; ledger + freeze row. */
export async function buyFreeze(tx: ProgressTx, userId: string, operationKey: string) {
  const profile = await requireProfile(tx, userId);
  const zone = String(profile['learningZone'] ?? DEFAULT_ZONE);
  const rewardsId = ids.rewards(userId);
  const stored = (await tx.get('p_rewards', rewardsId)) ?? emptyRewards(userId);
  const rewards = editable(stored);
  const slots = Number(rewards['freezeSlots'] ?? 0);
  if (slots >= freezeCapacity(Number(rewards['currentStreak'] ?? 0))) {
    throw new ServiceError('FREEZE_CAPACITY', { details: { freezeSlots: slots } });
  }
  if (Number(rewards['gems']) < FREEZE_PRICE_GEMS) {
    throw new ServiceError('INSUFFICIENT_GEMS', { details: { required: FREEZE_PRICE_GEMS } });
  }
  const opId = operationId('freeze-buy', userId, operationKey);
  rewards['gems'] = Number(rewards['gems']) - FREEZE_PRICE_GEMS;
  rewards['freezeSlots'] = slots + 1;
  tx.put('p_freeze_ledger', ids.freeze(userId, opId), {
    userId,
    operationId: opId,
    action: 'BUY',
    day: null,
    gemsDelta: -FREEZE_PRICE_GEMS,
    slotDelta: 1,
  });
  tx.put('p_reward_ledger', ids.ledger(userId, opId, 'FREEZE'), {
    eventId: opId,
    completionId: opId,
    userId,
    rewardIdentity: 'streak_freeze',
    kind: 'FREEZE',
    studyXpDelta: 0,
    leagueXpDelta: 0,
    gemsDelta: -FREEZE_PRICE_GEMS,
    learningDay: zonedDay(tx.nowIso, zone),
    leagueWeek: leagueWeek(tx.nowIso),
    occurredAt: tx.nowIso,
    capped: false,
  });
  tx.put('p_rewards', rewardsId, rewards);
  return rewardsView(
    { ...rewards, revision: Number(stored['revision'] ?? -1) + 1 },
    zone,
    tx.nowIso,
  );
}

export interface MissedDayResult {
  protectedDays: string[];
  lostStreak: number | null;
}

/**
 * Scheduled worker step for one user: walk missed days after lastQualifiedDay up to
 * yesterday (profile zone, at most 7-day catch-up), consume one equipped freeze per missed day
 * in chronological order (CONSUME id = hash(userId, day): never twice), otherwise end the
 * streak and remember it for the repair offer. A later late event can mark a protected day
 * active but never refunds the freeze.
 */
export async function processMissedDays(tx: ProgressTx, userId: string): Promise<MissedDayResult> {
  const result: MissedDayResult = { protectedDays: [], lostStreak: null };
  const profile = await tx.get('p_profiles', ids.profile(userId));
  if (!profile || profile['deletedAt']) return result;
  const zone = String(profile['learningZone'] ?? DEFAULT_ZONE);
  const rewardsId = ids.rewards(userId);
  const stored = await tx.get('p_rewards', rewardsId);
  if (!stored || !stored['lastQualifiedDay'] || Number(stored['currentStreak']) === 0)
    return result;
  const rewards = editable(stored);
  const yesterday = addDays(zonedDay(tx.nowIso, zone), -1);
  let day = addDays(String(rewards['lastQualifiedDay']), 1);
  let changed = false;
  // Bounded: each iteration either qualifies a day, consumes one of <= 5 freezes, or stops.
  for (let guard = 0; day <= yesterday && guard < 400; day = addDays(day, 1), guard++) {
    const dayId = ids.day(userId, day);
    const activity = await tx.get('p_day_activity', dayId);
    if (activity?.['active'] || activity?.['protected']) {
      rewards['lastQualifiedDay'] = day;
      continue;
    }
    const consumeId = operationId('freeze-consume', userId, day);
    const slots = Number(rewards['freezeSlots'] ?? 0);
    if (slots > 0 && !(await tx.get('p_freeze_ledger', ids.freeze(userId, consumeId)))) {
      tx.put('p_freeze_ledger', ids.freeze(userId, consumeId), {
        userId,
        operationId: consumeId,
        action: 'CONSUME',
        day,
        gemsDelta: 0,
        slotDelta: -1,
      });
      tx.put('p_day_activity', dayId, {
        ...(activity ? editable(activity) : {}),
        userId,
        day,
        zone,
        active: Boolean(activity?.['active']),
        protected: true,
        studyXp: Number(activity?.['studyXp'] ?? 0),
        replayXp: Number(activity?.['replayXp'] ?? 0),
        completedLessons: Number(activity?.['completedLessons'] ?? 0),
        originalCorrect: Number(activity?.['originalCorrect'] ?? 0),
        reviewSessions: Number(activity?.['reviewSessions'] ?? 0),
        minutesSpent: Number(activity?.['minutesSpent'] ?? 0),
        goalMet: Boolean(activity?.['goalMet']),
      });
      rewards['freezeSlots'] = slots - 1;
      rewards['currentStreak'] = Number(rewards['currentStreak']) + 1;
      rewards['bestStreak'] = Math.max(
        Number(rewards['bestStreak']),
        Number(rewards['currentStreak']),
      );
      rewards['lastQualifiedDay'] = day;
      result.protectedDays.push(day);
      changed = true;
      continue;
    }
    result.lostStreak = Number(rewards['currentStreak']);
    rewards['lostStreak'] = result.lostStreak;
    rewards['lostStreakDay'] = day;
    rewards['currentStreak'] = 0;
    rewards['streakStartDay'] = null;
    changed = true;
    break;
  }
  if (changed || rewards['lastQualifiedDay'] !== stored['lastQualifiedDay']) {
    tx.put('p_rewards', rewardsId, rewards);
  }
  return result;
}
