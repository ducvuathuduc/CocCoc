// Learning-owned persistence port. Only Learning writes these tables (docs/data/DATA_MODEL.md).
import type { OwnerStore } from '../../../shared/src/ports.js';

export const LEARNING_TABLES = [
  'l_courses',
  'l_content_versions',
  'l_enrollments',
  'l_active_slots',
  'l_sessions',
  'l_answers',
  'l_review_items',
  'l_reports',
  'l_receipts',
  'l_outbox',
  'l_inbox',
] as const;
export type LearningTable = (typeof LEARNING_TABLES)[number];
export type LearningPersistence = OwnerStore<'learning', LearningTable>;
