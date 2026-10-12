// `pnpm dev:smoke` — starts `dev:services` as a child process and exercises it over real HTTP:
// /health on all three services, fail-closed /ready, and a signed lesson.completed.v1 event sent
// with Learning's key to Progress /internal/events (accept, replay, substitution, impersonation,
// unsigned). Uses COC_DEV_PORT_BASE (default 4101). No cloud, no provider calls.
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import Ajv from 'ajv/dist/2020.js';
import formats from 'ajv-formats';
import { SERVICES, devPorts } from './dev-services.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const ports = devPorts();
const url = (name, p) => `http://127.0.0.1:${ports[name]}${p}`;

const child = spawn(process.execPath, [path.join(root, 'tools/scripts/dev-services.mjs')], {
  cwd: root,
  env: { ...process.env, COC_SERVICE_KEYS: '' },
  stdio: ['ignore', 'pipe', 'pipe'],
});
let output = '';
child.stdout.on('data', (chunk) => (output += chunk));
child.stderr.on('data', (chunk) => (output += chunk));
const stop = () => child.exitCode === null && child.kill('SIGTERM');
process.on('exit', stop);

async function waitForHealth(deadlineMs = 30000) {
  const start = Date.now();
  for (;;) {
    if (child.exitCode !== null) throw new Error(`dev:services exited early:\n${output}`);
    try {
      const results = await Promise.all(SERVICES.map((name) => fetch(url(name, '/health'))));
      if (results.every((response) => response.ok)) return;
    } catch {
      // not listening yet
    }
    if (Date.now() - start > deadlineMs) throw new Error(`dev:services not healthy:\n${output}`);
    await new Promise((resolve) => setTimeout(resolve, 200));
  }
}

try {
  await waitForHealth();
  const cache = path.join(root, '.cache/dev');
  const { devKey } = await import(pathToFileURL(path.join(cache, 'dev-keyring.mjs')));
  const { createInternalClient, signServiceRequest } = await import(
    pathToFileURL(path.join(cache, 'internal-client.mjs'))
  );
  const api = JSON.parse(fs.readFileSync(path.join(root, 'docs/api/openapi.yaml'), 'utf8'));
  const ajv = new Ajv({ strict: false });
  formats(ajv);
  ajv.addSchema({ $id: 'https://cocenglish.example.invalid/schema', components: api.components });
  const schema = (name) =>
    ajv.compile({ $ref: `https://cocenglish.example.invalid/schema#/components/schemas/${name}` });
  const [validateHealth, validateEvent, validateError] = ['Health', 'BusinessEvent', 'Error'].map(
    schema,
  );

  // 1. Health on every service (unauthenticated, identifies the package).
  for (const name of SERVICES) {
    const response = await fetch(url(name, '/health'));
    const body = await response.json();
    assert.equal(response.status, 200);
    assert.equal(body.service, name);
    assert.equal(validateHealth(body), true, JSON.stringify(validateHealth.errors));
    assert.ok(response.headers.get('x-request-id'));
  }

  // 2. Signed /ready: memory adapters are never admitted, so readiness fails closed.
  const maintainer = devKey('maintainer');
  const headers = signServiceRequest({
    key: maintainer,
    method: 'GET',
    path: '/ready',
    body: '',
    nowSeconds: Math.floor(Date.now() / 1000),
  });
  const ready = await fetch(url('progress', '/ready'), { headers });
  const readyBody = await ready.json();
  assert.equal(ready.status, 503);
  assert.equal(readyBody.error.code, 'SERVICE_NOT_CONFIGURED');
  assert.equal(validateError(readyBody), true);

  // 3. Cross-service event: Learning's key -> Progress inbox.
  const learningToProgress = createInternalClient({
    key: devKey('learning'),
    baseUrl: url('progress', ''),
  });
  const completionId = randomUUID();
  const event = {
    eventId: randomUUID(),
    type: 'lesson.completed.v1',
    schemaVersion: 1,
    producer: 'learning',
    aggregateId: completionId,
    occurredAt: new Date().toISOString(),
    requestId: randomUUID(),
    payload: {
      completionId,
      userId: 'dev-user',
      courseId: 'vi_en',
      lessonVersion: 'dev-v1',
      rewardIdentity: 'dev-lesson',
      source: 'ONLINE',
      mode: 'LESSON',
      originalCount: 10,
      originalCorrect: 10,
      assisted: false,
    },
  };
  assert.equal(validateEvent(event), true, JSON.stringify(validateEvent.errors));
  const accepted = await learningToProgress.deliverEvent(event);
  assert.deepEqual(
    [accepted.status, accepted.body.status],
    [200, 'accepted'],
    JSON.stringify(accepted),
  );
  const replayed = await learningToProgress.deliverEvent(event);
  assert.deepEqual([replayed.status, replayed.body.status], [200, 'replayed']);
  const substituted = await learningToProgress.deliverEvent({
    ...event,
    payload: { ...event.payload, originalCorrect: 9 },
  });
  assert.deepEqual(
    [substituted.status, substituted.body.error.code],
    [409, 'IDEMPOTENCY_CONFLICT'],
  );
  const aiToProgress = createInternalClient({ key: devKey('ai'), baseUrl: url('progress', '') });
  const impersonated = await aiToProgress.deliverEvent({ ...event, eventId: randomUUID() });
  assert.deepEqual([impersonated.status, impersonated.body.error.code], [403, 'FORBIDDEN']);
  const unsigned = await fetch(url('progress', '/internal/events'), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(event),
  });
  assert.equal(unsigned.status, 401);
  // Learning has no event consumer for lesson.completed.v1 (wrong receiver): refused.
  const wrongReceiver = await createInternalClient({
    key: devKey('learning'),
    baseUrl: url('learning', ''),
  }).deliverEvent(event);
  assert.equal(wrongReceiver.status, 403);

  console.log(
    JSON.stringify(
      {
        status: 'PASS',
        mode: 'LOCAL_DEV_IN_MEMORY',
        ports,
        health: SERVICES,
        readyFailsClosed: true,
        crossServiceEvent: {
          from: 'learning',
          to: 'progress',
          accepted: true,
          replayed: true,
          substitution: 409,
          impersonation: 403,
          unsigned: 401,
        },
        cloudIntegration: 'NOT_RUN',
        providerCalls: 0,
      },
      null,
      2,
    ),
  );
} finally {
  stop();
}
