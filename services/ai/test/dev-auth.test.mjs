// Opt-in dev identity for `pnpm dev:services ai` (COC_DEV_AUTH=1). The adapter is local to
// src/dev.ts; hosted bundles must never contain it.
import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { kit, repoRoot } from './kit.mjs';

const progressKey = { keyId: 'p-to-ai', sender: 'progress', secret: Buffer.alloc(32, 4) };

function devHandler(env) {
  return kit.createDevHandler(kit.createKeyring([progressKey]), env);
}

async function call(handler, method, urlPath, { token, body, idem } = {}) {
  const headers = {};
  if (token !== undefined) headers.authorization = `Bearer ${token}`;
  if (idem) headers['idempotency-key'] = idem;
  const bodyText = body === undefined ? undefined : JSON.stringify(body);
  return handler({
    req: {
      method,
      path: urlPath,
      headers,
      ...(bodyText !== undefined ? { bodyText } : {}),
      queryString: '',
    },
    res: { json: (responseBody, status) => ({ status, body: responseBody }) },
  });
}

async function grant(handler, userId, entitlementRevision = 1) {
  const eventId = randomUUID();
  const envelope = {
    eventId,
    type: 'entitlement.changed.v1',
    schemaVersion: 1,
    producer: 'progress',
    aggregateId: userId,
    occurredAt: new Date().toISOString(),
    requestId: eventId,
    payload: {
      userId,
      plan: 'MAX',
      status: 'ACTIVE',
      expiresAt: null,
      entitlementRevision,
    },
  };
  const bodyText = JSON.stringify(envelope);
  const headers = kit.signServiceRequest({
    key: progressKey,
    method: 'POST',
    path: '/internal/events',
    body: bodyText,
    nowSeconds: Math.floor(Date.now() / 1000),
  });
  const response = await handler({
    req: { method: 'POST', path: '/internal/events', headers, bodyText },
    res: { json: (responseBody, status) => ({ status, body: responseBody }) },
  });
  assert.equal(response.status, 200, JSON.stringify(response));
  return response;
}

const startBody = {
  kind: 'ROLEPLAY',
  courseId: 'vi_en',
  scenarioId: 'rp_cafe_order',
  voiceSessionId: null,
};

test('dev auth is off by default: private AI routes fail closed', async () => {
  const { handler } = devHandler({});
  for (const [method, urlPath] of [
    ['GET', '/v1/ai/capabilities'],
    ['GET', '/v1/conversations'],
    ['POST', '/v1/conversations'],
  ]) {
    for (const token of ['dev-alice', 'super-secret', undefined]) {
      const response = await call(handler, method, urlPath, {
        token,
        ...(method === 'POST' ? { body: startBody, idem: randomUUID() } : {}),
      });
      assert.equal(response.status, 503, `${method} ${urlPath} token=${token}`);
      assert.equal(response.body.error.code, 'SERVICE_NOT_CONFIGURED');
    }
  }
});

test('COC_DEV_AUTH=1: Bearer dev-<userId> reads capabilities and lists that user', async () => {
  const { handler } = devHandler({ COC_DEV_AUTH: '1' });
  const capabilities = await call(handler, 'GET', '/v1/ai/capabilities', {
    token: 'dev-alice',
  });
  assert.equal(capabilities.status, 200);
  assert.equal(capabilities.body.textTutor, true);
  await grant(handler, 'alice');
  const started = await call(handler, 'POST', '/v1/conversations', {
    token: 'dev-alice',
    idem: randomUUID(),
    body: startBody,
  });
  assert.equal(started.status, 200);
  const list = await call(handler, 'GET', '/v1/conversations', { token: 'dev-alice' });
  assert.equal(list.status, 200);
  assert.deepEqual(
    list.body.items.map((item) => item.conversationId),
    [started.body.conversationId],
  );
});

test('COC_DEV_AUTH=1: conversations are isolated per dev-<userId>', async () => {
  const { handler, persistence } = devHandler({ COC_DEV_AUTH: '1' });
  await grant(handler, 'alice');
  await grant(handler, 'bob');
  const aliceStart = await call(handler, 'POST', '/v1/conversations', {
    token: 'dev-alice',
    idem: randomUUID(),
    body: startBody,
  });
  assert.equal(aliceStart.status, 200);
  const bobList = await call(handler, 'GET', '/v1/conversations', { token: 'dev-bob' });
  assert.equal(bobList.status, 200);
  assert.equal(bobList.body.items.length, 0);
  const bobStart = await call(handler, 'POST', '/v1/conversations', {
    token: 'dev-bob',
    idem: randomUUID(),
    body: startBody,
  });
  assert.equal(bobStart.status, 200);
  const aliceList = await call(handler, 'GET', '/v1/conversations', { token: 'dev-alice' });
  assert.deepEqual(
    aliceList.body.items.map((item) => item.conversationId),
    [aliceStart.body.conversationId],
  );
  assert.deepEqual(
    persistence
      .dump('a_conversations')
      .map((item) => item.row.userId)
      .sort(),
    ['alice', 'bob'],
  );
});

test('COC_DEV_AUTH=1: forged or malformed tokens get 401 AUTH_REQUIRED', async () => {
  const { handler } = devHandler({ COC_DEV_AUTH: '1' });
  for (const token of ['super-secret', 'dev-', 'dev_alice', 'dev-alice extra']) {
    const response = await call(handler, 'GET', '/v1/ai/capabilities', { token });
    assert.equal(response.status, 401, token);
    assert.equal(response.body.error.code, 'AUTH_REQUIRED', token);
  }
  const missing = await call(handler, 'GET', '/v1/ai/capabilities');
  assert.deepEqual([missing.status, missing.body.error.code], [401, 'AUTH_REQUIRED']);
});

test('hosted composition never includes the opt-in dev auth adapter', () => {
  const source = fs.readFileSync(path.join(repoRoot, 'services/ai/src/index.ts'), 'utf8');
  assert.equal(/from\s+['"][^'"]*dev\.js['"]/.test(source), false, 'index.ts imports dev');
  assert.equal(source.includes('COC_DEV_AUTH'), false, 'index.ts references COC_DEV_AUTH');
  for (const file of ['function.mjs', 'http.mjs']) {
    const bundle = fs.readFileSync(path.join(repoRoot, 'services/ai/dist', file), 'utf8');
    assert.equal(bundle.includes('COC_DEV_AUTH'), false, `${file} contains COC_DEV_AUTH`);
    assert.equal(bundle.includes('^dev-('), false, `${file} contains the dev token regex`);
  }
});
