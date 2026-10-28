// P5-LESSON-003: transactional outbox -> signed lesson.completed.v1 delivery to Progress
// (EVENTS_ERRORS "Business event envelope", CONSISTENCY). The completion transaction inserts the
// PENDING row; a dispatcher leases <=20 due rows (lease 30s, optimistic transaction), delivers them
// sequentially, and records ACK, a jittered retry, or DEAD after 10 failures. Network delivery is
// at least once; Progress' inbox dedupe gives one effect per eventId.
import { ServiceError } from '../../../shared/src/errors.js';
import type { ApplicationReceipt } from '../../../shared/src/ports.js';
import { canonicalBodyHash } from '../../../shared/src/transport.js';
import type { SessionMode } from '../content/types.js';
import type { LearningTransaction, Row } from '../persistence/port.js';
import { iso, type LearningDeps } from './deps.js';

export const LEASE_MS = 30_000;
export const MAX_BATCH = 20;
export const DEAD_AFTER = 10;
/**
 * ADR-0018: after a broker confirm ('published') the row stays PENDING until Progress' application
 * receipt marks it ACK; if no receipt arrives it is republished (same eventId/payload) after this
 * wait. A confirm is never counted as applied, so the settlement watermark keeps waiting.
 */
export const RECEIPT_WAIT_MS = 10 * 60_000;

export interface LessonCompletedEvent {
  eventId: string;
  type: 'lesson.completed.v1';
  schemaVersion: 1;
  producer: 'learning';
  aggregateId: string;
  occurredAt: string;
  requestId: string;
  payload: {
    completionId: string;
    userId: string;
    courseId: string;
    lessonVersion: string;
    rewardIdentity: string;
    source: 'ONLINE' | 'OFFLINE';
    mode: SessionMode;
    originalCount: number;
    originalCorrect: number;
    assisted: boolean;
  };
}

/** account.purged.v1: Learning's acknowledgement that a deleted account's rows are gone. */
export interface AccountPurgedEvent {
  eventId: string;
  type: 'account.purged.v1';
  schemaVersion: 1;
  producer: 'learning';
  aggregateId: string;
  occurredAt: string;
  requestId: string;
  payload: { userId: string; requestId: string; owner: 'learning' };
}

/** Events Learning produces into l_outbox (all delivered to Progress /internal/events). */
export type LearningOutboxEvent = LessonCompletedEvent | AccountPurgedEvent;

export function stageOutboxEvent(
  tx: LearningTransaction,
  event: LearningOutboxEvent,
  nowMs: number,
): void {
  const at = iso(nowMs);
  tx.put('l_outbox', event.eventId, {
    eventId: event.eventId,
    type: event.type,
    schemaVersion: event.schemaVersion,
    aggregateId: event.aggregateId,
    occurredAt: event.occurredAt,
    payloadJson: JSON.stringify(event),
    attempt: 0,
    nextAttemptAt: at,
    leaseOwner: null,
    leaseUntil: null,
    status: 'PENDING',
    ackAt: null,
    revision: 0,
    createdAt: at,
    updatedAt: at,
  });
}

export type DeliveryOutcome = 'ack' | 'retry' | 'dead' | 'published';
/** Deliver one event; map the receiver's answer to an outcome. Must not throw for HTTP errors. */
export type Deliver = (event: LearningOutboxEvent) => Promise<DeliveryOutcome>;

export interface DispatchReport {
  leased: number;
  acked: number;
  retried: number;
  dead: number;
  /** Broker-confirmed, awaiting the application receipt (AMQP routes only; omitted when 0). */
  published?: number;
}

function backoffMs(attempt: number, random: () => number): number {
  const base = Math.min(2 ** attempt * 1000, 15 * 60_000);
  return Math.round(base / 2 + random() * (base / 2));
}

/** Lease due rows (PENDING with nextAttemptAt<=now, or LEASED with an expired lease). */
async function lease(
  deps: LearningDeps,
  owner: string,
  limit: number,
  onlyIds?: readonly string[],
): Promise<Row[]> {
  const now = deps.nowMs();
  const nowIso = iso(now);
  const candidates = onlyIds
    ? (
        await Promise.all(
          onlyIds.map(async (id) => ({ id, row: await deps.persistence.read('l_outbox', id) })),
        )
      ).filter((c): c is { id: string; row: Row } => !!c.row)
    : [
        ...(
          await deps.persistence.list('l_outbox', {
            equal: { status: 'PENDING' },
            lessThanEqual: { nextAttemptAt: nowIso },
            orderAsc: 'nextAttemptAt',
            limit,
          })
        ).items,
        ...(
          await deps.persistence.list('l_outbox', {
            equal: { status: 'LEASED' },
            lessThan: { leaseUntil: nowIso },
            orderAsc: 'leaseUntil',
            limit,
          })
        ).items,
      ].slice(0, limit);
  if (!candidates.length) return [];
  return deps.persistence.transact(async (tx) => {
    const leased: Row[] = [];
    for (const { id } of candidates) {
      const row = await tx.get('l_outbox', id);
      if (!row) continue;
      const due =
        (row['status'] === 'PENDING' && String(row['nextAttemptAt']) <= nowIso) ||
        (row['status'] === 'LEASED' && String(row['leaseUntil'] ?? '') < nowIso);
      if (!due) continue;
      const next = {
        ...row,
        status: 'LEASED',
        leaseOwner: owner,
        leaseUntil: iso(now + LEASE_MS),
        revision: Number(row['revision']) + 1,
        updatedAt: nowIso,
      };
      tx.put('l_outbox', id, next);
      leased.push(next);
    }
    return leased;
  });
}

