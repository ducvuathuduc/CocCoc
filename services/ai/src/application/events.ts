// AI inbox consumer (EVENTS_ERRORS: AI accepts account.deleted.v1 and entitlement.changed.v1 from
// Progress). The a_inbox row and every effect commit atomically; a duplicate replays; a changed
// payload under the same eventId is IDEMPOTENCY_CONFLICT; an invalid payload is VALIDATION_ERROR
// (never partially applied).
//
// account.deleted.v1 (FR-AUTH-005): every a_ row owned by the user is deleted in bounded batches;
// the last batch, the a_inbox row and the account.purged.v1 acknowledgement in a_outbox commit
// together, so an acknowledgement exists only after the purge finished.
// entitlement.changed.v1: keeps only the newest entitlementRevision as the AI plan projection.
import { ServiceError } from '../../../shared/src/errors.js';
import type { BusinessEvent, EventConsumer } from '../../../shared/src/ports.js';
import {
  ENTITLEMENT_DAY,
  ENTITLEMENT_STATUSES,
  PLANS,
  parseProjection,
  type EntitlementProjection,
} from '../domain/plans.js';
import { ids } from '../persistence/ids.js';
import type { AiTable, AiTransaction } from '../persistence/port.js';
import { iso, stamp, uuidFrom, type AiDeps } from './deps.js';
import { stageOutboxEvent, type AiEvent } from './outbox.js';

const ID = /^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
/** Rows deleted per transaction (Appwrite transactions are capped at 100 operations). */
export const PURGE_BATCH = 80;
/** a_ tables whose rows carry the owner's userId. */
const USER_TABLES: readonly AiTable[] = [
  'a_conversations',
  'a_voice_sessions',
  'a_active_slots',
  'a_jobs',
  'a_usage',
  'a_receipts',
];

function invalid(reason: string): never {
  throw new ServiceError('VALIDATION_ERROR', { details: { reason } });
}
function exactKeys(payload: Record<string, unknown>, keys: readonly string[]) {
  if (!payload || typeof payload !== 'object') invalid('PAYLOAD');
  const actual = Object.keys(payload);
  if (actual.some((k) => !keys.includes(k)) || keys.some((k) => !(k in payload))) {
    invalid('PAYLOAD_FIELDS');
  }
}

export function projectionRow(
  userId: string,
  projection: EntitlementProjection,
  previous: Readonly<Record<string, unknown>> | null,
  nowMs: number,
) {
  return stamp(
    previous,
    {
      userId,
      utcDay: ENTITLEMENT_DAY,
      liveReservedSeconds: 0,
      liveUsedSeconds: 0,
      liveGrants: 0,
      textRequests: 0,
      recordedSpeechSeconds: 0,
      recordedReservedSeconds: 0,
      reservationIdsJson: JSON.stringify(projection),
    },
    nowMs,
  );
}

export async function readProjection(
  deps: AiDeps,
  userId: string,
): Promise<EntitlementProjection | null> {
  const row = await deps.persistence.read('a_usage', ids.entitlement(userId));
  return row ? parseProjection(row['reservationIdsJson']) : null;
}

async function applyEntitlement(deps: AiDeps, event: BusinessEvent, bodyHash: string) {
  const p = event.payload as Record<string, unknown>;
  exactKeys(p, ['userId', 'plan', 'status', 'expiresAt', 'entitlementRevision']);
  if (typeof p['userId'] !== 'string' || !ID.test(p['userId'])) invalid('USER_ID');
  if (!(PLANS as readonly unknown[]).includes(p['plan'])) invalid('PLAN');
  if (!(ENTITLEMENT_STATUSES as readonly unknown[]).includes(p['status'])) invalid('STATUS');
  if (
    p['expiresAt'] !== null &&
    (typeof p['expiresAt'] !== 'string' || Number.isNaN(Date.parse(p['expiresAt'])))
  ) {
    invalid('EXPIRES_AT');
  }
  const revision = p['entitlementRevision'];
  if (!Number.isInteger(revision) || (revision as number) < 0 || (revision as number) > 2 ** 31 - 1)
    invalid('REVISION');
  const userId = p['userId'] as string;
  const incoming: EntitlementProjection = {
    plan: p['plan'] as EntitlementProjection['plan'],
    status: p['status'] as EntitlementProjection['status'],
    expiresAt: p['expiresAt'] === null ? null : iso(Date.parse(p['expiresAt'] as string)),
    entitlementRevision: revision as number,
  };
  return deps.persistence.applyInboxEvent(
    { eventId: event.eventId, type: event.type, bodyHash },
    async (tx) => {
      const id = ids.entitlement(userId);
      const current = await tx.get('a_usage', id);
      const known = current ? parseProjection(current['reservationIdsJson']) : null;
      // Out-of-order delivery: an older revision never overwrites a newer projection.
      if (known && known.entitlementRevision >= incoming.entitlementRevision) return;
      tx.put('a_usage', id, projectionRow(userId, incoming, current, deps.nowMs()));
    },
  );
}

