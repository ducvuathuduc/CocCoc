// Authorization audit (docs/api/AUTH.md): /health is the only unauthenticated route; every AI
// business route needs a verified subject; /internal/events and /ready need a signed service
// request from an allowed sender. The route table is read from the real wiring so new routes are
// covered automatically.
import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { kit } from './kit.mjs';

const NOW = Date.parse('2026-10-12T03:00:00Z');
const key = (sender, fill) => ({ keyId: `k-${sender}`, sender, secret: Buffer.alloc(32, fill) });
const KEYS = {
  learning: key('learning', 1),
  progress: key('progress', 2),
  ai: key('ai', 3),
  maintainer: key('maintainer', 4),
  scheduler: key('scheduler', 5),
};

function build() {
  const store = kit.createMemoryAiPersistence(() => NOW);
  const deps = {
    persistence: store,
    nowMs: () => NOW,
    newId: randomUUID,
    gates: kit.DEFAULT_GATES,
    provider: kit.SCRIPTED_PROVIDER,
  };
  const wiring = kit.aiWiring(deps);
  const router = kit.aiHandler(
    kit.createRouter({
      service: 'ai',
      persistence: store,
      mode: 'local-test',
      auth: kit.devAuth,
      keyring: kit.createKeyring(Object.values(KEYS)),
      routes: wiring.routes,
      eventConsumer: wiring.eventConsumer,
      nowMs: () => NOW,
    }),
  );
  async function call(method, path, { headers = {}, body, query = '' } = {}) {
    const bodyText =
      body === undefined ? undefined : typeof body === 'string' ? body : JSON.stringify(body);
    let result;
    await router({
      req: {
        method,
        path,
        headers,
        ...(bodyText !== undefined ? { bodyText } : {}),
        queryString: query,
      },
      res: { json: (b, status) => (result = { status, body: b }) },
    });
    return result;
  }
  return { store, deps, wiring, call };
}

const concrete = (path) => path.replace(/\{[A-Za-z]+\}/g, 'x1');

function sign(sender, method, path, bodyText = '') {
  return kit.signServiceRequest({
    key: KEYS[sender],
    method,
    path,
    body: bodyText,
    nowSeconds: Math.floor(NOW / 1000),
  });
}

test('GET /health is the only public route: no credential, and even a forged one, still answers', async () => {
  const { call } = build();
  for (const headers of [{}, { authorization: 'Bearer forged' }]) {
    const response = await call('GET', '/health', { headers });
    assert.equal(response.status, 200);
    assert.equal(response.body.status, 'degraded');
  }
});

test('every AI business route refuses a request without a verified subject (401 AUTH_REQUIRED)', async () => {
  const { wiring, call } = build();
  const userRoutes = wiring.routes.filter((route) => route.auth === 'user');
  assert.ok(userRoutes.length >= 11, `expected the AI business routes, got ${userRoutes.length}`);
  for (const route of userRoutes) {
    const path = concrete(route.path);
    const missing = await call(route.method, path);
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
      const response = await call(route.method, path, { headers });
      assert.deepEqual(
        [response.status, response.body.error.code],
        [401, 'AUTH_REQUIRED'],
        `${route.method} ${path} ${JSON.stringify(headers)}`,
      );
    }
  }
  const conflict = await call('GET', '/v1/ai/capabilities', {
    headers: { authorization: 'Bearer dev-alice', 'x-appwrite-user-jwt': 'dev-bob' },
  });
  assert.deepEqual([conflict.status, conflict.body.error.code], [401, 'AUTH_REQUIRED']);
});

test('a verified subject passes the guard on every AI business route (no blanket denial)', async () => {
  const { wiring, call } = build();
  for (const route of wiring.routes.filter((entry) => entry.auth === 'user')) {
    const response = await call(route.method, concrete(route.path), {
      headers: { authorization: 'Bearer dev-probe', 'idempotency-key': randomUUID() },
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

test('/internal/events refuses an unsigned request and a sender outside the allowlist', async () => {
  const { call } = build();
  const event = JSON.stringify({});
  const unsigned = await call('POST', '/internal/events', { body: event });
  assert.deepEqual([unsigned.status, unsigned.body.error.code], [401, 'AUTH_REQUIRED']);
  const foreign = await call('POST', '/internal/events', {
    headers: sign('learning', 'POST', '/internal/events', event),
    body: event,
  });
  assert.deepEqual([foreign.status, foreign.body.error.code], [403, 'FORBIDDEN']);
  const progress = await call('POST', '/internal/events', {
    headers: sign('progress', 'POST', '/internal/events', event),
    body: event,
  });
  assert.equal(progress.status, 400, 'allowed sender reaches envelope validation');
});

test('/ready is maintainer/internal-only', async () => {
  const { call } = build();
  const unsigned = await call('GET', '/ready');
  assert.deepEqual([unsigned.status, unsigned.body.error.code], [401, 'AUTH_REQUIRED']);
  const scheduler = await call('GET', '/ready', { headers: sign('scheduler', 'GET', '/ready') });
  assert.equal(scheduler.status, 403, 'the scheduler key cannot probe readiness');
  const maintainer = await call('GET', '/ready', { headers: sign('maintainer', 'GET', '/ready') });
  assert.equal(maintainer.status, 503, 'memory is never admitted in local-test');
});

test('identity comes only from the verified subject: a body userId is rejected, never honored', async () => {
  const { store, call } = build();
  const forged = await call('POST', '/v1/tutor', {
    headers: { authorization: 'Bearer dev-alice', 'idempotency-key': randomUUID() },
    body: {
      userId: 'bob',
      requestId: randomUUID(),
      learnerText: 'hello',
      level: 'A1',
      locale: 'en-US',
      feedbackLocale: 'vi-VN',
    },
  });
  assert.equal(forged.status, 400);
  assert.equal(forged.body.error.code, 'VALIDATION_ERROR');
  assert.equal(forged.body.error.details.field, 'body.userId');
  assert.equal(store.dump('a_conversations').length, 0);
});
