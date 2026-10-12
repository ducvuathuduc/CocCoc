// Learning HTTP wiring shared by the hosted entrypoint (src/index.ts) and local dev (src/dev.ts).
// Built-in /health, /ready and /internal/events come from services/shared/src/transport.ts.
// Business routes exist only for operations in docs/api/openapi.yaml. Path templates are resolved
// by withRequestScope (http/scope.ts); wrap the router with learningHandler().
import type { ReceiptOutcome } from '../../../shared/src/ports.js';
import { ServiceError } from '../../../shared/src/errors.js';
import {
  canonicalBodyHash,
  type FunctionContext,
  type Route,
  type RouteContext,
  type ServiceWiring,
} from '../../../shared/src/transport.js';
import { getBundle, getManifest, listCourses, publishContent } from '../application/content.js';
import type { LearningDeps } from '../application/deps.js';
import { getEnergy } from '../application/energy.js';
import { enrollCourse, enrollmentCommand, getPath } from '../application/enrollment.js';
import { listActivityProgress, listMistakes, listWords } from '../application/practice.js';
import { createLearningEventConsumer } from '../application/events.js';
import { dispatchOutbox, MAX_BATCH, outboxWatermark } from '../application/outbox.js';
import { syncOfflineCompletion } from '../application/offline.js';
import { createReport } from '../application/reports.js';
import { getReview } from '../application/review.js';
import {
  abandonSession,
  completeSession,
  getSessionView,
  startSession,
  submitAnswer,
} from '../application/sessions.js';
import { SESSION_MODES } from '../content/types.js';
import { emptyCounts, jobRoute } from '../../../shared/src/job-tick.js';
import { idempotencyKey, pathParam, withRequestScope } from './scope.js';
import * as v from './validate.js';

function userId(context: RouteContext): string {
  if (!context.subject) throw new ServiceError('AUTH_REQUIRED');
  return context.subject.userId;
}
const hash = (operation: string, body: unknown, params: Record<string, string> = {}) =>
  canonicalBodyHash({ operation, params, body });
const fromReceipt = (outcome: ReceiptOutcome) => ({
  status: outcome.receipt.statusCode,
  body: outcome.receipt.response,
});
const noBodyQuery = (context: RouteContext, allowed: readonly string[]) =>
  v.query(context.query, allowed);

