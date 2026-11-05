import test from 'node:test';
import assert from 'node:assert/strict';
import { buildOfflineDefines } from '../scripts/local-offline-defines.mjs';

const mobile = {
  DATA_SOURCE: 'api',
  USE_MOCK_AUTH: 'false',
  APPWRITE_ENDPOINT: 'https://10.0.2.2:8443/v1',
  APPWRITE_PROJECT_ID: 'cocenglish-local',
  LEARNING_API_URL: 'https://10.0.2.2:4101',
  PROGRESS_API_URL: 'https://10.0.2.2:4102',
  AI_API_URL: 'https://10.0.2.2:4103',
  LOCAL_DEV_CA_BASE64: Buffer.from(
    '-----BEGIN CERTIFICATE-----\nY2VydA==\n-----END CERTIFICATE-----\n',
  ).toString('base64'),
};

const smoke = {
  endpoint: 'https://127.0.0.1:8443/v1',
  project: 'cocenglish-local',
  status: 'passed',
  users: [
    {
      id: 'alice-local',
      email: 'alice@cocenglish.local',
      password: 'private-password',
    },
  ],
};

test('builds exact emulator defines with Alice credentials only', () => {
  assert.deepEqual(buildOfflineDefines(mobile, smoke), {
    ...mobile,
    LOCAL_TEST_EMAIL: 'alice@cocenglish.local',
    LOCAL_TEST_PASSWORD: 'private-password',
  });
});

test('rejects cloud, incomplete, or non-passed inputs without echoing secrets', () => {
  for (const [badMobile, badSmoke] of [
    [{ ...mobile, APPWRITE_ENDPOINT: 'https://cloud.appwrite.io/v1' }, smoke],
    [mobile, { ...smoke, project: 'production' }],
    [mobile, { ...smoke, status: 'running' }],
    [mobile, { ...smoke, users: [{ ...smoke.users[0], email: 'alice@example.com' }] }],
  ]) {
    assert.throws(
      () => buildOfflineDefines(badMobile, badSmoke),
      (error) =>
        error instanceof Error &&
        error.message === 'LOCAL_OFFLINE_CONFIGURATION_INVALID' &&
        !error.message.includes('private-password'),
    );
  }
});
