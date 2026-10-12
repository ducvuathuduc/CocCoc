// Optimistic transaction engine shared by the durable Appwrite adapter and the local memory adapter.
// An effect reads rows through the transaction (every read is recorded with its version), stages
// put/remove writes, and the backend commits them atomically only if every recorded read is still
// current. A conflict re-runs the effect on fresh state (bounded); receipts and inbox rows are
// ordinary staged rows, so "effect + receipt" and "inbox + effect" are one atomic commit.
import { ServiceError } from '../../../shared/src/errors.js';
import type {
  InboxEntry,
  ReceiptKey,
  ReceiptOutcome,
  StoredReceipt,
} from '../../../shared/src/ports.js';
import { ids } from './ids.js';
import {
  RECEIPT_TTL_MS,
  type LearningPersistence,
  type LearningTable,
  type LearningTransaction,
  type ListQuery,
  type ListResult,
  type Row,
} from './port.js';

export interface VersionedRow {
  row: Row;
  /** Opaque version (Appwrite $updatedAt / memory counter). */
  version: string;
}
export type StagedOp =
  | { action: 'create' | 'update'; table: LearningTable; id: string; data: Record<string, unknown> }
  | { action: 'delete'; table: LearningTable; id: string };
export interface RecordedRead {
  table: LearningTable;
  id: string;
  version: string | null;
}

export interface Backend {
  fetch(table: LearningTable, id: string): Promise<VersionedRow | null>;
  /** Apply ops atomically iff every recorded read still has its version. */
  commit(
    ops: readonly StagedOp[],
    reads: readonly RecordedRead[],
  ): Promise<'committed' | 'conflict'>;
  list(table: LearningTable, query: ListQuery): Promise<ListResult>;
  ping(): Promise<void>;
}

export interface EngineOptions {
  kind: 'memory' | 'appwrite';
  admittedForHosting: boolean;
  ownedTables: readonly LearningTable[];
  backend: Backend;
  nowMs?: () => number;
  maxAttempts?: number;
}

const clone = <V>(value: V): V => structuredClone(value);

