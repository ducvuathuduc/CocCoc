// P6-GAME-001/002: apply one lesson.completed.v1 inside the inbox transaction.
// Effects (all atomic with the p_inbox row): reward ledger (FIRST/REPLAY), first-reward marker,
// day activity, aggregate totals, streak, achievements, daily/monthly quests, friend quest,
// league eligible XP and the owner-readable notification hint.
// Rules: SRS FR-GAME-001/002/004, FR-QUEST-001/002, FR-SOCIAL-002 and the deterministic
// reward rules. Day = event server time in the zone selected from immutable history; league
// week = UTC week of the event, so a late delivery still counts for the week it occurred in.
import { ServiceError } from '../../../shared/src/errors.js';
import type { BusinessEvent } from '../../../shared/src/ports.js';
import { putWithReaders } from '../persistence/core.js';
import type { ProgressTx, Row } from '../persistence/port.js';
import {
  ACHIEVEMENTS,
  FRIEND_QUEST,
  FRIEND_QUEST_PREFIX,
  QUESTS,
  isStreakMilestone,
  tierFor,
  type QuestMetric,
} from '../domain/catalog.js';
import { computeAward, isAward } from '../domain/lesson-xp.js';
import { recomputeStreak, STREAK_WINDOW_DAYS } from '../domain/streak.js';
import { addDays, leagueWeek, monthKey, zonedDay } from '../domain/time.js';
import { activeBoostMultiplier } from './boosts.js';
import { extendFriendStreaks } from './settings.js';
import { editable, emptyRewards, ids, isDeleted, operationId, zoneAt } from './records.js';

export type CompletionEvent = Extract<BusinessEvent, { type: 'lesson.completed.v1' }>;

export async function applyLessonCompletion(tx: ProgressTx, event: CompletionEvent): Promise<void> {
  const p = event.payload;
  const userId = p.userId;
  // Tombstone stops rewards; the event is still acknowledged (inbox row) so it is not resent.
  if (await isDeleted(tx, userId)) return;
  if (
    (await tx.get('p_reward_ledger', ids.ledger(userId, p.completionId, 'FIRST'))) ||
    (await tx.get('p_reward_ledger', ids.ledger(userId, p.completionId, 'REPLAY')))
  ) {
    return; // a different event for an already-credited completion never double-awards
  }
  const zone = await zoneAt(tx, userId, event.occurredAt);
  const day = zonedDay(event.occurredAt, zone);
  const week = leagueWeek(event.occurredAt);
  const markerId = ids.firstReward(userId, p.rewardIdentity);
  const marker = p.mode === 'LESSON' ? await tx.get('p_first_rewards', markerId) : null;
  const dayId = ids.day(userId, day);
  const dayRow = await tx.get('p_day_activity', dayId);
  const award = computeAward(p, {
    firstCompletion: p.mode === 'LESSON' && !marker,
    dayStudyXp: Number(dayRow?.['studyXp'] ?? 0),
    dayReplayXp: Number(dayRow?.['replayXp'] ?? 0),
    boostMultiplier: await activeBoostMultiplier(tx, userId, event.occurredAt),
  });
  if (!isAward(award)) {
    const reason = award.ok ? 'INVALID_GRADED_RESULT' : award.reason;
    throw new ServiceError('VALIDATION_ERROR', { details: { reason } });
  }
  if (award.kind === null) return; // PLACEMENT: no XP, activity or quest credit

  tx.put('p_reward_ledger', ids.ledger(userId, p.completionId, award.kind), {
    eventId: event.eventId,
    completionId: p.completionId,
    userId,
    rewardIdentity: p.rewardIdentity,
    kind: award.kind,
    studyXpDelta: award.studyXp,
    leagueXpDelta: award.leagueXp,
    gemsDelta: 0,
    learningDay: day,
    leagueWeek: week,
    occurredAt: event.occurredAt,
    capped: award.capped,
  });
  if (award.kind === 'FIRST') {
    tx.put('p_first_rewards', markerId, {
      userId,
      rewardIdentity: p.rewardIdentity,
      completionId: p.completionId,
    });
  }

  const profile = await tx.get('p_profiles', ids.profile(userId));
  const dailyGoal = Number(profile?.['dailyGoal'] ?? 10);
  const isLesson = p.mode === 'LESSON';
  const becameActive = !dayRow?.['active'];
  const nextDay: Row = {
    userId,
    day,
    zone: (dayRow?.['zone'] as string | undefined) ?? zone,
    active: true,
    protected: Boolean(dayRow?.['protected']),
    studyXp: Number(dayRow?.['studyXp'] ?? 0) + award.studyXp,
    replayXp: Number(dayRow?.['replayXp'] ?? 0) + award.replayXp,
    completedLessons: Number(dayRow?.['completedLessons'] ?? 0) + (isLesson ? 1 : 0),
    originalCorrect: Number(dayRow?.['originalCorrect'] ?? 0) + (isLesson ? p.originalCorrect : 0),
    trackedOriginalCount:
      Number(dayRow?.['trackedOriginalCount'] ?? 0) + (isLesson ? p.originalCount : 0),
    trackedOriginalCorrect:
      Number(dayRow?.['trackedOriginalCorrect'] ?? 0) + (isLesson ? p.originalCorrect : 0),
    reviewSessions: Number(dayRow?.['reviewSessions'] ?? 0) + (p.mode === 'REVIEW' ? 1 : 0),
    minutesSpent: Number(dayRow?.['minutesSpent'] ?? 0),
    goalMet: false,
  };
  nextDay['goalMet'] = Number(nextDay['studyXp']) >= dailyGoal;
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
  await grantAchievements(tx, userId, rewards, award.kind === 'FIRST', event, visible);
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
    lessons: isLesson ? 1 : 0,
    originalCorrect: isLesson ? p.originalCorrect : 0,
    reviewSessions: p.mode === 'REVIEW' ? 1 : 0,
    activeDays: becameActive ? 1 : 0,
  });
  if (isLesson) await advanceFriendQuest(tx, userId, week, rewards);

  await addLeagueXp(tx, userId, week, award.leagueXp, event.occurredAt);

  tx.put('p_rewards', rewardsId, rewards);
  await putCreditedNotice(tx, userId, p.completionId, profile);
}

