// Adapter-neutral Progress store. A driver supplies single-attempt primitives (point read,
// bounded query, count, atomic commit with conflict detection); this core adds owner-table
// allowlisting, schema validation, mutable-row stamping (revision/createdAt/updatedAt),
// optimistic retry, idempotency receipts (p_receipts) and the event inbox (p_inbox).
// Hosted-safe: no fixture code. The memory driver (tests/dev) and the Appwrite TablesDB driver
// (hosting) share these exact semantics, so a domain test on memory exercises the same rules.
import { createHash } from 'node:crypto';
import { ServiceError } from '../../../shared/src/errors.js';
import type {
  AdapterKind,
  InboxEntry,
  ReceiptKey,
  ReceiptOutcome,
  StoredReceipt,
} from '../../../shared/src/ports.js';
import {
  PROGRESS_TABLES,
  type ListQuery,
  type ListedRow,
  type ProgressPersistence,
  type ProgressTable,
  type ProgressTx,
  type Row,
  type Scalar,
} from './port.js';
import { PROGRESS_SCHEMA, type ColumnSpec, type TableSpec } from './schema.js';

export const RECEIPT_TTL_MS = 30 * 24 * 60 * 60 * 1000;
export const MAX_ATTEMPTS = 4;
const ISO = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$/;

/** Thrown by a driver when a commit lost an optimistic race; the core re-runs the work. */
export class TransactionConflict extends Error {
  constructor(readonly reason: string) {
    super(`TRANSACTION_CONFLICT:${reason}`);
    this.name = 'TransactionConflict';
  }
}

export interface StagedOp {
  /** upsert only in non-strict (shared OwnerStore contract) mode: blind put of an unread row. */
  action: 'create' | 'update' | 'delete' | 'upsert';
  table: ProgressTable;
  id: string;
  data?: Row;
  /** For update/delete: the revision read in this attempt (optimistic precondition). */
  expectedRevision?: number;
  /** Row-level read grants (Appwrite Role.user ids); only p_notifications uses them. */
  readers?: string[];
}

export interface DriverAttempt {
  get(table: ProgressTable, id: string): Promise<Row | null>;
  list(table: ProgressTable, query: ListQuery): Promise<ListedRow[]>;
  count(table: ProgressTable, where: Readonly<Record<string, Scalar>>): Promise<number>;
  /** Apply every op atomically or throw TransactionConflict / ServiceError. */
  commit(ops: StagedOp[]): Promise<void>;
}

export interface ProgressDriver {
  readonly kind: AdapterKind;
  readonly admittedForHosting: boolean;
  ping(): Promise<void>;
  begin(): DriverAttempt;
  read(table: ProgressTable, id: string): Promise<Row | null>;
  list(table: ProgressTable, query: ListQuery): Promise<ListedRow[]>;
  /** Optional pause between conflict retries (jitter); memory uses none. */
  backoff?(attempt: number): Promise<void>;
}

export interface CoreOptions {
  nowMs?: () => number;
  /** Validate rows against PROGRESS_SCHEMA and stamp mutable fields (on for real adapters). */
  strictSchema?: boolean;
}

const OWNED = new Set<string>(PROGRESS_TABLES);
const SCHEMA = PROGRESS_SCHEMA as unknown as Record<string, TableSpec>;

export function assertOwned(table: string): asserts table is ProgressTable {
  if (!OWNED.has(table)) throw new ServiceError('FORBIDDEN', { details: { table } });
}

/** Deterministic row ID: first 32 hex chars of SHA-256(namespace|parts) (DATA_MODEL). */
export function rowId(namespace: string, ...parts: Array<string | number>): string {
  return createHash('sha256')
    .update([namespace, ...parts.map(String)].join('|'), 'utf8')
    .digest('hex')
    .slice(0, 32);
}

function invalid(table: string, column: string, reason: string): never {
  throw new ServiceError('INTERNAL_ERROR', {
    details: { reason: 'ROW_SCHEMA_VIOLATION', table, column, violation: reason },
  });
}