export function createEngine(options: EngineOptions): LearningPersistence {
  const { backend, ownedTables } = options;
  const nowMs = options.nowMs ?? Date.now;
  const maxAttempts = options.maxAttempts ?? 4;
  const owned = new Set<string>(ownedTables);
  const locks = new Map<string, Promise<unknown>>();

  function assertOwned(table: string): asserts table is LearningTable {
    if (!owned.has(table)) throw new ServiceError('FORBIDDEN', { details: { table } });
  }

  /** In-process serialization per receipt/inbox key (cross-process safety comes from commit). */
  function serialize<R>(key: string, work: () => Promise<R>): Promise<R> {
    const previous = locks.get(key) ?? Promise.resolve();
    const next = previous.then(work, work);
    const settled = next.then(
      () => undefined,
      () => undefined,
    );
    locks.set(key, settled);
    void settled.then(() => {
      if (locks.get(key) === settled) locks.delete(key);
    });
    return next;
  }

  async function attempt<R>(
    work: (tx: LearningTransaction) => Promise<R>,
  ): Promise<{ status: 'committed'; result: R } | { status: 'conflict' }> {
    const reads = new Map<string, RecordedRead & { row: Row | null }>();
    const staged = new Map<
      string,
      { table: LearningTable; id: string; data: Record<string, unknown> | null }
    >();
    const keyOf = (table: string, id: string) => `${table}\u0000${id}`;
    async function load(table: LearningTable, id: string) {
      const key = keyOf(table, id);
      const known = reads.get(key);
      if (known) return known;
      const fetched = await backend.fetch(table, id);
      const entry = {
        table,
        id,
        version: fetched?.version ?? null,
        row: fetched ? fetched.row : null,
      };
      reads.set(key, entry);
      return entry;
    }
    const tx: LearningTransaction = {
      async get(table, id) {
        assertOwned(table);
        const pending = staged.get(keyOf(table, id));
        if (pending) return pending.data ? clone(pending.data) : null;
        const entry = await load(table, id);
        return entry.row ? clone(entry.row) : null;
      },
      put(table, id, row) {
        assertOwned(table);
        staged.set(keyOf(table, id), { table, id, data: clone(row) });
      },
      remove(table, id) {
        assertOwned(table);
        staged.set(keyOf(table, id), { table, id, data: null });
      },
    };
    const result = await work(tx);
    const ops: StagedOp[] = [];
    for (const [key, write] of staged) {
      const before = reads.get(key) ?? (await load(write.table, write.id));
      if (write.data) {
        ops.push({
          action: before.version === null ? 'create' : 'update',
          table: write.table,
          id: write.id,
          data: write.data,
        });
      } else if (before.version !== null) {
        ops.push({ action: 'delete', table: write.table, id: write.id });
      }
    }
    if (!ops.length) return { status: 'committed', result };
    const outcome = await backend.commit(
      ops,
      [...reads.values()].map(({ table, id, version }) => ({ table, id, version })),
    );
    return outcome === 'committed' ? { status: 'committed', result } : { status: 'conflict' };
  }

  async function withRetry<R>(
    work: (tx: LearningTransaction) => Promise<R>,
    before?: () => Promise<R | undefined>,
  ): Promise<R> {
    for (let i = 0; i < maxAttempts; i++) {
      if (before) {
        const early = await before();
        if (early !== undefined) return early;
      }
      const outcome = await attempt(work);
      if (outcome.status === 'committed') return outcome.result;
    }
    throw new ServiceError('REVISION_CONFLICT', { details: { reason: 'TRANSACTION_CONFLICT' } });
  }

  function receiptFromRow(row: Row): StoredReceipt {
    return {
      userId: String(row['userId']),
      operation: String(row['operation']),
      key: String(row['key']),
      bodyHash: String(row['bodyHash']),
      statusCode: Number(row['statusCode']),
      response: JSON.parse(String(row['responseJson'])) as unknown,
      expiresAt: String(row['expiresAt']),
    };
  }

  const store: LearningPersistence = {
    service: 'learning',
    kind: options.kind,
    admittedForHosting: options.admittedForHosting,
    ownedTables,
    ping: () => backend.ping(),
    async read(table, id) {
      assertOwned(table);
      const found = await backend.fetch(table, id);
      return found ? clone(found.row) : null;
    },
    async list(table, query) {
      assertOwned(table);
      return backend.list(table, query);
    },
    transact: (effect) => withRetry(effect),
    commitWithReceipt(key: ReceiptKey, bodyHash, effect) {
      const id = ids.receipt(key.userId, key.operation, key.key);
      const replay = async (): Promise<ReceiptOutcome | undefined> => {
        const existing = await backend.fetch('l_receipts', id);
        if (!existing || Date.parse(String(existing.row['expiresAt'])) <= nowMs()) return undefined;
        if (existing.row['bodyHash'] !== bodyHash) throw new ServiceError('IDEMPOTENCY_CONFLICT');
        return { status: 'replayed', receipt: receiptFromRow(existing.row) };
      };
      return serialize(`receipt:${id}`, () =>
        withRetry<ReceiptOutcome>(async (tx) => {
          const current = await tx.get('l_receipts', id);
          if (current && Date.parse(String(current['expiresAt'])) > nowMs()) {
            // A concurrent commit won between the replay check and this attempt.
            if (current['bodyHash'] !== bodyHash) throw new ServiceError('IDEMPOTENCY_CONFLICT');
            return { status: 'replayed', receipt: receiptFromRow(current) };
          }
          const result = await effect(tx);
          const now = new Date(nowMs()).toISOString();
          const responseJson = JSON.stringify(result.response ?? null);
          if (responseJson.length > 16384)
            throw new ServiceError('INTERNAL_ERROR', { details: { reason: 'RECEIPT_TOO_LARGE' } });
          const receipt: StoredReceipt = {
            ...key,
            bodyHash,
            statusCode: result.statusCode,
            response: clone(result.response),
            expiresAt: new Date(nowMs() + RECEIPT_TTL_MS).toISOString(),
          };
          tx.put('l_receipts', id, {
            userId: key.userId,
            operation: key.operation,
            key: key.key,
            bodyHash,
            statusCode: result.statusCode,
            responseJson,
            expiresAt: receipt.expiresAt,
            revision: current ? Number(current['revision'] ?? 0) + 1 : 0,
            createdAt: current ? String(current['createdAt']) : now,
            updatedAt: now,
          });
          return { status: 'created', receipt };
        }, replay),
      );
    },
    applyInboxEvent(entry: Omit<InboxEntry, 'appliedAt'>, effect) {
      return serialize(`inbox:${entry.eventId}`, () =>
        withRetry<'accepted' | 'replayed'>(async (tx) => {
          const existing = await tx.get('l_inbox', entry.eventId);
          if (existing) {
            if (existing['bodyHash'] !== entry.bodyHash || existing['type'] !== entry.type) {
              throw new ServiceError('IDEMPOTENCY_CONFLICT', {
                details: { eventId: entry.eventId },
              });
            }
            return 'replayed';
          }
          await effect(tx);
          const now = new Date(nowMs()).toISOString();
          tx.put('l_inbox', entry.eventId, {
            eventId: entry.eventId,
            type: entry.type,
            bodyHash: entry.bodyHash,
            appliedAt: now,
            revision: 0,
            createdAt: now,
            updatedAt: now,
          });
          return 'accepted';
        }),
      );
    },
  };
  return store;
}
