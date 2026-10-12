// LOCAL TEST ADAPTER ONLY — never imported by src/index.ts or any hosted artifact.
// Same optimistic engine as the Appwrite adapter (engine.ts) over an in-process Map, with fault
// injection for tests. Not durable storage.
import { ServiceError } from '../../../shared/src/errors.js';
import { createEngine, type Backend } from './engine.js';
import { AI_TABLES, type AiPersistence, type AiTable, type ListQuery, type Row } from './port.js';

export interface MemoryAiPersistence extends AiPersistence {
  readonly kind: 'memory';
  readonly admittedForHosting: false;
  /** Fault injection: the next commit fails after the effect ran; nothing is persisted. */
  failNextCommit: boolean;
  /** Fault injection: ping rejects with DB_UNAVAILABLE. */
  unreachable: boolean;
  /** Test hook: runs inside commit before the version check (simulate a concurrent writer). */
  beforeCommit: (() => void) | undefined;
  readonly inboxSize: number;
  readonly receiptCount: number;
  /** Test/dev inspection of every row in a table. */
  dump(table: AiTable): { id: string; row: Row }[];
}

function matches(row: Row, query: ListQuery): boolean {
  for (const [key, expected] of Object.entries(query.equal ?? {})) {
    const values = Array.isArray(expected) ? expected : [expected];
    if (!values.includes(row[key] as never)) return false;
  }
  const cmp = (a: unknown, b: string | number) =>
    typeof b === 'number' ? Number(a) - b : String(a).localeCompare(b);
  for (const [key, bound] of Object.entries(query.lessThan ?? {})) {
    if (row[key] === null || row[key] === undefined || cmp(row[key], bound) >= 0) return false;
  }
  for (const [key, bound] of Object.entries(query.lessThanEqual ?? {})) {
    if (row[key] === null || row[key] === undefined || cmp(row[key], bound) > 0) return false;
  }
  for (const [key, bound] of Object.entries(query.greaterThan ?? {})) {
    if (row[key] === null || row[key] === undefined || cmp(row[key], bound) <= 0) return false;
  }
  for (const key of query.isNull ?? [])
    if (row[key] !== null && row[key] !== undefined) return false;
  return true;
}

export function createMemoryAiPersistence(nowMs?: () => number): MemoryAiPersistence {
  const rows = new Map<string, { table: AiTable; id: string; row: Row; version: number }>();
  let clock = 0;
  const keyOf = (table: string, id: string) => `${table}\u0000${id}`;
  const control = {
    failNextCommit: false,
    unreachable: false,
    beforeCommit: undefined as (() => void) | undefined,
  };
  const backend: Backend = {
    async fetch(table, id) {
      const found = rows.get(keyOf(table, id));
      return found ? { row: structuredClone(found.row), version: String(found.version) } : null;
    },
    async commit(ops, reads) {
      control.beforeCommit?.();
      for (const read of reads) {
        const current = rows.get(keyOf(read.table, read.id));
        if ((current ? String(current.version) : null) !== read.version) return 'conflict';
      }
      if (control.failNextCommit) {
        control.failNextCommit = false;
        throw new ServiceError('DB_UNAVAILABLE', { details: { reason: 'TRANSACTION_FAILED' } });
      }
      for (const op of ops) {
        const key = keyOf(op.table, op.id);
        if (op.action === 'delete') rows.delete(key);
        else
          rows.set(key, {
            table: op.table,
            id: op.id,
            row: structuredClone(op.data),
            version: ++clock,
          });
      }
      return 'committed';
    },
    async list(table, query) {
      let items = [...rows.values()].filter((r) => r.table === table && matches(r.row, query));
      const order = query.orderAsc ?? query.orderDesc;
      if (order) {
        const dir = query.orderAsc ? 1 : -1;
        items = items.sort((a, b) => {
          const x = a.row[order];
          const y = b.row[order];
          const c =
            typeof x === 'number' && typeof y === 'number'
              ? x - y
              : String(x ?? '').localeCompare(String(y ?? ''));
          return c * dir || a.id.localeCompare(b.id);
        });
      }
      const offset = query.offset ?? 0;
      return {
        total: items.length,
        items: items
          .slice(offset, offset + query.limit)
          .map((r) => ({ id: r.id, row: structuredClone(r.row) })),
      };
    },
    async ping() {
      if (control.unreachable) throw new ServiceError('DB_UNAVAILABLE');
    },
  };
  const engine = createEngine({
    kind: 'memory',
    admittedForHosting: false,
    ownedTables: AI_TABLES,
    backend,
    ...(nowMs ? { nowMs } : {}),
  });
  const count = (table: AiTable) => [...rows.values()].filter((r) => r.table === table).length;
  const extras = {
    kind: 'memory' as const,
    admittedForHosting: false as const,
    get failNextCommit() {
      return control.failNextCommit;
    },
    set failNextCommit(value: boolean) {
      control.failNextCommit = value;
    },
    get unreachable() {
      return control.unreachable;
    },
    set unreachable(value: boolean) {
      control.unreachable = value;
    },
    get beforeCommit() {
      return control.beforeCommit;
    },
    set beforeCommit(value: (() => void) | undefined) {
      control.beforeCommit = value;
    },
    get inboxSize() {
      return count('a_inbox');
    },
    get receiptCount() {
      return count('a_receipts');
    },
    dump(table: AiTable) {
      return [...rows.values()]
        .filter((r) => r.table === table)
        .map((r) => ({ id: r.id, row: structuredClone(r.row) }));
    },
  };
  // defineProperties (not Object.assign) keeps the fault-injection accessors live.
  return Object.defineProperties(
    engine,
    Object.getOwnPropertyDescriptors(extras),
  ) as MemoryAiPersistence;
}
