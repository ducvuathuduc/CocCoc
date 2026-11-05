// Request scope for AI routes (copy of the Learning-local scope; no shared change). The shared router matches exact paths and does not expose
// headers to handlers; this wrapper (service-local) matches OpenAPI path
// templates such as /v1/sessions/{sessionId}/answers, rewrites req.path to the template so the
// router finds the route, and exposes the path parameters and request headers to handlers through
// AsyncLocalStorage. Internal (HMAC-signed) paths have no templates and pass through unchanged.
import { AsyncLocalStorage } from 'node:async_hooks';
import type { FunctionContext } from '../../../shared/src/transport.js';
import { ServiceError } from '../../../shared/src/errors.js';

interface Scope {
  params: Record<string, string>;
  headers: Record<string, string | undefined>;
}
const storage = new AsyncLocalStorage<Scope>();
const SEGMENT = /^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$/;

interface Template {
  template: string;
  pattern: RegExp;
  names: string[];
}
function compile(template: string): Template {
  const names: string[] = [];
  const source = template
    .replace(/[.*+?^$()|[\]\\]/g, '\\$&')
    .replace(/\{([A-Za-z]+)\}/g, (_, name: string) => {
      names.push(name);
      return '([^/]+)';
    });
  return { template, pattern: new RegExp(`^${source}$`), names };
}

export function withRequestScope(
  handler: (context: FunctionContext) => Promise<unknown>,
  templates: readonly string[],
): (context: FunctionContext) => Promise<unknown> {
  const compiled = templates.filter((t) => t.includes('{')).map(compile);
  return (context) => {
    const headers: Record<string, string | undefined> = {};
    for (const [key, value] of Object.entries(context.req.headers ?? {}))
      headers[key.toLowerCase()] = value;
    const params: Record<string, string> = {};
    let path = context.req.path;
    if (!path.startsWith('/internal/')) {
      for (const t of compiled) {
        const match = t.pattern.exec(path);
        if (!match) continue;
        const values = match.slice(1).map((v) => {
          try {
            return decodeURIComponent(v);
          } catch {
            return '';
          }
        });
        // Malformed IDs fall through to the router's NOT_FOUND (after auth) rather than matching.
        if (!values.every((v) => SEGMENT.test(v))) break;
        t.names.forEach((name, i) => (params[name] = values[i] ?? ''));
        path = t.template;
        break;
      }
    }
    // The shared router requires a JSON body on every non-GET; OpenAPI DELETE operations carry
    // none, so an empty DELETE body is presented to it as {} (service-local shim).
    const emptyDelete = context.req.method === 'DELETE' && !context.req.bodyText;
    const emptyClose =
      context.req.method === 'POST' &&
      path === '/v1/voice-sessions/{sessionId}/close' &&
      !context.req.bodyText;
    const scoped: FunctionContext = {
      ...context,
      // Plain fields only: the Appwrite runtime req has lazy getters (bodyJson throws on empty body).
      req: {
        method: context.req.method,
        path,
        headers: context.req.headers ?? {},
        ...(emptyDelete || emptyClose
          ? { bodyText: '{}' }
          : context.req.bodyText !== undefined
            ? { bodyText: context.req.bodyText }
            : {}),
        ...(context.req.queryString !== undefined ? { queryString: context.req.queryString } : {}),
      },
    };
    return storage.run({ params, headers }, () => handler(scoped));
  };
}

export function pathParam(name: string): string {
  const value = storage.getStore()?.params[name];
  if (!value) throw new ServiceError('NOT_FOUND');
  return value;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
/** Idempotency-Key header: required UUID on business mutations (EVENTS_ERRORS). */
export function idempotencyKey(): string {
  const value = storage.getStore()?.headers['idempotency-key'];
  if (!value || !UUID.test(value))
    throw new ServiceError('VALIDATION_ERROR', { details: { field: 'Idempotency-Key' } });
  return value.toLowerCase();
}
