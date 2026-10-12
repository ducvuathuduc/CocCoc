import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import Ajv from 'ajv/dist/2020.js';
import formats from 'ajv-formats';
import {
  ERROR_CODES,
  ServiceError,
  createAppwriteAuthPort,
  createDisabledLearningPersistence,
  createDisabledProgressPersistence,
  createHostedHandler,
  createKeyring,
  createMemoryLearningPersistence,
  createMemoryProgressPersistence,
  createRouter,
  isRetryable,
  signServiceRequest,
  statusFor,
} from '../../../.cache/backend-fixtures/foundation-testkit.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const api = JSON.parse(fs.readFileSync(path.join(root, 'docs/api/openapi.yaml'), 'utf8'));
const ajv = new Ajv({ strict: false });
formats(ajv);
ajv.addSchema({ $id: 'https://cocenglish.example.invalid/schema', components: api.components });
const schema = (name) =>
  ajv.compile({ $ref: `https://cocenglish.example.invalid/schema#/components/schemas/${name}` });
const validateError = schema('Error');
const validateHealth = schema('Health');
const validateReceipt = schema('Receipt');
const validateEvent = schema('BusinessEvent');

const NOW_MS = 1760000000000;
const learningKey = { keyId: 'l-to-p', sender: 'learning', secret: Buffer.alloc(32, 7) };
const aiKey = { keyId: 'ai-to-p', sender: 'ai', secret: Buffer.alloc(32, 9) };
const maintainerKey = { keyId: 'ops', sender: 'maintainer', secret: Buffer.alloc(32, 3) };
const keyring = createKeyring([learningKey, aiKey, maintainerKey]);

/** Fake auth port: maps known tokens to subjects, records calls. */
function fakeAuth(map = { 'jwt-alice': 'alice', 'jwt-bob': 'bob' }) {
  const calls = [];
  return {
    calls,
    async verify(jwt) {
      calls.push(jwt);
      if (jwt === 'jwt-down') throw new ServiceError('AUTH_UNAVAILABLE');
      const userId = map[jwt];
      if (!userId) throw new ServiceError('AUTH_EXPIRED');
      return { userId };
    },
  };
}
const echoRoute = {
  method: 'POST',
  path: '/v1/echo',
  auth: 'user',
  async handle(ctx) {
    return {
      status: 200,
      body: { userId: ctx.subject.userId, body: ctx.body, trace: ctx.traceparent ?? null },
    };
  },
};
function call(handler, { method = 'GET', path: p, headers = {}, body, query } = {}) {
  return handler({
    req: { method, path: p, headers, bodyText: body, queryString: query },
    res: { json: (b, status, h) => ({ body: b, status, headers: h }) },
  });
}
function signed(key, method, p, body = '', query = '', allowedQueryKeys = []) {
  return signServiceRequest({
    key,
    method,
    path: p,
    query,
    allowedQueryKeys,
    body,
    nowSeconds: NOW_MS / 1000,
  });
}
function completionEvent(overrides = {}) {
  return {
    eventId: randomUUID(),
    type: 'lesson.completed.v1',
    schemaVersion: 1,
    producer: 'learning',
    aggregateId: 'session-1',
    occurredAt: '2026-10-03T10:00:00Z',
    requestId: randomUUID(),
    payload: {
      completionId: 'session-1',
      userId: 'alice',
      courseId: 'vi_en',
      lessonVersion: 'v1',
      rewardIdentity: 'lesson-1',
      source: 'ONLINE',
      mode: 'LESSON',
      originalCount: 10,
      originalCorrect: 9,
      assisted: false,
    },
    ...overrides,
  };
}

