// Progress-owned persistence port. Only Progress writes these tables (docs/data/DATA_MODEL.md).
import type { OwnerStore } from '../../../shared/src/ports.js';

export const PROGRESS_TABLES = [
  'p_profiles',
  'p_zone_history',
  'p_rewards',
  'p_reward_ledger',
  'p_first_rewards',
  'p_day_activity',
  'p_freeze_ledger',
  'p_quests',
  'p_follows',
  'p_friend_quests',
  'p_league_members',
  'p_league_runs',
  'p_activity',
  'p_achievements',
  'p_notifications',
  'p_inbox',
  'p_outbox',
  'p_receipts',
  'p_deletions',
] as const;
export type ProgressTable = (typeof PROGRESS_TABLES)[number];
export type ProgressPersistence = OwnerStore<'progress', ProgressTable>;