/** Daily/monthly quest metric increments for one credited completion (FR-QUEST-001). */
export async function bumpQuests(
  tx: ProgressTx,
  userId: string,
  day: string,
  increments: Record<QuestMetric, number>,
): Promise<void> {
  for (const quest of QUESTS) {
    const delta = increments[quest.metric];
    if (!delta) continue;
    const periodKey = quest.period === 'DAY' ? day : monthKey(day);
    const id = ids.quest(userId, quest.period, periodKey, quest.questId);
    const row = await tx.get('p_quests', id);
    tx.put('p_quests', id, {
      ...(row ? editable(row) : {}),
      userId,
      period: quest.period,
      periodKey,
      questId: quest.questId,
      metricValue: Number(row?.['metricValue'] ?? 0) + delta,
      target: quest.target,
      claimed: Boolean(row?.['claimed']),
      claimOperationId: (row?.['claimOperationId'] as string | null | undefined) ?? null,
    });
  }
}

/** League eligible XP for the event's UTC week; a settled or excluded member is not changed. */
export async function addLeagueXp(
  tx: ProgressTx,
  userId: string,
  week: string,
  leagueXp: number,
  occurredAt: string,
): Promise<void> {
  if (leagueXp <= 0) return;
  const memberId = ids.leagueMember(week, userId);
  const member = await tx.get('p_league_members', memberId);
  if (member && !member['settled'] && !member['excluded']) {
    tx.put('p_league_members', memberId, {
      ...editable(member),
      eligibleXp: Number(member['eligibleXp']) + leagueXp,
      lastXpAt: occurredAt,
    });
  }
}

/** Owner-readable "credited" hint for a completion (rewards status by completionId). */
export async function putCreditedNotice(
  tx: ProgressTx,
  userId: string,
  completionId: string,
  profile: Readonly<Row> | null,
): Promise<void> {
  const rewardsId = ids.rewards(userId);
  const notificationId = ids.notification(userId, completionId);
  const existing = await tx.get('p_notifications', notificationId);
  putWithReaders(
    tx,
    'p_notifications',
    notificationId,
    {
      ...(existing ? editable(existing) : {}),
      userId,
      completionId,
      status: 'CREDITED',
      profileRevision: Number(profile?.['revision'] ?? 0),
      rewardRevision: Number((await tx.get('p_rewards', rewardsId))?.['revision'] ?? 0),
    },
    [userId],
  );
}

/** Mark `day` qualified and recompute the uncapped streak (late days rebuild from the window). */
export async function advanceStreak(
  tx: ProgressTx,
  userId: string,
  rewards: Row,
  day: string,
): Promise<void> {
  const last = (rewards['lastQualifiedDay'] as string | null) ?? null;
  const current = Number(rewards['currentStreak'] ?? 0);
  if (last === day) return;
  if (!last || day > last) {
    if (last && addDays(last, 1) === day) {
      rewards['currentStreak'] = current + 1;
    } else {
      if (current > 0) {
        rewards['lostStreak'] = current;
        rewards['lostStreakDay'] = day;
      }
      rewards['currentStreak'] = 1;
      rewards['streakStartDay'] = day;
    }
    rewards['lastQualifiedDay'] = day;
  } else {
    // Late delivery for an earlier day: rebuild from qualified days (staged day included).
    const windowStart = addDays(last, -(STREAK_WINDOW_DAYS - 1));
    const rows = await tx.list('p_day_activity', {
      where: { userId },
      gte: { day: windowStart },
      orderBy: [['day', 'desc']],
      limit: STREAK_WINDOW_DAYS,
    });
    const qualified = new Set(
      rows
        .filter(({ row }) => row['active'] || row['protected'])
        .map(({ row }) => String(row['day'])),
    );
    qualified.add(day);
    const state = recomputeStreak(
      qualified,
      last,
      windowStart,
      (rewards['streakStartDay'] as string | null) ?? null,
    );
    rewards['currentStreak'] = state.currentStreak;
    rewards['streakStartDay'] = state.streakStartDay;
  }
  rewards['bestStreak'] = Math.max(
    Number(rewards['bestStreak'] ?? 0),
    Number(rewards['currentStreak']),
  );
}

