// Authorization audit (docs/api/AUTH.md): /health is the only unauthenticated route; every
// Progress business route needs a verified subject; /internal/* and /ready need a signed service
// request from an allowed sender. The route table is read from the real wiring so new routes are
// covered automatically.
import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { kit } from './kit.mjs';

const NOW = Date.parse('2026-10-12T03:00:00.000Z');
const key = (sender, fill) => ({ keyId: `k-${sender}`, sender, secret: Buffer.alloc(32, fill) });
const KEYS = {
  learning: key('learning', 1),
  progress: key('progress', 2),
  ai: key('ai', 3),
  maintainer: key('maintainer', 4),
  scheduler: key('scheduler', 5),
};

function build() {
  const store = kit.createMemoryProgressPersistence(() => NOW, { strictSchema: true });
  const wiring = kit.progressWiring(store, {}, { allowSimulatedCommerce: true });
  const router = kit.scopeProgressHandler(
    kit.createRouter({
      service: 'progress',
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
  return { store, wiring, call };
}

const concrete = (path) => path.replace(/\{[A-Za-z]+\}/g, 'x1');

function sign(sender, method, path, bodyText = '', { query = '', allowedQueryKeys = [] } = {}) {
  return kit.signServiceRequest({
    key: KEYS[sender],
    method,
    path,
    query,
    allowedQueryKeys,
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

test('every Progress business route refuses a request without a verified subject (401 AUTH_REQUIRED)', async () => {
  const { wiring, call } = build();
  const userRoutes = wiring.routes.filter((route) => route.auth === 'user');
  assert.ok(
    userRoutes.length >= 49,
    `expected the Progress business routes, got ${userRoutes.length}`,
  );
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
  const conflict = await call('GET', '/v1/me', {
    headers: { authorization: 'Bearer dev-alice', 'x-appwrite-user-jwt': 'dev-bob' },
  });
  assert.deepEqual([conflict.status, conflict.body.error.code], [401, 'AUTH_REQUIRED']);
});

test('a verified subject passes the guard on every Progress business route (no blanket denial)', async () => {
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

test('every Progress /internal route refuses an unsigned request (401 AUTH_REQUIRED)', async () => {
  const { wiring, call } = build();
  const serviceRoutes = wiring.routes.filter((route) => route.auth === 'service');
  assert.deepEqual(serviceRoutes.map((route) => `${route.method} ${route.path}`).sort(), [
    'POST /internal/billing/notifications',
    'POST /internal/jobs/deletion-purge',
    'POST /internal/jobs/league-settlement',
    'POST /internal/jobs/progress-outbox-relay',
    'POST /internal/jobs/streak-rollover',
  ]);
  for (const route of serviceRoutes) {
    for (const headers of [{}, { 'x-service-key-id': 'k-maintainer' }]) {
      const response = await call(route.method, route.path, { headers });
      assert.deepEqual(
        [response.status, response.body.error.code],
        [401, 'AUTH_REQUIRED'],
        `${route.method} ${route.path} ${JSON.stringify(headers)}`,
      );
    }
  }
});

test('Progress /internal routes refuse a signer that is not an allowed sender (403 FORBIDDEN)', async () => {
  const { call } = build();
  const notification = {
    notificationId: 'n1',
    purchaseId: 'p1',
    platform: 'SIMULATION',
    state: 'ACTIVE',
    occurredAt: new Date(NOW).toISOString(),
  };
  const bodyText = JSON.stringify(notification);
  const billing = await call('POST', '/internal/billing/notifications', {
    headers: sign('learning', 'POST', '/internal/billing/notifications', bodyText),
    body: bodyText,
  });
  assert.deepEqual([billing.status, billing.body.error.code], [403, 'FORBIDDEN']);

  const tick = JSON.stringify({ tickId: randomUUID(), scheduledAt: new Date(NOW).toISOString() });
  for (const job of [
    'streak-rollover',
    'league-settlement',
    'deletion-purge',
    'progress-outbox-relay',
  ]) {
    const path = `/internal/jobs/${job}`;
    const response = await call('POST', path, {
      headers: sign('learning', 'POST', path, tick),
      body: tick,
    });
    assert.deepEqual([response.status, response.body.error.code], [403, 'FORBIDDEN'], path);
  }
});

test('Progress /internal routes accept an allowed sender', async () => {
  const { call } = build();
  const notification = {
    notificationId: 'n1',
    purchaseId: 'p1',
    platform: 'SIMULATION',
    state: 'ACTIVE',
    occurredAt: new Date(NOW).toISOString(),
  };
  const bodyText = JSON.stringify(notification);
  const billing = await call('POST', '/internal/billing/notifications', {
    headers: sign('maintainer', 'POST', '/internal/billing/notifications', bodyText),
    body: bodyText,
  });
  assert.equal(billing.status, 404, 'unknown purchase: HMAC and sender allowlist passed');

  for (const job of [
    'streak-rollover',
    'league-settlement',
    'deletion-purge',
    'progress-outbox-relay',
  ]) {
    const path = `/internal/jobs/${job}`;
    const tick = JSON.stringify({ tickId: randomUUID(), scheduledAt: new Date(NOW).toISOString() });
    const response = await call('POST', path, {
      headers: sign('scheduler', 'POST', path, tick),
      body: tick,
    });
    assert.equal(
      response.status === 200 || response.body?.error?.code === 'SERVICE_NOT_CONFIGURED',
      true,
      `${path}: ${JSON.stringify(response.body)}`,
    );
  }
});

test('/ready is maintainer/internal-only and /internal/events needs an allowed sender', async () => {
  const { call } = build();
  const unsigned = await call('GET', '/ready');
  assert.deepEqual([unsigned.status, unsigned.body.error.code], [401, 'AUTH_REQUIRED']);
  const scheduler = await call('GET', '/ready', { headers: sign('scheduler', 'GET', '/ready') });
  assert.equal(scheduler.status, 403, 'the scheduler key cannot probe readiness');
  const maintainer = await call('GET', '/ready', { headers: sign('maintainer', 'GET', '/ready') });
  assert.equal(maintainer.status, 503, 'memory is never admitted in local-test');

  const event = JSON.stringify({});
  const unsignedEvent = await call('POST', '/internal/events', { body: event });
  assert.deepEqual([unsignedEvent.status, unsignedEvent.body.error.code], [401, 'AUTH_REQUIRED']);
  const foreignEvent = await call('POST', '/internal/events', {
    headers: sign('scheduler', 'POST', '/internal/events', event),
    body: event,
  });
  assert.deepEqual([foreignEvent.status, foreignEvent.body.error.code], [403, 'FORBIDDEN']);
  const learningEvent = await call('POST', '/internal/events', {
    headers: sign('learning', 'POST', '/internal/events', event),
    body: event,
  });
  assert.equal(learningEvent.status, 400, 'allowed sender reaches envelope validation');
});
