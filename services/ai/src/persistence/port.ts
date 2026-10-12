// AI-owned persistence port. Only AI writes these tables (docs/data/DATA_MODEL.md).
import type { OwnerStore } from '../../../shared/src/ports.js';

export const AI_TABLES = [
  'a_voice_sessions',
  'a_active_slots',
  'a_usage',
  'a_jobs',
  'a_receipts',
  'a_inbox',
  'a_outbox',
] as const;
export type AiTable = (typeof AI_TABLES)[number];
export type AiPersistence = OwnerStore<'ai', AiTable>;
