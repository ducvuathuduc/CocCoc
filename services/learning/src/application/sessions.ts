// P5-LESSON-002: startSession / getSession / submitAnswer / completeSession / abandonSession
// (FR-LESSON-001..006). Every mutation is one optimistic transaction committed with its idempotency
// receipt; the session revision is the client's compare-and-set token, so two devices answering the
// same item cannot both win. Completion writes session + frontier + review + outbox + receipt
// atomically and never touches Progress tables.
import { ServiceError } from '../../../shared/src/errors.js';
import type { Answer, Exercise, LessonBundle, SessionMode } from '../content/types.js';
import { gradeAnswer, gradedExercise } from '../domain/grading.js';
import {
  assertLessonUnlocked,
  assertMasteryUnlocked,
  completeLesson,
  nodeOfLesson,
  type EnrollmentView,
} from '../domain/path.js';
import { masteryPassed, queueState, tally, type AttemptRecord } from '../domain/session-queue.js';
import { ids } from '../persistence/ids.js';
import type { LearningTransaction, Row } from '../persistence/port.js';
import {
  bumped,
  created,
  iso,
  jsonArray,
  jsonObject,
  SESSION_TTL_MS,
  type LearningDeps,
} from './deps.js';
import { assertEnergyForStart, spendEnergy } from './energy.js';
import { activeEnrollment, enrollmentView } from './enrollment.js';
import { stageOutboxEvent, type LessonCompletedEvent } from './outbox.js';
import { stageMistakes } from './practice.js';
import { buildReviewBundle, REVIEW_LESSON_ID, stageReviewUpdates } from './review.js';

export interface StartBody {
  courseId: string;
  lessonId: string;
  mode: SessionMode;
  expectedEnrollmentRevision: number;
}
export interface AnswerBody {
  exerciseId: string;
  attemptOrdinal: number;
  answer: Answer;
  assisted: boolean;
  substituted: boolean;
  expectedRevision: number;
}

interface AnswerResultDto {
  exerciseId: string;
  correct: boolean;
  explanation: string;
  acceptedAnswer: string;
  nextOriginalOrdinal: number;
  retryPass: number;
  sessionRevision: number;
  provisional: boolean;
}

function isExpired(session: Row, nowMs: number): boolean {
  return session['status'] === 'ACTIVE' && Date.parse(String(session['expiresAt'])) <= nowMs;
}

function ownedSession(session: Row | null, userId: string, sessionId: string): Row {
  // Another user's session is indistinguishable from a missing one (no existence leak).
  if (!session || session['userId'] !== userId)
    throw new ServiceError('NOT_FOUND', { details: { sessionId } });
  return session;
}

function assertRevision(session: Row, expected: number): void {
  const current = Number(session['revision']);
  if (current !== expected)
    throw new ServiceError('REVISION_CONFLICT', { details: { currentRevision: current } });
}

async function sessionBundle(deps: LearningDeps, session: Row): Promise<LessonBundle> {
  if (session['lessonId'] === REVIEW_LESSON_ID) {
    const snapshot = jsonObject<LessonBundle>(session['bundleSnapshotJson']);
    if (!snapshot)
      throw new ServiceError('INTERNAL_ERROR', { details: { reason: 'REVIEW_SNAPSHOT_MISSING' } });
    return snapshot;
  }
  return deps.content.bundleByLessonVersion(
    String(session['courseId']),
    String(session['lessonId']),
    String(session['lessonVersion']),
  );
}

async function attemptsOf(deps: LearningDeps, sessionId: string) {
  const list = await deps.persistence.list('l_answers', {
    equal: { sessionId },
    orderAsc: 'receivedAt',
    limit: 60,
  });
  return list.items.map(({ row }) => row);
}
function toAttempt(row: Row): AttemptRecord {
  return {
    exerciseId: String(row['exerciseId']),
    attemptOrdinal: Number(row['attemptOrdinal']),
    correct: Boolean(row['correct']),
    assisted: Boolean(row['assisted']),
  };
}

// ---------------------------------------------------------------- start