export function learningRoutes(deps: LearningDeps): Route[] {
  const user = (method: string, path: string, handle: Route['handle']): Route => ({
    method,
    path,
    auth: 'user',
    handle,
  });
  return [
    user('GET', '/v1/courses', async (c) => {
      userId(c);
      const q = noBodyQuery(c, ['cursor', 'limit']);
      return { status: 200, body: await listCourses(deps, v.cursorOf(q), v.limitOf(q)) };
    }),
    user('GET', '/v1/courses/{courseId}/manifest', async (c) => {
      userId(c);
      const q = noBodyQuery(c, ['version']);
      return {
        status: 200,
        body: await getManifest(
          deps,
          pathParam('courseId'),
          q['version'] ? v.id(q['version'], 'version') : undefined,
        ),
      };
    }),
    user('GET', '/v1/courses/{courseId}/path', async (c) => {
      const q = noBodyQuery(c, ['cursor', 'limit']);
      return {
        status: 200,
        body: await getPath(
          deps,
          userId(c),
          pathParam('courseId'),
          v.cursorOf(q),
          v.limitOf(q, 24),
        ),
      };
    }),
    user('GET', '/v1/lessons/{lessonId}/bundle', async (c) => {
      userId(c);
      const q = noBodyQuery(c, ['version']);
      return {
        status: 200,
        body: await getBundle(
          deps,
          pathParam('lessonId'),
          q['version'] ? v.id(q['version'], 'version') : undefined,
        ),
      };
    }),
    user('POST', '/v1/enrollments', async (c) => {
      const uid = userId(c);
      const b = v.object(
        c.body,
        'body',
        ['courseId', 'startPoint', 'placementSessionId'],
        ['courseId', 'startPoint'],
      );
      const body = {
        courseId: v.id(b['courseId'], 'courseId'),
        startPoint: v.oneOf(b['startPoint'], 'startPoint', ['beginner', 'placement'] as const),
        placementSessionId:
          b['placementSessionId'] == null
            ? null
            : v.id(b['placementSessionId'], 'placementSessionId'),
      };
      return fromReceipt(
        await enrollCourse(deps, uid, body, idempotencyKey(), hash('enrollCourse', body)),
      );
    }),
    user('POST', '/v1/sessions', async (c) => {
      const uid = userId(c);
      const b = v.object(
        c.body,
        'body',
        ['courseId', 'lessonId', 'mode', 'expectedEnrollmentRevision'],
        ['courseId', 'lessonId', 'mode', 'expectedEnrollmentRevision'],
      );
      const body = {
        courseId: v.id(b['courseId'], 'courseId'),
        lessonId: v.id(b['lessonId'], 'lessonId'),
        mode: v.oneOf(b['mode'], 'mode', SESSION_MODES),
        expectedEnrollmentRevision: v.int(
          b['expectedEnrollmentRevision'],
          'expectedEnrollmentRevision',
          0,
          2147483647,
        ),
      };
      const outcome = await startSession(
        deps,
        uid,
        body,
        idempotencyKey(),
        hash('startSession', body),
      );
      const ref = (outcome.receipt.response as { sessionRef?: string } | null)?.sessionRef;
      if (!ref) return fromReceipt(outcome);
      return { status: 200, body: await getSessionView(deps, uid, ref) };
    }),
    user('GET', '/v1/sessions/{sessionId}', async (c) => {
      noBodyQuery(c, []);
      return { status: 200, body: await getSessionView(deps, userId(c), pathParam('sessionId')) };
    }),
    user('POST', '/v1/sessions/{sessionId}/answers', async (c) => {
      const uid = userId(c);
      const sessionId = pathParam('sessionId');
      const b = v.object(
        c.body,
        'body',
        ['exerciseId', 'attemptOrdinal', 'answer', 'assisted', 'substituted', 'expectedRevision'],
        ['exerciseId', 'attemptOrdinal', 'answer', 'assisted', 'substituted', 'expectedRevision'],
      );
      const body = {
        exerciseId: v.id(b['exerciseId'], 'exerciseId'),
        attemptOrdinal: v.int(b['attemptOrdinal'], 'attemptOrdinal', 0, 2),
        answer: v.answer(b['answer']),
        assisted: v.bool(b['assisted'], 'assisted'),
        substituted: v.bool(b['substituted'], 'substituted'),
        expectedRevision: v.int(b['expectedRevision'], 'expectedRevision', 0, 2147483647),
      };
      return fromReceipt(
        await submitAnswer(
          deps,
          uid,
          sessionId,
          body,
          idempotencyKey(),
          hash('submitAnswer', body, { sessionId }),
        ),
      );
    }),
    user('POST', '/v1/sessions/{sessionId}/complete', async (c) => {
      const uid = userId(c);
      const sessionId = pathParam('sessionId');
      const b = v.object(c.body, 'body', ['expectedRevision'], ['expectedRevision']);
      const body = {
        expectedRevision: v.int(b['expectedRevision'], 'expectedRevision', 0, 2147483647),
      };
      return fromReceipt(
        await completeSession(
          deps,
          uid,
          sessionId,
          body,
          idempotencyKey(),
          hash('completeSession', body, { sessionId }),
          c.requestId,
        ),
      );
    }),
    user('POST', '/v1/offline-completions', async (c) => {
      const uid = userId(c);
      const fields = [
        'operationId',
        'localCompletionId',
        'courseId',
        'lessonId',
        'lessonVersion',
        'bundleHash',
        'expectedEnrollmentRevision',
        'answers',
      ];
      const b = v.object(c.body, 'body', fields, fields);
      if (!Array.isArray(b['answers']) || b['answers'].length > 60)
        throw new ServiceError('VALIDATION_ERROR', { details: { field: 'answers' } });
      const answerFields = ['exerciseId', 'attemptOrdinal', 'answer', 'assisted', 'substituted'];
      const body = {
        operationId: v.uuid(b['operationId'], 'operationId'),
        localCompletionId: v.uuid(b['localCompletionId'], 'localCompletionId'),
        courseId: v.id(b['courseId'], 'courseId'),
        lessonId: v.id(b['lessonId'], 'lessonId'),
        lessonVersion: v.id(b['lessonVersion'], 'lessonVersion'),
        bundleHash: v.sha(b['bundleHash'], 'bundleHash'),
        expectedEnrollmentRevision: v.int(
          b['expectedEnrollmentRevision'],
          'expectedEnrollmentRevision',
          0,
          2147483647,
        ),
        answers: (b['answers'] as unknown[]).map((raw, i) => {
          const a = v.object(raw, `answers[${i}]`, answerFields, answerFields);
          return {
            exerciseId: v.id(a['exerciseId'], `answers[${i}].exerciseId`),
            attemptOrdinal: v.int(a['attemptOrdinal'], `answers[${i}].attemptOrdinal`, 0, 2),
            answer: v.answer(a['answer'], `answers[${i}].answer`),
            assisted: v.bool(a['assisted'], `answers[${i}].assisted`),
            substituted: v.bool(a['substituted'], `answers[${i}].substituted`),
          };
        }),
      };
      const result = await syncOfflineCompletion(
        deps,
        uid,
        body,
        idempotencyKey(),
        hash('syncOfflineCompletion', body),
        c.requestId,
      );
      return { status: result.statusCode, body: result.response };
    }),
    user('POST', '/v1/sessions/{sessionId}/abandon', async (c) => {
      const uid = userId(c);
      const sessionId = pathParam('sessionId');
      const b = v.object(c.body, 'body', ['expectedRevision'], ['expectedRevision']);
      const body = {
        expectedRevision: v.int(b['expectedRevision'], 'expectedRevision', 0, 2147483647),
      };
      return fromReceipt(
        await abandonSession(
          deps,
          uid,
          sessionId,
          body,
          idempotencyKey(),
          hash('abandonSession', body, { sessionId }),
          c.requestId,
        ),
      );
    }),
    user('GET', '/v1/review', async (c) => {
      const q = noBodyQuery(c, ['cursor', 'limit', 'courseId']);
      const courseId = q['courseId'] ? v.id(q['courseId'], 'courseId') : undefined;
      return {
        status: 200,
        body: await getReview(deps, userId(c), courseId, v.cursorOf(q), v.limitOf(q)),
      };
    }),
    user('POST', '/v1/reports', async (c) => {
      const uid = userId(c);
      const b = v.object(
        c.body,
        'body',
        ['exerciseId', 'lessonVersion', 'category', 'note'],
        ['exerciseId', 'lessonVersion', 'category'],
      );
      const body = {
        exerciseId: v.id(b['exerciseId'], 'exerciseId'),
        lessonVersion: v.id(b['lessonVersion'], 'lessonVersion'),
        category: v.oneOf(b['category'], 'category', [
          'CONTENT',
          'ANSWER',
          'AUDIO',
          'OTHER',
        ] as const),
        ...(b['note'] !== undefined ? { note: v.text(b['note'], 'note', 512) } : {}),
      };
      return fromReceipt(
        await createReport(
          deps,
          uid,
          body,
          idempotencyKey(),
          hash('createReport', body),
          c.requestId,
        ),
      );
    }),
    user('POST', '/v1/admin/content-versions', async (c) => {
      const uid = userId(c);
      const b = v.object(
        c.body,
        'body',
        ['courseId', 'versionId', 'manifestFileId', 'manifestSha256', 'expectedPublishedVersion'],
        ['courseId', 'versionId', 'manifestFileId', 'manifestSha256', 'expectedPublishedVersion'],
      );
      const body = {
        courseId: v.id(b['courseId'], 'courseId'),
        versionId: v.id(b['versionId'], 'versionId'),
        manifestFileId: v.id(b['manifestFileId'], 'manifestFileId'),
        manifestSha256: v.sha(b['manifestSha256'], 'manifestSha256'),
        expectedPublishedVersion:
          b['expectedPublishedVersion'] === null
            ? null
            : v.id(b['expectedPublishedVersion'], 'expectedPublishedVersion'),
      };
      return fromReceipt(
        await publishContent(
          deps,
          uid,
          body,
          idempotencyKey(),
          hash('publishContent', body),
          c.requestId,
        ),
      );
    }),
    user('GET', '/v1/me/energy', async (c) => {
      noBodyQuery(c, []);
      return { status: 200, body: await getEnergy(deps, userId(c)) };
    }),
    ...(['activate', 'reset'] as const).map((action) =>
      user('POST', `/v1/enrollments/{courseId}/${action}`, async (c) => {
        const uid = userId(c);
        const courseId = pathParam('courseId');
        const b = v.object(c.body, 'body', ['expectedRevision'], ['expectedRevision']);
        const body = {
          expectedRevision: v.int(b['expectedRevision'], 'expectedRevision', 0, 2147483647),
        };
        const op = action === 'activate' ? 'switchCourse' : 'resetCourse';
        return fromReceipt(
          await enrollmentCommand(
            deps,
            uid,
            courseId,
            op,
            body.expectedRevision,
            idempotencyKey(),
            hash(op, body, { courseId }),
            c.requestId,
          ),
        );
      }),
    ),
    user('DELETE', '/v1/enrollments/{courseId}', async (c) => {
      const uid = userId(c);
      const courseId = pathParam('courseId');
      v.object(c.body ?? {}, 'body', [], []);
      return fromReceipt(
        await enrollmentCommand(
          deps,
          uid,
          courseId,
          'removeCourse',
          null,
          idempotencyKey(),
          hash('removeCourse', {}, { courseId }),
          c.requestId,
        ),
      );
    }),
    user('GET', '/v1/mistakes', async (c) => {
      const q = noBodyQuery(c, ['courseId', 'includeResolved', 'cursor', 'limit']);
      const includeResolved =
        q['includeResolved'] === undefined
          ? false
          : v.oneOf(q['includeResolved'], 'includeResolved', ['true', 'false'] as const) === 'true';
      return {
        status: 200,
        body: await listMistakes(
          deps,
          userId(c),
          v.id(q['courseId'], 'courseId'),
          includeResolved,
          v.cursorOf(q),
          v.limitOf(q),
        ),
      };
    }),
    user('GET', '/v1/words', async (c) => {
      const q = noBodyQuery(c, ['courseId', 'sort', 'cursor', 'limit']);
      const sort =
        q['sort'] === undefined
          ? 'RECENT'
          : v.oneOf(q['sort'], 'sort', ['RECENT', 'ALPHABETICAL'] as const);
      return {
        status: 200,
        body: await listWords(
          deps,
          userId(c),
          v.id(q['courseId'], 'courseId'),
          sort,
          v.cursorOf(q),
          v.limitOf(q),
        ),
      };
    }),
    user('GET', '/v1/activities', async (c) => {
      const q = noBodyQuery(c, ['courseId', 'kind', 'cursor', 'limit']);
      const kind =
        q['kind'] === undefined
          ? undefined
          : v.oneOf(q['kind'], 'kind', [
              'STORY',
              'ADVENTURE',
              'RADIO',
              'SIDE_QUEST',
              'CLASH',
              'UNIT_REVIEW',
            ] as const);
      return {
        status: 200,
        body: await listActivityProgress(
          deps,
          userId(c),
          v.id(q['courseId'], 'courseId'),
          kind,
          v.cursorOf(q),
          v.limitOf(q),
        ),
      };
    }),
    {
      method: 'GET',
      path: '/internal/outbox-watermark',
      auth: 'service',
      allowedSenders: ['progress', 'maintainer'],
      allowedQueryKeys: ['before'],
      async handle(c) {
        const before = v.query(c.query, ['before'])['before'];
        const ms = before ? Date.parse(before) : NaN;
        if (!before || Number.isNaN(ms))
          throw new ServiceError('VALIDATION_ERROR', { details: { field: 'before' } });
        return { status: 200, body: await outboxWatermark(deps, new Date(ms).toISOString()) };
      },
    },
  ];
}