export function putActivity(
  tx: ProgressTx,
  eventId: string,
  userId: string,
  kind: 'MILESTONE' | 'QUEST' | 'STREAK',
  publicSummary: string,
  visible: boolean,
): void {
  tx.put('p_activity', ids.activity(eventId), {
    eventId,
    userId,
    kind,
    publicSummary: publicSummary.slice(0, 160),
    visible,
  });
}

export async function grantAchievements(
  tx: ProgressTx,
  userId: string,
  rewards: Row,
  firstCompletion: boolean,
  event: { eventId: string; occurredAt: string },
  visible: boolean,
): Promise<void> {
  const lessons = (await tx.count('p_first_rewards', { userId })) + (firstCompletion ? 1 : 0);
  const values: Record<string, number> = {
    lessons,
    streak: Number(rewards['currentStreak'] ?? 0),
  };
  for (const track of ACHIEVEMENTS) {
    const reached = tierFor(track, values[track.achievementId] ?? 0);
    for (let tier = 1; tier <= reached; tier++) {
      const id = ids.achievement(userId, track.achievementId, tier);
      if (await tx.get('p_achievements', id)) continue;
      tx.put('p_achievements', id, {
        userId,
        achievementId: track.achievementId,
        tier,
        earnedAt: event.occurredAt,
        sourceEventId: event.eventId,
      });
      const threshold = track.thresholds[tier - 1] ?? 0;
      putActivity(tx, id, userId, 'MILESTONE', track.summary(threshold), visible);
    }
  }
}

/** FR-QUEST-002: cooperative weekly quest; reward 10 gems to each member exactly once. */
async function advanceFriendQuest(tx: ProgressTx, userId: string, week: string, rewards: Row) {
  const mine = await tx.list('p_quests', {
    where: { userId, period: 'WEEK', periodKey: week },
    limit: 10,
  });
  const entry = mine.find(({ row }) => String(row['questId']).startsWith(FRIEND_QUEST_PREFIX));
  if (!entry || entry.row['claimed']) return;
  const questId = String(entry.row['questId']);
  const pairId = questId.slice(FRIEND_QUEST_PREFIX.length);
  const friendQuestId = ids.friendQuest(week, pairId);
  const pair = pairId === 'solo' ? null : await tx.get('p_friend_quests', friendQuestId);
  const members: string[] = pair ? (JSON.parse(String(pair['userIdsJson'])) as string[]) : [userId];
  const count = (pair ? Number(pair['count']) : Number(entry.row['metricValue'])) + 1;
  const done = count >= FRIEND_QUEST.target;
  if (pair) {
    if (JSON.parse(String(pair['claimedUserIdsJson'])).length) return;
    tx.put('p_friend_quests', friendQuestId, {
      ...editable(pair),
      count,
      claimedUserIdsJson: JSON.stringify(done ? members : []),
    });
  }
  const opId = operationId('friend-quest', week, pairId === 'solo' ? userId : pairId);
  for (const member of members) {
    const memberQuestId = ids.quest(member, 'WEEK', week, questId);
    const memberQuest = await tx.get('p_quests', memberQuestId);
    if (memberQuest) {
      tx.put('p_quests', memberQuestId, {
        ...editable(memberQuest),
        metricValue: count,
        claimed: done,
        claimOperationId: done ? opId : null,
      });
    }
    if (!done) continue;
    tx.put('p_reward_ledger', ids.ledger(member, opId, 'QUEST'), {
      eventId: operationId('friend-quest-ledger', opId, member),
      completionId: opId,
      userId: member,
      rewardIdentity: FRIEND_QUEST.templateId,
      kind: 'QUEST',
      studyXpDelta: 0,
      leagueXpDelta: 0,
      gemsDelta: FRIEND_QUEST.rewardGems,
      learningDay: week,
      leagueWeek: week,
      occurredAt: tx.nowIso,
      capped: false,
    });
    if (member === userId) {
      rewards['gems'] = Number(rewards['gems']) + FRIEND_QUEST.rewardGems;
    } else {
      const otherId = ids.rewards(member);
      const other = editable((await tx.get('p_rewards', otherId)) ?? emptyRewards(member));
      other['gems'] = Number(other['gems']) + FRIEND_QUEST.rewardGems;
      tx.put('p_rewards', otherId, other);
    }
  }
}