function checkColumn(table: string, key: string, spec: ColumnSpec, value: unknown): void {
  if (value === null || value === undefined) {
    if (spec.required) invalid(table, key, 'required');
    return;
  }
  switch (spec.type) {
    case 'string':
      if (typeof value !== 'string') invalid(table, key, 'type');
      if (spec.size !== undefined && value.length > spec.size) invalid(table, key, 'size');
      return;
    case 'integer':
      if (!Number.isSafeInteger(value)) invalid(table, key, 'type');
      if (spec.min !== undefined && (value as number) < spec.min) invalid(table, key, 'min');
      if (spec.max !== undefined && (value as number) > spec.max) invalid(table, key, 'max');
      return;
    case 'boolean':
      if (typeof value !== 'boolean') invalid(table, key, 'type');
      return;
    case 'datetime':
      if (typeof value !== 'string' || !ISO.test(value) || Number.isNaN(Date.parse(value))) {
        invalid(table, key, 'type');
      }
      return;
    case 'enum':
      if (typeof value !== 'string' || !spec.elements?.includes(value)) invalid(table, key, 'enum');
      return;
  }
}

export function validateRow(table: ProgressTable, row: Row): void {
  const spec = SCHEMA[table];
  if (!spec) invalid(table, '*', 'unknown table');
  for (const key of Object.keys(row)) {
    if (!spec.columns[key]) invalid(table, key, 'undeclared column');
  }
  for (const [key, column] of Object.entries(spec.columns))
    checkColumn(table, key, column, row[key]);
}

export function isMutable(table: ProgressTable): boolean {
  return Boolean(SCHEMA[table]?.mutable);
}

/** Normalize adapter datetimes to ISO-8601 with Z so domain comparisons are lexical-safe. */
export function normalizeRow(table: ProgressTable, row: Row): Row {
  const spec = SCHEMA[table];
  const out: Row = {};
  for (const [key, value] of Object.entries(row)) {
    if (key.startsWith('$')) continue;
    const column = spec?.columns[key];
    if (column?.type === 'datetime' && typeof value === 'string') {
      out[key] = new Date(value).toISOString();
    } else out[key] = value;
  }
  return out;
}

function matches(row: Row, query: ListQuery): boolean {
  for (const [key, value] of Object.entries(query.where ?? {})) {
    if ((row[key] ?? null) !== value) return false;
  }
  for (const [key, values] of Object.entries(query.anyOf ?? {})) {
    if (!values.includes(row[key] as string)) return false;
  }
  for (const [key, bound] of Object.entries(query.gte ?? {})) {
    const value = row[key];
    if (value === null || value === undefined || (value as string | number) < bound) return false;
  }
  for (const [key, bound] of Object.entries(query.lt ?? {})) {
    const value = row[key];
    if (value === null || value === undefined || (value as string | number) >= bound) return false;
  }
  return true;
}

/** Shared in-process sort used by the memory driver and by staged-row overlays. */
export function sortAndLimit(rows: ListedRow[], query: ListQuery): ListedRow[] {
  const order = query.orderBy ?? [];
  const sorted = [...rows].sort((a, b) => {
    for (const [key, direction] of order) {
      const x = a.row[key] as string | number | null | undefined;
      const y = b.row[key] as string | number | null | undefined;
      if (x === y) continue;
      // Nulls sort last in both directions (stable "unknown" placement).
      if (x === null || x === undefined) return 1;
      if (y === null || y === undefined) return -1;
      const cmp = x < y ? -1 : 1;
      return direction === 'asc' ? cmp : -cmp;
    }
    return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
  });
  return sorted.slice(0, clampLimit(query.limit));
}

export function clampLimit(limit: number | undefined): number {
  return Math.max(1, Math.min(limit ?? 100, 500));
}

export function rowMatches(row: Row, query: ListQuery): boolean {
  return matches(row, query);
}

interface Cached {
  row: Row | null;
}

