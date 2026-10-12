// Versioned server config for quests and achievements (DATA_MODEL: templates are config, not
// rows). Values come from SRS FR-QUEST-001/002 and FR-GAME-004.

export type QuestMetric = 'lessons' | 'originalCorrect' | 'reviewSessions' | 'activeDays';
export interface QuestTemplate {
  questId: string;
  period: 'DAY' | 'MONTH';
  metric: QuestMetric;
  target: number;
  rewardGems: number;
  /** Monthly challenge completion also writes this p_achievements badge (tier 0). */
  badge?: boolean;
}

export const QUEST_CATALOG_VERSION = 'q1';
export const QUESTS: readonly QuestTemplate[] = [
  { questId: 'daily_lessons', period: 'DAY', metric: 'lessons', target: 2, rewardGems: 5 },
  {
    questId: 'daily_correct',
    period: 'DAY',
    metric: 'originalCorrect',
    target: 15,
    rewardGems: 5,
  },
  { questId: 'daily_review', period: 'DAY', metric: 'reviewSessions', target: 1, rewardGems: 5 },
  {
    questId: 'monthly_active_days',
    period: 'MONTH',
    metric: 'activeDays',
    target: 20,
    rewardGems: 0,
    badge: true,
  },
];

export const FRIEND_QUEST = { templateId: 'lessons10', target: 10, rewardGems: 10 } as const;
export const FRIEND_QUEST_PREFIX = 'friend_';

export interface AchievementTrack {
  achievementId: string;
  thresholds: readonly number[];
  summary: (threshold: number) => string;
}
export const ACHIEVEMENTS: readonly AchievementTrack[] = [
  {
    achievementId: 'lessons',
    thresholds: [5, 20, 50],
    summary: (n) => `Completed ${n} lessons`,
  },
  {
    achievementId: 'streak',
    thresholds: [3, 7, 30],
    summary: (n) => `Reached a ${n}-day streak`,
  },
];

/** Highest tier (1-based) reached for a value; 0 when no threshold is met. */
export function tierFor(track: AchievementTrack, value: number): number {
  let tier = 0;
  track.thresholds.forEach((threshold, index) => {
    if (value >= threshold) tier = index + 1;
  });
  return tier;
}

export const STREAK_MILESTONES = [7, 30, 100, 365] as const;
export function isStreakMilestone(streak: number): boolean {
  return (
    (STREAK_MILESTONES as readonly number[]).includes(streak) ||
    (streak > 365 && streak % 365 === 0)
  );
}
