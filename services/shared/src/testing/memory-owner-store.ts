// LOCAL TEST ADAPTER ONLY. Never imported by a hosted entrypoint (enforced by tests and by
// createRouter refusing kind 'memory' in hosted mode). Not durable storage.
import { ServiceError } from '../errors.js';
import type {
  InboxEntry,
  OwnerStore,
  OwnerTransaction,
  ReceiptKey,
  ServiceName,
  StoredReceipt,
} from '../ports.js';

const RECEIPT_TTL_MS = 30 * 24 * 60 * 60 * 1000;

export interface MemoryOwnerStore<S extends ServiceName, T extends string> extends OwnerStore<
  S,
  T
> {
  readonly kind: 'memory';
  readonly admittedForHosting: false;
  /** Fault injection: the next commit fails after the effect ran; nothing is persisted. */
  failNextCommit: boolean;
  /** Fault injection: ping rejects with DB_UNAVAILABLE. */
  unreachable: boolean;
  readonly inboxSize: number;
  readonly receiptCount: number;
}

export function createMemoryOwnerStore<S extends ServiceName, T extends string>(
  service: S,
  ownedTables: readonly T[],
  nowMs: () => number = Date.now,
): MemoryOwnerStore<S, T> {
  const rows = new Map<string, Record<string, unknown>>();
  const receipts = new Map<string, StoredReceipt>();
  const inbox = new Map<string, InboxEntry>();
  const locks = new Map<string, Promise<unknown>>();
  const owned = new Set<string>(ownedTables);
  const rowKey = (table: string, id: string) => JSON.stringify([table, id]);
  const clone = <V>(value: V): V => structuredClone(value);

  function assertOwned(table: string): void {
    if (!owned.has(table)) throw new ServiceError('FORBIDDEN', { details: { table } });
  }

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

  async function transact<R>(work: (tx: OwnerTransaction<T>) => Promise<R>): Promise<{
    result: R;
    staged: Map<string, Record<string, unknown>>;
  }> {
    const staged = new Map<string, Record<string, unknown>>();
    const tx: OwnerTransaction<T> = {
      async get(table, id) {
        assertOwned(table);
        const key = rowKey(table, id);
        const value = staged.get(key) ?? rows.get(key);
        return value ? clone(value) : null;
      },
      put(table, id, row) {
        assertOwned(table);
        staged.set(rowKey(table, id), clone(row));
      },
    };
    const result = await work(tx);
    return { result, staged };
  }

  function commit(staged: Map<string, Record<string, unknown>>, finalize: () => void): void {
    if (store.failNextCommit) {
      store.failNextCommit = false;
      throw new ServiceError('DB_UNAVAILABLE', { details: { reason: 'TRANSACTION_FAILED' } });
    }
    for (const [key, value] of staged) rows.set(key, value);
    finalize();
  }

  const store: MemoryOwnerStore<S, T> = {
    service,
    kind: 'memory',
    admittedForHosting: false,
    ownedTables,
    failNextCommit: false,
    unreachable: false,
    get inboxSize() {
      return inbox.size;
    },
    get receiptCount() {
      return receipts.size;
    },
    async ping() {
      if (store.unreachable) throw new ServiceError('DB_UNAVAILABLE');
    },
    async read(table, id) {
      assertOwned(table);
      const value = rows.get(rowKey(table, id));
      return value ? clone(value) : null;
    },
    commitWithReceipt(key: ReceiptKey, bodyHash, effect) {
      const id = JSON.stringify([key.userId, key.operation, key.key]);
      return serialize(`receipt:${id}`, async () => {
        const existing = receipts.get(id);
        if (existing && Date.parse(existing.expiresAt) > nowMs()) {
          if (existing.bodyHash !== bodyHash) throw new ServiceError('IDEMPOTENCY_CONFLICT');
          return { status: 'replayed' as const, receipt: clone(existing) };
        }
        const { result, staged } = await transact(effect);
        const receipt: StoredReceipt = {
          ...key,
          bodyHash,
          statusCode: result.statusCode,
          response: clone(result.response),
          expiresAt: new Date(nowMs() + RECEIPT_TTL_MS).toISOString(),
        };
        commit(staged, () => receipts.set(id, receipt));
        return { status: 'created' as const, receipt: clone(receipt) };
      });
    },
    applyInboxEvent(entry, effect) {
      return serialize(`inbox:${entry.eventId}`, async () => {
        const existing = inbox.get(entry.eventId);
        if (existing) {
          if (existing.bodyHash !== entry.bodyHash || existing.type !== entry.type) {
            throw new ServiceError('IDEMPOTENCY_CONFLICT', {
              details: { eventId: entry.eventId },
            });
          }
          return 'replayed' as const;
        }
        const { staged } = await transact(effect);
        commit(staged, () =>
          inbox.set(entry.eventId, { ...entry, appliedAt: new Date(nowMs()).toISOString() }),
        );
        return 'accepted' as const;
      });
    },
  };
  return store;
}
