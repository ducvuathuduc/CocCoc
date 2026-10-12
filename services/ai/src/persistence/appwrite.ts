// Durable AI persistence over Appwrite TablesDB (node-appwrite), same commit protocol as the
// Learning adapter. One database (`cocenglish`); AI writes only its a_ tables. Commits use TablesDB transactions:
//   1. stage every create/update/delete with createOperations (unique row IDs collide on duplicates),
//   2. re-read every row the effect read and abort if its $updatedAt moved (closes the window
//      between our read and staging; Appwrite's own commit check covers staging -> commit),
//   3. commit. Any 409 (conflict / duplicate row) is a retryable conflict for the engine.
// Rows are created without permissions: a_ tables are server-only (docs/data/PERMISSIONS.md).
// The credential is read on every call: hosted Functions pass the per-execution dynamic key
// (`x-appwrite-key`, limited by the function scopes) first, then a configured fallback key.
import { AppwriteException, Client, Query, TablesDB } from 'node-appwrite';
import { ServiceError } from '../../../shared/src/errors.js';
import { createEngine, type Backend, type StagedOp } from './engine.js';
import { AI_TABLES, type AiPersistence, type AiTable, type ListQuery, type Row } from './port.js';

export interface AppwriteAiConfig {
  endpoint: string;
  projectId: string;
  /** Server key, or a provider read per call (dynamic per-execution key first). */
  apiKey: string | (() => string | undefined);
  databaseId?: string;
  /** True only after the admitted cloud gate passed for this deployment (see services/AGENTS.md). */
  admittedForHosting: boolean;
  nowMs?: () => number;
  /** Max staged operations per transaction (Appwrite Free plan cap is 100). */
  maxOperations?: number;
  transactionTtlSeconds?: number;
}

const DATETIME_KEY = /(At|Until)$/;

/** Strip Appwrite system fields; normalize datetimes to ISO-8601 Z so string order == time order. */
export function fromAppwriteRow(raw: Record<string, unknown>): Row {
  const row: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(raw)) {
    if (key.startsWith('$')) continue;
    if (typeof value === 'string' && DATETIME_KEY.test(key)) {
      const ms = Date.parse(value);
      row[key] = Number.isNaN(ms) ? value : new Date(ms).toISOString();
    } else row[key] = value;
  }
  return row;
}

function statusOf(error: unknown): number | undefined {
  return error instanceof AppwriteException
    ? error.code
    : (error as { code?: number } | null)?.code;
}
function isConflict(error: unknown): boolean {
  return statusOf(error) === 409;
}
function toServiceError(error: unknown): ServiceError {
  if (error instanceof ServiceError) return error;
  const status = statusOf(error);
  const type = error instanceof AppwriteException ? error.type : undefined;
  if (status === undefined || status >= 500 || status === 429 || status === 408) {
    return new ServiceError('DB_UNAVAILABLE', {
      details: { ...(type ? { appwriteType: type } : {}) },
    });
  }
  return new ServiceError('INTERNAL_ERROR', {
    details: { ...(type ? { appwriteType: type } : {}), status },
  });
}

