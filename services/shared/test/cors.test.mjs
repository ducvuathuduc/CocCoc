import test from 'node:test';
import assert from 'node:assert/strict';
import { createHttpRuntime } from '../../../.cache/backend-fixtures/runtime-http.mjs';
import {
  DEFAULT_CORS_ORIGINS,
  ServiceError,
  corsOriginsFromEnv,
  corsResponseHeaders,
  createDisabledProgressPersistence,
  createHostedHandler,
  createMemoryLearningPersistence,
  createRouter,
} from '../../../.cache/backend-fixtures/foundation-testkit.mjs';

const ALLOWED = 'http://127.0.0.1:8087';

function fakeAuth() {
  const calls = [];
  return {
    calls,
    async verify(jwt) {
      calls.push(jwt);
      if (jwt !== 'jwt-alice') throw new ServiceError('AUTH_REQUIRED');
      return { userId: 'alice' };
    },
  };
}

function makeRouter(overrides = {}) {
  const auth = fakeAuth();
  const handler = createRouter({
    service: 'learning',
    persistence: createMemoryLearningPersistence(),
    mode: 'local-test',
    auth,
    routes: [
      {
        method: 'GET',
        path: '/v1/me',
        auth: 'user',
        async handle(ctx) {
          return { status: 200, body: { userId: ctx.subject.userId } };
        },
      },
    ],
    ...overrides,
  });
  return { handler, auth };
}

function call(handler, { method = 'GET', path: p = '/health', headers = {}, body } = {}) {
  return handler({
    req: { method, path: p, headers, bodyText: body, queryString: '' },
    res: { json: (b, status, h) => ({ body: b, status, headers: h }) },
  });
}

test('OPTIONS preflight answers 204 with the echoed origin and allowed surface, before auth', async () => {
  const { handler, auth } = makeRouter();
  const result = await call(handler, {
    method: 'OPTIONS',
    path: '/v1/me',
    headers: { origin: ALLOWED, 'access-control-request-method': 'GET' },
  });
  assert.equal(result.status, 204);
  assert.equal(result.body, undefined);
  assert.equal(result.headers['Access-Control-Allow-Origin'], ALLOWED);
  assert.equal(result.headers['Access-Control-Allow-Methods'], 'GET, POST, PATCH, DELETE, OPTIONS');
  const allowedHeaders = result.headers['Access-Control-Allow-Headers'].split(', ');
  for (const name of [
    'authorization',
    'content-type',
    'idempotency-key',
    'x-appwrite-user-jwt',
    'x-service-key-id',
    'x-service-timestamp',
    'x-service-signature',
  ]) {
    assert.ok(allowedHeaders.includes(name), name);
  }
  assert.equal(result.headers['Access-Control-Max-Age'], '600');
  assert.equal(result.headers['Access-Control-Allow-Credentials'], 'true');
  assert.equal(result.headers.Vary, 'Origin');
  assert.equal(auth.calls.length, 0);

  // Preflight is answered before route lookup: an unknown path still gets 204.
  const unknown = await call(handler, { method: 'OPTIONS', path: '/v1/nowhere' });
  assert.equal(unknown.status, 204);
});

test('a disallowed origin gets no allow-origin header (browser blocks the call)', async () => {
  const { handler } = makeRouter();
  const result = await call(handler, {
    method: 'OPTIONS',
    path: '/v1/me',
    headers: { origin: 'https://evil.example' },
  });
  assert.equal(result.status, 204);
  assert.equal(result.headers['Access-Control-Allow-Origin'], undefined);
  assert.equal(result.headers['Access-Control-Allow-Credentials'], undefined);
  assert.equal(result.headers.Vary, 'Origin');
});

test('normal GET from an allowed origin carries the CORS headers on success and errors', async () => {
  const { handler } = makeRouter();
  const ok = await call(handler, {
    path: '/v1/me',
    headers: { authorization: 'Bearer jwt-alice', origin: ALLOWED },
  });
  assert.equal(ok.status, 200);
  assert.equal(ok.body.userId, 'alice');
  assert.equal(ok.headers['Access-Control-Allow-Origin'], ALLOWED);
  assert.equal(ok.headers['Access-Control-Allow-Credentials'], 'true');

  const unauthorized = await call(handler, { path: '/v1/me', headers: { origin: ALLOWED } });
  assert.equal(unauthorized.status, 401);
  assert.equal(unauthorized.body.error.code, 'AUTH_REQUIRED');
  assert.equal(unauthorized.headers['Access-Control-Allow-Origin'], ALLOWED);

  const missing = await call(handler, {
    path: '/v1/missing',
    headers: { authorization: 'Bearer jwt-alice', origin: ALLOWED },
  });
  assert.equal(missing.status, 404);
  assert.equal(missing.headers['Access-Control-Allow-Origin'], ALLOWED);
});