export async function startSession(
  deps: LearningDeps,
  userId: string,
  body: StartBody,
  key: string,
  bodyHash: string,
) {
  const { manifest } = await deps.content.published(body.courseId);
  const enrollmentRowId = ids.enrollment(userId, body.courseId);
  const sessionId = ids.session(userId, key);
  // Content reads happen before the transaction (immutable, verified, cached).
  let bundleInfo: {
    lessonVersion: string;
    rewardIdentity: string;
    hash: string;
    snapshot: string | null;
  };
  const enrollmentNow = activeEnrollment(
    await deps.persistence.read('l_enrollments', enrollmentRowId),
  );
  if (body.mode === 'PLACEMENT') {
    if (body.lessonId !== manifest.placementBundle.lessonId)
      throw new ServiceError('NOT_FOUND', { details: { lessonId: body.lessonId } });
    bundleInfo = {
      lessonVersion: manifest.placementBundle.lessonVersion,
      rewardIdentity: manifest.placementBundle.rewardIdentity,
      hash: manifest.placementBundle.sha256,
      snapshot: null,
    };
  } else if (body.mode === 'REVIEW') {
    if (body.lessonId !== REVIEW_LESSON_ID)
      throw new ServiceError('VALIDATION_ERROR', {
        details: { field: 'lessonId', expected: REVIEW_LESSON_ID },
      });
    if (!enrollmentNow)
      throw new ServiceError('NOT_FOUND', {
        details: { courseId: body.courseId, reason: 'NOT_ENROLLED' },
      });
    const review = await buildReviewBundle(deps, {
      userId,
      courseId: body.courseId,
      manifest,
      enrollment: enrollmentView(enrollmentNow),
      sessionKey: `${userId}|${key}`,
    });
    bundleInfo = {
      lessonVersion: review.bundle.lessonVersion,
      rewardIdentity: REVIEW_LESSON_ID,
      hash: review.hash,
      snapshot: review.text,
    };
  } else {
    const index = manifest.bundles.find((b) => b.lessonId === body.lessonId);
    if (!index) throw new ServiceError('NOT_FOUND', { details: { lessonId: body.lessonId } });
    await deps.content.bundle(manifest, body.lessonId); // verify the file before pinning it
    bundleInfo = {
      lessonVersion: index.lessonVersion,
      rewardIdentity: index.rewardIdentity,
      hash: index.sha256,
      snapshot: null,
    };
  }

  return deps.persistence.commitWithReceipt(
    { userId, operation: 'startSession', key },
    bodyHash,
    async (tx) => {
      const now = deps.nowMs();
      const enrollment = activeEnrollment(await tx.get('l_enrollments', enrollmentRowId));
      const currentRevision = enrollment ? Number(enrollment['revision']) : 0;
      if (body.mode === 'PLACEMENT') {
        if (
          enrollment &&
          (enrollment['placementUsed'] || jsonArray(enrollment['completedLessonsJson']).length)
        ) {
          throw new ServiceError('NODE_LOCKED', { details: { reason: 'PLACEMENT_UNAVAILABLE' } });
        }
      } else if (!enrollment) {
        throw new ServiceError('NOT_FOUND', {
          details: { courseId: body.courseId, reason: 'NOT_ENROLLED' },
        });
      }
      if (currentRevision !== body.expectedEnrollmentRevision) {
        throw new ServiceError('REVISION_CONFLICT', { details: { currentRevision } });
      }
      if (enrollment && body.mode === 'LESSON')
        assertLessonUnlocked(manifest, enrollmentView(enrollment), body.lessonId);
      if (enrollment && body.mode === 'MASTERY')
        assertMasteryUnlocked(manifest, enrollmentView(enrollment), body.lessonId);
      await assertEnergyForStart(deps, tx, userId, body.mode);

      // One active online session per user/course (FR-LESSON-001).
      const slotId = ids.slot(userId, body.courseId);
      const slot = await tx.get('l_active_slots', slotId);
      if (slot) {
        const holder = await tx.get('l_sessions', String(slot['sessionId']));
        if (holder && holder['status'] === 'ACTIVE') {
          if (!isExpired(holder, now)) {
            throw new ServiceError('SESSION_CONFLICT', {
              details: {
                activeSessionId: String(slot['sessionId']),
                expiresAt: String(holder['expiresAt']),
              },
            });
          }
          tx.put('l_sessions', String(slot['sessionId']), {
            ...holder,
            status: 'EXPIRED',
            ...bumped(holder, now),
          });
        }
      }
      const expiresAt = iso(now + SESSION_TTL_MS);
      tx.put('l_active_slots', slotId, {
        userId,
        courseId: body.courseId,
        sessionId,
        expiresAt,
        ...(slot ? { createdAt: slot['createdAt'], ...bumped(slot, now) } : created(now)),
      });
      tx.put('l_sessions', sessionId, {
        userId,
        courseId: body.courseId,
        lessonId: body.lessonId,
        lessonVersion: bundleInfo.lessonVersion,
        rewardIdentity: bundleInfo.rewardIdentity,
        mode: body.mode,
        source: 'ONLINE',
        status: 'ACTIVE',
        bundleHash: bundleInfo.hash,
        bundleSnapshotJson: bundleInfo.snapshot,
        nextOriginalOrdinal: 0,
        retryPass: 0,
        assisted: false,
        energySpent: 0,
        energyEarned: 0,
        startedAt: iso(now),
        expiresAt,
        completedAt: null,
        resultJson: '{}',
        ...created(now),
      });
      // The receipt stores a reference; replays re-render the current session view (a full Session
      // with its bundle can exceed the 16KB receipt column).
      return { statusCode: 200, response: { sessionRef: sessionId } };
    },
  );
}

