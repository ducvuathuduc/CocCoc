// Durable Learning persistence over Appwrite TablesDB (node-appwrite). One serverless database
// (`cocenglish`); Learning writes only its l_ tables. Commits use TablesDB transactions:
//   1. stage every create/update/delete with createOperations (unique row IDs collide on duplicates),
//   2. re-read every row the effect read and abort if its $updatedAt moved (closes the window
//      between our read and staging; Appwrite's own commit check covers staging -> commit),
//   3. commit. Any 409 (conflict / duplicate row) is a retryable conflict for the engine.
// Rows are created without permissions: l_ tables are server-only (docs/data/PERMISSIONS.md).
import { AppwriteException, Client, Query, TablesDB } from 'node-appwrite';
import { ServiceError } from '../../../shared/src/errors.js';
import { createEngine, type Backend, type StagedOp } from './engine.js';
import {
  LEARNING_TABLES,
  type LearningPersistence,
  type LearningTable,
  type ListQuery,
  type Row,
} from './port.js';

export interface AppwriteLearningConfig {
  endpoint: string;
  projectId: string;
  apiKey: string;
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

export function createAppwriteLearningPersistence(
  config: AppwriteLearningConfig,
  tables: TablesDB = new TablesDB(
    new Client().setEndpoint(config.endpoint).setProject(config.projectId).setKey(config.apiKey),
  ),
): LearningPersistence {
  if (!config.endpoint.startsWith('https://') || !config.projectId || !config.apiKey) {
    throw new Error('INVALID_APPWRITE_CONFIGURATION');
  }
  const databaseId = config.databaseId ?? 'cocenglish';
  const maxOperations = config.maxOperations ?? 95;
  const ttl = config.transactionTtlSeconds ?? 60;

  async function fetchRaw(table: LearningTable, id: string) {
    try {
      return (await tables.getRow({ databaseId, tableId: table, rowId: id })) as unknown as Record<
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
        transactionId = (await tables.createTransaction({ ttl })).$id;
        await tables.createOperations({ transactionId, operations: ops.map(operation) });
        for (const read of reads) {
          const raw = await fetchRaw(read.table, read.id);
          const version = raw ? String(raw['$updatedAt']) : null;
          if (version !== read.version) {
            await tables
              .updateTransaction({ transactionId, rollback: true })
              .catch(() => undefined);
            return 'conflict';
          }
        }
        await tables.updateTransaction({ transactionId, commit: true });
        return 'committed';
      } catch (error) {
        if (transactionId) {
          await tables.updateTransaction({ transactionId, rollback: true }).catch(() => undefined);
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
        const result = await tables.listRows({ databaseId, tableId: table, queries });
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
        await tables.listRows({ databaseId, tableId: 'l_courses', queries: [Query.limit(1)] });
      } catch {
        throw new ServiceError('DB_UNAVAILABLE');
      }
    },
  };
  return createEngine({
    kind: 'appwrite',
    admittedForHosting: config.admittedForHosting,
    ownedTables: LEARNING_TABLES,
    backend,
    ...(config.nowMs ? { nowMs: config.nowMs } : {}),
  });
}

/**
 * Hosted configuration from the Function environment. Returns undefined (caller keeps the disabled
 * adapter) unless COC_LEARNING_PERSISTENCE=appwrite and endpoint/project/key are all present.
 * Admission additionally needs COC_LEARNING_ADMITTED=reviewed-cloud-gate.
 */
export function appwriteConfigFromEnv(
  env: Record<string, string | undefined>,
): AppwriteLearningConfig | undefined {
  if (env['COC_LEARNING_PERSISTENCE'] !== 'appwrite') return undefined;
  const endpoint = env['APPWRITE_FUNCTION_API_ENDPOINT'] ?? env['APPWRITE_ENDPOINT'];
  const projectId = env['APPWRITE_FUNCTION_PROJECT_ID'] ?? env['APPWRITE_PROJECT_ID'];
  const apiKey = env['APPWRITE_API_KEY'];
  if (!endpoint?.startsWith('https://') || !projectId || !apiKey) return undefined;
  return {
    endpoint,
    projectId,
    apiKey,
    databaseId: env['COC_DATABASE_ID'] ?? 'cocenglish',
    admittedForHosting: env['COC_LEARNING_ADMITTED'] === 'reviewed-cloud-gate',
  };
}
