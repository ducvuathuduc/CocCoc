// [VI] Cầu nối giữa Appwrite Function runtime và router của service:
// - plainRequest(): chỉ copy các field request an toàn; không spread req vì getter bodyJson
//   có thể ném lỗi khi body rỗng/không phải JSON.
// - Dynamic key: Appwrite inject key theo từng execution qua header x-appwrite-key;
//   key chỉ sống trong AsyncLocalStorage của execution, không log, không lưu DB.
// - Scheduled execution: cron của Appwrite gọi path "/" với x-appwrite-trigger=schedule;
//   worker không đọc input từ request, mọi job đều idempotent nên trigger giả không gây hại.
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
