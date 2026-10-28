// Opt-in dev identity for `pnpm dev:services progress` (COC_DEV_AUTH=1). The adapter is local to
// src/dev.ts; hosted bundles must never contain it.
import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { kit, repoRoot } from './kit.mjs';

function devHandler(env) {
  return kit.createDevHandler(kit.createKeyring([]), env);
}

async function call(handler, method, urlPath, { token, body } = {}) {
  const headers = {};
  if (token !== undefined) headers.authorization = `Bearer ${token}`;
  if (method !== 'GET') headers['idempotency-key'] = randomUUID();
  const bodyText = body === undefined ? undefined : JSON.stringify(body);
  const response = await handler({
    req: {
      method,
      path: urlPath,
      headers,
      ...(bodyText !== undefined ? { bodyText } : {}),
      queryString: '',
    },
    res: { json: (responseBody, status) => ({ status, body: responseBody }) },
  });
  return response;
}

test('dev auth is off by default: private Progress routes fail closed', async () => {
  const { handler } = devHandler({});
  for (const [method, urlPath] of [
    ['GET', '/v1/me'],
    ['POST', '/v1/me/initialize'],
  ]) {
    for (const token of ['dev-alice', 'super-secret', undefined]) {
      const response = await call(handler, method, urlPath, { token });
      assert.equal(response.status, 503, `${method} ${urlPath} token=${token}`);
      assert.equal(response.body.error.code, 'SERVICE_NOT_CONFIGURED');
    }
  }
});

test('COC_DEV_AUTH=1: Bearer dev-<userId> maps the request to that user', async () => {
  const { handler } = devHandler({ COC_DEV_AUTH: '1' });
  const init = await call(handler, 'POST', '/v1/me/initialize', { token: 'dev-alice' });
  assert.equal(init.status, 200);
  assert.equal(init.body.userId, 'alice');
  const me = await call(handler, 'GET', '/v1/me', { token: 'dev-alice' });
  assert.equal(me.status, 200);
  assert.equal(me.body.userId, 'alice');
  const patched = await call(handler, 'PATCH', '/v1/me', {
    token: 'dev-alice',
    body: { nickname: 'Dev Alice', expectedRevision: me.body.revision },
  });
  assert.equal(patched.status, 200);
  assert.equal(patched.body.nickname, 'Dev Alice');
});

test('COC_DEV_AUTH=1: state written as user A is not visible as user B', async () => {
  const { handler, persistence } = devHandler({ COC_DEV_AUTH: '1' });
  assert.equal(
    (await call(handler, 'POST', '/v1/me/initialize', { token: 'dev-alice' })).status,
    200,
  );
  assert.equal(
    (await call(handler, 'POST', '/v1/me/initialize', { token: 'dev-bob' })).status,
    200,
  );
  const aliceInit = await call(handler, 'GET', '/v1/me', { token: 'dev-alice' });
  assert.equal(
    (
      await call(handler, 'PATCH', '/v1/me', {
        token: 'dev-alice',
        body: { nickname: 'Only Alice', expectedRevision: aliceInit.body.revision },
      })
    ).status,
    200,
  );
  const alice = await call(handler, 'GET', '/v1/me', { token: 'dev-alice' });
  const bob = await call(handler, 'GET', '/v1/me', { token: 'dev-bob' });
  assert.deepEqual([alice.status, alice.body.nickname], [200, 'Only Alice']);
  assert.equal(bob.status, 200);
  assert.equal(bob.body.userId, 'bob');
  assert.notEqual(bob.body.nickname, 'Only Alice');
  assert.deepEqual(
    persistence
      .dump('p_profiles')
      .map((item) => item.row.userId)
      .sort(),
    ['alice', 'bob'],
  );
});

test('COC_DEV_AUTH=1: forged or malformed tokens get 401 AUTH_REQUIRED', async () => {
  const { handler } = devHandler({ COC_DEV_AUTH: '1' });
  for (const token of ['super-secret', 'dev-', 'dev_alice', 'dev-alice extra']) {
    const response = await call(handler, 'GET', '/v1/me', { token });
    assert.equal(response.status, 401, token);
    assert.equal(response.body.error.code, 'AUTH_REQUIRED', token);
  }
  const missing = await call(handler, 'GET', '/v1/me');
  assert.deepEqual([missing.status, missing.body.error.code], [401, 'AUTH_REQUIRED']);
});

test('hosted composition never includes the opt-in dev auth adapter', () => {
  const source = fs.readFileSync(path.join(repoRoot, 'services/progress/src/index.ts'), 'utf8');
  assert.equal(/from\s+['"][^'"]*dev\.js['"]/.test(source), false, 'index.ts imports dev');
  assert.equal(source.includes('COC_DEV_AUTH'), false, 'index.ts references COC_DEV_AUTH');
  for (const file of ['function.mjs', 'http.mjs']) {
    const bundle = fs.readFileSync(path.join(repoRoot, 'services/progress/dist', file), 'utf8');
    assert.equal(bundle.includes('COC_DEV_AUTH'), false, `${file} contains COC_DEV_AUTH`);
    assert.equal(bundle.includes('^dev-('), false, `${file} contains the dev token regex`);
  }
});