class Attempt implements ProgressTx {
  readonly nowMs: number;
  readonly nowIso: string;
  private readonly cache = new Map<string, Cached>();
  private readonly staged = new Map<string, StagedOp>();
  constructor(
    private readonly driver: DriverAttempt,
    private readonly strict: boolean,
    now: number,
  ) {
    this.nowMs = now;
    this.nowIso = new Date(now).toISOString();
  }
  private key(table: string, id: string): string {
    return `${table}\u0000${id}`;
  }
  async get(table: ProgressTable, id: string): Promise<Readonly<Row> | null> {
    assertOwned(table);
    const key = this.key(table, id);
    const staged = this.staged.get(key);
    if (staged) return staged.action === 'delete' ? null : structuredClone(staged.data ?? null);
    let cached = this.cache.get(key);
    if (!cached) {
      cached = { row: await this.driver.get(table, id) };
      this.cache.set(key, cached);
    }
    return cached.row ? structuredClone(cached.row) : null;
  }
  put(table: ProgressTable, id: string, input: Record<string, unknown>): void {
    this.stage(table, id, input);
  }
  /** Stage a write with optional row read grants (p_notifications owner read). */
  stage(table: ProgressTable, id: string, input: Record<string, unknown>, readers?: string[]) {
    assertOwned(table);
    const key = this.key(table, id);
    const previous = this.staged.get(key);
    const base = this.cache.get(key)?.row ?? null;
    const row: Row = { ...input };
    if (this.strict && isMutable(table)) {
      const prior = (previous?.action !== 'delete' ? previous?.data : undefined) ?? base;
      row['createdAt'] = (prior?.['createdAt'] as string | undefined) ?? this.nowIso;
      row['updatedAt'] = this.nowIso;
      row['revision'] = base ? Number(base['revision'] ?? 0) + 1 : 0;
    }
    if (this.strict) validateRow(table, row);
    const action: StagedOp['action'] = base ? 'update' : this.strict ? 'create' : 'upsert';
    if (!base && !isMutable(table) && previous) invalid(table, '*', 'immutable row rewritten');
    if (base && !isMutable(table)) invalid(table, '*', 'immutable row updated');
    const op: StagedOp = { action, table, id, data: row };
    if (base) op.expectedRevision = Number(base['revision'] ?? 0);
    if (readers) op.readers = readers;
    this.staged.set(key, op);
  }
  delete(table: ProgressTable, id: string): void {
    assertOwned(table);
    const key = this.key(table, id);
    const base = this.cache.get(key)?.row ?? null;
    if (!base) {
      this.staged.delete(key);
      return;
    }
    this.staged.set(key, {
      action: 'delete',
      table,
      id,
      expectedRevision: Number(base['revision'] ?? 0),
    });
  }
  async list(table: ProgressTable, query: ListQuery): Promise<ListedRow[]> {
    assertOwned(table);
    const committed = await this.driver.list(table, { ...query, limit: 500 });
    for (const entry of committed) {
      // Seed the attempt cache so a listed row can be updated or deleted in this attempt.
      const key = this.key(table, entry.id);
      if (!this.cache.has(key)) this.cache.set(key, { row: entry.row as Row });
    }
    const byId = new Map(committed.map((entry) => [entry.id, entry]));
    for (const op of this.staged.values()) {
      if (op.table !== table) continue;
      if (op.action === 'delete') byId.delete(op.id);
      else if (op.data && matches(op.data, query)) byId.set(op.id, { id: op.id, row: op.data });
      else byId.delete(op.id);
    }
    return sortAndLimit([...byId.values()], query).map((entry) => structuredClone(entry));
  }
  count(table: ProgressTable, where: Readonly<Record<string, Scalar>>): Promise<number> {
    assertOwned(table);
    return this.driver.count(table, where);
  }
  ops(): StagedOp[] {
    return [...this.staged.values()];
  }
}

export interface CoreStore extends ProgressPersistence {
  readonly driver: ProgressDriver;
}

/** Stage a row with read grants when the transaction supports it (p_notifications). */
export function putWithReaders(
  tx: ProgressTx,
  table: ProgressTable,
  id: string,
  row: Row,
  readers: string[],
): void {
  if (tx instanceof Attempt) tx.stage(table, id, row, readers);
  else tx.put(table, id, row);
}

