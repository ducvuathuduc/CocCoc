import test from 'node:test';
import assert from 'node:assert/strict';
import { disposableRuntimeEnv } from '../scripts/runtime-test-env.mjs';

test('local smoke children cannot inherit server credentials or admission', () => {
  const source = {
    PATH: '/bin',
    SystemRoot: 'C:\\Windows',
    APPWRITE_API_KEY: 'fake-private',
    COC_LEARNING_ADMITTED: 'reviewed-cloud-gate',
    COC_AI_PROVIDER: 'speech',
    GEMINI_API_KEY: 'fake-provider',
    NODE_OPTIONS: '--inspect',
    UNRELATED_SECRET: 'fake-other',
  };
  const env = disposableRuntimeEnv({ PORT: '4200' }, source);
  assert.equal(env.PATH, '/bin');
  assert.equal(env.SystemRoot, 'C:\\Windows');
  assert.equal(env.PORT, '4200');
  for (const name of [
    'APPWRITE_API_KEY',
    'COC_LEARNING_ADMITTED',
    'COC_AI_PROVIDER',
    'GEMINI_API_KEY',
    'NODE_OPTIONS',
    'UNRELATED_SECRET',
  ])
    assert.equal(env[name], undefined);
});
