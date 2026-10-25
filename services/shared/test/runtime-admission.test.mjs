import test from 'node:test';
import assert from 'node:assert/strict';
import {
  createDisabledLearningPersistence,
  createHostedHandler,
  signServiceRequest,
} from '../../../.cache/backend-fixtures/foundation-testkit.mjs';

function call(handler, request) {
  return handler({
    req: request,
    res: { json: (body, status = 200, headers = {}) => ({ body, status, headers }) },
  });
}

test('container public Appwrite names configure auth while disabled persistence stays unready', async () => {
  const secret = Buffer.alloc(32, 23);
  const key = { keyId: 'ops', sender: 'maintainer', secret };
  const handler = createHostedHandler('learning', createDisabledLearningPersistence(), {
    APPWRITE_ENDPOINT: 'https://appwrite.example.test/v1',
    APPWRITE_PROJECT_ID: 'project-test',
    COC_SERVICE_KEYS: JSON.stringify([
      { keyId: key.keyId, sender: key.sender, secretHex: secret.toString('hex') },
    ]),
  });
  const response = await call(handler, {
    method: 'GET',
    path: '/ready',
    queryString: '',
    bodyText: '',
    headers: signServiceRequest({
      key,
      method: 'GET',
      path: '/ready',
      body: '',
      nowSeconds: Date.now() / 1000,
    }),
  });
  assert.equal(response.status, 503);
  assert.equal(response.body.error.code, 'SERVICE_NOT_CONFIGURED');
  assert.equal(response.body.error.details.checks.auth, true);
  assert.equal(response.body.error.details.checks.persistence, false);
});

test('Appwrite Function identity variables retain precedence over public container names', async () => {
  const secret = Buffer.alloc(32, 29);
  const key = { keyId: 'ops-precedence', sender: 'maintainer', secret };
  const handler = createHostedHandler('learning', createDisabledLearningPersistence(), {
    APPWRITE_FUNCTION_API_ENDPOINT: 'http://platform-value-is-authoritative.invalid/v1',
    APPWRITE_FUNCTION_PROJECT_ID: 'platform-project',
    APPWRITE_ENDPOINT: 'https://public-fallback.example.test/v1',
    APPWRITE_PROJECT_ID: 'public-project',
    COC_SERVICE_KEYS: JSON.stringify([
      { keyId: key.keyId, sender: key.sender, secretHex: secret.toString('hex') },
    ]),
  });
  const response = await call(handler, {
    method: 'GET',
    path: '/ready',
    queryString: '',
    bodyText: '',
    headers: signServiceRequest({
      key,
      method: 'GET',
      path: '/ready',
      body: '',
      nowSeconds: Date.now() / 1000,
    }),
  });
  assert.equal(response.status, 503);
  assert.equal(response.body.error.details.checks.auth, false);
});

test('Progress hosted schedule refuses configured Appwrite before explicit admission', async () => {
  const names = [
    'APPWRITE_ENDPOINT',
    'APPWRITE_PROJECT_ID',
    'APPWRITE_API_KEY',
    'COC_PROGRESS_PERSISTENCE',
    'COC_PROGRESS_ADMITTED',
  ];
  const previous = Object.fromEntries(names.map((name) => [name, process.env[name]]));
  Object.assign(process.env, {
    APPWRITE_ENDPOINT: 'https://127.0.0.1:1/v1',
    APPWRITE_PROJECT_ID: 'project-test',
    APPWRITE_API_KEY: 'test-key-never-sent-after-fix',
    COC_PROGRESS_PERSISTENCE: 'appwrite',
  });
  delete process.env.COC_PROGRESS_ADMITTED;
  try {
    const { default: handler } = await import(
      `../../../services/progress/dist/function.mjs?unadmitted=${Date.now()}`
    );
    const response = await handler({
      req: {
        method: 'POST',
        path: '/',
        queryString: '',
        bodyText: '',
        headers: { 'x-appwrite-trigger': 'schedule', 'x-appwrite-key': 'execution-key' },
      },
      res: { json: (body, status = 200) => ({ body, status }) },
    });
    assert.deepEqual(response, {
      body: { worker: 'progress', status: 'SERVICE_NOT_CONFIGURED' },
      status: 503,
    });
  } finally {
    for (const name of names) {
      const value = previous[name];
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    }
  }
});