test('error table: every code has its documented status; retryable only for bounded transient codes', () => {
  const expected = {
    AUTH_REQUIRED: 401,
    FORBIDDEN: 403,
    NOT_FOUND: 404,
    IDEMPOTENCY_CONFLICT: 409,
    PAYLOAD_TOO_LARGE: 413,
    RATE_LIMITED: 429,
    INTERNAL_ERROR: 500,
    DB_UNAVAILABLE: 503,
    DEADLINE_EXCEEDED: 504,
  };
  for (const [code, status] of Object.entries(expected)) assert.equal(statusFor(code), status);
  // Every server code in the EVENTS_ERRORS table maps to that row's HTTP status.
  const doc = fs.readFileSync(path.join(root, 'docs/api/EVENTS_ERRORS.md'), 'utf8');
  const rows = [...doc.matchAll(/^\| (\d{3}) \| ([A-Z_, ]+) \|/gm)];
  assert.ok(rows.length >= 10);
  for (const [, status, codes] of rows) {
    for (const code of codes.split(',').map((c) => c.trim())) {
      assert.ok(ERROR_CODES.includes(code), `${code} missing`);
      assert.equal(statusFor(code), Number(status), code);
    }
  }
  assert.equal(isRetryable('DB_UNAVAILABLE'), true);
  assert.equal(isRetryable('DEADLINE_EXCEEDED'), true);
  assert.equal(isRetryable('NATIVE_LIVE_DISABLED'), false);
  assert.equal(isRetryable('IDEMPOTENCY_CONFLICT'), false);
  assert.equal(isRetryable('AUTH_REQUIRED'), false);
});

test('verified JWT via injected auth port; forged user-id headers are ignored', async () => {
  const auth = fakeAuth();
  const handler = createRouter({
    service: 'learning',
    persistence: createMemoryLearningPersistence(),
    mode: 'local-test',
    auth,
    routes: [echoRoute],
  });
  const ok = await call(handler, {
    method: 'POST',
    path: '/v1/echo',
    headers: {
      Authorization: 'Bearer jwt-alice',
      'x-appwrite-user-id': 'bob',
      'X-Request-ID': 'req-1',
    },
    body: '{"userId":"bob"}',
  });
  assert.equal(ok.status, 200);
  assert.equal(ok.body.userId, 'alice');
  assert.equal(ok.headers['X-Request-ID'], 'req-1');
  assert.equal(ok.headers['Cache-Control'], 'no-store');
  const direct = await call(handler, {
    method: 'POST',
    path: '/v1/echo',
    headers: { 'x-appwrite-user-jwt': 'jwt-bob' },
    body: '{}',
  });
  assert.equal(direct.body.userId, 'bob');
  const forged = await call(handler, {
    method: 'POST',
    path: '/v1/echo',
    headers: { 'x-appwrite-user-id': 'alice' },
    body: '{}',
  });
  assert.equal(forged.status, 401);
  assert.equal(forged.body.error.code, 'AUTH_REQUIRED');
  assert.equal(validateError(forged.body), true, JSON.stringify(validateError.errors));
  const mismatch = await call(handler, {
    method: 'POST',
    path: '/v1/echo',
    headers: { authorization: 'Bearer jwt-alice', 'x-appwrite-user-jwt': 'jwt-bob' },
    body: '{}',
  });
  assert.equal(mismatch.body.error.code, 'AUTH_REQUIRED');
  const expired = await call(handler, {
    method: 'POST',
    path: '/v1/echo',
    headers: { authorization: 'Bearer stale' },
    body: '{}',
  });
  assert.deepEqual([expired.status, expired.body.error.code], [401, 'AUTH_EXPIRED']);
  const down = await call(handler, {
    method: 'POST',
    path: '/v1/echo',
    headers: { authorization: 'Bearer jwt-down' },
    body: '{}',
  });
  assert.deepEqual(
    [down.status, down.body.error.code, down.body.error.retryable],
    [503, 'AUTH_UNAVAILABLE', true],
  );
  const badScheme = await call(handler, {
    method: 'POST',
    path: '/v1/echo',
    headers: { authorization: 'Basic abc' },
    body: '{}',
  });
  assert.equal(badScheme.body.error.code, 'AUTH_REQUIRED');
  assert.equal(auth.calls.includes('abc'), false);
});

