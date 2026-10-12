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
import { enrollCourse, getPath } from '../application/enrollment.js';
import { outboxWatermark } from '../application/outbox.js';
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

export function learningWiring(deps: LearningDeps): ServiceWiring {
  return { routes: learningRoutes(deps) };
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
