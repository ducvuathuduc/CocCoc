// ADR-0018 event transport selection. Default: the direct signed HTTP relay (EVENTS_ERRORS).
// AMQP is used only when COC_EVENT_TRANSPORT=amqp, a broker URL is present (amqps://, or amqp://
// with the explicit private Compose marker) and COC_AMQP_ROUTES names the producer->consumer
// routes cut over so far (one route at a time; docs/devops/OPERATIONS.md). Anything partial or
// unknown is 'refused': the caller keeps the direct relay and reports the reason, never a fake.
import { ServiceError } from './errors.js';
import type { EventOwner, EventTransport } from './ports.js';

export type EventRoute = `${EventOwner}->${EventOwner}`;
/** Producer->consumer pairs that exist in the receiver allowlists (transport.ts EVENT_ALLOWLIST). */
export const EVENT_ROUTES: readonly EventRoute[] = [
  'learning->progress',
  'ai->progress',
  'progress->learning',
  'progress->ai',
];
export const PLAINTEXT_MARKER = 'private-compose-network';

export type EventTransportConfig =
  | { mode: 'direct'; routes: [] }
  | { mode: 'refused'; reason: string; routes: [] }
  | { mode: 'amqp'; url: string; routes: EventRoute[]; prefetch: number; vhostLabel: string };

function bounded(raw: string | undefined, fallback: number, min: number, max: number): number {
  const value = raw === undefined || raw === '' ? fallback : Number(raw);
  return Number.isSafeInteger(value) && value >= min && value <= max ? value : fallback;
}

export function eventTransportConfigFromEnv(
  env: Record<string, string | undefined>,
): EventTransportConfig {
  const mode = env['COC_EVENT_TRANSPORT'] ?? 'direct';
  if (mode === 'direct' || mode === '') return { mode: 'direct', routes: [] };
  if (mode !== 'amqp') return { mode: 'refused', reason: 'UNKNOWN_EVENT_TRANSPORT', routes: [] };
  const url = env['COC_AMQP_URL'];
  if (!url) return { mode: 'refused', reason: 'AMQP_URL_MISSING', routes: [] };
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return { mode: 'refused', reason: 'AMQP_URL_INVALID', routes: [] };
  }
  if (parsed.protocol !== 'amqps:' && parsed.protocol !== 'amqp:') {
    return { mode: 'refused', reason: 'AMQP_URL_INVALID', routes: [] };
  }
  if (parsed.protocol === 'amqp:' && env['COC_AMQP_ALLOW_PLAINTEXT'] !== PLAINTEXT_MARKER) {
    return { mode: 'refused', reason: 'AMQP_TLS_REQUIRED', routes: [] };
  }
  const requested = (env['COC_AMQP_ROUTES'] ?? '')
    .split(',')
    .map((route) => route.trim())
    .filter(Boolean);
  if (!requested.length) return { mode: 'refused', reason: 'AMQP_ROUTES_MISSING', routes: [] };
  if (requested.some((route) => !EVENT_ROUTES.includes(route as EventRoute))) {
    return { mode: 'refused', reason: 'AMQP_ROUTE_UNKNOWN', routes: [] };
  }
  return {
    mode: 'amqp',
    url,
    routes: [...new Set(requested as EventRoute[])],
    prefetch: bounded(env['COC_AMQP_PREFETCH'], 10, 1, 100),
    vhostLabel: decodeURIComponent(parsed.pathname.replace(/^\//, '')) || '/',
  };
}

/** Whether producer->consumer currently travels over AMQP (else the direct signed relay). */
export function usesAmqp(
  config: EventTransportConfig,
  producer: EventOwner,
  consumer: EventOwner,
): boolean {
  return config.mode === 'amqp' && config.routes.includes(`${producer}->${consumer}`);
}

/** Loggable description: never the URL or its credentials. */
export function describeEventTransport(config: EventTransportConfig): Record<string, unknown> {
  if (config.mode === 'amqp') {
    return {
      mode: 'amqp',
      routes: config.routes,
      prefetch: config.prefetch,
      vhost: config.vhostLabel,
    };
  }
  if (config.mode === 'refused') return { mode: 'direct', refusedAmqp: config.reason };
  return { mode: 'direct' };
}

/** Fail-closed transport used whenever AMQP is not (fully) configured or admitted. */
export function createDisabledEventTransport(reason: string): EventTransport {
  const refuse = () =>
    Promise.reject(new ServiceError('SERVICE_NOT_CONFIGURED', { details: { reason } }));
  return {
    kind: 'disabled',
    publish: refuse,
    consume: refuse,
    health: () => ({ kind: 'disabled', connected: false, reason }),
    close: async () => undefined,
  };
}