test('auth precedes route lookup; unknown routes are 404 only after verification', async () => {
  const handler = createRouter({
    service: 'learning',
    persistence: createMemoryLearningPersistence(),
    mode: 'local-test',
    auth: fakeAuth(),
    routes: [echoRoute],
  });
  assert.equal((await call(handler, { path: '/v1/private' })).status, 401);
  const unknown = await call(handler, {
    path: '/v1/private',
    headers: { authorization: 'Bearer jwt-alice' },
  });
  assert.deepEqual([unknown.status, unknown.body.error.code], [404, 'NOT_FOUND']);
});

test('envelope: body limits, GET body, malformed JSON, traceparent and redacted internal errors', async () => {
  const boom = {
    method: 'POST',
    path: '/v1/boom',
    auth: 'user',
    async handle() {
      throw new Error('SELECT * FROM secret_table');
    },
  };
  const handler = createRouter({
    service: 'learning',
    persistence: createMemoryLearningPersistence(),
    mode: 'local-test',
    auth: fakeAuth(),
    routes: [echoRoute, boom],
  });
  const h = { authorization: 'Bearer jwt-alice' };
  const big = await call(handler, {
    method: 'POST',
    path: '/v1/echo',
    headers: h,
    body: JSON.stringify({ x: 'a'.repeat(64000) }),
  });
  assert.deepEqual([big.status, big.body.error.code], [413, 'PAYLOAD_TOO_LARGE']);
  const getBody = await call(handler, { method: 'GET', path: '/v1/echo', headers: h, body: '{}' });
  assert.equal(getBody.body.error.code, 'VALIDATION_ERROR');
  const malformed = await call(handler, {
    method: 'POST',
    path: '/v1/echo',
    headers: h,
    body: '{nope',
  });
  assert.deepEqual([malformed.status, malformed.body.error.code], [400, 'VALIDATION_ERROR']);
  const traced = await call(handler, {
    method: 'POST',
    path: '/v1/echo',
    headers: { ...h, traceparent: '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01' },
    body: '{}',
  });
  assert.equal(traced.body.trace, '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01');
  const zeroTrace = await call(handler, {
    method: 'POST',
    path: '/v1/echo',
    headers: { ...h, traceparent: '00-00000000000000000000000000000000-00f067aa0ba902b7-01' },
    body: '{}',
  });
  assert.equal(zeroTrace.body.trace, null);
  const internal = await call(handler, {
    method: 'POST',
    path: '/v1/boom',
    headers: h,
    body: '{}',
  });
  assert.equal(internal.status, 500);
  assert.equal(internal.body.error.code, 'INTERNAL_ERROR');
  assert.doesNotMatch(JSON.stringify(internal.body), /secret_table/);
  assert.equal(validateError(internal.body), true);
});

test('hosted mode refuses memory adapters and fails closed without an admitted adapter', async () => {
  assert.throws(
    () =>
      createRouter({
        service: 'learning',
        persistence: createMemoryLearningPersistence(),
        mode: 'hosted',
      }),
    /MEMORY_ADAPTER_NOT_ALLOWED/,
  );
  assert.throws(
    () =>
      createRouter({
        service: 'progress',
        persistence: createDisabledLearningPersistence(),
        mode: 'hosted',
      }),
    /PERSISTENCE_OWNER_MISMATCH/,
  );
  const hosted = createRouter({
    service: 'learning',
    persistence: createDisabledLearningPersistence(),
    mode: 'hosted',
    auth: fakeAuth(),
    routes: [echoRoute],
  });
  const response = await call(hosted, {
    method: 'POST',
    path: '/v1/echo',
    headers: { authorization: 'Bearer jwt-alice' },
    body: '{}',
  });
  assert.deepEqual([response.status, response.body.error.code], [503, 'SERVICE_NOT_CONFIGURED']);
});

