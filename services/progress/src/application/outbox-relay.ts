// Progress outbox relay (docs/architecture/CONSISTENCY.md, EVENTS_ERRORS "Business event
// envelope"): leases <= 20 due p_outbox rows (lease 30s, optimistic transaction), delivers each
// event signed to every target owner, and records ACK only when every target acknowledged, a
// jittered retry otherwise, or DEAD after 10 failed attempts (or a non-retryable answer).
// Targets: account.deleted.v1 -> Learning + AI; entitlement.changed.v1 -> Learning + AI;
// energy.granted.v1 -> Learning. Receivers dedupe by eventId (inbox), so re-sending to a target
// that already acknowledged in an earlier attempt replays harmlessly: delivery is at least once,
// the effect once.
import type { ProgressPersistence, Row } from '../persistence/port.js';
import { editable } from './records.js';

export const RELAY_LEASE_MS = 30_000;
export const RELAY_MAX_BATCH = 20;
export const RELAY_DEAD_AFTER = 10;

export type RelayTarget = 'learning' | 'ai';
export const RELAY_TARGETS: Readonly<Record<string, readonly RelayTarget[]>> = {
  'account.deleted.v1': ['learning', 'ai'],
  'entitlement.changed.v1': ['learning', 'ai'],
  'energy.granted.v1': ['learning'],
};

export interface ProgressEvent {
  eventId: string;
  type: string;
  schemaVersion: 1;
  producer: 'progress';
  aggregateId: string;
  occurredAt: string;
  requestId: string;
  payload: Record<string, unknown>;
}

export type RelayOutcome = 'ack' | 'retry' | 'dead';
/** Deliver one event to one target; must not throw for HTTP errors (a throw counts as retry). */
export type RelayDeliver = (target: RelayTarget, event: ProgressEvent) => Promise<RelayOutcome>;

export interface RelayReport {
  leased: number;
  acked: number;
  retried: number;
  dead: number;
}

/** Map a receiver's /internal/events answer to an outcome (same table as Learning's dispatcher). */
export function relayOutcomeForStatus(status: number, code?: string): RelayOutcome {
  if (status === 200) return 'ack';
  if (status === 409 && code === 'IDEMPOTENCY_CONFLICT') return 'dead';
  if (status === 400 || status === 403) return 'dead';
  return 'retry';
}

/** Rebuild the signed envelope from the stored row; stable across attempts (same body hash). */
export function eventOf(row: Readonly<Row>): ProgressEvent {
  const occurred = Date.parse(String(row['occurredAt']));
  return {
    eventId: String(row['eventId']),
    type: String(row['type']),
    schemaVersion: 1,
    producer: 'progress',
    aggregateId: String(row['aggregateId']),
    occurredAt: Number.isNaN(occurred)
      ? String(row['occurredAt'])
      : new Date(occurred).toISOString(),
    requestId: String(row['eventId']),
    payload: JSON.parse(String(row['payloadJson'])) as Record<string, unknown>,
  };
}

function backoffMs(attempt: number, random: () => number): number {
  const base = Math.min(2 ** attempt * 1000, 15 * 60_000);
  return Math.round(base / 2 + random() * (base / 2));
}

async function leaseDue(
  store: ProgressPersistence,
  owner: string,
  limit: number,
  onlyIds?: readonly string[],
): Promise<Array<{ id: string; row: Row }>> {
  const nowIso = new Date(store.nowMs()).toISOString();
  const candidates = onlyIds
    ? (
        await Promise.all(
          onlyIds.map(async (id) => ({ id, row: await store.read('p_outbox', id) })),
        )
      ).filter((c): c is { id: string; row: Row } => !!c.row)
    : [
        ...(await store.list('p_outbox', {
          where: { status: 'PENDING' },
          lt: { nextAttemptAt: new Date(store.nowMs() + 1).toISOString() },
          orderBy: [['nextAttemptAt', 'asc']],
          limit,
        })),
        ...(await store.list('p_outbox', {
          where: { status: 'LEASED' },
          lt: { leaseUntil: nowIso },
          orderBy: [['leaseUntil', 'asc']],
          limit,
        })),
      ]
        .slice(0, limit)
        .map(({ id, row }) => ({ id, row: { ...row } }));
  if (!candidates.length) return [];
  return store.transact(async (tx) => {
    const leased: Array<{ id: string; row: Row }> = [];
    for (const { id } of candidates) {
      const row = await tx.get('p_outbox', id);
      if (!row) continue;
      const due =
        (row['status'] === 'PENDING' &&
          Date.parse(String(row['nextAttemptAt'])) <= Date.parse(tx.nowIso)) ||
        (row['status'] === 'LEASED' &&
          Date.parse(String(row['leaseUntil'] ?? '')) < Date.parse(tx.nowIso));
      if (!due) continue;
      const next: Row = {
        ...editable(row),
        status: 'LEASED',
        leaseOwner: owner,
        leaseUntil: new Date(tx.nowMs + RELAY_LEASE_MS).toISOString(),
      };
      tx.put('p_outbox', id, next);
      leased.push({ id, row: next });
    }
    return leased;
  });
}

