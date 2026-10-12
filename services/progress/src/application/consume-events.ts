// Progress inbox consumer (docs/api/EVENTS_ERRORS.md, docs/architecture/CONSISTENCY.md).
// lesson.completed.v1: the inbox row and the FIRST ledger row commit atomically through the
// owner store; duplicate delivery replays. Other allowlisted types are not implemented yet and
// fail closed (no ack), so the producer keeps them in its outbox.
import { ServiceError } from '../../../shared/src/errors.js';
import type { BusinessEvent, EventConsumer } from '../../../shared/src/ports.js';
import { firstCompletionXp } from '../domain/lesson-xp.js';
import type { ProgressPersistence } from '../persistence/port.js';

type CompletionEvent = Extract<BusinessEvent, { type: 'lesson.completed.v1' }>;

export function createProgressEventConsumer(store: ProgressPersistence): EventConsumer {
  return {
    async consume(event, context) {
      if (event.type !== 'lesson.completed.v1') throw new ServiceError('SERVICE_NOT_CONFIGURED');
      const { payload } = event as CompletionEvent;
      const xp = firstCompletionXp(payload);
      if (!xp.ok) throw new ServiceError('VALIDATION_ERROR', { details: { reason: xp.reason } });
      return store.applyInboxEvent(
        { eventId: event.eventId, type: event.type, bodyHash: context.bodyHash },
        async (tx) => {
          // Row id mirrors the unique index (userId, completionId, kind) in DATA_MODEL.
          const id = `${payload.userId}:${payload.completionId}:FIRST`;
          if (await tx.get('p_reward_ledger', id)) return;
          tx.put('p_reward_ledger', id, {
            eventId: event.eventId,
            completionId: payload.completionId,
            userId: payload.userId,
            rewardIdentity: payload.rewardIdentity,
            kind: 'FIRST',
            studyXpDelta: xp.studyXp,
            occurredAt: event.occurredAt,
          });
        },
      );
    },
  };
}