test('/ready: HMAC required; reports ok only with auth + admitted, reachable persistence', async () => {
  const readyHeaders = (key = maintainerKey) => signed(key, 'GET', '/ready');
  const memory = createMemoryLearningPersistence();
  const local = createRouter({
    service: 'learning',
    persistence: memory,
    mode: 'local-test',
    auth: fakeAuth(),
    keyring,
    nowMs: () => NOW_MS,
  });
  assert.equal((await call(local, { path: '/ready' })).status, 401);
  const notAdmitted = await call(local, { path: '/ready', headers: readyHeaders() });
  assert.deepEqual(
    [notAdmitted.status, notAdmitted.body.error.code],
    [503, 'SERVICE_NOT_CONFIGURED'],
  );
  assert.equal(notAdmitted.body.error.details.checks.persistence, false);
  const stale = await call(local, {
    path: '/ready',
    headers: signServiceRequest({
      key: maintainerKey,
      method: 'GET',
      path: '/ready',
      body: '',
      nowSeconds: NOW_MS / 1000 - 301,
    }),
  });
  assert.equal(stale.body.error.code, 'AUTH_EXPIRED');

  // A stand-in for a future admitted durable adapter: readiness logic only.
  let reachable = true;
  const admitted = {
    service: 'learning',
    kind: 'appwrite',
    admittedForHosting: true,
    async ping() {
      if (!reachable) throw new ServiceError('DB_UNAVAILABLE');
    },
  };
  const prod = createRouter({
    service: 'learning',
    persistence: admitted,
    mode: 'hosted',
    auth: fakeAuth(),
    keyring,
    nowMs: () => NOW_MS,
    buildId: 'b-123',
  });
  const ok = await call(prod, { path: '/ready', headers: readyHeaders(learningKey) });
  assert.equal(ok.status, 200);
  assert.deepEqual(ok.body, { service: 'learning', buildId: 'b-123', status: 'ok' });
  assert.equal(validateHealth(ok.body), true);
  reachable = false;
  const down = await call(prod, { path: '/ready', headers: readyHeaders() });
  assert.deepEqual([down.status, down.body.error.code], [503, 'DB_UNAVAILABLE']);
  const noAuth = createRouter({
    service: 'learning',
    persistence: { ...admitted, async ping() {} },
    mode: 'hosted',
    keyring,
    nowMs: () => NOW_MS,
  });
  const noAuthReady = await call(noAuth, { path: '/ready', headers: readyHeaders() });
  assert.equal(noAuthReady.body.error.code, 'SERVICE_NOT_CONFIGURED');
  assert.equal(noAuthReady.body.error.details.checks.auth, false);
});

function progressConsumer(store) {
  return {
    async consume(event, context) {
      return store.applyInboxEvent(
        { eventId: event.eventId, type: event.type, bodyHash: context.bodyHash },
        async (tx) => {
          const key = `${event.payload.userId}:${event.payload.completionId}`;
          if (!(await tx.get('p_reward_ledger', key)))
            tx.put('p_reward_ledger', key, {
              userId: event.payload.userId,
              eventId: event.eventId,
            });
        },
      );
    },
  };
}

