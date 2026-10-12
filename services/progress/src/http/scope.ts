// Request scope for Progress routes. The shared router (services/shared/src/transport.ts) matches
// exact paths and hands handlers only body/query/subject; Progress needs OpenAPI path parameters
// ({questId}, {userId}) and the Idempotency-Key header. This wrapper runs in front of the shared
// router: it maps a concrete path onto its OpenAPI template, captures the parameters and the
// Idempotency-Key in an AsyncLocalStorage scope for the matched handler, and supplies the empty
// JSON body the shared router requires for body-less mutations (initialize, freezes, league
// join, friend-quest opt-in, unfollow). Authentication still happens in the shared router.
import { AsyncLocalStorage } from 'node:async_hooks';
import { ServiceError } from '../../../shared/src/errors.js';
import type { FunctionContext } from '../../../shared/src/transport.js';

export interface RouteTemplate {
  method: string;
  path: string;
  /** Operation has no requestBody in OpenAPI. */
  noBody?: boolean;
}

export interface RequestScope {
  params: Readonly<Record<string, string>>;
  idempotencyKey: string | undefined;
}

const storage = new AsyncLocalStorage<RequestScope>();
const PARAM_VALUE = /^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$/;

export function requestScope(): RequestScope {
  return storage.getStore() ?? { params: {}, idempotencyKey: undefined };
}

export function pathParam(name: string): string {
  const value = requestScope().params[name];
  if (!value) throw new ServiceError('VALIDATION_ERROR', { details: { field: name } });
  return value;
}

function match(template: string, path: string): Record<string, string> | null {
  const t = template.split('/');
  const p = path.split('/');
  if (t.length !== p.length) return null;
  const params: Record<string, string> = {};
  for (let i = 0; i < t.length; i++) {
    const part = t[i] as string;
    const value = p[i] as string;
    if (part.startsWith('{') && part.endsWith('}')) {
      let decoded: string;
      try {
        decoded = decodeURIComponent(value);
      } catch {
        return null;
      }
      if (!PARAM_VALUE.test(decoded)) return null;
      params[part.slice(1, -1)] = decoded;
    } else if (part !== value) return null;
  }
  return params;
}

export function withRequestScope(
  router: (context: FunctionContext) => Promise<unknown>,
  templates: readonly RouteTemplate[],
) {
  return (context: FunctionContext): Promise<unknown> => {
    const req = context.req;
    const method = (req.method ?? 'GET').toUpperCase();
    let path = req.path;
    let bodyText = req.bodyText;
    let params: Record<string, string> = {};
    for (const template of templates) {
      if (template.method !== method) continue;
      const found = match(template.path, req.path);
      if (!found) continue;
      path = template.path;
      params = found;
      if (template.noBody && !bodyText) bodyText = '{}';
      break;
    }
    let idempotencyKey: string | undefined;
    for (const [key, value] of Object.entries(req.headers ?? {})) {
      if (key.toLowerCase() === 'idempotency-key') idempotencyKey = value;
    }
    const scoped: FunctionContext = {
      ...context,
      req: { ...req, path, ...(bodyText !== undefined ? { bodyText } : {}) },
    };
    return storage.run({ params, idempotencyKey }, () => router(scoped));
  };
}
