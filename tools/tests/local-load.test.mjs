import test from 'node:test';
import assert from 'node:assert/strict';
import { parseOptions, runLoad } from '../scripts/local-load.mjs';

test('load configuration has bounded requests and concurrency', () => {
  assert.deepEqual(parseOptions([]), { requests: 200, concurrency: 10, port: 24101 });
  assert.deepEqual(parseOptions(['--requests=50', '--concurrency=5', '--port=26001']), {
    requests: 50,
    concurrency: 5,
    port: 26001,
  });
  for (const args of [
    ['--requests=2001'],
    ['--requests=0'],
    ['--concurrency=51'],
    ['--concurrency=0'],
    ['--port=80'],
    ['--port=65534'],
    ['--host=example.com'],
    ['--requests=1', '--requests=2'],
    ['--requests=1.5'],
  ])
    assert.throws(() => parseOptions(args), /Invalid/);
});

test('load workers bound concurrency and count both rejected and failed requests', async () => {
  let active = 0;
  let peak = 0;
  let count = 0;
  const result = await runLoad({ requests: 30, concurrency: 4 }, async () => {
    active++;
    peak = Math.max(peak, active);
    const index = count++;
    await new Promise((resolve) => setImmediate(resolve));
    active--;
    if (index === 2) throw new Error('network');
    return index === 3 ? 503 : 200;
  });
  assert.equal(count, 30);
  assert.equal(peak, 4);
  assert.equal(result.successes, 28);
  assert.equal(result.failures, 2);
  assert.equal(result.statusCounts['503'], 1);
  assert.equal(result.statusCounts.network, 1);
  assert.ok(result.latencyMs.p99 >= result.latencyMs.p95);
});
