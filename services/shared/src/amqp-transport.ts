// RabbitMQ adapter for the EventTransport port (ADR-0018 "Event bus protocol requirements").
//
// Topology (one vhost per environment):
//   exchange coc.events      (topic, durable)  routing key <consumer>.<event type>
//   exchange coc.events.dlx  (topic, durable)  dead letters, same routing key
//   queue coc.<owner>.events       quorum, bound coc.events <owner>.#, explicit
//       x-delivery-limit=10, x-dead-letter-exchange=coc.events.dlx,
//       x-dead-letter-strategy=at-least-once, x-overflow=reject-publish
//   queue coc.<owner>.events.dead  quorum, bound coc.events.dlx <owner>.#, retained
// Each consumer owner declares its own queues (least privilege); producers declare exchanges
// only. Publishing to a route whose consumer never declared its queue is returned (mandatory)
// and reported as 'returned': the outbox keeps the row and retries, it never becomes ACK.
//
// Publishing: confirm channel, persistent + mandatory, messageId = eventId. Resolves
// 'confirmed' only after the broker ack with no basic.return; 'returned'/'nacked' otherwise;
// rejects on timeout/connection loss (unknown outcome -> retry the same event later).
//
// Consuming: bounded prefetch, manual ack. The handler decides; 'retry' waits a jittered backoff
// before requeue (no tight nack loop), and once the delivery count reaches the application limit
// (equal to the pinned broker limit) the delivery is rejected without requeue so the broker
// dead-letters it at-least-once. A connection loss requeues unacked deliveries (broker side);
// the consumer reconnects with bounded backoff until stopped.
import { connect as amqpConnect } from 'amqplib';
import { ServiceError } from './errors.js';
import { signEnvelope, verifyEnvelope } from './event-envelope.js';
import type {
  BusinessEvent,
  ConsumerHandle,
  DeliveryHandler,
  EventOwner,
  EventTransport,
  PublishOutcome,
  TransportHealth,
} from './ports.js';
import type { Keyring, ServiceKey } from './service-hmac.js';

export const EXCHANGE = 'coc.events';
export const DEAD_LETTER_EXCHANGE = 'coc.events.dlx';
/** Pinned broker delivery limit; the application retry limit is the same number. */
export const DELIVERY_LIMIT = 10;
export const queueFor = (owner: EventOwner) => `coc.${owner}.events`;
export const deadQueueFor = (owner: EventOwner) => `coc.${owner}.events.dead`;
export const routingKeyFor = (target: EventOwner, event: Pick<BusinessEvent, 'type'>) =>
  `${target}.${event.type}`;

export function queueArguments(): Record<string, unknown> {
  return {
    'x-queue-type': 'quorum',
    'x-delivery-limit': DELIVERY_LIMIT,
    'x-dead-letter-exchange': DEAD_LETTER_EXCHANGE,
    'x-dead-letter-strategy': 'at-least-once',
    'x-overflow': 'reject-publish',
  };
}
export function deadQueueArguments(): Record<string, unknown> {
  return { 'x-queue-type': 'quorum' };
}