// ---------------------------------------------------------------- read

export async function getSessionView(deps: LearningDeps, userId: string, sessionId: string) {
  const session = ownedSession(
    await deps.persistence.read('l_sessions', sessionId),
    userId,
    sessionId,
  );
  const bundle = await sessionBundle(deps, session);
  const answers = await attemptsOf(deps, sessionId);
  const last = answers.at(-1);
  return {
    sessionId,
    courseId: String(session['courseId']),
    lessonId: String(session['lessonId']),
    lessonVersion: String(session['lessonVersion']),
    status: isExpired(session, deps.nowMs()) ? 'EXPIRED' : String(session['status']),
    mode: String(session['mode']),
    revision: Number(session['revision']),
    nextOriginalOrdinal: Number(session['nextOriginalOrdinal']),
    retryPass: Number(session['retryPass']),
    expiresAt: String(session['expiresAt']),
    bundle,
    answerHistory: answers.map((row) => ({
      exerciseId: String(row['exerciseId']),
      attemptOrdinal: Number(row['attemptOrdinal']),
      answer: JSON.parse(String(row['answerJson'])) as Answer,
      assisted: Boolean(row['assisted']),
      substituted: Boolean(row['substituted']),
    })),
    lastFeedback: last ? (JSON.parse(String(last['resultJson'])) as AnswerResultDto) : null,
  };
}

// ---------------------------------------------------------------- answer

function activeOrThrow(session: Row, nowMs: number): void {
  if (isExpired(session, nowMs) || session['status'] === 'EXPIRED')
    throw new ServiceError('SESSION_EXPIRED');
  if (session['status'] !== 'ACTIVE')
    throw new ServiceError('SESSION_CONFLICT', { details: { status: String(session['status']) } });
}

export async function submitAnswer(
  deps: LearningDeps,
  userId: string,
  sessionId: string,
  body: AnswerBody,
  key: string,
  bodyHash: string,
) {
  const preview = ownedSession(
    await deps.persistence.read('l_sessions', sessionId),
    userId,
    sessionId,
  );
  const bundle = await sessionBundle(deps, preview);
  return deps.persistence.commitWithReceipt(
    { userId, operation: 'submitAnswer', key },
    bodyHash,
    async (tx) => {
      const now = deps.nowMs();
      const session = ownedSession(await tx.get('l_sessions', sessionId), userId, sessionId);
      activeOrThrow(session, now);
      assertRevision(session, body.expectedRevision);
      const attempts = (await attemptsOf(deps, sessionId)).map(toAttempt);
      const order = bundle.exercises.map((e) => e.id);
      const expected = queueState(order, attempts).next;
      if (
        !expected ||
        expected.exerciseId !== body.exerciseId ||
        expected.attemptOrdinal !== body.attemptOrdinal
      ) {
        throw new ServiceError('SESSION_CONFLICT', { details: { expected: expected ?? null } });
      }
      const exercise = bundle.exercises.find((e) => e.id === body.exerciseId) as Exercise;
      const graded = gradedExercise(exercise, body.substituted);
      const verdict = gradeAnswer(graded, body.answer);
      const after = queueState(order, [
        ...attempts,
        {
          exerciseId: body.exerciseId,
          attemptOrdinal: body.attemptOrdinal,
          correct: verdict.correct,
          assisted: body.assisted,
        },
      ]);
      const revision = Number(session['revision']) + 1;
      const result: AnswerResultDto = {
        exerciseId: body.exerciseId,
        correct: verdict.correct,
        explanation: graded.explanation.slice(0, 1024),
        acceptedAnswer: verdict.acceptedAnswer.slice(0, 512),
        nextOriginalOrdinal: after.nextOriginalOrdinal,
        retryPass: after.retryPass,
        sessionRevision: revision,
        provisional: false,
      };
      const answerId = ids.answer(sessionId, body.exerciseId, body.attemptOrdinal);
      if (await tx.get('l_answers', answerId))
        throw new ServiceError('SESSION_CONFLICT', { details: { reason: 'ALREADY_ANSWERED' } });
      const spent = await spendEnergy(deps, tx, userId, String(session['mode']));
      tx.put('l_answers', answerId, {
        sessionId,
        userId,
        exerciseId: body.exerciseId,
        attemptOrdinal: body.attemptOrdinal,
        answerJson: JSON.stringify(body.answer),
        correct: verdict.correct,
        assisted: body.assisted,
        substituted: body.substituted,
        receivedAt: iso(now),
        resultJson: JSON.stringify(result),
        ...created(now),
      });
      tx.put('l_sessions', sessionId, {
        ...session,
        nextOriginalOrdinal: after.nextOriginalOrdinal,
        retryPass: after.retryPass,
        assisted: Boolean(session['assisted']) || body.assisted,
        energySpent: Number(session['energySpent'] ?? 0) + spent,
        revision,
        updatedAt: iso(now),
      });
      return { statusCode: 200, response: result };
    },
  );
}