async function settle(
  deps: LearningDeps,
  row: Row,
  owner: string,
  outcome: DeliveryOutcome,
  random: () => number,
) {
  const id = String(row['eventId']);
  await deps.persistence.transact(async (tx) => {
    const current = await tx.get('l_outbox', id);
    // Lost the lease (expired and re-leased elsewhere): leave the row to its new owner.
    if (!current || current['status'] !== 'LEASED' || current['leaseOwner'] !== owner) return;
    const now = deps.nowMs();
    const attempt = Number(current['attempt']) + (outcome === 'ack' ? 0 : 1);
    const base = {
      ...current,
      leaseOwner: null,
      leaseUntil: null,
      revision: Number(current['revision']) + 1,
      updatedAt: iso(now),
    };
    if (outcome === 'ack') tx.put('l_outbox', id, { ...base, status: 'ACK', ackAt: iso(now) });
    else if (outcome === 'published')
      tx.put('l_outbox', id, {
        ...base,
        status: 'PENDING',
        attempt: Number(current['attempt']),
        nextAttemptAt: iso(now + RECEIPT_WAIT_MS),
      });
    else if (outcome === 'dead' || attempt >= DEAD_AFTER)
      tx.put('l_outbox', id, { ...base, status: 'DEAD', attempt });
    else
      tx.put('l_outbox', id, {
        ...base,
        status: 'PENDING',
        attempt,
        nextAttemptAt: iso(now + backoffMs(attempt, random)),
      });
  });
}

export async function dispatchOutbox(
  deps: LearningDeps,
  deliver: Deliver,
  options: {
    owner?: string;
    limit?: number;
    eventIds?: readonly string[];
    deadlineMs?: number;
    random?: () => number;
  } = {},
): Promise<DispatchReport> {
  const owner = (options.owner ?? `dispatcher-${deps.newId()}`).slice(0, 64);
  const random = options.random ?? Math.random;
  const report: DispatchReport = { leased: 0, acked: 0, retried: 0, dead: 0 };
  const rows = await lease(
    deps,
    owner,
    Math.min(options.limit ?? MAX_BATCH, MAX_BATCH),
    options.eventIds,
  );
  report.leased = rows.length;
  const started = deps.nowMs();
  for (const row of rows) {
    // Stay inside the lease: anything not attempted before the deadline is retried by a later run.
    if (options.deadlineMs !== undefined && deps.nowMs() - started > options.deadlineMs) break;
    let outcome: DeliveryOutcome;
    try {
      outcome = await deliver(JSON.parse(String(row['payloadJson'])) as LearningOutboxEvent);
    } catch {
      outcome = 'retry';
    }
    await settle(deps, row, owner, outcome, random);
    if (outcome === 'ack') report.acked++;
    else if (outcome === 'dead') report.dead++;
    else if (outcome === 'published') report.published = (report.published ?? 0) + 1;
    else report.retried++;
  }
  return report;
}

/**
 * Record Progress' application receipt for a Learning outbox event (ADR-0018). Only the event's
 * target may acknowledge it and only for the exact payload; a repeat is a harmless replay. The
 * row becomes ACK even if it was DEAD or leased: the consumer proved the effect is committed.
 */
export async function recordOutboxReceipt(
  deps: LearningDeps,
  receipt: ApplicationReceipt,
): Promise<'recorded' | 'replayed'> {
  if (receipt.producer !== 'learning' || receipt.consumer !== 'progress') {
    throw new ServiceError('FORBIDDEN');
  }
  return deps.persistence.transact(async (tx) => {
    const row = await tx.get('l_outbox', receipt.eventId);
    if (!row) throw new ServiceError('NOT_FOUND');
    if (canonicalBodyHash(JSON.parse(String(row['payloadJson']))) !== receipt.bodyHash) {
      throw new ServiceError('IDEMPOTENCY_CONFLICT');
    }
    if (row['status'] === 'ACK') return 'replayed';
    const now = deps.nowMs();
    tx.put('l_outbox', receipt.eventId, {
      ...row,
      status: 'ACK',
      ackAt: iso(now),
      leaseOwner: null,
      leaseUntil: null,
      revision: Number(row['revision']) + 1,
      updatedAt: iso(now),
    });
    return 'recorded';
  });
}

/** Map a Progress /internal/events HTTP answer to an outcome (EVENTS_ERRORS). */
export function outcomeForStatus(status: number, code?: string): DeliveryOutcome {
  if (status === 200) return 'ack';
  // A changed payload under the same eventId is a security error: never retry it blindly.
  if (status === 409 && code === 'IDEMPOTENCY_CONFLICT') return 'dead';
  if (status === 400 || status === 403) return 'dead';
  return 'retry';
}

/** GET /internal/outbox-watermark: undelivered events (PENDING/LEASED/DEAD) older than `before`. */
export async function outboxWatermark(deps: LearningDeps, before: string) {
  const result = await deps.persistence.list('l_outbox', {
    equal: { status: ['PENDING', 'LEASED', 'DEAD'] },
    lessThan: { occurredAt: before },
    orderAsc: 'occurredAt',
    limit: 1,
  });
  return {
    before,
    oldestUndeliveredAt: result.items[0] ? String(result.items[0].row['occurredAt']) : null,
    pendingBefore: result.total,
  };
}
