// LOCAL TEST ADAPTER ONLY — never imported by src/index.ts or any hosted artifact.
// In-memory Progress driver with the same optimistic semantics as the Appwrite TablesDB driver:
// update/delete carry the revision read in the attempt and fail with a conflict when it moved;
// create fails when the row already exists (TablesDB unique row ID / unique index 409).
import { ServiceError } from '../../../shared/src/errors.js';
import {
  createProgressStore,
  rowMatches,
  sortAndLimit,
  TransactionConflict,
  type CoreStore,
  type ProgressDriver,
  type StagedOp,
} from './core.js';
import type { ListedRow, ProgressTable, Row } from './port.js';

export interface MemoryProgressPersistence extends CoreStore {
  readonly kind: 'memory';
  readonly admittedForHosting: false;
  /** Fault injection: the next non-empty commit fails after the effect ran; nothing persists. */
  failNextCommit: boolean;
  /** Fault injection: ping rejects with DB_UNAVAILABLE. */
  unreachable: boolean;
  /** Fault injection: invoked between the attempt's reads and its commit (race windows). */
  beforeCommit: (() => Promise<void>) | undefined;
  readonly inboxSize: number;
  readonly receiptCount: number;
  /** Rows of one table (test inspection). */
  dump(table: ProgressTable): ListedRow[];
  /** Grants recorded for a row (p_notifications owner read). */
  readersOf(table: ProgressTable, id: string): string[] | undefined;
}

export interface MemoryOptions {
  /** Validate rows against the declared schema and stamp mutable fields (default false for
   *  the shared OwnerStore contract tests; Progress tests and dev mode enable it). */
  strictSchema?: boolean;
}

export function createMemoryProgressPersistence(
  nowMs: () => number = Date.now,
  options: MemoryOptions = {},
): MemoryProgressPersistence {
  const tables = new Map<string, Map<string, Row>>();
  const readers = new Map<string, string[]>();
  const tableOf = (table: string) => {
    let rows = tables.get(table);
    if (!rows) tables.set(table, (rows = new Map()));
    return rows;
  };
  const clone = <V>(value: V): V => structuredClone(value);
  const listRows = (table: ProgressTable, query: Parameters<ProgressDriver['list']>[1]) =>
    sortAndLimit(
      [...tableOf(table).entries()]
        .filter(([, row]) => rowMatches(row, query))
        .map(([id, row]) => ({ id, row: clone(row) })),
      query,
    );

  function commit(ops: StagedOp[]): void {
    // Validate every precondition first so a failed commit applies nothing.
    for (const op of ops) {
      const current = tableOf(op.table).get(op.id);
      if (op.action === 'create' && current) throw new TransactionConflict('row_exists');
      if (op.action === 'update' || op.action === 'delete') {
        if (!current) throw new TransactionConflict('row_missing');
        if (Number(current['revision'] ?? 0) !== (op.expectedRevision ?? 0)) {
          throw new TransactionConflict('revision_moved');
        }
      }
    }
    if (memory.failNextCommit) {
      memory.failNextCommit = false;
      throw new ServiceError('DB_UNAVAILABLE', { details: { reason: 'TRANSACTION_FAILED' } });
    }
    for (const op of ops) {
      if (op.action === 'delete') tableOf(op.table).delete(op.id);
      else tableOf(op.table).set(op.id, clone(op.data ?? {}));
      if (op.readers) readers.set(`${op.table}/${op.id}`, [...op.readers]);
    }
  }

  const driver: ProgressDriver = {
    kind: 'memory',
    admittedForHosting: false,
    async ping() {
      if (memory.unreachable) throw new ServiceError('DB_UNAVAILABLE');
    },
    async read(table, id) {
      const row = tableOf(table).get(id);
      return row ? clone(row) : null;
    },
    async list(table, query) {
      return listRows(table, query);
    },
    begin() {
      return {
        async get(table, id) {
          const row = tableOf(table).get(id);
          return row ? clone(row) : null;
        },
        async list(table, query) {
          return listRows(table, query);
        },
        async count(table, where) {
          return listRows(table, { where, limit: 500 }).length;
        },
        async commit(ops) {
          if (memory.beforeCommit) await memory.beforeCommit();
          commit(ops);
        },
      };
    },
  };

  const core = createProgressStore(driver, {
    nowMs,
    strictSchema: options.strictSchema ?? false,
  });
  const memory = core as unknown as MemoryProgressPersistence;
  Object.defineProperties(memory, {
    failNextCommit: { value: false, writable: true, enumerable: true },
    unreachable: { value: false, writable: true, enumerable: true },
    beforeCommit: { value: undefined, writable: true, enumerable: true },
    inboxSize: { get: () => tableOf('p_inbox').size },
    receiptCount: { get: () => tableOf('p_receipts').size },
    dump: { value: (table: ProgressTable) => listRows(table, { limit: 500 }) },
    readersOf: {
      value: (table: ProgressTable, id: string) => readers.get(`${table}/${id}`),
    },
  });
  return memory;
}
