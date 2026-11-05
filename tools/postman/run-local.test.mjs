import test from 'node:test';
import assert from 'node:assert/strict';
import { executeCollection } from './run-local.mjs';

const collection = (script, prerequest = '') => ({
  item: [
    {
      name: 'local check',
      request: { method: 'GET', url: { raw: '{{base}}/health' }, header: [] },
      event: [
        { listen: 'prerequest', script: { exec: [prerequest] } },
        { listen: 'test', script: { exec: [script] } },
      ],
    },
  ],
});

test('executes response assertions rather than accepting any HTTP response', async () => {
  const result = await executeCollection(
    collection('pm.test("status", () => pm.response.to.have.status(200));'),
    new Map([['base', 'http://127.0.0.1:25101']]),
    {
      allowedOrigins: ['http://127.0.0.1:25101'],
      fetchImpl: async () => new Response('{}', { status: 503 }),
    },
  );
  assert.equal(result.requests, 1);
  assert.equal(result.failedAssertions, 1);
  assert.equal(result.passedAssertions, 0);
});

test('script skip is reported separately and never sends an HTTP request', async () => {
  let calls = 0;
  const result = await executeCollection(
    collection('', 'pm.execution.skipRequest();'),
    new Map([['base', 'http://127.0.0.1:25101']]),
    {
      allowedOrigins: ['http://127.0.0.1:25101'],
      fetchImpl: async () => {
        calls++;
        return new Response('{}');
      },
    },
  );
  assert.equal(calls, 0);
  assert.equal(result.skippedRequests, 1);
});

test('refuses redirects, external URLs and unsupported script APIs', async () => {
  let calls = 0;
  const external = await executeCollection(
    collection(''),
    new Map([['base', 'https://example.com']]),
    {
      allowedOrigins: ['http://127.0.0.1:25101'],
      fetchImpl: async () => {
        calls++;
        return new Response('{}');
      },
    },
  );
  assert.equal(calls, 0);
  assert.equal(external.scriptErrors, 1);
  const unsupported = await executeCollection(
    collection('', 'pm.sendRequest("https://example.com");'),
    new Map([['base', 'http://127.0.0.1:25101']]),
    {
      allowedOrigins: ['http://127.0.0.1:25101'],
      fetchImpl: async () => {
        calls++;
        return new Response('{}');
      },
    },
  );
  assert.equal(unsupported.scriptErrors, 1);
  assert.equal(calls, 0);
});

test('HTTP execution disables redirects and has a bounded request deadline', async () => {
  const result = await executeCollection(
    collection('pm.test("status", () => pm.response.to.have.status(200));'),
    new Map([['base', 'http://127.0.0.1:25101']]),
    {
      allowedOrigins: ['http://127.0.0.1:25101'],
      fetchImpl: async (_url, options) => {
        assert.equal(options.redirect, 'error');
        assert.ok(options.signal instanceof AbortSignal);
        return Response.json({ ok: true });
      },
    },
  );
  assert.equal(result.success, true);
  assert.equal(result.passedAssertions, 1);
});