/** Signed scheduler tick: the backstop dispatcher for l_outbox (scheduler/maintainer key). */
export function learningJobRoutes(deps: LearningDeps): Route[] {
  return [
    jobRoute(
      '/internal/jobs/learning-outbox-dispatch',
      'LEARNING_OUTBOX_DISPATCH',
      () => deps.nowMs(),
      async (tick) => {
        if (!deps.deliver) {
          throw new ServiceError('SERVICE_NOT_CONFIGURED', { details: { job: 'dispatch' } });
        }
        const report = await dispatchOutbox(deps, deps.deliver, {
          limit: Math.min(tick.limit ?? MAX_BATCH, MAX_BATCH),
          deadlineMs: 20_000,
          owner: `tick-${tick.tickId.slice(0, 8)}-${deps.newId().slice(0, 8)}`,
        });
        return {
          ...emptyCounts(),
          processed: report.leased,
          succeeded: report.acked,
          retried: report.retried,
          dead: report.dead,
          skipped: report.leased - report.acked - report.retried - report.dead,
        };
      },
    ),
  ];
}

export function learningWiring(deps: LearningDeps): ServiceWiring {
  return {
    routes: [...learningRoutes(deps), ...learningJobRoutes(deps)],
    eventConsumer: createLearningEventConsumer(deps),
  };
}

/** Wrap a router built from learningWiring so OpenAPI path templates resolve. */
export function learningHandler(
  router: (context: FunctionContext) => Promise<unknown>,
  deps: LearningDeps,
) {
  return withRequestScope(
    router,
    learningRoutes(deps).map((route) => route.path),
  );
}
