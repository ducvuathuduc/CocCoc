// Protocol-level port contracts the shared router depends on. Owner-specific persistence
// interfaces (tables, receipts, inbox) live in services/<owner>/src/persistence/port.ts.
import type { components } from '../../../packages/api_contracts/generated.js';
import type { ServiceSender } from './service-hmac.js';

export type ServiceName = 'learning' | 'progress' | 'ai';
export type BusinessEvent = components['schemas']['BusinessEvent'];
export type AdapterKind = 'memory' | 'appwrite' | 'disabled';

/** Minimal persistence surface needed for readiness. */
export interface PersistencePort {
  readonly service: ServiceName;
  readonly kind: AdapterKind;
  /**
   * True only for a durable adapter that passed the admitted cloud gate
   * (transactions/conflict/permission probes). In-memory adapters are never admitted.
   */
  readonly admittedForHosting: boolean;
  /** Cheap reachability probe; throws ServiceError('DB_UNAVAILABLE') on failure. */
  ping(): Promise<void>;
}

/** Idempotency receipt identity: unique(userId, operation, key) per owner (DATA_MODEL). */
export interface ReceiptKey {
  userId: string;
  operation: string;
  key: string;
}
export interface StoredReceipt extends ReceiptKey {
  bodyHash: string;
  statusCode: number;
  response: unknown;
  expiresAt: string;
}
export type ReceiptOutcome =
  { status: 'created'; receipt: StoredReceipt } | { status: 'replayed'; receipt: StoredReceipt };

/** Inbox row: unique(eventId); bodyHash rejects payload substitution. */
export interface InboxEntry {
  eventId: string;
  type: string;
  bodyHash: string;
  appliedAt: string;
}

export interface EventContext {
  bodyHash: string;
  requestId: string;
  sender: ServiceSender;
}
/** Owner domain consumer: inbox row and every domain effect commit atomically. */
export interface EventConsumer {
  consume(event: BusinessEvent, context: EventContext): Promise<'accepted' | 'replayed'>;
}

/** Staged, owner-table-scoped writes committed atomically with the receipt/inbox row. */
export interface OwnerTransaction<Table extends string> {
  get(table: Table, id: string): Promise<Readonly<Record<string, unknown>> | null>;
  put(table: Table, id: string, row: Record<string, unknown>): void;
}
export interface OwnerStore<
  Service extends ServiceName,
  Table extends string,
> extends PersistencePort {
  readonly service: Service;
  /** Tables this owner may write (DATA_MODEL prefix); anything else is refused. */
  readonly ownedTables: readonly Table[];
  /**
   * Same key + same body hash replays the stored response; same key + different hash is
   * IDEMPOTENCY_CONFLICT; otherwise the effect's staged writes and the receipt commit together.
   */
  commitWithReceipt(
    key: ReceiptKey,
    bodyHash: string,
    effect: (tx: OwnerTransaction<Table>) => Promise<{ statusCode: number; response: unknown }>,
  ): Promise<ReceiptOutcome>;
  /**
   * Same eventId + same hash replays; changed hash is IDEMPOTENCY_CONFLICT; otherwise the
   * inbox row and the effect's staged writes commit together. A failed commit leaves neither.
   */
  applyInboxEvent(
    entry: Omit<InboxEntry, 'appliedAt'>,
    effect: (tx: OwnerTransaction<Table>) => Promise<void>,
  ): Promise<'accepted' | 'replayed'>;
  read(table: Table, id: string): Promise<Readonly<Record<string, unknown>> | null>;
}

// ---------------------------------------------------------------------------------------------
// ADR-0018 runtime ports (Phase 5.2). Both are optional: the direct signed HTTP relay and
// uncached primary reads remain the default and the rollback path. Adapters live in
// amqp-transport.ts / redis-cache.ts; the disabled forms in event-transport.ts / read-cache.ts.
// ---------------------------------------------------------------------------------------------

/** Owner service that produced or must apply an event (never 'maintainer'/'scheduler'). */
export type EventOwner = ServiceName;

/** Result of one broker publish. Only 'confirmed' means the broker durably accepted it. */
export type PublishOutcome = 'confirmed' | 'returned' | 'nacked';

export interface TransportHealth {
  kind: 'amqp' | 'disabled';
  connected: boolean;
  reason?: string;
}

/** One event as delivered from the broker after envelope signature verification. */
export interface TransportDelivery {
  event: BusinessEvent;
  /** canonicalBodyHash(event): the same identity the direct relay and the inbox use. */
  bodyHash: string;
  /** Producer proven by the envelope signature, never by AMQP headers alone. */
  sender: EventOwner;
  keyId: string;
  /** Broker redelivery count (quorum `x-delivery-count`), 0 on first delivery. */
  deliveryCount: number;
}

/**
 * What the consumer decided for one delivery. 'ack' is only returned after the inbox commit AND
 * the producer recorded the application receipt; 'retry' requeues with backoff (bounded by the
 * pinned delivery limit); 'dead' routes to the retained dead-letter queue (security failure,
 * unknown producer/type, or attempts exhausted).
 */
export type DeliveryDecision = 'ack' | 'retry' | 'dead';
export type DeliveryHandler = (delivery: TransportDelivery) => Promise<DeliveryDecision>;

export interface ConsumerHandle {
  stop(): Promise<void>;
}

/** Asynchronous event transport over the owner outbox/inbox. Never a source of truth. */
export interface EventTransport {
  readonly kind: 'amqp' | 'disabled';
  /**
   * Publish the unchanged event to one target owner's queue after the outbox commit. Resolves
   * after the broker confirm (or return/nack); rejects when the outcome is unknown (connection
   * lost, timeout): the caller retries the SAME event ID and payload later.
   */
  publish(target: EventOwner, event: BusinessEvent): Promise<PublishOutcome>;
  /** Consume this owner's queue with bounded prefetch. */
  consume(owner: EventOwner, handler: DeliveryHandler): Promise<ConsumerHandle>;
  health(): TransportHealth;
  close(): Promise<void>;
}

/**
 * Application receipt (ADR-0018): the consumer tells the producing owner that the event was
 * applied (or replayed) by that consumer. Sent fresh and authenticated after the consumer's inbox
 * commit; the AMQP delivery is acknowledged only after the producer recorded it.
 */
export interface ApplicationReceipt {
  eventId: string;
  bodyHash: string;
  producer: EventOwner;
  consumer: EventOwner;
  outcome: 'applied' | 'replayed';
}
/** Sends a receipt to the producer; resolves only once the producer durably recorded it. */
export interface ReceiptPort {
  send(receipt: ApplicationReceipt): Promise<void>;
}

export interface CacheHealth {
  kind: 'redis' | 'disabled';
  connected: boolean;
  reason?: string;
}
/**
 * Disposable derived read cache (cache-aside). Implementations never throw from get/set/
 * invalidate: a cache failure is a miss and the caller reads the primary owner store.
 * Never store JWTs, provider secrets, audio, ledgers, receipts or entitlement decisions.
 */
export interface ReadCache {
  readonly kind: 'redis' | 'disabled';
  get(key: string): Promise<string | undefined>;
  set(key: string, value: string, ttlSeconds: number): Promise<void>;
  /** Remove every key under a namespace prefix (bounded scan). */
  invalidate(prefix: string): Promise<void>;
  health(): CacheHealth;
  close(): Promise<void>;
}
