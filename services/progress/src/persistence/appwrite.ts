// Durable Progress adapter over Appwrite TablesDB (node-appwrite 29.2.0, server API key).
// One attempt = point reads/queries outside the transaction, then at commit: createTransaction,
// stage every op with one createOperations call, re-read each updated/deleted row and abort
// when its revision moved (closes the read->stage window), then commit. TablesDB rejects the
// commit with 409 when a staged row changed after staging or a create collides with an
// existing row ID / unique index; both surface as TransactionConflict and the core re-runs the
// work. Live evidence: services/progress/test/appwrite-live.test.mjs (gated, test project).
import { AppwriteException, Client, Permission, Query, Role, TablesDB } from 'node-appwrite';
import { ServiceError } from '../../../shared/src/errors.js';
import {
  clampLimit,
  createProgressStore,
  normalizeRow,
  TransactionConflict,
  type CoreStore,
  type DriverAttempt,
  type ProgressDriver,
  type StagedOp,
} from './core.js';
import type { ListQuery, ListedRow, ProgressTable, Row, Scalar } from './port.js';

export interface AppwriteProgressOptions {
  endpoint: string;
  projectId: string;
  /**
   * Server key, or a provider read on every call: hosted Functions pass the per-execution dynamic
   * key (`x-appwrite-key` request header) so no long-lived key needs to be stored.
   */
  apiKey: string | (() => string | undefined);
  databaseId?: string;
  /** True only when the deployment opted in after the live gate (see src/index.ts). */
  admitted: boolean;
  nowMs?: () => number;
  /** Injected for tests; defaults to a TablesDB client with the server key. */
  tables?: TablesDB;
}

const PAGE = 100;
const TX_TTL_SECONDS = 60;

function mapError(error: unknown): never {
  if (error instanceof TransactionConflict || error instanceof ServiceError) throw error;
  const code = error instanceof AppwriteException ? error.code : undefined;
  if (code === 409) throw new TransactionConflict('appwrite_409');
  if (code === 400) {
    throw new ServiceError('INTERNAL_ERROR', {
      details: { reason: 'STORAGE_REJECTED_ROW', type: (error as AppwriteException).type },
    });
  }
  throw new ServiceError('DB_UNAVAILABLE', {
    details: { reason: code ? `APPWRITE_${code}` : 'APPWRITE_TRANSPORT' },
  });
}

function buildQueries(query: ListQuery): string[] {
  const queries: string[] = [];
  for (const [key, value] of Object.entries(query.where ?? {})) {
    queries.push(value === null ? Query.isNull(key) : Query.equal(key, value as Scalar & {}));
  }
  for (const [key, values] of Object.entries(query.anyOf ?? {})) {
    if (!values.length)
      throw new ServiceError('INTERNAL_ERROR', { details: { reason: 'EMPTY_ANY_OF' } });
    queries.push(Query.equal(key, [...values]));
  }
  for (const [key, value] of Object.entries(query.gte ?? {})) {
    queries.push(Query.greaterThanEqual(key, value));
  }
  for (const [key, value] of Object.entries(query.lt ?? {})) {
    queries.push(Query.lessThan(key, value));
  }
  for (const [key, direction] of query.orderBy ?? []) {
    queries.push(direction === 'asc' ? Query.orderAsc(key) : Query.orderDesc(key));
  }
  queries.push(Query.orderAsc('$id'));
  return queries;
}

