// Progress-owned persistence port. Only Progress writes these tables (docs/data/DATA_MODEL.md).
// The shared OwnerStore contract (receipts + inbox) is extended with a generic optimistic
// transaction, deletes and bounded owner-table queries; every adapter (memory for tests/dev,
// Appwrite TablesDB for hosting) implements the same driver contract in ./core.ts.
import type {
  InboxEntry,
  OwnerStore,
  OwnerTransaction,
  ReceiptKey,
  ReceiptOutcome,
} from '../../../shared/src/ports.js';
import { PROGRESS_SCHEMA } from './schema.js';

export type ProgressTable = keyof typeof PROGRESS_SCHEMA;
export const PROGRESS_TABLES = Object.keys(PROGRESS_SCHEMA) as ProgressTable[];

export type Row = Record<string, unknown>;
export type Scalar = string | number | boolean | null;

export interface ListQuery {
  /** Equality filters (AND). */
  where?: Readonly<Record<string, Scalar>>;
  /** Column value is one of the listed strings (at most 100 values). */
  anyOf?: Readonly<Record<string, readonly string[]>>;
  /** Inclusive lower / exclusive upper bounds on string or integer columns. */
  gte?: Readonly<Record<string, string | number>>;
  lt?: Readonly<Record<string, string | number>>;
  /** Sort keys; the row id is always the final tiebreaker. */
  orderBy?: ReadonlyArray<readonly [string, 'asc' | 'desc']>;
  /** Maximum rows returned (1..500). */
  limit?: number;
}
export interface ListedRow {
  id: string;
  row: Readonly<Row>;
}

export interface ProgressTx extends OwnerTransaction<ProgressTable> {
  /** Stage a delete of a row previously read in this transaction. */
  delete(table: ProgressTable, id: string): void;
  /** Committed rows matching the query with this transaction's staged writes overlaid. */
  list(table: ProgressTable, query: ListQuery): Promise<ListedRow[]>;
  /** Committed row count for equality filters (staged writes not included). */
  count(table: ProgressTable, where: Readonly<Record<string, Scalar>>): Promise<number>;
  /** Server clock for this attempt (ISO-8601 UTC); never the client's clock. */
  readonly nowIso: string;
  readonly nowMs: number;
}

export interface ProgressPersistence extends OwnerStore<'progress', ProgressTable> {
  /** Optimistic transaction: conflicts (concurrent update, duplicate create) re-run `work`. */
  transact<R>(work: (tx: ProgressTx) => Promise<R>): Promise<R>;
  commitWithReceipt(
    key: ReceiptKey,
    bodyHash: string,
    effect: (tx: ProgressTx) => Promise<{ statusCode: number; response: unknown }>,
  ): Promise<ReceiptOutcome>;
  applyInboxEvent(
    entry: Omit<InboxEntry, 'appliedAt'>,
    effect: (tx: ProgressTx) => Promise<void>,
  ): Promise<'accepted' | 'replayed'>;
  list(table: ProgressTable, query: ListQuery): Promise<ListedRow[]>;
  nowMs(): number;
}

/** Progress effects receive the extended transaction (a superset of OwnerTransaction). */
export type ProgressEffect<R> = (tx: ProgressTx) => Promise<R>;