export function createProgressStore(driver: ProgressDriver, options: CoreOptions = {}): CoreStore {
  const nowMs = options.nowMs ?? Date.now;
  const strict = options.strictSchema ?? true;

  async function transact<R>(work: (tx: ProgressTx) => Promise<R>): Promise<R> {
    for (let attempt = 1; ; attempt++) {
      const attemptDriver = driver.begin();
      const tx = new Attempt(attemptDriver, strict, nowMs());
      const result = await work(tx);
      const ops = tx.ops();
      try {
        if (ops.length) await attemptDriver.commit(ops);
        return result;
      } catch (error) {
        if (!(error instanceof TransactionConflict)) throw error;
        if (attempt >= MAX_ATTEMPTS) {
          throw new ServiceError('REVISION_CONFLICT', {
            message: 'Concurrent update; fetch the current state and retry.',
            details: { reason: 'TRANSACTION_CONFLICT' },
          });
        }
        await driver.backoff?.(attempt);
      }
    }
  }

  const receiptId = (key: ReceiptKey) => rowId('p_receipts', key.userId, key.operation, key.key);

  const store: CoreStore = {
    service: 'progress',
    driver,
    get kind() {
      return driver.kind;
    },
    get admittedForHosting() {
      return driver.admittedForHosting;
    },
    ownedTables: PROGRESS_TABLES,
    ping: () => driver.ping(),
    nowMs,
    transact,
    async read(table, id) {
      assertOwned(table);
      return driver.read(table, id);
    },
    async list(table, query) {
      assertOwned(table);
      return driver.list(table, query);
    },
    commitWithReceipt(key, bodyHash, effect) {
      return transact(async (tx): Promise<ReceiptOutcome> => {
        const id = receiptId(key);
        const existing = await tx.get('p_receipts', id);
        if (existing && Date.parse(String(existing['expiresAt'])) > tx.nowMs) {
          if (existing['bodyHash'] !== bodyHash) throw new ServiceError('IDEMPOTENCY_CONFLICT');
          return { status: 'replayed', receipt: toReceipt(existing) };
        }
        const result = await effect(tx);
        const receipt: StoredReceipt = {
          ...key,
          bodyHash,
          statusCode: result.statusCode,
          response: structuredClone(result.response),
          expiresAt: new Date(tx.nowMs + RECEIPT_TTL_MS).toISOString(),
        };
        const responseJson = JSON.stringify(receipt.response ?? null);
        if (responseJson.length > 16384) invalid('p_receipts', 'responseJson', 'size');
        tx.put('p_receipts', id, {
          userId: key.userId,
          operation: key.operation,
          key: key.key,
          bodyHash,
          statusCode: result.statusCode,
          responseJson,
          expiresAt: receipt.expiresAt,
        });
        return { status: 'created', receipt };
      });
    },
    applyInboxEvent(entry, effect) {
      return transact(async (tx) => {
        const existing = await tx.get('p_inbox', entry.eventId);
        if (existing) {
          if (existing['bodyHash'] !== entry.bodyHash || existing['type'] !== entry.type) {
            throw new ServiceError('IDEMPOTENCY_CONFLICT', { details: { eventId: entry.eventId } });
          }
          return 'replayed' as const;
        }
        await effect(tx);
        const row: Omit<InboxEntry, 'eventId'> & Row = {
          eventId: entry.eventId,
          type: entry.type,
          bodyHash: entry.bodyHash,
          appliedAt: tx.nowIso,
          resultJson: '{}',
        };
        tx.put('p_inbox', entry.eventId, row);
        return 'accepted' as const;
      });
    },
  };
  return store;
}

function toReceipt(row: Readonly<Row>): StoredReceipt {
  let response: unknown = null;
  try {
    response = JSON.parse(String(row['responseJson'] ?? 'null'));
  } catch {
    response = null;
  }
  return {
    userId: String(row['userId']),
    operation: String(row['operation']),
    key: String(row['key']),
    bodyHash: String(row['bodyHash']),
    statusCode: Number(row['statusCode']),
    response,
    expiresAt: String(row['expiresAt']),
  };
}