// Minimal structural view of amqplib's promise API, so a test broker can stand in.
export interface AmqpMessage {
  content: Buffer;
  fields: { deliveryTag: number; redelivered: boolean; routingKey: string; exchange: string };
  properties: { messageId?: string; headers?: Record<string, unknown> };
}
export interface AmqpChannel {
  on(event: 'close', listener: () => void): unknown;
  on(event: 'error', listener: (err: Error) => void): unknown;
  on(event: 'return', listener: (message: AmqpMessage) => void): unknown;
  assertExchange(name: string, type: string, options: Record<string, unknown>): Promise<unknown>;
  assertQueue(name: string, options: Record<string, unknown>): Promise<unknown>;
  bindQueue(queue: string, exchange: string, pattern: string): Promise<unknown>;
  prefetch(count: number): Promise<unknown>;
  consume(
    queue: string,
    onMessage: (message: AmqpMessage | null) => void,
    options: Record<string, unknown>,
  ): Promise<{ consumerTag: string }>;
  cancel(consumerTag: string): Promise<unknown>;
  ack(message: AmqpMessage): void;
  nack(message: AmqpMessage, allUpTo: boolean, requeue: boolean): void;
  close(): Promise<void>;
}
export interface AmqpConfirmChannel extends AmqpChannel {
  publish(
    exchange: string,
    routingKey: string,
    content: Buffer,
    options: Record<string, unknown>,
    callback: (err: unknown) => void,
  ): boolean;
}
export interface AmqpConnection {
  on(event: 'close', listener: (err?: Error) => void): unknown;
  on(event: 'error', listener: (err: Error) => void): unknown;
  on(event: 'blocked', listener: (reason: string) => void): unknown;
  on(event: 'unblocked', listener: () => void): unknown;
  createChannel(): Promise<AmqpChannel>;
  createConfirmChannel(): Promise<AmqpConfirmChannel>;
  close(): Promise<void>;
}
export type AmqpConnect = (url: string) => Promise<AmqpConnection>;

const defaultConnect: AmqpConnect = async (url) =>
  (await amqpConnect(url, { timeout: 10_000 })) as unknown as AmqpConnection;

export interface AmqpTransportOptions {
  url: string;
  /** This process's owner (producer of its outbox, consumer of its queue). */
  service: EventOwner;
  /** COC_SERVICE_KEYS: producers' keys for verification, this owner's key for signing. */
  keyring: Keyring;
  signingKey: ServiceKey;
  prefetch?: number;
  confirmTimeoutMs?: number;
  connect?: AmqpConnect;
  /** Delay before requeueing a 'retry' delivery (default: jittered 1 s * 2^n, cap 30 s). */
  retryDelayMs?: (deliveryCount: number) => number;
  /** Delay before reconnecting a dropped consumer (default: jittered, cap 30 s). */
  reconnectDelayMs?: (attempt: number) => number;
  log?: (entry: Record<string, unknown>) => void;
}

function jittered(base: number, cap: number): number {
  const value = Math.min(base, cap);
  return Math.round(value / 2 + Math.random() * (value / 2));
}

function deliveryCountOf(message: AmqpMessage): number {
  const raw = message.properties.headers?.['x-delivery-count'];
  const count = typeof raw === 'number' ? raw : Number(raw ?? 0);
  return Number.isSafeInteger(count) && count >= 0 ? count : 0;
}

