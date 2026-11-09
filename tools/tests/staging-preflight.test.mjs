import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { spawnSync } from 'node:child_process';
import { checkStaging } from '../scripts/staging-preflight.mjs';

const read = (file) => JSON.parse(fs.readFileSync(file, 'utf8'));
const testProject = read('appwrite/ops/project.json');
const realProfile = read('apps/mobile/config/real.public.json');
const exampleOverlay = fs.readFileSync('appwrite/ops/project.staging.example.json', 'utf8');
const exampleMobile = fs.readFileSync('apps/mobile/config/staging.public.example.json', 'utf8');

const FILL = [
  ['REPLACE_WITH_STAGING_PROJECT_ID', 'stg0abc123def456gh78'],
  ['REPLACE_REGION', 'fra'],
  ['REPLACE-staging-learning', 'cocstg-learning'],
  ['REPLACE-staging-progress', 'cocstg-progress'],
  ['REPLACE-staging-ai', 'cocstg-ai'],
  ['REPLACE_WITH_STAGING_ED25519_PUBLIC_KEY_HEX', '9f'.repeat(32)],
  ['REPLACE_WITH_STAGING_MAINTAINER_USER_ID', 'stgmaint1'],
];
const filled = (text) => FILL.reduce((out, [token, value]) => out.replaceAll(token, value), text);
const good = () => ({
  test: testProject,
  realProfile,
  overlay: JSON.parse(filled(exampleOverlay)),
  mobile: JSON.parse(filled(exampleMobile)),
});
const codes = (input) => checkStaging(input).problems.map((p) => p.code);

test('the example files are templates: they fail until every placeholder is filled', () => {
  const result = checkStaging({
    test: testProject,
    realProfile,
    overlay: JSON.parse(exampleOverlay),
    mobile: JSON.parse(exampleMobile),
  });
  assert.equal(result.status, 'FAIL');
  assert.ok(result.problems.some((p) => p.code === 'PLACEHOLDER_LEFT_IN'));
});

test('a filled-in staging profile that shares nothing with TEST passes', () => {
  assert.deepEqual(checkStaging(good()), { status: 'PASS', problems: [] });
});

test('staging that shares the TEST project, environment or domains is refused', () => {
  let input = good();
  input.overlay.projectId = testProject.projectId;
  for (const fn of Object.values(input.overlay.functions))
    fn.variables.APPWRITE_PROJECT_ID = testProject.projectId;
  assert.ok(codes(input).includes('SAME_PROJECT_AS_TEST'));

  input = good();
  input.overlay.projectEnv = 'test';
  assert.ok(codes(input).includes('ENV_NOT_STAGING'));

  input = good();
  input.overlay.functions['coc-learning'].functionDomain =
    testProject.functions['coc-learning'].functionDomain;
  assert.ok(codes(input).includes('DOMAIN_SHARED_WITH_TEST'));

  input = good();
  input.overlay.functions['coc-ai'].variables.COC_PROGRESS_URL =
    testProject.functions['coc-ai'].variables.COC_PROGRESS_URL;
  assert.ok(codes(input).includes('PEER_URL_NOT_STAGING'));

  input = good();
  input.overlay.functions['coc-progress'].variables.APPWRITE_PROJECT_ID = testProject.projectId;
  assert.ok(codes(input).includes('FUNCTION_POINTS_AT_OTHER_PROJECT'));
});

test('the dev content key is refused in staging, a missing or malformed key too', () => {
  const key = (value) => {
    const input = good();
    input.overlay.functions['coc-learning'].variables.COC_CONTENT_PUBLIC_KEYS =
      JSON.stringify(value);
    return codes(input);
  };
  const dev = JSON.parse(testProject.functions['coc-learning'].variables.COC_CONTENT_PUBLIC_KEYS);
  assert.ok(key(dev).includes('DEV_CONTENT_KEY'));
  assert.ok(
    key([{ keyId: 'staging-content-1', publicKeyHex: dev[0].publicKeyHex }]).includes(
      'DEV_CONTENT_KEY',
    ),
  );
  assert.ok(
    key([{ keyId: 'dev-content-1', publicKeyHex: '9f'.repeat(32) }]).includes('DEV_CONTENT_KEY'),
  );
  assert.ok(key([]).includes('CONTENT_KEY_MISSING'));
  assert.ok(
    key([{ keyId: 'staging-content-1', publicKeyHex: 'not-hex' }]).includes('CONTENT_KEY_NOT_HEX'),
  );
});

test('secrets, a shared OAuth client and missing maintainers are refused', () => {
  let input = good();
  input.overlay.functions['coc-learning'].variables.APPWRITE_API_KEY = 'standard_' + 'a'.repeat(64);
  assert.ok(codes(input).includes('SECRET_IN_FILE'));

  input = good();
  input.overlay.functions['coc-learning'].variables.COC_SERVICE_KEYS = '[{"keyId":"k"}]';
  assert.ok(codes(input).includes('SECRET_IN_FILE'));

  input = good();
  input.overlay.auth.oauth2.google = {
    enabled: true,
    clientId: testProject.auth.oauth2.google.clientId,
  };
  assert.ok(codes(input).includes('OAUTH_CLIENT_SHARED_WITH_TEST'));

  input = good();
  input.overlay.functions['coc-learning'].variables.COC_MAINTAINER_USER_IDS = ' , ';
  assert.ok(codes(input).includes('MAINTAINERS_MISSING'));

  input = good();
  input.overlay.functions['coc-learning'].variables.COC_LEARNING_ADMITTED = 'anything';
  assert.ok(codes(input).includes('ADMISSION_GATE_CHANGED'));
});

test('the staging mobile profile must be an API profile for the same staging project', () => {
  const mutate = (change) => {
    const input = good();
    change(input.mobile);
    return codes(input);
  };
  assert.ok(
    mutate((m) => (m.APPWRITE_PROJECT_ID = testProject.projectId)).includes(
      'MOBILE_PROJECT_MISMATCH',
    ),
  );
  assert.ok(mutate((m) => (m.USE_MOCK_AUTH = 'true')).includes('MOBILE_MOCK_AUTH'));
  assert.ok(mutate((m) => (m.DATA_SOURCE = 'mock')).includes('MOBILE_NOT_API'));
  assert.ok(
    mutate((m) => (m.ALLOW_INSECURE_LOCAL_ENDPOINTS = 'true')).includes(
      'MOBILE_INSECURE_ENDPOINTS',
    ),
  );
  const real = mutate((m) => (m.LEARNING_API_URL = realProfile.LEARNING_API_URL));
  assert.ok(
    real.includes('MOBILE_URL_NOT_STAGING') && real.includes('MOBILE_URL_SHARED_WITH_REAL'),
  );
  assert.ok(
    mutate((m) => (m.APPWRITE_ENDPOINT = 'http://127.0.0.1/v1')).includes(
      'MOBILE_ENDPOINT_MISMATCH',
    ),
  );
});

test('the CLI reports BLOCKED, not PASS, when the staging files do not exist', () => {
  const run = spawnSync(process.execPath, ['tools/scripts/staging-preflight.mjs'], {
    encoding: 'utf8',
  });
  assert.equal(run.status, 2, run.stderr);
  assert.equal(JSON.parse(run.stdout).status, 'BLOCKED');
});