// ---------------------------------------------------------------- complete

export async function completeSession(
  deps: LearningDeps,
  userId: string,
  sessionId: string,
  body: { expectedRevision: number },
  key: string,
  bodyHash: string,
  requestId: string,
) {
  const preview = ownedSession(
    await deps.persistence.read('l_sessions', sessionId),
    userId,
    sessionId,
  );
  const bundle = await sessionBundle(deps, preview);
  const courseId = String(preview['courseId']);
  const manifest =
    preview['mode'] === 'LESSON' || preview['mode'] === 'MASTERY'
      ? (await deps.content.published(courseId)).manifest
      : null;
  // Review snapshots mix exercises from several lessons: map each back to its authored version.
  const sourceVersions = new Map<string, string>();
  if (preview['lessonId'] === REVIEW_LESSON_ID) {
    const published = (await deps.content.published(courseId)).manifest;
    for (const exercise of bundle.exercises) {
      const index = published.bundles.find((b) => exercise.id.startsWith(`${b.lessonId}-`));
      if (index) sourceVersions.set(exercise.id, index.lessonVersion);
    }
  }
  let eventId: string | null = null;
  const outcome = await deps.persistence.commitWithReceipt(
    { userId, operation: 'completeSession', key },
    bodyHash,
    async (tx) => {
      eventId = null; // reset per attempt: a conflicted attempt's event never committed
      const now = deps.nowMs();
      const session = ownedSession(await tx.get('l_sessions', sessionId), userId, sessionId);
      if (session['status'] === 'COMPLETED') {
        // Retry with a new key (e.g. after a lost response) returns the original completion; no
        // second frontier update or event.
        const stored = jsonObject<{ completion: unknown }>(session['resultJson']);
        return { statusCode: 200, response: stored?.completion ?? null };
      }
      activeOrThrow(session, now);
      assertRevision(session, body.expectedRevision);
      const attempts = (await attemptsOf(deps, sessionId)).map(toAttempt);
      const order = bundle.exercises.map((e) => e.id);
      const state = queueState(order, attempts);
      if (state.nextOriginalOrdinal < order.length) {
        throw new ServiceError('SESSION_INCOMPLETE', {
          details: { attempted: state.nextOriginalOrdinal, required: order.length },
        });
      }
      const summary = tally(order, attempts);
      const mode = String(session['mode']) as SessionMode;
      const completedAt = iso(now);

      // Frontier / mastery (monotonic) for enrolled modes.
      let enrollmentRevision = 0;
      const enrollmentId = ids.enrollment(userId, courseId);
      const enrollment = activeEnrollment(await tx.get('l_enrollments', enrollmentId));
      if (enrollment) {
        const view = enrollmentView(enrollment);
        let next: EnrollmentView = view;
        if (mode === 'LESSON' && manifest)
          next = completeLesson(manifest, view, String(session['lessonId']));
        if (mode === 'MASTERY' && manifest && masteryPassed(summary)) {
          const node = nodeOfLesson(manifest, String(session['lessonId']));
          if (node && !view.masteredNodeIds.includes(node.nodeId))
            next = { ...view, masteredNodeIds: [...view.masteredNodeIds, node.nodeId] };
        }
        const bump = bumped(enrollment, now);
        enrollmentRevision = bump.revision;
        tx.put('l_enrollments', enrollmentId, {
          ...enrollment,
          frontierNodeOrder: next.frontierNodeOrder,
          completedLessonsJson: JSON.stringify(next.completedLessonIds),
          masteredNodesJson: JSON.stringify(next.masteredNodeIds),
          lastPracticedAt:
            mode === 'PLACEMENT' ? (enrollment['lastPracticedAt'] ?? null) : completedAt,
          ...bump,
        });
      }
      if (mode !== 'PLACEMENT') {
        await stageReviewUpdates(tx, {
          userId,
          courseId,
          exercises: bundle.exercises,
          attempts,
          advance: mode !== 'LESSON',
          nowMs: now,
        });
        await stageMistakes(deps, tx, {
          userId,
          courseId,
          sessionId,
          mode,
          exercises: bundle.exercises,
          attempts,
          lessonVersionOf: (exerciseId) =>
            sourceVersions.get(exerciseId) ?? String(session['lessonVersion']),
          nowMs: now,
        });
      }
      await releaseSlot(tx, userId, courseId, sessionId);

      const completion = {
        completionId: sessionId,
        sessionId,
        originalCount: summary.originalCount,
        originalCorrect: summary.originalCorrect,
        assisted: summary.assisted,
        source: 'ONLINE' as const,
        mode,
        completedAt,
        enrollmentRevision,
        // PLACEMENT earns no reward/activity: no event is emitted for it.
        rewardStatus: mode === 'PLACEMENT' ? ('notEligible' as const) : ('pending' as const),
        needsReviewIds: summary.needsReviewIds,
      };
      if (mode !== 'PLACEMENT') {
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
            courseId,
            lessonVersion: String(session['lessonVersion']),
            rewardIdentity: String(session['rewardIdentity']),
            source: 'ONLINE',
            mode,
            originalCount: summary.originalCount,
            originalCorrect: summary.originalCorrect,
            assisted: summary.assisted,
          },
        };
        stageOutboxEvent(tx, event, now);
        eventId = event.eventId;
      }
      tx.put('l_sessions', sessionId, {
        ...session,
        status: 'COMPLETED',
        completedAt,
        assisted: summary.assisted,
        resultJson: JSON.stringify({ completion, eventId }),
        ...bumped(session, now),
      });
      return { statusCode: 200, response: completion };
    },
  );
  if (outcome.status === 'created' && eventId && deps.relay) {
    await deps.relay.afterCommit([eventId]).catch(() => undefined);
  }
  return outcome;
}

