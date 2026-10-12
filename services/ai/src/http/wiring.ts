// AI HTTP wiring shared by the hosted entrypoint (src/index.ts) and local dev (src/dev.ts).
// Built-in /health, /ready and /internal/events come from services/shared/src/transport.ts.
// Every route below implements a docs/api/openapi.yaml operation (tag ai).
import {
  canonicalBodyHash,
  type FunctionContext,
  type Route,
  type RouteContext,
  type ServiceWiring,
} from '../../../shared/src/transport.js';
import { ServiceError } from '../../../shared/src/errors.js';
import type { ReceiptOutcome } from '../../../shared/src/ports.js';
import { createAssessment, getAssessment } from '../application/assessment.js';
import { capabilities } from '../application/capabilities.js';
import {
  completeConversation,
  listConversations,
  startConversation,
} from '../application/conversations.js';
import type { AiDeps } from '../application/deps.js';
import { createAiEventConsumer } from '../application/events.js';
import { tutorFeedback } from '../application/tutor.js';
import {
  closeVoiceSession,
  createVoiceSession,
  heartbeatVoiceSession,
  submitVoiceTurn,
} from '../application/voice.js';
import { idempotencyKey, pathParam, withRequestScope } from './scope.js';
import * as v from './validate.js';

const KINDS = ['ROLEPLAY', 'VIDEO_CALL'] as const;
const LEVELS = ['A1', 'A2'] as const;
const WAV_MAX = 640064;
const AUDIO_ROUTE_BYTES = 700000;

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

