import test from 'node:test';
import assert from 'node:assert/strict';
import {
  assertLocalKeys,
  validLocalReceipt,
  ensureLocalKey,
} from '../scripts/local-appwrite-lib.mjs';

test('partial bootstrap cannot admit any service', () => {
  assert.throws(() => assertLocalKeys({ setup: 'key', learning: 'key' }), /INCOMPLETE_LOCAL_KEYS/);
  assert.throws(
    () => assertLocalKeys({ setup: 'key', learning: 'key', progress: 'undefined', ai: 'key' }),
    /INCOMPLETE_LOCAL_KEYS/,
  );
  assert.doesNotThrow(() =>
    assertLocalKeys({ setup: 'key', learning: 'key', progress: 'key', ai: 'key' }),
  );
});

test('admission requires a current, complete, successful evidence fingerprint', () => {
  const expected = {
    endpoint: 'https://127.0.0.1:8443/v1',
    project: 'cocenglish-local',
    fingerprint: 'current',
  };
  const receipt = { ...expected, at: 1000, status: 'passed' };
  assert.equal(validLocalReceipt(receipt, expected, 2000), true);
  for (const change of [
    { at: undefined },
    { at: NaN },
    { at: Infinity },
    { at: 2001 },
    { at: -1 },
    { fingerprint: 'old' },
    { status: 'running' },
    { endpoint: 'https://cloud.example/v1' },
  ]) {
    assert.equal(validLocalReceipt({ ...receipt, ...change }, expected, 2000), false);
  }
  assert.equal(validLocalReceipt(receipt, expected, 3_601_001), false);
});

test('a remote key created before a local crash is recovered on rerun without rotation', async () => {
  let remote;
  let creates = 0;
  const request = async (method, route, body) => {
    if (method === 'GET') return { response: { status: remote ? 200 : 404 }, data: remote ?? {} };
    if (method === 'POST') {
      creates++;
      remote = { secret: 'recovered-local-secret', ...body };
      return { response: { status: 201 }, data: remote };
    }
    if (method === 'PUT') return { response: { status: 200 }, data: { ...remote, ...body } };
    throw new Error('unexpected mutation');
  };
  const input = {
    request,
    project: 'cocenglish-local',
    owner: 'learning',
    headers: {},
    scopes: ['rows.read'],
  };
  await ensureLocalKey(input); // Imagine a process crash before its secret is saved locally.
  assert.equal(await ensureLocalKey(input), 'recovered-local-secret');
  assert.equal(creates, 1);
});
