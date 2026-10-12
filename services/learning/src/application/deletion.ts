// FR-AUTH-005 Learning purge: account.deleted.v1 (Progress -> Learning) removes every private
// Learning row of the user, then acknowledges with account.purged.v1 (Learning -> Progress).
// Rows are removed in bounded batches (each one transaction of <= PURGE_BATCH removals; removal is
// idempotent, so a crash or timeout simply leaves the rest for the relay's retry). The final step
// (the l_energy row, the l_inbox dedupe row and the account.purged.v1 outbox row) commits as one
// transaction, so Progress is never told "purged" before the rows are gone (DATA_MODEL "final
// private-row purge and account.purged.v1 outbox acknowledgement commit together").
// Kept: l_outbox history (payloads carry only IDs/counters; ACK rows age out), published content.
import { ServiceError } from '../../../shared/src/errors.js';
import type { BusinessEvent } from '../../../shared/src/ports.js';
import { ids } from '../persistence/ids.js';
import type { LearningTable } from '../persistence/port.js';
import { iso, type LearningDeps } from './deps.js';
import { stageOutboxEvent, type AccountPurgedEvent } from './outbox.js';

/** Learning tables holding a user's private rows, keyed by a `userId` column. */
export const USER_TABLES: readonly LearningTable[] = [
  'l_answers',
  'l_sessions',
  'l_active_slots',
  'l_review_items',
  'l_mistakes',
  'l_activity_progress',
  'l_reports',
  'l_receipts',
  'l_enrollments',
];
export const PURGE_BATCH = 80;
const ID = /^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export interface AccountDeletion {
  userId: string;
  requestId: string;
}

export function parseAccountDeletion(event: BusinessEvent): AccountDeletion {
  const p = event.payload as unknown as Record<string, unknown>;
  const keys = Object.keys(p);
  const fail = (reason: string): never => {
    throw new ServiceError('VALIDATION_ERROR', { details: { reason } });
  };
  if (keys.length !== 2 || !keys.includes('userId') || !keys.includes('requestId')) {
    fail('PAYLOAD_FIELDS');
  }
  if (typeof p['userId'] !== 'string' || !ID.test(p['userId'])) fail('userId');
  if (p['userId'] !== event.aggregateId) fail('aggregateId');
  if (typeof p['requestId'] !== 'string' || !UUID.test(p['requestId'])) fail('requestId');
  return { userId: p['userId'] as string, requestId: p['requestId'] as string };
}

/** Remove the user's rows table by table in bounded transactions; returns rows removed. */
export async function purgeUserRows(
  deps: LearningDeps,
  userId: string,
  deadlineMs = 20_000,
): Promise<number> {
  const started = deps.nowMs();
  let removed = 0;
  for (const table of USER_TABLES) {
    for (;;) {
      if (deps.nowMs() - started > deadlineMs) {
        // Not finished in this delivery: answer retryable so the relay comes back.
        throw new ServiceError('DEADLINE_EXCEEDED', { details: { reason: 'PURGE_IN_PROGRESS' } });
      }
      const page = await deps.persistence.list(table, {
        equal: { userId },
        limit: PURGE_BATCH,
      });
      if (!page.items.length) break;
      await deps.persistence.transact(async (tx) => {
        for (const item of page.items) tx.remove(table, item.id);
      });
      removed += page.items.length;
    }
  }
  return removed;
}

export async function applyAccountDeletion(
  deps: LearningDeps,
  event: BusinessEvent,
  bodyHash: string,
): Promise<'accepted' | 'replayed'> {
  const deletion = parseAccountDeletion(event);
  await purgeUserRows(deps, deletion.userId);
  let purgedEventId: string | undefined;
  const status = await deps.persistence.applyInboxEvent(
    { eventId: event.eventId, type: event.type, bodyHash },
    async (tx) => {
      const now = deps.nowMs();
      tx.remove('l_energy', ids.energy(deletion.userId));
      const ack: AccountPurgedEvent = {
        eventId: deps.newId(),
        type: 'account.purged.v1',
        schemaVersion: 1,
        producer: 'learning',
        aggregateId: deletion.userId,
        occurredAt: iso(now),
        requestId: deletion.requestId,
        payload: { userId: deletion.userId, requestId: deletion.requestId, owner: 'learning' },
      };
      stageOutboxEvent(tx, ack, now);
      purgedEventId = ack.eventId;
    },
  );
  if (status === 'accepted' && purgedEventId && deps.relay) {
    await deps.relay.afterCommit([purgedEventId]).catch(() => undefined);
  }
  return status;
}
