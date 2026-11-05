// Authorization audit (docs/api/AUTH.md): /health is the only unauthenticated route; every
// business route needs a verified subject (or an explicitly allowed internal HMAC sender);
// /ready is maintainer/internal-only; content publication needs maintainer membership.
// The route table below is read from the real wiring, so a new route is covered automatically.
import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { loadKit } from './helpers/kit.mjs';

const kit = await loadKit('authz');
const KEYS = {
  learning: kit.devKey('learning'),
  progress: kit.devKey('progress'),
  ai: kit.devKey('ai'),
  maintainer: kit.devKey('maintainer'),
  scheduler: kit.devKey('scheduler'),
};
const keyring = kit.createKeyring(Object.values(KEYS));

async function app() {
  return kit.createTestApp({ keyring });
}

const concrete = (path) => path.replace(/\{[A-Za-z]+\}/g, 'x1');

function sign(key, method, path, bodyText = '', { query = '', allowedQueryKeys = [] } = {}) {
  return kit.signServiceRequest({
    key,
    method,
    path,
    query,
    allowedQueryKeys,
    body: bodyText,
    nowSeconds: Math.floor(Date.now() / 1000),
  });
}

async function rawCall(a, method, path, { headers = {}, bodyText, query } = {}) {
  return a.call(method, path, {
    headers,
    ...(bodyText !== undefined ? { body: bodyText } : {}),
    ...(query !== undefined ? { query } : {}),
  });
}

test('GET /health is the only public route: no credential, and even a forged one, still answers', async () => {
  const a = await app();
  for (const headers of [{}, { authorization: 'Bearer forged' }]) {
    const response = await rawCall(a, 'GET', '/health', { headers });
    assert.equal(response.status, 200);
    assert.equal(response.body.status, 'degraded');
  }
});

test('every Learning business route refuses a request without a verified subject (401 AUTH_REQUIRED)', async () => {
  const a = await app();
  const userRoutes = a.routes.filter((route) => route.auth === 'user');
  assert.ok(
    userRoutes.length >= 20,
    `expected the Learning business routes, got ${userRoutes.length}`,
  );
  for (const route of userRoutes) {
    const path = concrete(route.path);
    const missing = await rawCall(a, route.method, path);
    assert.deepEqual(
      [missing.status, missing.body.error.code],
      [401, 'AUTH_REQUIRED'],
      `${route.method} ${path} (no credential)`,
    );
    for (const headers of [
      { authorization: 'Bearer forged' },
      { authorization: 'Basic dXNlcjphbGljZQ==' },
      { 'x-appwrite-user-id': 'alice' },
    ]) {
      const response = await rawCall(a, route.method, path, { headers });
      assert.deepEqual(
        [response.status, response.body.error.code],
        [401, 'AUTH_REQUIRED'],
        `${route.method} ${path} ${JSON.stringify(headers)}`,
      );
    }
  }
  // A caller-supplied x-appwrite-user-id alone is never a credential (extractJwt only reads the
  // bearer/direct JWT headers), and conflicting JWT headers fail closed.
  const conflict = await rawCall(a, 'GET', '/v1/courses', {
    headers: { authorization: 'Bearer user-alice', 'x-appwrite-user-jwt': 'user-bob' },
  });
  assert.deepEqual([conflict.status, conflict.body.error.code], [401, 'AUTH_REQUIRED']);
  assert.equal(
    (await rawCall(a, 'GET', '/v1/courses', { headers: { 'x-appwrite-user-jwt': 'user-alice' } }))
      .status,
    200,
    'the Appwrite direct-execution header is accepted after Account.get verification',
  );
});

test('a verified subject passes the guard on every Learning business route (no blanket denial)', async () => {
  const a = await app();
  for (const route of a.routes.filter((entry) => entry.auth === 'user')) {
    const response = await a.call(route.method, concrete(route.path), {
      user: 'authorization-probe',
      key: randomUUID(),
    });
    assert.notEqual(
      response.status,
      401,
      `${route.method} ${route.path} denied a verified subject`,
    );
    assert.notEqual(
      response.body?.error?.code,
      'AUTH_REQUIRED',
      `${route.method} ${route.path} reported AUTH_REQUIRED for a verified subject`,
    );
  }
});

test('every Learning /internal route refuses an unsigned request (401 AUTH_REQUIRED)', async () => {
  const a = await app();
  const serviceRoutes = a.routes.filter((route) => route.auth === 'service');
  assert.deepEqual(serviceRoutes.map((route) => `${route.method} ${route.path}`).sort(), [
    'GET /internal/outbox-watermark',
    'POST /internal/jobs/learning-outbox-dispatch',
  ]);
  for (const route of serviceRoutes) {
    const response = await rawCall(a, route.method, route.path);
    assert.deepEqual(
      [response.status, response.body.error.code],
      [401, 'AUTH_REQUIRED'],
      `${route.method} ${route.path} (unsigned)`,
    );
    const partial = await rawCall(a, route.method, route.path, {
      headers: { 'x-service-key-id': 'dev-progress' },
    });
    assert.deepEqual([partial.status, partial.body.error.code], [401, 'AUTH_REQUIRED']);
  }
});

