// Learning-owned persistence port. Only Learning writes these tables (docs/data/DATA_MODEL.md).
// It extends the shared OwnerStore contract (receipts, inbox, owner-table allowlist) with the two
// things Learning's use cases need beyond get-by-id: indexed listing and a receipt-less atomic
// transaction (outbox leasing, seeding), plus row removal (active-slot release).
import type {
  InboxEntry,
  OwnerStore,
  OwnerTransaction,
  ReceiptKey,
  ReceiptOutcome,
} from '../../../shared/src/ports.js';

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
  'l_energy',
  'l_mistakes',
  'l_activity_progress',
] as const;
export type LearningTable = (typeof LEARNING_TABLES)[number];
export type Row = Readonly<Record<string, unknown>>;

export interface LearningTransaction extends OwnerTransaction<LearningTable> {
  /** Stage deletion of a row (no-op when it does not exist). */
  remove(table: LearningTable, id: string): void;
}

export type Scalar = string | number | boolean;
export interface ListQuery {
  equal?: Record<string, Scalar | readonly Scalar[]>;
  lessThan?: Record<string, string | number>;
  lessThanEqual?: Record<string, string | number>;
  greaterThan?: Record<string, string | number>;
  isNull?: readonly string[];
  orderAsc?: string;
  orderDesc?: string;
  limit: number;
  offset?: number;
}
export interface ListResult {
  items: { id: string; row: Row }[];
  /** Total matching rows (may be capped by the backend; used for counts like the watermark). */
  total: number;
}

export interface LearningPersistence extends Omit<
  OwnerStore<'learning', LearningTable>,
  'commitWithReceipt' | 'applyInboxEvent'
> {
  /**
   * Same key + same body hash replays the stored response; same key + different hash is
   * IDEMPOTENCY_CONFLICT; otherwise the effect's staged writes and the receipt commit together.
   * A concurrent write to any row the effect read makes the commit retry the whole effect on
   * fresh state; a persistent conflict surfaces as REVISION_CONFLICT.
   */
  commitWithReceipt(
    key: ReceiptKey,
    bodyHash: string,
    effect: (tx: LearningTransaction) => Promise<{ statusCode: number; response: unknown }>,
  ): Promise<ReceiptOutcome>;
  applyInboxEvent(
    entry: Omit<InboxEntry, 'appliedAt'>,
    effect: (tx: LearningTransaction) => Promise<void>,
  ): Promise<'accepted' | 'replayed'>;
  /** Atomic staged writes without an idempotency receipt (dispatcher leases, seeding). */
  transact<R>(effect: (tx: LearningTransaction) => Promise<R>): Promise<R>;
  list(table: LearningTable, query: ListQuery): Promise<ListResult>;
}

/** Receipts are kept 30 days (DATA_MODEL l_receipts). */
export const RECEIPT_TTL_MS = 30 * 24 * 60 * 60 * 1000;