test('/internal/events: signed, allowlisted, deduped by inbox; substitution is 409', async () => {
  const store = createMemoryProgressPersistence(() => NOW_MS);
  const handler = createRouter({
    service: 'progress',
    persistence: store,
    mode: 'local-test',
    keyring,
    nowMs: () => NOW_MS,
    eventConsumer: progressConsumer(store),
  });
  const event = completionEvent();
  assert.equal(validateEvent(event), true, JSON.stringify(validateEvent.errors));
  const body = JSON.stringify(event);
  const deliver = (b, key = learningKey) =>
    call(handler, {
      method: 'POST',
      path: '/internal/events',
      headers: signed(key, 'POST', '/internal/events', b),
      body: b,
    });
  const first = await deliver(body);
  assert.equal(first.status, 200);
  assert.equal(first.body.status, 'accepted');
  assert.equal(validateReceipt(first.body), true);
  const reordered = JSON.stringify(Object.fromEntries(Object.entries(event).reverse()));
  const replay = await deliver(reordered);
  assert.deepEqual([replay.status, replay.body.status], [200, 'replayed']);
  const substituted = JSON.stringify({
    ...event,
    payload: { ...event.payload, originalCorrect: 10 },
  });
  const conflict = await deliver(substituted);
  assert.deepEqual([conflict.status, conflict.body.error.code], [409, 'IDEMPOTENCY_CONFLICT']);
  assert.equal(store.inboxSize, 1);
  assert.ok(await store.read('p_reward_ledger', 'alice:session-1'));

  const unsigned = await call(handler, { method: 'POST', path: '/internal/events', body });
  assert.equal(unsigned.status, 401);
  const tampered = await call(handler, {
    method: 'POST',
    path: '/internal/events',
    headers: signed(learningKey, 'POST', '/internal/events', body),
    body: body.replace('"originalCorrect":9', '"originalCorrect":10'),
  });
  assert.equal(tampered.body.error.code, 'AUTH_REQUIRED');
  // AI may send purge acks but cannot impersonate Learning's completion producer.
  const impersonated = await deliver(JSON.stringify(completionEvent()), aiKey);
  assert.deepEqual([impersonated.status, impersonated.body.error.code], [403, 'FORBIDDEN']);
  // Maintainer keys are not event producers.
  const maintainer = await deliver(JSON.stringify(completionEvent()), maintainerKey);
  assert.equal(maintainer.body.error.code, 'FORBIDDEN');
  const unknownType = await deliver(
    JSON.stringify(completionEvent({ type: 'lesson.completed.v2' })),
  );
  assert.deepEqual([unknownType.status, unknownType.body.error.code], [400, 'VALIDATION_ERROR']);
  const extraField = await deliver(JSON.stringify({ ...completionEvent(), userId: 'mallory' }));
  assert.equal(extraField.body.error.code, 'VALIDATION_ERROR');
  assert.equal(store.inboxSize, 1);
  // ai.practice.completed.v1 is allowlisted for the AI producer only.
  const practice = {
    eventId: randomUUID(),
    type: 'ai.practice.completed.v1',
    schemaVersion: 1,
    producer: 'ai',
    aggregateId: 'alice',
    occurredAt: '2026-10-03T10:00:00.000Z',
    requestId: randomUUID(),
    payload: {
      completionId: 'conv-1',
      userId: 'alice',
      kind: 'ROLEPLAY',
      courseId: 'vi_en',
      scenarioId: 'rp_ask_directions',
      xp: 20,
      wordsUsed: 6,
      stars: 3,
    },
  };
  assert.equal(validateEvent(practice), true, JSON.stringify(validateEvent.errors));
  const fromLearning = await deliver(
    JSON.stringify({ ...practice, producer: 'learning' }),
    learningKey,
  );
  assert.deepEqual([fromLearning.status, fromLearning.body.error.code], [403, 'FORBIDDEN']);
  const spoofed = await deliver(JSON.stringify(practice), learningKey);
  assert.deepEqual([spoofed.status, spoofed.body.error.code], [403, 'FORBIDDEN']);
  const fromAi = await deliver(JSON.stringify(practice), aiKey);
  assert.deepEqual([fromAi.status, fromAi.body.status], [200, 'accepted']);
  assert.equal(store.inboxSize, 2);
});

test('/internal/events: failed commit leaves no inbox row; receivers without a consumer never ack', async () => {
  const store = createMemoryProgressPersistence(() => NOW_MS);
  const handler = createRouter({
    service: 'progress',
    persistence: store,
    mode: 'local-test',
    keyring,
    nowMs: () => NOW_MS,
    eventConsumer: progressConsumer(store),
  });
  const body = JSON.stringify(completionEvent());
  const headers = signed(learningKey, 'POST', '/internal/events', body);
  store.failNextCommit = true;
  const failed = await call(handler, { method: 'POST', path: '/internal/events', headers, body });
  assert.deepEqual([failed.status, failed.body.error.retryable], [503, true]);
  assert.equal(store.inboxSize, 0);
  assert.equal(await store.read('p_reward_ledger', 'alice:session-1'), null);
  assert.equal(
    (await call(handler, { method: 'POST', path: '/internal/events', headers, body })).body.status,
    'accepted',
  );

  const noConsumer = createRouter({
    service: 'progress',
    persistence: createDisabledProgressPersistence(),
    mode: 'hosted',
    keyring,
    nowMs: () => NOW_MS,
  });
  const pending = await call(noConsumer, {
    method: 'POST',
    path: '/internal/events',
    headers,
    body,
  });
  assert.deepEqual([pending.status, pending.body.error.code], [503, 'SERVICE_NOT_CONFIGURED']);
  // Learning only accepts account.deleted.v1 from Progress.
  const learning = createRouter({
    service: 'learning',
    persistence: createMemoryLearningPersistence(),
    mode: 'local-test',
    keyring,
    nowMs: () => NOW_MS,
  });
  const wrongReceiver = await call(learning, {
    method: 'POST',
    path: '/internal/events',
    headers,
    body,
  });
  assert.equal(wrongReceiver.status, 403);
});

