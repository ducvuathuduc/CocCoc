// Offline tests for the per-service Appwrite operations declaration (no network).
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { test } from 'node:test';
import { fileURLToPath, pathToFileURL } from 'node:url';
import {
  KEYRING_SENDERS,
  SERVICES,
  diffVariables,
  generateKeyrings,
  isCron,
  validateOps,
} from '../scripts/ops-lib.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');
const load = () => ({
  config: JSON.parse(read('appwrite/appwrite.config.json')),
  ops: JSON.parse(read('appwrite/ops/project.json')),
});
const context = {
  descriptors: Object.fromEntries(
    SERVICES.map((s) => [s, JSON.parse(read(`services/${s}/appwrite-function.json`))]),
  ),
  mobileIds: {
    android: read('apps/mobile/android/app/build.gradle.kts').match(
      /applicationId\s*=\s*"([^"]+)"/,
    )[1],
    apple: 'com.cocenglish.cocenglish',
  },
};

test('committed declaration is valid and has one function per service', () => {
  const { config, ops } = load();
  assert.deepEqual(validateOps(config, ops, context), []);
  assert.deepEqual(config.functions.map((f) => f.$id).sort(), [
    'coc-ai',
    'coc-learning',
    'coc-progress',
  ]);
  for (const fn of config.functions) assert.equal(fn.runtime, 'node-22');
});

test('validation rejects unsafe or drifting declarations', () => {
  const cases = [
    [(c) => (c.config.functions[0].execute = ['users']), /execute must be/],
    [
      (c) => c.config.functions.find((f) => f.$id === 'coc-learning').scopes.push('users.write'),
      /scopes beyond learning/,
    ],
    [
      (c) => c.config.functions.find((f) => f.$id === 'coc-ai').scopes.push('tables.write'),
      /scopes beyond ai/,
    ],
    [(c) => (c.ops.functions['coc-ai'].variables.GEMINI_API_KEY = 'x'), /looks secret/],
    [
      (c) => (c.ops.functions['coc-ai'].variables.COC_GEMINI_ENABLED = 'true'),
      /Gemini must stay disabled/,
    ],
    [(c) => (c.ops.functions['coc-learning'].variables.COC_X = 'a'.repeat(64)), /key material/],
    [(c) => (c.ops.schedules[0].status = 'active'), /schedule must equal/],
    [(c) => (c.ops.auth.methods.anonymous = true), /anonymous must be off/],
    [(c) => (c.ops.auth.policies['password-strength'].min = 8), /password-strength/],
    [(c) => (c.ops.platforms[0].applicationId = 'com.example.other'), /differs from apps\/mobile/],
    [(c) => (c.ops.functions['coc-progress'].keyringSenders = ['progress']), /keyringSenders/],
    [(c) => (c.config.functions[1].path = '../services/progress/src'), /path must be/],
  ];
  for (const [mutate, pattern] of cases) {
    const c = load();
    mutate(c);
    const problems = validateOps(c.config, c.ops, context);
    assert.ok(
      problems.some((p) => pattern.test(p)),
      `${pattern} not in ${JSON.stringify(problems)}`,
    );
  }
});

test('cron syntax check', () => {
  assert.ok(isCron('* * * * *'));
  assert.ok(isCron('15 0 * * 1'));
  assert.ok(!isCron('every minute'));
  assert.ok(!isCron('* * * *'));
});

test('generated keyrings give each function only the senders it verifies', () => {
  const { ops } = load();
  let n = 0;
  const rings = generateKeyrings(ops, new Date('2026-10-12T00:00:00Z'), (size) =>
    Buffer.alloc(size, ++n),
  );
  const secretBySender = {};
  for (const [functionId, raw] of Object.entries(rings)) {
    const ring = JSON.parse(raw);
    const service = functionId.replace('coc-', '');
    assert.deepEqual(
      ring.map((k) => k.sender),
      KEYRING_SENDERS[service],
    );
    for (const key of ring) {
      assert.match(key.secretHex, /^[0-9a-f]{64}$/);
      assert.match(key.keyId, /^[a-z]+-20261012-[0-9a-f]{6}$/);
      secretBySender[key.sender] ??= key.secretHex;
      assert.equal(
        secretBySender[key.sender],
        key.secretHex,
        'one secret per sender across receivers',
      );
    }
  }
  assert.equal(new Set(Object.values(secretBySender)).size, 3);
});

test('variable diff never surfaces secret values', () => {
  const { ops } = load();
  const decl = ops.functions['coc-learning'];
  const live = [
    ...Object.entries(decl.variables).map(([key, value]) => ({ key, value, secret: false })),
    { key: 'COC_SERVICE_KEYS', value: '', secret: true },
    { key: 'BUILD_ID', value: 'abc', secret: false },
  ];
  assert.deepEqual(diffVariables(decl, live), { missing: [], drift: [], extra: [] });
  const leaked = diffVariables(
    decl,
    live.map((v) =>
      v.key === 'COC_SERVICE_KEYS' ? { ...v, secret: false, value: 'deadbeef' } : v,
    ),
  );
  assert.equal(leaked.drift[0].key, 'COC_SERVICE_KEYS');
  assert.ok(!JSON.stringify(leaked).includes('deadbeef'));
});

test('runtime adapter tolerates Appwrite lazy getters and passes a plain request', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'coc-adapter-'));
  fs.copyFileSync(path.join(root, 'appwrite/runtime/main.mjs'), path.join(dir, 'main.mjs'));
  fs.writeFileSync(
    path.join(dir, 'function.mjs'),
    'export default async (ctx) => ctx.res.json({ ...ctx.req });\n',
  );
  const { default: main } = await import(pathToFileURL(path.join(dir, 'main.mjs')).href);
  const req = {
    method: 'GET',
    path: '/health',
    headers: { 'x-request-id': 'r1' },
    bodyText: '',
    queryString: '',
  };
  Object.defineProperty(req, 'bodyJson', { enumerable: true, get: () => JSON.parse('') });
  const seen = await main({ req, res: { json: (body) => body }, log() {}, error() {} });
  assert.equal(seen.path, '/health');
  assert.equal(seen.bodyText, '');
  assert.equal(seen.headers['x-request-id'], 'r1');
  assert.ok(!('bodyJson' in seen));
});
