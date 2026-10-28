// Opt-in dev identity for `pnpm dev:services` (COC_DEV_AUTH=1). The adapter is local to
// src/dev.ts; hosted bundles must never contain it.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { loadKit, root } from './helpers/kit.mjs';

const kit = await loadKit('dev-auth');
const keyring = kit.createKeyring([]);

function devHandler(env) {
  return kit.createDevHandler(keyring, env).handler;
}

async function call(handler, method, urlPath, { token } = {}) {
  const headers = {};
  if (token !== undefined) headers.authorization = `Bearer ${token}`;
  const response = await handler({
    req: { method, path: urlPath, headers, queryString: '' },
    res: { json: (body, status) => ({ status, body }) },
  });
  return response;
}

test('dev auth is off by default: private Learning routes fail closed', async () => {
  const handler = devHandler({});
  for (const token of ['dev-alice', 'super-secret', undefined]) {
    const response = await call(handler, 'GET', '/v1/courses', { token });
    assert.equal(response.status, 503, `token=${token}`);
    assert.equal(response.body.error.code, 'SERVICE_NOT_CONFIGURED');
  }
});

test('COC_DEV_AUTH=1: Bearer dev-<userId> reaches user routes', async () => {
  const handler = devHandler({ COC_DEV_AUTH: '1' });
  const courses = await call(handler, 'GET', '/v1/courses', { token: 'dev-alice' });
  assert.equal(courses.status, 200);
  assert.ok(Array.isArray(courses.body.items));

  assert.deepEqual(await kit.devAuth.verify('dev-alice'), { userId: 'alice' });
});

test('COC_DEV_AUTH=1: forged or malformed tokens get 401 AUTH_REQUIRED', async () => {
  const handler = devHandler({ COC_DEV_AUTH: '1' });
  for (const token of ['super-secret', 'dev-', 'dev_alice', 'dev-alice extra']) {
    const response = await call(handler, 'GET', '/v1/courses', { token });
    assert.equal(response.status, 401, token);
    assert.equal(response.body.error.code, 'AUTH_REQUIRED', token);
  }
  const missing = await call(handler, 'GET', '/v1/courses');
  assert.deepEqual([missing.status, missing.body.error.code], [401, 'AUTH_REQUIRED']);
  await assert.rejects(() => kit.devAuth.verify('forged'), { code: 'AUTH_REQUIRED' });
});

test('hosted composition never includes the opt-in dev auth adapter', () => {
  const source = fs.readFileSync(path.join(root, 'services/learning/src/index.ts'), 'utf8');
  assert.equal(/from\s+['"][^'"]*dev\.js['"]/.test(source), false, 'index.ts imports dev');
  assert.equal(source.includes('COC_DEV_AUTH'), false, 'index.ts references COC_DEV_AUTH');
  for (const file of ['function.mjs', 'http.mjs', 'worker.mjs']) {
    const bundle = fs.readFileSync(path.join(root, 'services/learning/dist', file), 'utf8');
    assert.equal(bundle.includes('COC_DEV_AUTH'), false, `${file} contains COC_DEV_AUTH`);
    assert.equal(bundle.includes('^dev-('), false, `${file} contains the dev token regex`);
  }
});
