// AI transactional outbox -> signed delivery to Progress /internal/events (EVENTS_ERRORS,
// CONSISTENCY). The producing transaction (conversation completion, account purge) stages a
// PENDING a_outbox row; a dispatcher leases <= 20 due rows (lease 30 s, optimistic transaction),
// delivers them, and records ACK, a jittered retry, or DEAD after 10 failures. Progress dedupes by
// eventId, so delivery is at least once and the effect once. Same lease/settle protocol as the
// Learning dispatcher (services/learning/src/application/outbox.ts).
import { createInternalClient } from '../../../shared/src/internal-client.js';
import type { ServiceKey } from '../../../shared/src/service-hmac.js';
import type { AiTransaction, Row } from '../persistence/port.js';
import { iso, type AiDeps, type EventRelay } from './deps.js';

export const LEASE_MS = 30_000;
export const MAX_BATCH = 20;
export const DEAD_AFTER = 10;

export interface AiEvent {
  eventId: string;
  type: 'ai.practice.completed.v1' | 'account.purged.v1';
  schemaVersion: 1;
  producer: 'ai';
  aggregateId: string;
  occurredAt: string;
  requestId: string;
  payload: Record<string, unknown>;
}

export function stageOutboxEvent(tx: AiTransaction, event: AiEvent, nowMs: number): void {
  const at = iso(nowMs);
  tx.put('a_outbox', event.eventId, {
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

export type DeliveryOutcome = 'ack' | 'retry' | 'dead';
export type Deliver = (event: AiEvent) => Promise<DeliveryOutcome>;
export interface DispatchReport {
  leased: number;
  acked: number;
  retried: number;
  dead: number;
}

function backoffMs(attempt: number, random: () => number): number {
  const base = Math.min(2 ** attempt * 1000, 15 * 60_000);
  return Math.round(base / 2 + random() * (base / 2));
}

async function lease(deps: AiDeps, owner: string, limit: number, onlyIds?: readonly string[]) {
  const now = deps.nowMs();
  const nowIso = iso(now);
  const candidates = onlyIds
    ? (
        await Promise.all(
          onlyIds.map(async (id) => ({ id, row: await deps.persistence.read('a_outbox', id) })),
        )
      ).filter((c): c is { id: string; row: Row } => !!c.row)
    : [
        ...(
          await deps.persistence.list('a_outbox', {
            equal: { status: 'PENDING' },
            lessThanEqual: { nextAttemptAt: nowIso },
            orderAsc: 'nextAttemptAt',
            limit,
          })
        ).items,
        ...(
          await deps.persistence.list('a_outbox', {
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
      const row = await tx.get('a_outbox', id);
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
      tx.put('a_outbox', id, next);
      leased.push(next);
    }
    return leased;
  });
}

async function settle(
  deps: AiDeps,
  row: Row,
  owner: string,
  outcome: DeliveryOutcome,
  random: () => number,
) {
  const id = String(row['eventId']);
  await deps.persistence.transact(async (tx) => {
    const current = await tx.get('a_outbox', id);
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
    if (outcome === 'ack') tx.put('a_outbox', id, { ...base, status: 'ACK', ackAt: iso(now) });
    else if (outcome === 'dead' || attempt >= DEAD_AFTER)
      tx.put('a_outbox', id, { ...base, status: 'DEAD', attempt });
    else
      tx.put('a_outbox', id, {
        ...base,
        status: 'PENDING',
        attempt,
        nextAttemptAt: iso(now + backoffMs(attempt, random)),
      });
  });
}

export async function dispatchOutbox(
  deps: AiDeps,
  deliver: Deliver,
  options: {
    owner?: string;
    limit?: number;
    eventIds?: readonly string[];
    deadlineMs?: number;
    random?: () => number;
  } = {},
): Promise<DispatchReport> {
  const owner = (options.owner ?? `ai-dispatcher-${deps.newId()}`).slice(0, 64);
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
    if (options.deadlineMs !== undefined && deps.nowMs() - started > options.deadlineMs) break;
    let outcome: DeliveryOutcome;
    try {
      outcome = await deliver(JSON.parse(String(row['payloadJson'])) as AiEvent);
    } catch {
      outcome = 'retry';
    }
    await settle(deps, row, owner, outcome, random);
    if (outcome === 'ack') report.acked++;
    else if (outcome === 'dead') report.dead++;
    else report.retried++;
  }
  return report;
}

/**
 * Map a Progress /internal/events answer to an outcome. As Learning/Progress: 200 ack;
 * IDEMPOTENCY_CONFLICT, 403 and other 400s dead-letter. One exception: a 400 whose details name
 * the event `type` means the receiver deployment does not accept this event type yet (Progress
 * ships its ai.practice.completed.v1 consumer separately); that is retried, not dead-lettered,
 * so the completion is not lost while the receiver catches up (DEAD after 10 attempts still holds).
 */
export function outcomeForStatus(status: number, body: unknown): DeliveryOutcome {
  const error = (body as { error?: { code?: string; details?: { field?: string } } } | null)?.error;
  if (status === 200) return 'ack';
  if (status === 409 && error?.code === 'IDEMPOTENCY_CONFLICT') return 'dead';
  if (status === 400 && error?.details?.field === 'type') return 'retry';
  if (status === 400 || status === 403) return 'dead';
  return 'retry';
}

export function httpDeliver(options: {
  key: ServiceKey;
  progressBaseUrl: string;
  fetchImpl?: typeof fetch;
}): Deliver {
  const client = createInternalClient({
    key: options.key,
    baseUrl: options.progressBaseUrl,
    ...(options.fetchImpl ? { fetchImpl: options.fetchImpl } : {}),
  });
  return async (event) => {
    const response = await client.deliverEvent(event);
    return outcomeForStatus(response.status, response.body);
  };
}

/** Try to deliver just-committed events right away, bounded so the response is not held long. */
export function createImmediateRelay(
  getDeps: () => AiDeps,
  deliver: Deliver,
  deadlineMs = 1500,
): EventRelay {
  return {
    async afterCommit(eventIds) {
      if (!eventIds.length) return;
      try {
        await Promise.race([
          dispatchOutbox(getDeps(), deliver, { eventIds, deadlineMs }),
          new Promise<void>((resolve) => {
            setTimeout(resolve, deadlineMs).unref();
          }),
        ]);
      } catch {
        // The row stays PENDING/LEASED; a later dispatcher run delivers it.
      }
    },
  };
}