export function createAppwriteProgressPersistence(options: AppwriteProgressOptions): CoreStore {
  if (!options.endpoint.startsWith('https://') || !options.projectId || !options.apiKey) {
    throw new Error('INVALID_APPWRITE_CONFIGURATION');
  }
  const databaseId = options.databaseId ?? 'cocenglish';
  const clients = new Map<string, TablesDB>();
  const keyOf = () => {
    const key = typeof options.apiKey === 'function' ? options.apiKey() : options.apiKey;
    if (!key) throw new ServiceError('SERVICE_NOT_CONFIGURED', { details: { reason: 'NO_KEY' } });
    return key;
  };
  /** TablesDB client for the current key (one cached client per key; old keys dropped). */
  const db = (): TablesDB => {
    if (options.tables) return options.tables;
    const key = keyOf();
    let client = clients.get(key);
    if (!client) {
      clients.clear();
      client = new TablesDB(
        new Client().setEndpoint(options.endpoint).setProject(options.projectId).setKey(key),
      );
      clients.set(key, client);
    }
    return client;
  };

  async function getRow(table: ProgressTable, id: string): Promise<Row | null> {
    try {
      const row = await db().getRow({ databaseId, tableId: table, rowId: id });
      return normalizeRow(table, row as unknown as Row);
    } catch (error) {
      if (error instanceof AppwriteException && error.code === 404) return null;
      return mapError(error);
    }
  }

  async function list(table: ProgressTable, query: ListQuery): Promise<ListedRow[]> {
    const limit = clampLimit(query.limit);
    const base = buildQueries(query);
    const out: ListedRow[] = [];
    let cursor: string | undefined;
    try {
      while (out.length < limit) {
        const page = Math.min(PAGE, limit - out.length);
        const queries = [...base, Query.limit(page)];
        if (cursor) queries.push(Query.cursorAfter(cursor));
        const result = await db().listRows({ databaseId, tableId: table, queries, total: false });
        for (const row of result.rows) {
          out.push({ id: row.$id, row: normalizeRow(table, row as unknown as Row) });
        }
        if (result.rows.length < page) break;
        cursor = result.rows[result.rows.length - 1]?.$id;
      }
    } catch (error) {
      return mapError(error);
    }
    return out;
  }

  async function count(table: ProgressTable, where: Readonly<Record<string, Scalar>>) {
    try {
      const queries = buildQueries({ where }).filter((q) => !q.includes('"$id"'));
      const result = await db().listRows({
        databaseId,
        tableId: table,
        queries: [...queries, Query.limit(1)],
      });
      return result.total;
    } catch (error) {
      return mapError(error);
    }
  }

  function toOperation(op: StagedOp): Record<string, unknown> {
    const operation: Record<string, unknown> = {
      action: op.action,
      databaseId,
      tableId: op.table,
      rowId: op.id,
    };
    if (op.action !== 'delete') {
      const data: Record<string, unknown> = { ...op.data };
      if (op.readers && op.action === 'create') {
        data['$permissions'] = op.readers.map((user) => Permission.read(Role.user(user)));
      }
      operation['data'] = data;
    }
    return operation;
  }

  async function commit(ops: StagedOp[]): Promise<void> {
    let transactionId: string | undefined;
    try {
      const tx = await db().createTransaction({ ttl: TX_TTL_SECONDS });
      transactionId = tx.$id;
      await db().createOperations({ transactionId, operations: ops.map(toOperation) });
      const guarded = ops.filter((op) => op.action === 'update' || op.action === 'delete');
      const current = await Promise.all(guarded.map((op) => getRow(op.table, op.id)));
      guarded.forEach((op, index) => {
        const row = current[index];
        if (!row || Number(row['revision'] ?? 0) !== (op.expectedRevision ?? 0)) {
          throw new TransactionConflict('revision_moved');
        }
      });
      await db().updateTransaction({ transactionId, commit: true });
      transactionId = undefined;
    } catch (error) {
      if (transactionId) {
        await db()
          .updateTransaction({ transactionId, rollback: true })
          .catch(() => undefined);
      }
      mapError(error);
    }
  }

  const driver: ProgressDriver = {
    kind: 'appwrite',
    admittedForHosting: options.admitted,
    async ping() {
      try {
        await db().listRows({
          databaseId,
          tableId: 'p_inbox',
          queries: [Query.limit(1)],
          total: false,
        });
      } catch {
        throw new ServiceError('DB_UNAVAILABLE');
      }
    },
    read: getRow,
    list,
    begin(): DriverAttempt {
      return { get: getRow, list, count, commit };
    },
    async backoff(attempt) {
      await new Promise((resolve) => setTimeout(resolve, 25 * attempt + Math.random() * 75));
    },
  };
  return createProgressStore(driver, {
    ...(options.nowMs ? { nowMs: options.nowMs } : {}),
    strictSchema: true,
  });
}