test('never pairs a wildcard origin with credentials', async () => {
  const { handler } = makeRouter();
  for (const origin of [ALLOWED, 'http://localhost:8087', 'https://evil.example', undefined]) {
    const result = await call(handler, {
      path: '/v1/me',
      headers: origin ? { authorization: 'Bearer jwt-alice', origin } : {},
    });
    const allowOrigin = result.headers['Access-Control-Allow-Origin'];
    assert.notEqual(allowOrigin, '*');
    if (result.headers['Access-Control-Allow-Credentials'] === 'true') {
      assert.ok(allowOrigin, 'credentials require an echoed origin');
    }
  }
});

test('COC_CORS_ALLOWED_ORIGINS replaces the default allow-list; blank keeps the default', () => {
  assert.deepEqual(corsOriginsFromEnv(undefined), DEFAULT_CORS_ORIGINS);
  assert.deepEqual(corsOriginsFromEnv('   '), DEFAULT_CORS_ORIGINS);
  assert.deepEqual(corsOriginsFromEnv(' https://a.example , https://b.example '), [
    'https://a.example',
    'https://b.example',
  ]);
});

test('corsResponseHeaders echoes an exact origin only', () => {
  const allowed = ['https://a.example'];
  const headers = corsResponseHeaders('https://a.example', allowed);
  assert.equal(headers['Access-Control-Allow-Origin'], 'https://a.example');
  assert.equal(headers['Access-Control-Allow-Credentials'], 'true');
  assert.equal(headers.Vary, 'Origin');
  assert.deepEqual(corsResponseHeaders('https://a.example/', allowed), { Vary: 'Origin' });
  assert.deepEqual(corsResponseHeaders('https://a.example.evil.test', allowed), {
    Vary: 'Origin',
  });
  assert.deepEqual(corsResponseHeaders(undefined, allowed), { Vary: 'Origin' });
});

test('hosted handler takes the allow-list from COC_CORS_ALLOWED_ORIGINS', async () => {
  const hosted = createHostedHandler('progress', createDisabledProgressPersistence(), {
    COC_CORS_ALLOWED_ORIGINS: 'https://web.example.test',
  });
  const configured = await call(hosted, {
    method: 'OPTIONS',
    path: '/v1/me',
    headers: { origin: 'https://web.example.test' },
  });
  assert.equal(configured.status, 204);
  assert.equal(configured.headers['Access-Control-Allow-Origin'], 'https://web.example.test');

  const localDefault = await call(hosted, {
    method: 'OPTIONS',
    path: '/v1/me',
    headers: { origin: ALLOWED },
  });
  assert.equal(localDefault.headers['Access-Control-Allow-Origin'], undefined);

  const unset = createHostedHandler('progress', createDisabledProgressPersistence(), {});
  const devDefault = await call(unset, {
    method: 'OPTIONS',
    path: '/v1/me',
    headers: { origin: ALLOWED },
  });
  assert.equal(devDefault.headers['Access-Control-Allow-Origin'], ALLOWED);
});

test('native HTTP layer emits the CORS headers over the wire', async (t) => {
  const { handler } = makeRouter();
  const runtime = createHttpRuntime(handler, { service: 'learning', port: 0 });
  const address = await runtime.listen();
  t.after(() => runtime.close());
  const base = `http://127.0.0.1:${address.port}`;

  const preflight = await fetch(`${base}/v1/me`, {
    method: 'OPTIONS',
    headers: { origin: ALLOWED, 'access-control-request-method': 'GET' },
  });
  assert.equal(preflight.status, 204);
  assert.equal(preflight.headers.get('access-control-allow-origin'), ALLOWED);
  assert.equal(preflight.headers.get('access-control-allow-credentials'), 'true');

  const ok = await fetch(`${base}/v1/me`, {
    headers: { authorization: 'Bearer jwt-alice', origin: ALLOWED },
  });
  assert.equal(ok.status, 200);
  assert.equal(ok.headers.get('access-control-allow-origin'), ALLOWED);

  const blocked = await fetch(`${base}/health`, { headers: { origin: 'https://evil.example' } });
  assert.equal(blocked.status, 200);
  assert.equal(blocked.headers.has('access-control-allow-origin'), false);
});

test('runtime-generated error envelopes also carry the CORS headers', async (t) => {
  const runtime = createHttpRuntime(
    async () => {
      throw new ServiceError('INTERNAL_ERROR');
    },
    { service: 'learning', port: 0 },
  );
  const address = await runtime.listen();
  t.after(() => runtime.close());
  const response = await fetch(`http://127.0.0.1:${address.port}/v1/me`, {
    headers: { origin: ALLOWED },
  });
  assert.equal(response.status, 500);
  assert.equal(response.headers.get('access-control-allow-origin'), ALLOWED);
  const body = await response.json();
  assert.equal(body.error.code, 'INTERNAL_ERROR');
});
