// AI-owned persistence port. Only AI writes these tables (docs/data/DATA_MODEL.md).
// It extends the shared OwnerStore contract (receipts, inbox, owner-table allowlist) with indexed
// listing, a receipt-less atomic transaction (outbox leasing, account purge) and row removal,
// the same shape as Learning's port so both run on the same optimistic engine design.
import type {
  InboxEntry,
  OwnerStore,
  OwnerTransaction,
  ReceiptKey,
  ReceiptOutcome,
} from '../../../shared/src/ports.js';

export const AI_TABLES = [
  'a_voice_sessions',
  'a_active_slots',
  'a_usage',
  'a_jobs',
  'a_receipts',
  'a_inbox',
  'a_outbox',
  'a_conversations',
] as const;
export type AiTable = (typeof AI_TABLES)[number];
export type Row = Readonly<Record<string, unknown>>;

export interface AiTransaction extends OwnerTransaction<AiTable> {
  /** Stage deletion of a row (no-op when it does not exist). */
  remove(table: AiTable, id: string): void;
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
  /** Total matching rows (may be capped by the backend). */
  total: number;
}

export interface AiPersistence extends Omit<
  OwnerStore<'ai', AiTable>,
  'commitWithReceipt' | 'applyInboxEvent'
> {
  /**
   * Same key + same body hash replays the stored response; same key + different hash is
   * IDEMPOTENCY_CONFLICT; otherwise the effect's staged writes and the receipt commit together.
   * A concurrent write to any row the effect read re-runs the effect on fresh state; a persistent
   * conflict surfaces as REVISION_CONFLICT.
   */
  commitWithReceipt(
    key: ReceiptKey,
    bodyHash: string,
    effect: (tx: AiTransaction) => Promise<{ statusCode: number; response: unknown }>,
  ): Promise<ReceiptOutcome>;
  /** a_inbox has no `type` column (DATA_MODEL): the row stores eventId/bodyHash/appliedAt. */
  applyInboxEvent(
    entry: Omit<InboxEntry, 'appliedAt'>,
    effect: (tx: AiTransaction) => Promise<void>,
  ): Promise<'accepted' | 'replayed'>;
  /** Atomic staged writes without an idempotency receipt (outbox leases, purge batches). */
  transact<R>(effect: (tx: AiTransaction) => Promise<R>): Promise<R>;
  list(table: AiTable, query: ListQuery): Promise<ListResult>;
}

/** Receipts are kept 30 days (DATA_MODEL a_receipts columnsFrom l_receipts). */
export const RECEIPT_TTL_MS = 30 * 24 * 60 * 60 * 1000;
