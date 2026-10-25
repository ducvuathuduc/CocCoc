import test from 'node:test';
import assert from 'node:assert/strict';
import { request as httpRequest } from 'node:http';
import { createHttpRuntime } from '../../../.cache/backend-fixtures/runtime-http.mjs';
import { createWorkerRuntime } from '../../../.cache/backend-fixtures/runtime-worker.mjs';

function assertErrorEnvelope(body, code) {
  assert.deepEqual(Object.keys(body), ['error']);
  assert.deepEqual(Object.keys(body.error).sort(), [
    'code',
    'details',
    'message',
    'requestId',
    'retryable',
  ]);
  assert.equal(body.error.code, code);
  assert.equal(typeof body.error.message, 'string');
  assert.equal(typeof body.error.requestId, 'string');
  assert.deepEqual(body.error.details, {});
  assert.equal(typeof body.error.retryable, 'boolean');
}

test('native HTTP bridge strips Appwrite authority headers and has no CORS default', async (t) => {
  let received;
  const runtime = createHttpRuntime(
    async (context) => {
      received = context.req;
      return context.res.json({ headers: context.req.headers });
    },
    { service: 'learning', port: 0 },
  );
  const address = await runtime.listen();
  t.after(() => runtime.close());

  const response = await fetch(`http://127.0.0.1:${address.port}/health?q=1`, {
    headers: {
      authorization: 'Bearer jwt',
      'x-appwrite-key': 'forged-key',
      'x-appwrite-trigger': 'schedule',
      'x-appwrite-user-jwt': 'forged-jwt',
    },
  });

  assert.equal(response.status, 200);
  assert.equal(response.headers.has('access-control-allow-origin'), false);
  assert.equal(received.headers.authorization, 'Bearer jwt');
  assert.equal(
    Object.keys(received.headers).some((key) => key.startsWith('x-appwrite-')),
    false,
  );
  assert.equal(received.path, '/health');
  assert.equal(received.queryString, 'q=1');
});

test('native HTTP bridge rejects a body larger than the shared limit before handler', async (t) => {
  let calls = 0;
  const runtime = createHttpRuntime(
    async (context) => {
      calls++;
      return context.res.json({ ok: true });
    },
    { service: 'learning', port: 0 },
  );
  const address = await runtime.listen();
  t.after(() => runtime.close());
  const response = await fetch(`http://127.0.0.1:${address.port}/v1/private`, {
    method: 'POST',
    body: 'x'.repeat(750001),
  });
  assert.equal(response.status, 413);
  assert.equal(calls, 0);
  const body = await response.json();
  assertErrorEnvelope(body, 'PAYLOAD_TOO_LARGE');
  assert.equal(JSON.stringify(body).includes('x'.repeat(100)), false);
});

test('native HTTP bridge redacts unexpected handler errors', async (t) => {
  const runtime = createHttpRuntime(
    async () => {
      throw new Error('database password and private row');
    },
    { service: 'learning', port: 0 },
  );
  const address = await runtime.listen();
  t.after(() => runtime.close());
  const response = await fetch(`http://127.0.0.1:${address.port}/health`);
  const body = await response.json();
  assert.equal(response.status, 500);
  assertErrorEnvelope(body, 'INTERNAL_ERROR');
  assert.doesNotMatch(JSON.stringify(body), /password|private row/);
});

test('native HTTP malformed URL fallback uses a complete 400 envelope', async (t) => {
  const runtime = createHttpRuntime(async (context) => context.res.json({ ok: true }), {
    service: 'learning',
    port: 0,
  });
  const address = await runtime.listen();
  t.after(() => runtime.close());
  const result = await new Promise((resolve, reject) => {
    const request = httpRequest(
      { host: '127.0.0.1', port: address.port, path: '//%', method: 'GET' },
      (response) => {
        const chunks = [];
        response.on('data', (chunk) => chunks.push(chunk));
        response.on('end', () =>
          resolve({ status: response.statusCode, body: JSON.parse(Buffer.concat(chunks)) }),
        );
      },
    );
    request.once('error', reject);
    request.end();
  });
  assert.equal(result.status, 400);
  assertErrorEnvelope(result.body, 'VALIDATION_ERROR');
});

test('native HTTP timeout uses a complete retryable error envelope', async (t) => {
  const runtime = createHttpRuntime(
    async (context) => {
      await new Promise((resolve) => setTimeout(resolve, 30));
      return context.res.json({ tooLate: true });
    },
    { service: 'learning', port: 0, requestTimeoutMs: 5 },
  );
  const address = await runtime.listen();
  t.after(() => runtime.close());
  const response = await fetch(`http://127.0.0.1:${address.port}/health`);
  assert.equal(response.status, 504);
  assertErrorEnvelope(await response.json(), 'DEADLINE_EXCEEDED');
});

test('worker injects the trusted schedule trigger internally and never overlaps ticks', async () => {
  let active = 0;
  let maximum = 0;
  let calls = 0;
  const runtime = createWorkerRuntime(
    async (context) => {
      calls++;
      active++;
      maximum = Math.max(maximum, active);
      assert.equal(context.req.headers['x-appwrite-trigger'], 'schedule');
      assert.equal(context.req.headers['x-appwrite-key'], undefined);
      await new Promise((resolve) => setTimeout(resolve, 25));
      active--;
      return context.res.json({ ok: true });
    },
    { service: 'learning', intervalMs: 5 },
  );
  runtime.start();
  await new Promise((resolve) => setTimeout(resolve, 68));
  await runtime.stop();
  assert.equal(maximum, 1);
  assert.ok(calls >= 2);
});
