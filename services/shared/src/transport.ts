// Shared REST router: request ID, error envelope, verified JWT (AuthPort), service HMAC,
// fail-closed /ready and /internal/events. No grading/reward logic lives here.
import { randomUUID } from 'node:crypto';
import { createAppwriteAuthPort, extractJwt, type AuthPort, type VerifiedSubject } from './auth.js';
import { ServiceError, toErrorResponse } from './errors.js';
import type { BusinessEvent, EventConsumer, PersistencePort, ServiceName } from './ports.js';
import {
  parseKeyring,
  sha256Hex,
  verifyServiceRequest,
  type Keyring,
  type ServiceSender,
} from './service-hmac.js';
import { createAccountVerifier } from './verify-jwt.js';

export type { ServiceName } from './ports.js';
export interface FunctionContext {
  req: {
    method: string;
    path: string;
    headers: Record<string, string | undefined>;
    bodyText?: string;
    queryString?: string;
  };
  res: { json: (body: unknown, status?: number, headers?: Record<string, string>) => unknown };
}

export const DEFAULT_BODY_LIMIT = 64000;
export const LARGE_BODY_LIMIT = 750000;
const REQUEST_ID = /^[A-Za-z0-9-]{1,64}$/;
const TRACEPARENT = /^([0-9a-f]{2})-([0-9a-f]{32})-([0-9a-f]{16})-([0-9a-f]{2})$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const AGGREGATE_ID = /^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$/;
const EVENT_KEYS = new Set([
  'eventId',
  'type',
  'schemaVersion',
  'producer',
  'aggregateId',
  'occurredAt',
  'requestId',
  'payload',
]);

/** Receiver allowlist: event type -> producers accepted by this receiver (EVENTS_ERRORS). */
export const EVENT_ALLOWLIST: Record<ServiceName, Record<string, readonly ServiceName[]>> = {
  progress: { 'lesson.completed.v1': ['learning'], 'account.purged.v1': ['learning', 'ai'] },
  learning: { 'account.deleted.v1': ['progress'] },
  ai: { 'account.deleted.v1': ['progress'] },
};

export function parseTraceparent(value: string | undefined): string | undefined {
  const match = value ? TRACEPARENT.exec(value) : null;
  if (!match) return undefined;
  const [, version, traceId, parentId] = match;
  if (version === 'ff' || /^0+$/.test(traceId ?? '') || /^0+$/.test(parentId ?? '')) {
    return undefined;
  }
  return value;
}