export function createAppwriteAiPersistence(
  config: AppwriteAiConfig,
  injected?: TablesDB,
): AiPersistence {
  if (!config.endpoint.startsWith('https://') || !config.projectId || !config.apiKey) {
    throw new Error('INVALID_APPWRITE_CONFIGURATION');
  }
  const clients = new Map<string, TablesDB>();
  /** TablesDB client for the current key (one cached client per key; older keys dropped). */
  const db = (): TablesDB => {
    if (injected) return injected;
    const key = typeof config.apiKey === 'function' ? config.apiKey() : config.apiKey;
    if (!key) throw new ServiceError('SERVICE_NOT_CONFIGURED', { details: { reason: 'NO_KEY' } });
    let client = clients.get(key);
    if (!client) {
      clients.clear();
      client = new TablesDB(
        new Client().setEndpoint(config.endpoint).setProject(config.projectId).setKey(key),
      );
      clients.set(key, client);
    }
    return client;
  };
  const databaseId = config.databaseId ?? 'cocenglish';
  const maxOperations = config.maxOperations ?? 95;
  const ttl = config.transactionTtlSeconds ?? 60;

  async function fetchRaw(table: AiTable, id: string) {
    try {
      return (await db().getRow({ databaseId, tableId: table, rowId: id })) as unknown as Record<
        string,
        unknown
      >;
    } catch (error) {
      if (statusOf(error) === 404) return null;
      throw toServiceError(error);
    }
  }

  function operation(op: StagedOp) {
    const base = { databaseId, tableId: op.table, rowId: op.id };
    if (op.action === 'delete') return { ...base, action: 'delete' };
    return { ...base, action: op.action, data: op.data };
  }

  const backend: Backend = {
    async fetch(table, id) {
      const raw = await fetchRaw(table, id);
      return raw ? { row: fromAppwriteRow(raw), version: String(raw['$updatedAt']) } : null;
    },
    async commit(ops, reads) {
      if (ops.length > maxOperations) {
        throw new ServiceError('INTERNAL_ERROR', {
          details: { reason: 'TRANSACTION_TOO_LARGE', operations: ops.length },
        });
      }
      let transactionId: string | undefined;
      try {
        transactionId = (await db().createTransaction({ ttl })).$id;
        await db().createOperations({ transactionId, operations: ops.map(operation) });
        for (const read of reads) {
          const raw = await fetchRaw(read.table, read.id);
          const version = raw ? String(raw['$updatedAt']) : null;
          if (version !== read.version) {
            await db()
              .updateTransaction({ transactionId, rollback: true })
              .catch(() => undefined);
            return 'conflict';
          }
        }
        await db().updateTransaction({ transactionId, commit: true });
        return 'committed';
      } catch (error) {
        if (transactionId) {
          await db()
            .updateTransaction({ transactionId, rollback: true })
            .catch(() => undefined);
        }
        // 404 at commit: a row we update/delete vanished concurrently -> also a conflict.
        if (isConflict(error) || statusOf(error) === 404) return 'conflict';
        throw toServiceError(error);
      }
    },
    async list(table, query: ListQuery) {
      const queries: string[] = [];
      for (const [key, value] of Object.entries(query.equal ?? {})) {
        queries.push(
          Query.equal(
            key,
            Array.isArray(value) ? [...value] : [value as string | number | boolean],
          ),
        );
      }
      for (const [key, value] of Object.entries(query.lessThan ?? {}))
        queries.push(Query.lessThan(key, value));
      for (const [key, value] of Object.entries(query.lessThanEqual ?? {}))
        queries.push(Query.lessThanEqual(key, value));
      for (const [key, value] of Object.entries(query.greaterThan ?? {}))
        queries.push(Query.greaterThan(key, value));
      for (const key of query.isNull ?? []) queries.push(Query.isNull(key));
      if (query.orderAsc) queries.push(Query.orderAsc(query.orderAsc));
      if (query.orderDesc) queries.push(Query.orderDesc(query.orderDesc));
      queries.push(Query.orderAsc('$id'));
      queries.push(Query.limit(Math.min(Math.max(query.limit, 1), 5000)));
      if (query.offset) queries.push(Query.offset(query.offset));
      try {
        const result = await db().listRows({ databaseId, tableId: table, queries });
        return {
          total: result.total,
          items: result.rows.map((raw) => ({
            id: String((raw as unknown as Record<string, unknown>)['$id']),
            row: fromAppwriteRow(raw as unknown as Record<string, unknown>),
          })),
        };
      } catch (error) {
        throw toServiceError(error);
      }
    },
    async ping() {
      try {
        await db().listRows({ databaseId, tableId: 'a_inbox', queries: [Query.limit(1)] });
      } catch {
        throw new ServiceError('DB_UNAVAILABLE');
      }
    },
  };
  return createEngine({
    kind: 'appwrite',
    admittedForHosting: config.admittedForHosting,
    ownedTables: AI_TABLES,
    backend,
    ...(config.nowMs ? { nowMs: config.nowMs } : {}),
  });
}

/**
 * Hosted configuration from the Function environment. Returns undefined (caller keeps the disabled
 * adapter) unless COC_AI_PERSISTENCE=appwrite with an https endpoint and a project. The key is the
 * per-execution dynamic key, falling back to COC_AI_APPWRITE_KEY / APPWRITE_API_KEY. Business
 * routes are served only when admitted (COC_AI_ADMITTED=reviewed-cloud-gate).
 */
export function appwriteConfigFromEnv(
  env: Record<string, string | undefined>,
  dynamicKey: () => string | undefined,
): AppwriteAiConfig | undefined {
  if (env['COC_AI_PERSISTENCE'] !== 'appwrite') return undefined;
  const endpoint = env['APPWRITE_FUNCTION_API_ENDPOINT'] ?? env['APPWRITE_ENDPOINT'];
  const projectId = env['APPWRITE_FUNCTION_PROJECT_ID'] ?? env['APPWRITE_PROJECT_ID'];
  const fallback = env['COC_AI_APPWRITE_KEY'] ?? env['APPWRITE_API_KEY'];
  if (!endpoint?.startsWith('https://') || !projectId) return undefined;
  return {
    endpoint,
    projectId,
    apiKey: () => dynamicKey() ?? fallback,
    databaseId: env['COC_DATABASE_ID'] ?? 'cocenglish',
    admittedForHosting: env['COC_AI_ADMITTED'] === 'reviewed-cloud-gate',
  };
}