export function aiRoutes(deps: AiDeps): Route[] {
  const user = (
    method: string,
    path: string,
    handle: Route['handle'],
    maxBodyBytes?: number,
  ): Route => ({
    method,
    path,
    auth: 'user',
    handle,
    ...(maxBodyBytes ? { maxBodyBytes } : {}),
  });
  return [
    user('GET', '/v1/ai/capabilities', async (c) => {
      userId(c);
      v.query(c.query, []);
      return { status: 200, body: capabilities(deps) };
    }),
    user('POST', '/v1/tutor', async (c) => {
      const uid = userId(c);
      const b = v.object(
        c.body,
        'body',
        [
          'requestId',
          'exerciseId',
          'lessonVersion',
          'scenarioId',
          'learnerText',
          'level',
          'locale',
          'feedbackLocale',
        ],
        ['requestId', 'learnerText', 'level', 'locale', 'feedbackLocale'],
      );
      v.oneOf(b['locale'], 'locale', ['en-US'] as const);
      v.oneOf(b['feedbackLocale'], 'feedbackLocale', ['vi-VN'] as const);
      const body = {
        requestId: v.uuid(b['requestId'], 'requestId'),
        exerciseId: v.nullableId(b['exerciseId'], 'exerciseId'),
        lessonVersion: v.nullableId(b['lessonVersion'], 'lessonVersion'),
        scenarioId: v.nullableId(b['scenarioId'], 'scenarioId'),
        learnerText: v.text(b['learnerText'], 'learnerText', 0, 512),
        level: v.oneOf(b['level'], 'level', LEVELS),
      };
      return fromReceipt(await tutorFeedback(deps, uid, body, hash('tutorFeedback', body)));
    }),
    user('POST', '/v1/voice-sessions', async (c) => {
      const uid = userId(c);
      const b = v.object(
        c.body,
        'body',
        ['sessionId', 'scenarioId', 'mode', 'level'],
        ['sessionId', 'scenarioId', 'mode', 'level'],
      );
      const body = {
        sessionId: v.uuid(b['sessionId'], 'sessionId'),
        scenarioId: v.id(b['scenarioId'], 'scenarioId'),
        mode: v.oneOf(b['mode'], 'mode', ['LIVE', 'TURN'] as const),
        level: v.oneOf(b['level'], 'level', LEVELS),
      };
      return fromReceipt(
        await createVoiceSession(
          deps,
          uid,
          body,
          idempotencyKey(),
          hash('createVoiceSession', body),
        ),
      );
    }),
    user('POST', '/v1/voice-sessions/{sessionId}/heartbeat', async (c) => {
      const uid = userId(c);
      const b = v.object(
        c.body,
        'body',
        ['epoch', 'elapsedSeconds', 'turnCount'],
        ['epoch', 'elapsedSeconds', 'turnCount'],
      );
      const body = {
        epoch: v.int(b['epoch'], 'epoch', 0, 2147483647),
        elapsedSeconds: v.int(b['elapsedSeconds'], 'elapsedSeconds', 0, 180),
        turnCount: v.int(b['turnCount'], 'turnCount', 0, 50),
      };
      return {
        status: 200,
        body: await heartbeatVoiceSession(deps, uid, pathParam('sessionId'), body),
      };
    }),
    user('POST', '/v1/voice-sessions/{sessionId}/close', async (c) => {
      const uid = userId(c);
      return { status: 200, body: await closeVoiceSession(deps, uid, pathParam('sessionId')) };
    }),
    user(
      'POST',
      '/v1/voice-sessions/{sessionId}/turns',
      async (c) => {
        const uid = userId(c);
        const sessionId = pathParam('sessionId');
        const b = v.object(
          c.body,
          'body',
          ['turnId', 'epoch', 'wavBase64', 'audioSha256'],
          ['turnId', 'epoch', 'wavBase64', 'audioSha256'],
        );
        const body = {
          turnId: v.uuid(b['turnId'], 'turnId'),
          epoch: v.int(b['epoch'], 'epoch', 0, 2147483647),
          wavBase64: v.text(b['wavBase64'], 'wavBase64', 4, WAV_MAX),
          audioSha256: v.sha(b['audioSha256'], 'audioSha256'),
        };
        return fromReceipt(
          await submitVoiceTurn(
            deps,
            uid,
            sessionId,
            body,
            idempotencyKey(),
            hash('submitVoiceTurn', body, { sessionId }),
          ),
        );
      },
      AUDIO_ROUTE_BYTES,
    ),
    user(
      'POST',
      '/v1/assessment-jobs',
      async (c) => {
        const uid = userId(c);
        const b = v.object(
          c.body,
          'body',
          [
            'jobId',
            'referenceExerciseId',
            'lessonVersion',
            'locale',
            'wavBase64',
            'audioSha256',
            'referenceText',
          ],
          ['jobId', 'referenceExerciseId', 'lessonVersion', 'locale', 'wavBase64', 'audioSha256'],
        );
        const body = {
          jobId: v.uuid(b['jobId'], 'jobId'),
          referenceExerciseId: v.id(b['referenceExerciseId'], 'referenceExerciseId'),
          lessonVersion: v.id(b['lessonVersion'], 'lessonVersion'),
          locale: v.oneOf(b['locale'], 'locale', ['en-US'] as const),
          wavBase64: v.text(b['wavBase64'], 'wavBase64', 4, WAV_MAX),
          audioSha256: v.sha(b['audioSha256'], 'audioSha256'),
          ...(b['referenceText'] === undefined || b['referenceText'] === null
            ? {}
            : { referenceText: v.text(b['referenceText'], 'referenceText', 1, 300) }),
        };
        return fromReceipt(
          await createAssessment(deps, uid, body, idempotencyKey(), hash('createAssessment', body)),
        );
      },
      AUDIO_ROUTE_BYTES,
    ),
    user('GET', '/v1/assessment-jobs/{jobId}', async (c) => {
      v.query(c.query, []);
      return {
        status: 200,
        body: await getAssessment(deps, userId(c), v.uuid(pathParam('jobId'), 'jobId')),
      };
    }),
    user('GET', '/v1/conversations', async (c) => {
      const uid = userId(c);
      const q = v.query(c.query, ['kind', 'scenarioId', 'cursor', 'limit']);
      const limit = q['limit'] === undefined ? 20 : Number(q['limit']);
      return {
        status: 200,
        body: await listConversations(deps, uid, {
          ...(q['kind'] ? { kind: v.oneOf(q['kind'], 'kind', KINDS) } : {}),
          ...(q['scenarioId'] ? { scenarioId: v.id(q['scenarioId'], 'scenarioId') } : {}),
          ...(q['cursor'] ? { cursor: v.text(q['cursor'], 'cursor', 1, 256) } : {}),
          limit: v.int(Number.isNaN(limit) ? -1 : limit, 'limit', 1, 100),
        }),
      };
    }),
    user('POST', '/v1/conversations', async (c) => {
      const uid = userId(c);
      const b = v.object(
        c.body,
        'body',
        ['kind', 'courseId', 'scenarioId', 'voiceSessionId'],
        ['kind', 'courseId', 'scenarioId', 'voiceSessionId'],
      );
      const body = {
        kind: v.oneOf(b['kind'], 'kind', KINDS),
        courseId: v.id(b['courseId'], 'courseId'),
        scenarioId: v.id(b['scenarioId'], 'scenarioId'),
        voiceSessionId: v.nullableId(b['voiceSessionId'], 'voiceSessionId'),
      };
      return fromReceipt(
        await startConversation(deps, uid, body, idempotencyKey(), hash('startConversation', body)),
      );
    }),
    user('POST', '/v1/conversations/{conversationId}/complete', async (c) => {
      const uid = userId(c);
      const conversationId = pathParam('conversationId');
      const b = v.object(c.body, 'body', ['endReason'], ['endReason']);
      const body = {
        endReason: v.oneOf(b['endReason'], 'endReason', ['COMPLETED', 'USER_EXIT'] as const),
      };
      const { outcome, eventIds } = await completeConversation(
        deps,
        uid,
        conversationId,
        body.endReason,
        idempotencyKey(),
        hash('completeConversation', body, { conversationId }),
      );
      if (deps.relay) await deps.relay.afterCommit(eventIds);
      return fromReceipt(outcome);
    }),
  ];
}

export const AI_PATH_TEMPLATES = [
  '/v1/voice-sessions/{sessionId}/heartbeat',
  '/v1/voice-sessions/{sessionId}/close',
  '/v1/voice-sessions/{sessionId}/turns',
  '/v1/assessment-jobs/{jobId}',
  '/v1/conversations/{conversationId}/complete',
];

export function aiWiring(deps: AiDeps): ServiceWiring {
  return { routes: aiRoutes(deps), eventConsumer: createAiEventConsumer(deps) };
}

/** Wrap a router so templated paths resolve and handlers can read params/headers. */
export function aiHandler(
  router: (context: FunctionContext) => Promise<unknown>,
): (context: FunctionContext) => Promise<unknown> {
  return withRequestScope(router, AI_PATH_TEMPLATES);
}