async function settle(
  store: ProgressPersistence,
  id: string,
  owner: string,
  outcome: RelayOutcome,
  random: () => number,
): Promise<void> {
  await store.transact(async (tx) => {
    const current = await tx.get('p_outbox', id);
    // Lost the lease (expired and re-leased elsewhere): the new owner settles it.
    if (!current || current['status'] !== 'LEASED' || current['leaseOwner'] !== owner) return;
    const attempt = Number(current['attempt'] ?? 0) + (outcome === 'ack' ? 0 : 1);
    const base = { ...editable(current), leaseOwner: null, leaseUntil: null };
    if (outcome === 'ack') tx.put('p_outbox', id, { ...base, status: 'ACK', ackAt: tx.nowIso });
    else if (outcome === 'dead' || attempt >= RELAY_DEAD_AFTER)
      tx.put('p_outbox', id, { ...base, status: 'DEAD', attempt });
    else
      tx.put('p_outbox', id, {
        ...base,
        status: 'PENDING',
        attempt,
        nextAttemptAt: new Date(tx.nowMs + backoffMs(attempt, random)).toISOString(),
      });
  });
}

/** Deliver one event to all of its targets; ack only when every target acknowledged. */
async function deliverAll(deliver: RelayDeliver, event: ProgressEvent): Promise<RelayOutcome> {
  const targets = RELAY_TARGETS[event.type];
  if (!targets) return 'dead'; // unknown type: never partially applied, surfaces as a dead letter
  let result: RelayOutcome = 'ack';
  for (const target of targets) {
    let outcome: RelayOutcome;
    try {
      outcome = await deliver(target, event);
    } catch {
      outcome = 'retry';
    }
    if (outcome === 'dead') return 'dead';
    if (outcome === 'retry') result = 'retry';
  }
  return result;
}

export async function relayOutbox(
  store: ProgressPersistence,
  deliver: RelayDeliver,
  options: {
    owner?: string;
    limit?: number;
    rowIds?: readonly string[];
    deadlineMs?: number;
    random?: () => number;
  } = {},
): Promise<RelayReport> {
  const owner = (
    options.owner ??
    `relay-${store.nowMs().toString(36)}-${Math.random().toString(36).slice(2, 10)}`
  ).slice(0, 64);
  const random = options.random ?? Math.random;
  const report: RelayReport = { leased: 0, acked: 0, retried: 0, dead: 0 };
  const rows = await leaseDue(
    store,
    owner,
    Math.min(options.limit ?? RELAY_MAX_BATCH, RELAY_MAX_BATCH),
    options.rowIds,
  );
  report.leased = rows.length;
  const started = store.nowMs();
  for (const { id, row } of rows) {
    // Stay inside the lease: anything not attempted before the deadline expires and is retried.
    if (options.deadlineMs !== undefined && store.nowMs() - started > options.deadlineMs) break;
    let outcome: RelayOutcome;
    try {
      outcome = await deliverAll(deliver, eventOf(row));
    } catch {
      outcome = 'dead'; // unparseable stored payload: never retried blindly
    }
    await settle(store, id, owner, outcome, random);
    if (outcome === 'ack') report.acked++;
    else if (outcome === 'dead') report.dead++;
    else report.retried++;
  }
  return report;
}
