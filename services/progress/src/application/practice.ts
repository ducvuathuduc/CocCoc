// Apply one ai.practice.completed.v1 (AI -> Progress) inside the inbox transaction.
// Effects (atomic with the p_inbox row): PRACTICE reward ledger row (completionId =
// conversationId, once per user+conversation), day activity (active, study XP, goal), aggregate
// totals, streak + friend streaks, streak achievements, monthly active-days quest, league eligible
// XP and the owner-readable credited hint. It never counts as a lesson (daily "2 lessons",
// originalCorrect, lesson achievements and the friend lesson quest stay LESSON-only).
// Rules: domain/practice-xp.ts; day = event server time in the zone from immutable history.
import type { BusinessEvent } from '../../../shared/src/ports.js';
import type { ProgressTx, Row } from '../persistence/port.js';
import { isStreakMilestone } from '../domain/catalog.js';
import { computePracticeAward, PRACTICE_DAILY_CAP } from '../domain/practice-xp.js';
import { leagueWeek, zonedDay } from '../domain/time.js';
import { activeBoostMultiplier } from './boosts.js';
import { extendFriendStreaks } from './settings.js';
import { editable, emptyRewards, ids, isDeleted, operationId, zoneAt } from './records.js';
import {
  addLeagueXp,
  advanceStreak,
  bumpQuests,
  grantAchievements,
  putActivity,
  putCreditedNotice,
} from './rewards.js';

export type PracticeEvent = Extract<BusinessEvent, { type: 'ai.practice.completed.v1' }>;

/** PRACTICE XP already credited on `day` (non-zero rows only; at most cap rows exist). */
async function dayPracticeXp(tx: ProgressTx, userId: string, day: string): Promise<number> {
  const rows = await tx.list('p_reward_ledger', {
    where: { userId, learningDay: day, kind: 'PRACTICE' },
    gte: { studyXpDelta: 1 },
    limit: PRACTICE_DAILY_CAP,
  });
  return rows.reduce((sum, { row }) => sum + Number(row['studyXpDelta'] ?? 0), 0);
}

export async function applyPracticeCompletion(tx: ProgressTx, event: PracticeEvent): Promise<void> {
  const p = event.payload;
  const userId = p.userId;
  if (await isDeleted(tx, userId)) return; // tombstone: acknowledged, never credited
  const ledgerId = ids.ledger(userId, p.completionId, 'PRACTICE');
  if (await tx.get('p_reward_ledger', ledgerId)) return; // one credit per conversation
  const zone = await zoneAt(tx, userId, event.occurredAt);
  const day = zonedDay(event.occurredAt, zone);
  const week = leagueWeek(event.occurredAt);
  const dayId = ids.day(userId, day);
  const dayRow = await tx.get('p_day_activity', dayId);
  const award = computePracticeAward(p.xp, {
    dayStudyXp: Number(dayRow?.['studyXp'] ?? 0),
    dayPracticeXp: await dayPracticeXp(tx, userId, day),
    boostMultiplier: await activeBoostMultiplier(tx, userId, event.occurredAt),
  });
  tx.put('p_reward_ledger', ledgerId, {
    eventId: event.eventId,
    completionId: p.completionId,
    userId,
    rewardIdentity: `practice-${p.scenarioId}`.slice(0, 36),
    kind: 'PRACTICE',
    studyXpDelta: award.studyXp,
    leagueXpDelta: award.leagueXp,
    gemsDelta: 0,
    learningDay: day,
    leagueWeek: week,
    occurredAt: event.occurredAt,
    capped: award.capped,
  });

  const profile = await tx.get('p_profiles', ids.profile(userId));
  const dailyGoal = Number(profile?.['dailyGoal'] ?? 10);
  const becameActive = !dayRow?.['active'];
  const studyXp = Number(dayRow?.['studyXp'] ?? 0) + award.studyXp;
  const nextDay: Row = {
    userId,
    day,
    zone: (dayRow?.['zone'] as string | undefined) ?? zone,
    active: true,
    protected: Boolean(dayRow?.['protected']),
    studyXp,
    replayXp: Number(dayRow?.['replayXp'] ?? 0),
    completedLessons: Number(dayRow?.['completedLessons'] ?? 0),
    originalCorrect: Number(dayRow?.['originalCorrect'] ?? 0),
    reviewSessions: Number(dayRow?.['reviewSessions'] ?? 0),
    minutesSpent: Number(dayRow?.['minutesSpent'] ?? 0),
    goalMet: studyXp >= dailyGoal,
  };
  tx.put('p_day_activity', dayId, nextDay);

  const rewardsId = ids.rewards(userId);
  const rewards = editable((await tx.get('p_rewards', rewardsId)) ?? emptyRewards(userId));
  rewards['studyXp'] = Number(rewards['studyXp']) + award.studyXp;
  rewards['leagueXpLifetime'] = Number(rewards['leagueXpLifetime']) + award.leagueXp;
  if (becameActive) {
    await advanceStreak(tx, userId, rewards, day);
    await extendFriendStreaks(tx, userId, day);
  }
  const visible = Boolean(profile?.['publicOptIn']) && profile?.['ageBand'] !== 'CHILD';
  await grantAchievements(tx, userId, rewards, false, event, visible);
  if (becameActive && isStreakMilestone(Number(rewards['currentStreak']))) {
    putActivity(
      tx,
      operationId(
        'streak',
        userId,
        String(rewards['streakStartDay']),
        String(rewards['currentStreak']),
      ),
      userId,
      'STREAK',
      `Reached a ${String(rewards['currentStreak'])}-day streak`,
      visible,
    );
  }
  await bumpQuests(tx, userId, day, {
    lessons: 0,
    originalCorrect: 0,
    reviewSessions: 0,
    activeDays: becameActive ? 1 : 0,
  });
  await addLeagueXp(tx, userId, week, award.leagueXp, event.occurredAt);
  tx.put('p_rewards', rewardsId, rewards);
  await putCreditedNotice(tx, userId, p.completionId, profile);
}