async function releaseSlot(
  tx: LearningTransaction,
  userId: string,
  courseId: string,
  sessionId: string,
) {
  const slotId = ids.slot(userId, courseId);
  const slot = await tx.get('l_active_slots', slotId);
  if (slot && slot['sessionId'] === sessionId) tx.remove('l_active_slots', slotId);
}

// ---------------------------------------------------------------- abandon

export async function abandonSession(
  deps: LearningDeps,
  userId: string,
  sessionId: string,
  body: { expectedRevision: number },
  key: string,
  bodyHash: string,
  requestId: string,
) {
  return deps.persistence.commitWithReceipt(
    { userId, operation: 'abandonSession', key },
    bodyHash,
    async (tx) => {
      const now = deps.nowMs();
      const session = ownedSession(await tx.get('l_sessions', sessionId), userId, sessionId);
      if (session['status'] === 'ABANDONED') {
        return { statusCode: 200, response: { operationId: key, status: 'replayed', requestId } };
      }
      if (session['status'] === 'COMPLETED')
        throw new ServiceError('SESSION_CONFLICT', { details: { status: 'COMPLETED' } });
      assertRevision(session, body.expectedRevision);
      tx.put('l_sessions', sessionId, {
        ...session,
        status: isExpired(session, now) ? 'EXPIRED' : 'ABANDONED',
        ...bumped(session, now),
      });
      await releaseSlot(tx, userId, String(session['courseId']), sessionId);
      return { statusCode: 200, response: { operationId: key, status: 'accepted', requestId } };
    },
  );
}
