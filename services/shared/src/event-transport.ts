// ADR-0018 event transport selection. Default: the direct signed HTTP relay (EVENTS_ERRORS).
// AMQP is used only when COC_EVENT_TRANSPORT=amqp, a broker URL is present (amqps://, or amqp://
// with the explicit private Compose marker) and COC_AMQP_ROUTES names the producer->consumer
// routes cut over so far (one route at a time; docs/devops/OPERATIONS.md). Anything partial or
// unknown is 'refused': the caller keeps the direct relay and reports the reason, never a fake.
import { ServiceError } from './errors.js';
import type {
  BusinessEvent,
  DeliveryHandler,
  EventConsumer,
  EventOwner,
  EventTransport,
  ReceiptPort,
} from './ports.js';
import { acceptBusinessEvent } from './transport.js';

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

/**
 * Outbox delivery over a broker for one target. 'published' means the broker durably accepted
 * the event; the outbox row stays pending until the consumer's application receipt arrives
 * (a confirm never counts as applied). Anything else, including an unknown outcome, is 'retry'
 * with the same event ID and payload.
 */
export async function publishForTarget(
  transport: EventTransport,
  target: EventOwner,
  event: BusinessEvent,
): Promise<'published' | 'retry'> {
  try {
    return (await transport.publish(target, event)) === 'confirmed' ? 'published' : 'retry';
  } catch {
    return 'retry';
  }
}

const DEAD_CODES = new Set(['IDEMPOTENCY_CONFLICT', 'FORBIDDEN', 'VALIDATION_ERROR']);

/**
 * Consumer pipeline for one owner (ADR-0018 application receipt path):
 *   1. allowlist + producer == verified envelope signer (acceptBusinessEvent),
 *   2. the owner's consumer commits inbox + domain effects atomically,
 *   3. a fresh authenticated receipt is recorded by the producer,
 *   4. only then 'ack'.
 * A crash or failure between any two steps leaves the delivery unacknowledged: the broker
 * redelivers, step 2 replays from the inbox (same eventId/hash) and step 3 is idempotent.
 * A changed payload under the same eventId, an unknown type or a wrong producer dead-letters.
 */
export function createReceiptingHandler(options: {
  owner: EventOwner;
  consumer: EventConsumer;
  receipts: ReceiptPort;
  log?: (entry: Record<string, unknown>) => void;
}): DeliveryHandler {
  const log = options.log ?? (() => undefined);
  return async (delivery) => {
    let outcome: 'accepted' | 'replayed';
    try {
      outcome = await acceptBusinessEvent(
        options.owner,
        options.consumer,
        delivery.event,
        delivery.sender,
        delivery.event.requestId,
      );
    } catch (error) {
      const code = error instanceof ServiceError ? error.code : 'INTERNAL_ERROR';
      log({ service: options.owner, runtime: 'amqp', status: 'CONSUME_FAILED', code });
      return DEAD_CODES.has(code) ? 'dead' : 'retry';
    }
    try {
      await options.receipts.send({
        eventId: delivery.event.eventId,
        bodyHash: delivery.bodyHash,
        producer: delivery.sender,
        consumer: options.owner,
        outcome: outcome === 'accepted' ? 'applied' : 'replayed',
      });
    } catch {
      // Effects are committed; without the producer's record we must not ack. Redelivery replays.
      log({ service: options.owner, runtime: 'amqp', status: 'RECEIPT_FAILED' });
      return 'retry';
    }
    return 'ack';
  };
}
