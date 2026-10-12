// Hosted Appwrite Function entry helpers (transport only, no business logic).
// - plainRequest: copy only the documented plain request fields; the runtime req has lazy getters
//   (bodyJson throws on an empty/non-JSON body), so it must never be spread or enumerated.
// - Dynamic key: Appwrite injects a per-execution API key in the `x-appwrite-key` header, limited
//   by the function scopes. It is removed from the headers the router sees and held only for the
//   current execution (AsyncLocalStorage), never logged or stored.
// - Scheduled executions: Appwrite runs a function cron at `/` with `x-appwrite-trigger: schedule`.
//   The platform sets that header itself (b-ops probe: a client-supplied value over the public
//   domain arrives as `http`); the worker takes no input from the request at all, and every job
//   it runs is idempotent, so even a spoofed trigger can only cause an early, harmless drain.
import { AsyncLocalStorage } from 'node:async_hooks';
import type { FunctionContext } from './transport.js';

export interface RawAppwriteContext {
  req: unknown;
  res: FunctionContext['res'];
  log?: (message: string) => void;
  error?: (message: string) => void;
}

function field<T>(read: () => T, fallback: T): T {
  try {
    const value = read();
    return value === undefined || value === null ? fallback : value;
  } catch {
    return fallback;
  }
}

export function plainRequest(raw: unknown): FunctionContext['req'] {
  const source = (raw ?? {}) as Record<string, unknown>;
  const headers: Record<string, string | undefined> = {};
  const rawHeaders = field(() => source['headers'] as Record<string, unknown>, {});
  for (const [key, value] of Object.entries(rawHeaders)) {
    if (typeof value === 'string') headers[key.toLowerCase()] = value;
  }
  return {
    method: String(field(() => source['method'], 'GET')),
    path: String(field(() => source['path'], '/')),
    headers,
    bodyText: String(
      field(
        () => source['bodyText'],
        field(() => source['bodyRaw'], ''),
      ),
    ),
    queryString: String(field(() => source['queryString'], '')),
  };
}

const executionKey = new AsyncLocalStorage<string | undefined>();

/** Run one execution with the dynamic key taken out of (and removed from) its headers. */
export function withExecutionKey<R>(req: FunctionContext['req'], run: () => R): R {
  const key = req.headers['x-appwrite-key'];
  delete req.headers['x-appwrite-key'];
  return executionKey.run(key && key.length <= 4096 ? key : undefined, run);
}

/** The current execution's dynamic key (undefined outside an execution or when not injected). */
export function currentExecutionKey(): string | undefined {
  return executionKey.getStore();
}

export function isScheduledExecution(req: FunctionContext['req']): boolean {
  return req.headers['x-appwrite-trigger'] === 'schedule' && (req.path === '/' || req.path === '');
}
