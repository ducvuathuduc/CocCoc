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
