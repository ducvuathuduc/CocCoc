// Progress inbox consumer (docs/api/EVENTS_ERRORS.md, docs/architecture/CONSISTENCY.md).
// lesson.completed.v1: the inbox row and every reward effect (ledger, day, totals, streak,
// quests, league, achievements, notification) commit atomically; duplicate delivery replays and
// a changed payload under the same eventId is IDEMPOTENCY_CONFLICT.
// ai.practice.completed.v1: PRACTICE credit for one completed Roleplay/Video Call conversation,
// same inbox atomicity and once-per-event rules (application/practice.ts).
// account.purged.v1: owner acknowledgement recorded with the inbox row; the purge itself runs
// in bounded follow-up transactions (application/deletion.ts).
import { ServiceError } from '../../../shared/src/errors.js';
import type { BusinessEvent, EventConsumer } from '../../../shared/src/ports.js';
import { validateGraded } from '../domain/lesson-xp.js';
import { PRACTICE_KINDS, PRACTICE_MAX_EVENT_XP } from '../domain/practice-xp.js';
import type { ProgressPersistence } from '../persistence/port.js';
import { purgeDeletedAccount, recordPurgeAck } from './deletion.js';
import { applyPracticeCompletion, type PracticeEvent } from './practice.js';
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

const PRACTICE_KEYS = [
  'completionId',
  'userId',
  'kind',
  'courseId',
  'scenarioId',
  'xp',
  'wordsUsed',
  'stars',
];
const isInt = (value: unknown, min: number, max: number) =>
  Number.isInteger(value) && (value as number) >= min && (value as number) <= max;

function checkPractice(event: PracticeEvent): void {
  const p = event.payload as unknown as Record<string, unknown>;
  if (!p || typeof p !== 'object') invalid('INVALID_PRACTICE');
  if (Object.keys(p).some((key) => !PRACTICE_KEYS.includes(key))) invalid('UNKNOWN_FIELD');
  for (const key of ['completionId', 'userId', 'courseId', 'scenarioId']) {
    if (typeof p[key] !== 'string' || !ID.test(p[key])) invalid('INVALID_IDENTIFIER');
  }
  // The AI producer keys its practice events by the owning user.
  if (p['userId'] !== event.aggregateId) invalid('AGGREGATE_MISMATCH');
  if (!(PRACTICE_KINDS as readonly unknown[]).includes(p['kind'])) invalid('INVALID_PRACTICE');
  if (
    !isInt(p['xp'], 0, PRACTICE_MAX_EVENT_XP) ||
    !isInt(p['wordsUsed'], 0, 2147483647) ||
    !isInt(p['stars'], 0, 3)
  ) {
    invalid('INVALID_PRACTICE');
  }
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
      if (event.type === 'ai.practice.completed.v1') {
        const practice = event as PracticeEvent;
        checkPractice(practice);
        return store.applyInboxEvent(entry, (tx) => applyPracticeCompletion(tx, practice));
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