function canonicalJson(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(',')}]`;
  if (value && typeof value === 'object') {
    const entries = Object.entries(value as Record<string, unknown>).sort(([a], [b]) =>
      a < b ? -1 : a > b ? 1 : 0,
    );
    return `{${entries.map(([k, v]) => `${JSON.stringify(k)}:${canonicalJson(v)}`).join(',')}}`;
  }
  return JSON.stringify(value);
}
/** Canonical body hash used for idempotency receipts and inbox payload-substitution checks. */
export function canonicalBodyHash(value: unknown): string {
  return sha256Hex(canonicalJson(value));
}

export interface RouteContext {
  requestId: string;
  traceparent: string | undefined;
  subject: VerifiedSubject | undefined;
  sender: ServiceSender | undefined;
  body: unknown;
  query: string;
}
export interface RouteResult {
  status: number;
  body: unknown;
}
export interface Route {
  method: string;
  path: string;
  auth: 'user' | 'service';
  allowedSenders?: readonly ServiceSender[];
  allowedQueryKeys?: readonly string[];
  maxBodyBytes?: number;
  handle(context: RouteContext): Promise<RouteResult>;
}

export interface RouterOptions {
  service: ServiceName;
  persistence: PersistencePort;
  /**
   * hosted: memory adapters refused, business routes need an admitted adapter.
   * local-test: unit tests. local-dev: `pnpm dev:services` with explicit in-memory adapters.
   */
  mode: 'hosted' | 'local-test' | 'local-dev';
  auth?: AuthPort | undefined;
  keyring?: Keyring | undefined;
  routes?: readonly Route[];
  eventConsumer?: EventConsumer | undefined;
  buildId?: string;
  nowMs?: () => number;
}

function validateEventEnvelope(value: unknown): BusinessEvent {
  const event = value as Record<string, unknown> | null;
  if (!event || typeof event !== 'object' || Array.isArray(event)) {
    throw new ServiceError('VALIDATION_ERROR');
  }
  const invalid =
    Object.keys(event).some((key) => !EVENT_KEYS.has(key)) ||
    typeof event['eventId'] !== 'string' ||
    !UUID.test(event['eventId']) ||
    typeof event['type'] !== 'string' ||
    event['schemaVersion'] !== 1 ||
    typeof event['producer'] !== 'string' ||
    typeof event['aggregateId'] !== 'string' ||
    !AGGREGATE_ID.test(event['aggregateId']) ||
    typeof event['occurredAt'] !== 'string' ||
    Number.isNaN(Date.parse(event['occurredAt'])) ||
    typeof event['requestId'] !== 'string' ||
    event['requestId'].length > 64 ||
    !event['payload'] ||
    typeof event['payload'] !== 'object' ||
    Array.isArray(event['payload']);
  if (invalid) throw new ServiceError('VALIDATION_ERROR', { details: { field: 'event' } });
  return event as unknown as BusinessEvent;
}

export function createRouter(options: RouterOptions) {
  const { service, persistence, mode } = options;
  if (persistence.service !== service) throw new Error('PERSISTENCE_OWNER_MISMATCH');
  if (mode === 'hosted' && persistence.kind === 'memory') {
    throw new Error('MEMORY_ADAPTER_NOT_ALLOWED_IN_HOSTED_MODE');
  }
  const nowMs = options.nowMs ?? Date.now;
  const routes = options.routes ?? [];
  const allowlist = EVENT_ALLOWLIST[service];
  const eventSenders = [...new Set(Object.values(allowlist).flat())];

  async function ready(): Promise<RouteResult> {
    const checks = {
      auth: Boolean(options.auth),
      persistence: persistence.admittedForHosting && persistence.kind !== 'memory',
      database: false,
    };
    if (checks.persistence) {
      try {
        await persistence.ping();
        checks.database = true;
      } catch {
        throw new ServiceError('DB_UNAVAILABLE', { details: { checks } });
      }
    }
    if (!checks.auth || !checks.persistence) {
      throw new ServiceError('SERVICE_NOT_CONFIGURED', { details: { checks } });
    }
    return { status: 200, body: { service, buildId, status: 'ok' } };
  }

  async function consumeEvent(context: RouteContext): Promise<RouteResult> {
    const event = validateEventEnvelope(context.body);
    const producers = allowlist[event.type];
    if (!producers) throw new ServiceError('VALIDATION_ERROR', { details: { field: 'type' } });
    if (!producers.includes(event.producer as ServiceName) || event.producer !== context.sender) {
      throw new ServiceError('FORBIDDEN');
    }
    if (!options.eventConsumer) throw new ServiceError('SERVICE_NOT_CONFIGURED');
    const status = await options.eventConsumer.consume(event, {
      bodyHash: canonicalBodyHash(event),
      requestId: context.requestId,
      sender: context.sender,
    });
    return {
      status: 200,
      body: { operationId: event.eventId, status, requestId: context.requestId },
    };
  }

  const builtIn: Route[] = [
    {
      method: 'GET',
      path: '/ready',
      auth: 'service',
      allowedSenders: ['maintainer', 'learning', 'progress', 'ai'],
      handle: ready,
    },
    {
      method: 'POST',
      path: '/internal/events',
      auth: 'service',
      allowedSenders: eventSenders,
      handle: consumeEvent,
    },
  ];
  const buildId = (options.buildId ?? 'local-scaffold').slice(0, 64);

  async function dispatch(
    req: FunctionContext['req'],
    headers: Record<string, string | undefined>,
    requestId: string,
  ): Promise<RouteResult> {
    const method = req.method.toUpperCase();
    const rawBody = req.bodyText ?? '';
    if (method === 'GET' && req.path === '/health') {
      return { status: 200, body: { service, buildId, status: 'degraded' } };
    }
    const route = [...builtIn, ...routes].find((r) => r.path === req.path && r.method === method);
    const limit = route?.maxBodyBytes ?? DEFAULT_BODY_LIMIT;
    if (Buffer.byteLength(rawBody, 'utf8') > limit) throw new ServiceError('PAYLOAD_TOO_LARGE');
    if ((method === 'GET' || method === 'HEAD') && rawBody) {
      throw new ServiceError('VALIDATION_ERROR', { details: { field: 'body' } });
    }
    const context: RouteContext = {
      requestId,
      traceparent: parseTraceparent(headers['traceparent']),
      subject: undefined,
      sender: undefined,
      body: undefined,
      query: req.queryString ?? '',
    };
    if (route?.auth === 'service' || req.path.startsWith('/internal/') || req.path === '/ready') {
      const verified = verifyServiceRequest({
        keyring: options.keyring,
        headers,
        method,
        path: req.path,
        query: context.query,
        allowedQueryKeys: route?.allowedQueryKeys ?? [],
        body: rawBody,
        nowSeconds: Math.floor(nowMs() / 1000),
        allowedSenders: route?.allowedSenders ?? [],
      });
      if (!route) throw new ServiceError('NOT_FOUND');
      context.sender = verified.sender;
    } else {
      // Every other operation needs a verified subject; without an auth port we fail closed.
      if (!options.auth) throw new ServiceError('SERVICE_NOT_CONFIGURED');
      context.subject = await options.auth.verify(extractJwt(headers));
      if (!route) {
        throw new ServiceError(routes.length ? 'NOT_FOUND' : 'SERVICE_NOT_CONFIGURED');
      }
      if (mode === 'hosted' && !persistence.admittedForHosting) {
        throw new ServiceError('SERVICE_NOT_CONFIGURED');
      }
    }
    if (method !== 'GET' && method !== 'HEAD') {
      if (!rawBody) throw new ServiceError('VALIDATION_ERROR', { details: { field: 'body' } });
      try {
        context.body = JSON.parse(rawBody);
      } catch {
        throw new ServiceError('VALIDATION_ERROR', { details: { field: 'body' } });
      }
    }
    return route.handle(context);
  }

  return async (context: FunctionContext): Promise<unknown> => {
    const headers: Record<string, string | undefined> = {};
    for (const [key, value] of Object.entries(context.req.headers ?? {})) {
      headers[key.toLowerCase()] = value;
    }
    const candidate = headers['x-request-id'];
    const requestId = candidate && REQUEST_ID.test(candidate) ? candidate : randomUUID();
    const responseHeaders: Record<string, string> = {
      'X-Request-ID': requestId,
      'Cache-Control': 'no-store',
    };
    try {
      const result = await dispatch(context.req, headers, requestId);
      return context.res.json(result.body, result.status, responseHeaders);
    } catch (error) {
      const failure = toErrorResponse(error, requestId);
      if (failure.retryAfterSeconds !== undefined) {
        responseHeaders['Retry-After'] = String(failure.retryAfterSeconds);
      }
      return context.res.json(failure.body, failure.status, responseHeaders);
    }
  };
}

/** Service-specific wiring shared by the hosted entrypoint and local dev (src/http/wiring.ts). */
export interface ServiceWiring {
  routes?: readonly Route[];
  eventConsumer?: EventConsumer | undefined;
}

/**
 * Hosted Function entrypoint. Reads Appwrite-provided endpoint/project env for the
 * Account.get verifier and COC_SERVICE_KEYS for HMAC. Owner persistence is injected;
 * cloud entrypoints pass their disabled adapter until the durable adapter is admitted.
 */
export function createHostedHandler(
  service: ServiceName,
  persistence: PersistencePort,
  env: Record<string, string | undefined> = process.env,
  wiring: ServiceWiring = {},
) {
  const endpoint = env['APPWRITE_FUNCTION_API_ENDPOINT'];
  const project = env['APPWRITE_FUNCTION_PROJECT_ID'];
  let auth: AuthPort | undefined;
  if (endpoint && project && endpoint.startsWith('https://')) {
    auth = createAppwriteAuthPort(createAccountVerifier(endpoint, project));
  }
  let keyring: Keyring | undefined;
  try {
    keyring = parseKeyring(env['COC_SERVICE_KEYS']);
  } catch {
    keyring = undefined; // malformed key material: internal routes and /ready stay closed
  }
  return createRouter({
    service,
    persistence,
    mode: 'hosted',
    auth,
    keyring,
    buildId: env['BUILD_ID'] ?? 'local-scaffold',
    ...(wiring.routes ? { routes: wiring.routes } : {}),
    eventConsumer: wiring.eventConsumer,
  });
}
