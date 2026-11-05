// FR-LESSON-007 / FR-SYNC-001 syncOfflineCompletion (POST /v1/offline-completions): a lesson
// played offline against a pinned, signed bundle is submitted once with its full answer log. The
// server regrades every answer (client verdicts are never trusted), replays the log through the
// same queue rules as an online session (originals in order, then up to two retry passes), and
// commits the completion exactly like completeSession: session row (source OFFLINE) + frontier +
// review + mistakes + lesson.completed.v1 (source OFFLINE, so Progress grants no league XP or
// backdated streak) + receipt, in one transaction. The immutable localCompletionId is the dedupe
// key: any later submission of it returns the original completion, a different log under it is
// IDEMPOTENCY_CONFLICT. Individual answers are not stored as l_answers rows (a 60-answer log would
// exceed the transaction operation budget); the regraded summary lives in the session result.
import { ServiceError } from '../../../shared/src/errors.js';
import type { Answer } from '../content/types.js';
import { canonicalJson, sha256 } from '../content/integrity.js';
import { gradeAnswer, gradedExercise } from '../domain/grading.js';
import { assertLessonUnlocked, completeLesson } from '../domain/path.js';
import { queueState, tally, type AttemptRecord } from '../domain/session-queue.js';
import { ids } from '../persistence/ids.js';
import type { Row } from '../persistence/port.js';
import { bumped, created, iso, jsonObject, type LearningDeps } from './deps.js';
import { activeEnrollment, enrollmentView } from './enrollment.js';
import { stageOutboxEvent, type LessonCompletedEvent } from './outbox.js';
import { stageMistakes } from './practice.js';
import { stageReviewUpdates } from './review.js';

export interface OfflineAnswer {
  exerciseId: string;
  attemptOrdinal: number;
  answer: Answer;
  assisted: boolean;
  substituted: boolean;
}
export interface OfflineCompletionBody {
  operationId: string;
  localCompletionId: string;
  courseId: string;
  lessonId: string;
  lessonVersion: string;
  bundleHash: string;
  expectedEnrollmentRevision: number;
  answers: OfflineAnswer[];
}