test('Learning /internal routes refuse a signer that is not an allowed sender (403 FORBIDDEN)', async () => {
  const a = await app();
  const watermarkQuery = '?before=2026-10-12T00:00:00.000Z';
  const watermark = await rawCall(a, 'GET', '/internal/outbox-watermark', {
    query: watermarkQuery,
    headers: sign(KEYS.ai, 'GET', '/internal/outbox-watermark', '', {
      query: watermarkQuery,
      allowedQueryKeys: ['before'],
    }),
  });
  assert.deepEqual([watermark.status, watermark.body.error.code], [403, 'FORBIDDEN']);

  const tick = JSON.stringify({ tickId: randomUUID(), scheduledAt: new Date().toISOString() });
  const job = await rawCall(a, 'POST', '/internal/jobs/learning-outbox-dispatch', {
    headers: sign(KEYS.ai, 'POST', '/internal/jobs/learning-outbox-dispatch', tick),
    bodyText: tick,
  });
  assert.deepEqual([job.status, job.body.error.code], [403, 'FORBIDDEN']);
});

test('Learning /internal routes accept an allowed sender (Progress watermark, scheduler tick)', async () => {
  const a = await app();
  const watermarkQuery = '?before=2026-10-12T00:00:00.000Z';
  const watermark = await rawCall(a, 'GET', '/internal/outbox-watermark', {
    query: watermarkQuery,
    headers: sign(KEYS.progress, 'GET', '/internal/outbox-watermark', '', {
      query: watermarkQuery,
      allowedQueryKeys: ['before'],
    }),
  });
  assert.equal(watermark.status, 200);

  const tick = JSON.stringify({ tickId: randomUUID(), scheduledAt: new Date().toISOString() });
  const job = await rawCall(a, 'POST', '/internal/jobs/learning-outbox-dispatch', {
    headers: sign(KEYS.scheduler, 'POST', '/internal/jobs/learning-outbox-dispatch', tick),
    bodyText: tick,
  });
  assert.equal(job.status, 503, 'no delivery port in the test app: fails closed, not denied');
  assert.equal(job.body.error.code, 'SERVICE_NOT_CONFIGURED');
});

test('/ready is maintainer/internal-only and /internal/events needs an allowed sender', async () => {
  const a = await app();
  const unsigned = await rawCall(a, 'GET', '/ready');
  assert.deepEqual([unsigned.status, unsigned.body.error.code], [401, 'AUTH_REQUIRED']);
  const scheduler = await rawCall(a, 'GET', '/ready', {
    headers: sign(KEYS.scheduler, 'GET', '/ready'),
  });
  assert.equal(scheduler.status, 403, 'the scheduler key cannot probe readiness');
  const maintainer = await rawCall(a, 'GET', '/ready', {
    headers: sign(KEYS.maintainer, 'GET', '/ready'),
  });
  assert.equal(maintainer.status, 503, 'memory is never admitted in local-test');

  const event = JSON.stringify({});
  const unsignedEvent = await rawCall(a, 'POST', '/internal/events', { bodyText: event });
  assert.deepEqual([unsignedEvent.status, unsignedEvent.body.error.code], [401, 'AUTH_REQUIRED']);
  const foreignEvent = await rawCall(a, 'POST', '/internal/events', {
    headers: sign(KEYS.ai, 'POST', '/internal/events', event),
    bodyText: event,
  });
  assert.deepEqual([foreignEvent.status, foreignEvent.body.error.code], [403, 'FORBIDDEN']);
  const progressEvent = await rawCall(a, 'POST', '/internal/events', {
    headers: sign(KEYS.progress, 'POST', '/internal/events', event),
    bodyText: event,
  });
  assert.equal(progressEvent.status, 400, 'allowed sender reaches envelope validation');
});

test('content publication requires server-authoritative maintainer membership (403 MAINTAINER_REQUIRED)', async () => {
  const a = await app();
  const body = {
    courseId: 'vi_en',
    versionId: 'v9',
    manifestFileId: 'f1',
    manifestSha256: 'a'.repeat(64),
    expectedPublishedVersion: null,
  };
  const denied = await a.call('POST', '/v1/admin/content-versions', {
    user: 'learner',
    body,
    key: randomUUID(),
  });
  assert.deepEqual([denied.status, denied.body.error.code], [403, 'MAINTAINER_REQUIRED']);
  const anonymous = await rawCall(a, 'POST', '/v1/admin/content-versions', {
    bodyText: JSON.stringify(body),
  });
  assert.deepEqual([anonymous.status, anonymous.body.error.code], [401, 'AUTH_REQUIRED']);
});

test('identity comes only from the verified subject: a body userId is rejected, never honored', async () => {
  const a = await app();
  const forged = await a.call('POST', '/v1/sessions', {
    user: 'alice',
    key: randomUUID(),
    body: {
      userId: 'bob',
      courseId: 'vi_en',
      lessonId: 'u1n1l1',
      mode: 'LESSON',
      expectedEnrollmentRevision: 0,
    },
  });
  assert.equal(forged.status, 400);
  assert.equal(forged.body.error.code, 'VALIDATION_ERROR');
  assert.equal(forged.body.error.details.field, 'body.userId');
});