/** Up to `limit` rows owned by the user across the a_ tables (plus its outbox rows). */
async function ownedRows(deps: AiDeps, userId: string, limit: number) {
  const found: Array<{ table: AiTable; id: string }> = [];
  for (const table of USER_TABLES) {
    if (found.length >= limit) break;
    const page = await deps.persistence.list(table, {
      equal: { userId },
      limit: limit - found.length,
    });
    for (const item of page.items) found.push({ table, id: item.id });
  }
  if (found.length < limit) {
    const outbox = await deps.persistence.list('a_outbox', {
      equal: { aggregateId: userId, type: 'ai.practice.completed.v1' },
      limit: limit - found.length,
    });
    for (const item of outbox.items) found.push({ table: 'a_outbox', id: item.id });
  }
  return found;
}

async function applyDeletion(deps: AiDeps, event: BusinessEvent, bodyHash: string) {
  const p = event.payload as Record<string, unknown>;
  exactKeys(p, ['userId', 'requestId']);
  if (typeof p['userId'] !== 'string' || !ID.test(p['userId'])) invalid('USER_ID');
  if (typeof p['requestId'] !== 'string' || !UUID.test(p['requestId'])) invalid('REQUEST_ID');
  const userId = p['userId'] as string;
  const requestId = p['requestId'] as string;
  const entry = { eventId: event.eventId, type: event.type, bodyHash };
  const inbox = await deps.persistence.read('a_inbox', ids.inbox(event.eventId));
  if (inbox) {
    if (inbox['bodyHash'] !== bodyHash) {
      throw new ServiceError('IDEMPOTENCY_CONFLICT', { details: { eventId: event.eventId } });
    }
    return { status: 'replayed' as const, eventIds: [] };
  }
  const removeAll = (tx: AiTransaction, rows: Array<{ table: AiTable; id: string }>) => {
    for (const row of rows) tx.remove(row.table, row.id);
  };
  // Bounded batches; each batch commits on its own and a re-delivery resumes where it stopped.
  for (let guard = 0; guard < 1000; guard++) {
    const rows = await ownedRows(deps, userId, PURGE_BATCH);
    if (rows.length >= PURGE_BATCH) {
      await deps.persistence.transact(async (tx) => removeAll(tx, rows));
      continue;
    }
    const ack: AiEvent = {
      eventId: uuidFrom(`account.purged.v1|ai|${event.eventId}`),
      type: 'account.purged.v1',
      schemaVersion: 1,
      producer: 'ai',
      aggregateId: userId,
      occurredAt: iso(deps.nowMs()),
      requestId: requestId,
      payload: { userId, requestId, owner: 'ai' },
    };
    const status = await deps.persistence.applyInboxEvent(entry, async (tx) => {
      removeAll(tx, rows);
      stageOutboxEvent(tx, ack, deps.nowMs());
    });
    return { status, eventIds: status === 'accepted' ? [ack.eventId] : [] };
  }
  throw new ServiceError('INTERNAL_ERROR', { details: { reason: 'PURGE_DID_NOT_CONVERGE' } });
}

export function createAiEventConsumer(deps: AiDeps): EventConsumer {
  return {
    async consume(event, context) {
      if (event.type === 'entitlement.changed.v1') {
        return applyEntitlement(deps, event, context.bodyHash);
      }
      if (event.type === 'account.deleted.v1') {
        const result = await applyDeletion(deps, event, context.bodyHash);
        if (deps.relay) await deps.relay.afterCommit(result.eventIds);
        return result.status;
      }
      throw new ServiceError('SERVICE_NOT_CONFIGURED');
    },
  };
}