export async function syncOfflineCompletion(
  deps: LearningDeps,
  userId: string,
  body: OfflineCompletionBody,
  key: string,
  bodyHash: string,
  requestId: string,
): Promise<{ statusCode: number; response: unknown }> {
  const sessionId = ids.session(userId, `offline|${body.localCompletionId}`);
  // The immutable localCompletionId wins over the Idempotency-Key: a completed offline lesson is
  // returned as is (lost response, retry with a new key) without regrading.
  const existing = await deps.persistence.read('l_sessions', sessionId);
  if (existing && existing['userId'] === userId && existing['status'] === 'COMPLETED') {
    // Check the full request against the idempotency receipt even when the
    // local completion already exists. A new key may replay the immutable log;
    // an existing key must never accept a different request wrapper.
    const replay = await deps.persistence.commitWithReceipt(
      { userId, operation: 'syncOfflineCompletion', key },
      bodyHash,
      async (tx) => {
        const current = await tx.get('l_sessions', sessionId);
        if (!current || current['userId'] !== userId || current['status'] !== 'COMPLETED') {
          throw new ServiceError('NOT_FOUND');
        }
        return { statusCode: 200, response: replayCompletion(current, body) };
      },
    );
    return { statusCode: replay.receipt.statusCode, response: replay.receipt.response };
  }

  const { manifest } = await deps.content.published(body.courseId);
  const bundle = await deps.content.bundleByLessonVersion(
    body.courseId,
    body.lessonId,
    body.lessonVersion,
  );
  if (bundle.lessonId === manifest.placementBundle.lessonId) {
    throw new ServiceError('VALIDATION_ERROR', { details: { field: 'lessonId' } });
  }
  if (sha256(canonicalJson(bundle)) !== body.bundleHash) {
    throw new ServiceError('VALIDATION_ERROR', {
      details: { field: 'bundleHash', reason: 'BUNDLE_MISMATCH' },
    });
  }

  // Full regrade + queue replay (outside the transaction: pure, content is immutable).
  const order = bundle.exercises.map((e) => e.id);
  const byId = new Map(bundle.exercises.map((e) => [e.id, e]));
  const attempts: AttemptRecord[] = [];
  for (const [i, a] of body.answers.entries()) {
    const expected = queueState(order, attempts).next;
    if (
      !expected ||
      expected.exerciseId !== a.exerciseId ||
      expected.attemptOrdinal !== a.attemptOrdinal
    ) {
      throw new ServiceError('VALIDATION_ERROR', {
        details: { field: `answers[${i}]`, reason: 'OUT_OF_ORDER', expected: expected ?? null },
      });
    }
    const exercise = byId.get(a.exerciseId)!;
    const verdict = gradeAnswer(gradedExercise(exercise, a.substituted), a.answer);
    attempts.push({
      exerciseId: a.exerciseId,
      attemptOrdinal: a.attemptOrdinal,
      correct: verdict.correct,
      assisted: a.assisted,
    });
  }
  const finalState = queueState(order, attempts);
  if (finalState.nextOriginalOrdinal < order.length || finalState.next) {
    throw new ServiceError('SESSION_INCOMPLETE', {
      details: { attempted: finalState.nextOriginalOrdinal, required: order.length },
    });
  }
  const summary = tally(order, attempts);
  const index = [...manifest.bundles].find(
    (b) => b.lessonId === body.lessonId && b.lessonVersion === body.lessonVersion,
  );
  const rewardIdentity = index?.rewardIdentity ?? bundle.rewardIdentity;

  let eventId: string | null = null;
  const outcome = await deps.persistence.commitWithReceipt(
    { userId, operation: 'syncOfflineCompletion', key },
    bodyHash,
    async (tx) => {
      eventId = null;
      const now = deps.nowMs();
      const completedAt = iso(now);
      const prior = await tx.get('l_sessions', sessionId);
      if (prior && prior['status'] === 'COMPLETED') {
        return { statusCode: 200, response: replayCompletion(prior, body) };
      }
      const enrollmentId = ids.enrollment(userId, body.courseId);
      const enrollment = activeEnrollment(await tx.get('l_enrollments', enrollmentId));
      if (!enrollment) {
        throw new ServiceError('NOT_FOUND', {
          details: { courseId: body.courseId, reason: 'NOT_ENROLLED' },
        });
      }
      const currentRevision = Number(enrollment['revision']);
      if (currentRevision !== body.expectedEnrollmentRevision) {
        throw new ServiceError('REVISION_CONFLICT', { details: { currentRevision } });
      }
      const view = enrollmentView(enrollment);
      assertLessonUnlocked(manifest, view, body.lessonId);
      const next = completeLesson(manifest, view, body.lessonId);
      const bump = bumped(enrollment, now);
      tx.put('l_enrollments', enrollmentId, {
        ...enrollment,
        frontierNodeOrder: next.frontierNodeOrder,
        completedLessonsJson: JSON.stringify(next.completedLessonIds),
        masteredNodesJson: JSON.stringify(next.masteredNodeIds),
        lastPracticedAt: completedAt,
        ...bump,
      });
      await stageReviewUpdates(tx, {
        userId,
        courseId: body.courseId,
        exercises: bundle.exercises,
        attempts,
        advance: false,
        nowMs: now,
      });
      await stageMistakes(deps, tx, {
        userId,
        courseId: body.courseId,
        sessionId,
        mode: 'LESSON',
        exercises: bundle.exercises,
        attempts,
        lessonVersionOf: () => body.lessonVersion,
        nowMs: now,
      });
      const completion = {
        completionId: sessionId,
        sessionId,
        originalCount: summary.originalCount,
        originalCorrect: summary.originalCorrect,
        assisted: summary.assisted,
        source: 'OFFLINE' as const,
        mode: 'LESSON' as const,
        completedAt,
        enrollmentRevision: bump.revision,
        rewardStatus: 'pending' as const,
        needsReviewIds: summary.needsReviewIds,
      };
      const event: LessonCompletedEvent = {
        eventId: deps.newId(),
        type: 'lesson.completed.v1',
        schemaVersion: 1,
        producer: 'learning',
        aggregateId: sessionId,
        occurredAt: completedAt,
        requestId: requestId.slice(0, 64),
        payload: {
          completionId: sessionId,
          userId,
          courseId: body.courseId,
          lessonVersion: body.lessonVersion,
          rewardIdentity,
          source: 'OFFLINE',
          mode: 'LESSON',
          originalCount: summary.originalCount,
          originalCorrect: summary.originalCorrect,
          assisted: summary.assisted,
        },
      };
      stageOutboxEvent(tx, event, now);
      eventId = event.eventId;
      tx.put('l_sessions', sessionId, {
        userId,
        courseId: body.courseId,
        lessonId: body.lessonId,
        lessonVersion: body.lessonVersion,
        rewardIdentity,
        mode: 'LESSON',
        source: 'OFFLINE',
        status: 'COMPLETED',
        bundleHash: body.bundleHash,
        bundleSnapshotJson: null,
        nextOriginalOrdinal: order.length,
        retryPass: finalState.retryPass,
        assisted: summary.assisted,
        energySpent: 0,
        energyEarned: 0,
        startedAt: completedAt,
        expiresAt: completedAt,
        completedAt,
        resultJson: JSON.stringify({ completion, eventId, logHash: logHashOf(body) }),
        ...created(now),
      });
      return { statusCode: 200, response: completion };
    },
  );
  if (outcome.status === 'created' && eventId && deps.relay) {
    await deps.relay.afterCommit([eventId]).catch(() => undefined);
  }
  return { statusCode: outcome.receipt.statusCode, response: outcome.receipt.response };
}

/** Apply the same immutable-log check on both the early and transactional replay paths. */
function replayCompletion(row: Row, body: OfflineCompletionBody): unknown {
  const stored = jsonObject<{ completion: unknown; logHash?: string }>(row['resultJson']);
  if (stored?.logHash && stored.logHash !== logHashOf(body)) {
    throw new ServiceError('IDEMPOTENCY_CONFLICT', {
      details: { localCompletionId: body.localCompletionId },
    });
  }
  return stored?.completion ?? null;
}

/** Hash of what the localCompletionId stands for (lesson + answer log), not of the retry wrapper. */
function logHashOf(body: OfflineCompletionBody): string {
  return sha256(
    canonicalJson({
      courseId: body.courseId,
      lessonId: body.lessonId,
      lessonVersion: body.lessonVersion,
      bundleHash: body.bundleHash,
      answers: body.answers,
    }),
  );
}