test('appwrite auth port: Account.get errors map fail-closed with one bounded transient retry', async () => {
  const sleeps = [];
  const port = (impl) =>
    createAppwriteAuthPort(impl, { sleep: async (ms) => sleeps.push(ms), deadlineMs: 50 });
  assert.deepEqual(await port(async () => 'user_1').verify('jwt'), { userId: 'user_1' });
  await assert.rejects(
    port(async () => {
      throw Object.assign(new Error('x'), { code: 401, type: 'user_jwt_invalid' });
    }).verify('jwt'),
    { code: 'AUTH_EXPIRED' },
  );
  await assert.rejects(
    port(async () => {
      throw Object.assign(new Error('x'), { code: 401, type: 'user_blocked' });
    }).verify('jwt'),
    { code: 'ACCOUNT_BLOCKED' },
  );
  await assert.rejects(
    port(async () => {
      throw new Error('AUTH_REQUIRED');
    }).verify(''),
    { code: 'AUTH_REQUIRED' },
  );
  let attempts = 0;
  await assert.rejects(
    port(async () => {
      attempts++;
      throw Object.assign(new Error('x'), { code: 503 });
    }).verify('jwt'),
    { code: 'AUTH_UNAVAILABLE' },
  );
  assert.equal(attempts, 2);
  let flaky = 0;
  assert.deepEqual(
    await port(async () => {
      if (flaky++ === 0) throw new Error('ECONNRESET');
      return 'u2';
    }).verify('jwt'),
    { userId: 'u2' },
  );
  await assert.rejects(port(() => new Promise(() => {})).verify('jwt'), {
    code: 'AUTH_UNAVAILABLE',
  });
  await assert.rejects(port(async () => '').verify('jwt'), { code: 'AUTH_UNAVAILABLE' });
});

test('hosted handler: env wiring builds auth and keyring; malformed keyring keeps /ready closed', async () => {
  const keys = JSON.stringify([
    { keyId: 'ops', sender: 'maintainer', secretHex: Buffer.alloc(32, 3).toString('hex') },
  ]);
  const env = {
    APPWRITE_FUNCTION_API_ENDPOINT: 'https://example.invalid/v1',
    APPWRITE_FUNCTION_PROJECT_ID: 'p',
    COC_SERVICE_KEYS: keys,
  };
  const handler = createHostedHandler('learning', createDisabledLearningPersistence(), env);
  const unauth = await call(handler, { path: '/v1/courses' });
  assert.deepEqual([unauth.status, unauth.body.error.code], [401, 'AUTH_REQUIRED']);
  const now = Math.floor(Date.now() / 1000);
  const ready = await call(handler, {
    path: '/ready',
    headers: signServiceRequest({
      key: maintainerKey,
      method: 'GET',
      path: '/ready',
      body: '',
      nowSeconds: now,
    }),
  });
  assert.deepEqual([ready.status, ready.body.error.code], [503, 'SERVICE_NOT_CONFIGURED']);
  const broken = createHostedHandler('learning', createDisabledLearningPersistence(), {
    ...env,
    COC_SERVICE_KEYS: '[{"keyId":"short","sender":"maintainer","secretHex":"abcd"}]',
  });
  assert.equal(
    (await call(broken, { path: '/ready', headers: { 'x-service-key-id': 'short' } })).status,
    401,
  );
});
