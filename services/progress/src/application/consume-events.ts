// Progress inbox consumer (docs/api/EVENTS_ERRORS.md, docs/architecture/CONSISTENCY.md).
// lesson.completed.v1: the inbox row and every reward effect (ledger, day, totals, streak,
// quests, league, achievements, notification) commit atomically; duplicate delivery replays and
// a changed payload under the same eventId is IDEMPOTENCY_CONFLICT.
// account.purged.v1: owner acknowledgement recorded with the inbox row; the purge itself runs
// in bounded follow-up transactions (application/deletion.ts).
import { ServiceError } from '../../../shared/src/errors.js';
import type { BusinessEvent, EventConsumer } from '../../../shared/src/ports.js';
import { validateGraded } from '../domain/lesson-xp.js';
import type { ProgressPersistence } from '../persistence/port.js';
import { purgeDeletedAccount, recordPurgeAck } from './deletion.js';
import { applyLessonCompletion, type CompletionEvent } from './rewards.js';

type PurgeEvent = Extract<BusinessEvent, { type: 'account.purged.v1' }>;
const ID = /^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const LESSON_KEYS = [
  'completionId',
  'userId',
  'courseId',
  'lessonVersion',
  'rewardIdentity',
  'source',
  'mode',
  'originalCount',
  'originalCorrect',
  'assisted',
];

function invalid(reason: string): never {
  throw new ServiceError('VALIDATION_ERROR', { details: { reason } });
}

function checkLesson(event: CompletionEvent): void {
  const p = event.payload as unknown as Record<string, unknown>;
  if (Object.keys(p).some((key) => !LESSON_KEYS.includes(key))) invalid('UNKNOWN_FIELD');
  for (const key of ['completionId', 'userId', 'courseId', 'lessonVersion', 'rewardIdentity']) {
    if (typeof p[key] !== 'string' || !ID.test(p[key])) invalid('INVALID_IDENTIFIER');
  }
  const graded = validateGraded(event.payload);
  if (graded && !graded.ok) invalid(graded.reason);
}

export interface ConsumerOptions {
  /** Run the purge right after the last owner acknowledgement (default true). */
  purgeAfterAck?: boolean;
}

export function createProgressEventConsumer(
  store: ProgressPersistence,
  options: ConsumerOptions = {},
): EventConsumer {
  return {
    async consume(event, context) {
      const entry = { eventId: event.eventId, type: event.type, bodyHash: context.bodyHash };
      if (event.type === 'lesson.completed.v1') {
        const completion = event as CompletionEvent;
        checkLesson(completion);
        return store.applyInboxEvent(entry, (tx) => applyLessonCompletion(tx, completion));
      }
      if (event.type === 'account.purged.v1') {
        const { payload } = event as PurgeEvent;
        if (
          typeof payload?.userId !== 'string' ||
          !ID.test(payload.userId) ||
          typeof payload.requestId !== 'string' ||
          !UUID.test(payload.requestId) ||
          (payload.owner !== 'learning' && payload.owner !== 'ai') ||
          payload.owner !== event.producer
        ) {
          invalid('INVALID_PURGE_ACK');
        }
        const status = await store.applyInboxEvent(entry, (tx) => recordPurgeAck(tx, payload));
        if (options.purgeAfterAck !== false) await purgeDeletedAccount(store, payload.userId);
        return status;
      }
      throw new ServiceError('SERVICE_NOT_CONFIGURED');
    },
  };
}