export function createAmqpEventTransport(options: AmqpTransportOptions): EventTransport {
  const connectFn = options.connect ?? defaultConnect;
  const confirmTimeoutMs = options.confirmTimeoutMs ?? 5000;
  const retryDelayMs =
    options.retryDelayMs ?? ((count: number) => jittered(1000 * 2 ** count, 30_000));
  const reconnectDelayMs =
    options.reconnectDelayMs ?? ((attempt: number) => jittered(500 * 2 ** attempt, 30_000));
  const log = options.log ?? (() => undefined);
  if (options.signingKey.sender !== options.service) {
    throw new ServiceError('SERVICE_NOT_CONFIGURED', { details: { reason: 'SIGNING_KEY_OWNER' } });
  }

  let closed = false;
  let connection: AmqpConnection | undefined;
  let connecting: Promise<AmqpConnection> | undefined;
  let publisher: Promise<AmqpConfirmChannel> | undefined;
  let blocked = false;
  let lastError: string | undefined;
  const returned = new Set<string>();
  const pendingPublishes = new Set<(error: Error) => void>();
  const consumers = new Set<() => Promise<void>>();

  const dropConnection = (reason: string) => {
    lastError = reason;
    connection = undefined;
    connecting = undefined;
    publisher = undefined;
  };

  const getConnection = (): Promise<AmqpConnection> => {
    if (closed) return Promise.reject(new ServiceError('SERVICE_NOT_CONFIGURED'));
    if (connection) return Promise.resolve(connection);
    connecting ??= (async () => {
      try {
        const conn = await connectFn(options.url);
        conn.on('error', () => undefined); // 'close' follows; the error message may hold the URL
        conn.on('close', () => {
          if (connection === conn) dropConnection('CONNECTION_CLOSED');
        });
        conn.on('blocked', () => {
          blocked = true;
        });
        conn.on('unblocked', () => {
          blocked = false;
        });
        connection = conn;
        lastError = undefined;
        return conn;
      } catch {
        dropConnection('CONNECT_FAILED');
        throw new ServiceError('SERVICE_NOT_CONFIGURED', { details: { reason: 'AMQP_CONNECT' } });
      }
    })();
    return connecting;
  };

  const getPublisher = (): Promise<AmqpConfirmChannel> => {
    publisher ??= (async () => {
      try {
        const conn = await getConnection();
        const channel = await conn.createConfirmChannel();
        channel.on('error', () => undefined);
        channel.on('close', () => {
          publisher = undefined;
          const lost = new ServiceError('SERVICE_NOT_CONFIGURED', {
            details: { reason: 'AMQP_CLOSED' },
          });
          for (const fail of [...pendingPublishes]) fail(lost);
        });
        channel.on('return', (message) => {
          if (message.properties.messageId) returned.add(message.properties.messageId);
        });
        await channel.assertExchange(EXCHANGE, 'topic', { durable: true });
        await channel.assertExchange(DEAD_LETTER_EXCHANGE, 'topic', { durable: true });
        return channel;
      } catch (error) {
        publisher = undefined;
        throw error;
      }
    })();
    return publisher;
  };

  async function publish(target: EventOwner, event: BusinessEvent): Promise<PublishOutcome> {
    if (target === options.service) throw new ServiceError('FORBIDDEN');
    if (blocked) {
      // Broker resource alarm (disk/memory): do not pile up unconfirmed publishes.
      throw new ServiceError('SERVICE_NOT_CONFIGURED', { details: { reason: 'AMQP_BLOCKED' } });
    }
    const content = signEnvelope(options.signingKey, event);
    const channel = await getPublisher();
    returned.delete(event.eventId);
    return new Promise<PublishOutcome>((resolve, reject) => {
      let settled = false;
      const finish = (outcome: PublishOutcome | Error) => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        pendingPublishes.delete(finish);
        if (outcome instanceof Error) reject(outcome);
        else resolve(outcome);
      };
      pendingPublishes.add(finish);
      const timer = setTimeout(
        () => finish(new ServiceError('DEADLINE_EXCEEDED', { details: { reason: 'AMQP_CONFIRM' } })),
        confirmTimeoutMs,
      );
      try {
        channel.publish(
          EXCHANGE,
          routingKeyFor(target, event),
          content,
          {
            persistent: true,
            mandatory: true,
            messageId: event.eventId,
            type: event.type,
            appId: options.service,
            contentType: 'application/json',
          },
          (err) => {
            if (err) return finish('nacked');
            // basic.return precedes basic.ack for an unroutable mandatory message.
            const wasReturned = returned.delete(event.eventId);
            finish(wasReturned ? 'returned' : 'confirmed');
          },
        );
      } catch {
        finish(new ServiceError('SERVICE_NOT_CONFIGURED', { details: { reason: 'AMQP_PUBLISH' } }));
      }
    });
  }

  async function declareOwnQueues(channel: AmqpChannel, owner: EventOwner) {
    await channel.assertExchange(EXCHANGE, 'topic', { durable: true });
    await channel.assertExchange(DEAD_LETTER_EXCHANGE, 'topic', { durable: true });
    await channel.assertQueue(deadQueueFor(owner), {
      durable: true,
      arguments: deadQueueArguments(),
    });
    await channel.bindQueue(deadQueueFor(owner), DEAD_LETTER_EXCHANGE, `${owner}.#`);
    await channel.assertQueue(queueFor(owner), { durable: true, arguments: queueArguments() });
    await channel.bindQueue(queueFor(owner), EXCHANGE, `${owner}.#`);
  }

  async function consume(owner: EventOwner, handler: DeliveryHandler): Promise<ConsumerHandle> {
    if (owner !== options.service) throw new ServiceError('FORBIDDEN');
    let stopping = false;
    let current: { channel: AmqpChannel; tag: string } | undefined;
    let attempt = 0;
    let restartTimer: NodeJS.Timeout | undefined;
    const inflight = new Set<Promise<void>>();
    const waits = new Set<() => void>();

    const sleep = (ms: number) =>
      new Promise<void>((resolve) => {
        const done = () => {
          clearTimeout(timer);
          waits.delete(done);
          resolve();
        };
        const timer = setTimeout(done, ms);
        waits.add(done);
      });

    const handle = async (channel: AmqpChannel, message: AmqpMessage) => {
      const deliveryCount = deliveryCountOf(message);
      let decision: 'ack' | 'retry' | 'dead';
      try {
        const verified = verifyEnvelope(options.keyring, message.content);
        decision = await handler({ ...verified, deliveryCount });
      } catch (error) {
        // Envelope/authentication failures are never retried; anything else is transient.
        const code = error instanceof ServiceError ? error.code : undefined;
        decision =
          code === 'VALIDATION_ERROR' ||
          code === 'AUTH_REQUIRED' ||
          code === 'FORBIDDEN' ||
          code === 'PAYLOAD_TOO_LARGE'
            ? 'dead'
            : 'retry';
      }
      try {
        if (decision === 'ack') channel.ack(message);
        else if (decision === 'dead' || deliveryCount + 1 >= DELIVERY_LIMIT) {
          channel.nack(message, false, false);
          log({ service: owner, runtime: 'amqp', status: 'DEAD_LETTERED', deliveryCount });
        } else {
          if (!stopping) await sleep(retryDelayMs(deliveryCount));
          channel.nack(message, false, true);
        }
      } catch {
        // Channel already closed: the broker requeues the unacked delivery itself.
      }
    };

    const start = async (): Promise<void> => {
      if (stopping || closed) return;
      try {
        const conn = await getConnection();
        const channel = await conn.createChannel();
        channel.on('error', () => undefined);
        channel.on('close', () => {
          if (current?.channel === channel) current = undefined;
          if (!stopping && !closed) scheduleRestart();
        });
        await channel.prefetch(options.prefetch ?? 10);
        await declareOwnQueues(channel, owner);
        const { consumerTag } = await channel.consume(
          queueFor(owner),
          (message) => {
            if (!message) return; // consumer cancelled by the broker; 'close' handles restart
            const task = handle(channel, message).finally(() => inflight.delete(task));
            inflight.add(task);
          },
          { noAck: false },
        );
        current = { channel, tag: consumerTag };
        attempt = 0;
      } catch {
        scheduleRestart();
      }
    };

    const scheduleRestart = () => {
      if (stopping || closed || restartTimer) return;
      const delay = reconnectDelayMs(attempt++);
      restartTimer = setTimeout(() => {
        restartTimer = undefined;
        void start();
      }, delay);
    };

    const stop = async () => {
      stopping = true;
      if (restartTimer) clearTimeout(restartTimer);
      restartTimer = undefined;
      for (const wake of [...waits]) wake();
      const active = current;
      current = undefined;
      if (active) {
        try {
          await active.channel.cancel(active.tag);
        } catch {
          /* channel already gone */
        }
      }
      await Promise.allSettled([...inflight]);
      if (active) {
        try {
          await active.channel.close();
        } catch {
          /* already closed */
        }
      }
      consumers.delete(stop);
    };
    consumers.add(stop);
    await start();
    return { stop };
  }

  return {
    kind: 'amqp',
    publish,
    consume,
    health(): TransportHealth {
      const health: TransportHealth = { kind: 'amqp', connected: Boolean(connection) && !closed };
      const reason = closed ? 'CLOSED' : blocked ? 'BLOCKED' : lastError;
      if (reason) health.reason = reason;
      return health;
    },
    async close() {
      if (closed) return;
      for (const stop of [...consumers]) await stop();
      closed = true;
      const conn = connection;
      dropConnection('CLOSED');
      if (conn) {
        try {
          await conn.close();
        } catch {
          /* already closed */
        }
      }
    },
  };
}
