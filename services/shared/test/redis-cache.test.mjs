import test from 'node:test';
import assert from 'node:assert/strict';
import { buildSync } from 'esbuild';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { root } from './kit.mjs';

const outfile = path.join(root, `.cache/shared-tests/redis-${process.pid}.mjs`);
buildSync({
  entryPoints: [path.join(root, 'services/shared/src/redis-cache.ts')],
  outfile,
  bundle: true,
  platform: 'node',
  target: 'node22',
  format: 'esm',
  logLevel: 'error',
  banner: {
    js: "import { createRequire as __cocCreateRequire } from 'node:module';\nconst require = __cocCreateRequire(import.meta.url);",
  },
});
const { createRedisReadCache } = await import(pathToFileURL(outfile).href);

const config = {
  mode: 'redis',
  url: 'rediss://default:secret@cache.internal:6380',
  environment: 'test',
  privateSnapshots: false,
  timeoutMs: 25,
  maxValueBytes: 32,
};

class FakeRedisClient {
  constructor(store = new Map()) {
    this.store = store;
    this.connected = false;
    this.destroyed = false;
    this.calls = [];
    this.listeners = new Map();
    this.pending = new Set();
  }

  on(event, listener) {
    const listeners = this.listeners.get(event) ?? [];
    listeners.push(listener);
    this.listeners.set(event, listeners);
    return this;
  }

  emit(event) {
    for (const listener of this.listeners.get(event) ?? []) listener();
  }

  async connect() {
    this.calls.push(['connect']);
    if (this.connectError) throw this.connectError;
    this.connected = true;
    this.emit('ready');
    return this;
  }

  async get(key) {
    this.calls.push(['get', key]);
    if (this.getValue !== undefined) return this.getValue;
    return this.store.get(key) ?? null;
  }

  async set(key, value, options) {
    this.calls.push(['set', key, value, options]);
    this.store.set(key, value);
    return 'OK';
  }

  async scan(cursor, options) {
    this.calls.push(['scan', cursor, options]);
    if (this.scanPages) return this.scanPages.shift() ?? { cursor: '0', keys: [] };
    const prefix = options.MATCH.slice(0, -1);
    return { cursor: '0', keys: [...this.store.keys()].filter((key) => key.startsWith(prefix)) };
  }

  async unlink(keys) {
    this.calls.push(['unlink', keys]);
    for (const key of keys) this.store.delete(key);
    return keys.length;
  }

  destroy() {
    this.calls.push(['destroy']);
    this.destroyed = true;
    this.connected = false;
    this.emit('end');
  }
}

function factory(clients, store = new Map()) {
  return () => {
    const client = new FakeRedisClient(store);
    clients.push(client);
    return client;
  };
}

test('stores namespaced values with bounded TTL and invalidates only matching keys', async () => {
  const clients = [];
  const store = new Map([
    ['coc:test:learning:v1:pub:catalog:r1', 'old'],
    ['coc:test:learning:v1:pub:path:r1', 'keep'],
    ['coc:test:progress:v1:pub:catalog:r1', 'foreign-owner'],
    ['coc:prod:learning:v1:pub:catalog:r1', 'foreign-env'],
  ]);
  const cache = createRedisReadCache(config, factory(clients, store));

  await cache.set('coc:test:learning:v1:pub:catalog:r2', 'fresh', 999);
  assert.equal(await cache.get('coc:test:learning:v1:pub:catalog:r2'), 'fresh');
  assert.deepEqual(
    clients[0].calls.find((call) => call[0] === 'set'),
    ['set', 'coc:test:learning:v1:pub:catalog:r2', 'fresh', { EX: 60 }],
  );
  await cache.invalidate('coc:test:learning:v1:pub:catalog:');

  assert.equal(store.has('coc:test:learning:v1:pub:catalog:r1'), false);
  assert.equal(store.has('coc:test:learning:v1:pub:catalog:r2'), false);
  assert.equal(store.has('coc:test:learning:v1:pub:path:r1'), true);
  assert.equal(store.has('coc:test:progress:v1:pub:catalog:r1'), true);
  assert.equal(store.has('coc:prod:learning:v1:pub:catalog:r1'), true);
  assert.deepEqual(cache.health(), { kind: 'redis', connected: true });
  await cache.close();
});

test('rejects oversized, invalid-TTL, wildcard and foreign namespace writes without throwing', async () => {
  const clients = [];
  const cache = createRedisReadCache(config, factory(clients));

  await cache.set('coc:test:learning:v1:pub:x:r1', 'x'.repeat(33), 10);
  await cache.set('coc:test:learning:v1:pub:x:r1', 'ok', 0);
  await cache.set('coc:test:learning:v1:pub:*:r1', 'ok', 10);
  await cache.set('coc:prod:learning:v1:pub:x:r1', 'ok', 10);
  await cache.set('coc:test:unknown:v1:pub:x:r1', 'ok', 10);
  assert.equal(await cache.get('coc:prod:learning:v1:pub:x:r1'), undefined);
  await cache.invalidate('coc:test:learning:*');
  await cache.invalidate('coc:prod:learning:v1:pub:');

  assert.equal(clients.length, 0, 'invalid input never reaches Redis');
});

test('filters malicious SCAN results and bounds invalidation pages', async () => {
  const clients = [];
  const cache = createRedisReadCache(config, factory(clients));
  await cache.get('coc:test:learning:v1:pub:x:r1');
  clients[0].scanPages = Array.from({ length: 40 }, (_, index) => ({
    cursor: String(index + 1),
    keys: [
      `coc:test:learning:v1:pub:catalog:r${index}`,
      'coc:prod:learning:v1:pub:catalog:r1',
      'coc:test:progress:v1:pub:catalog:r1',
    ],
  }));

  await cache.invalidate('coc:test:learning:v1:pub:catalog:');

  assert.equal(clients[0].calls.filter((call) => call[0] === 'scan').length, 32);
  assert.equal(clients[0].calls.filter((call) => call[0] === 'unlink').length, 32);
  assert.ok(
    clients[0].calls
      .filter((call) => call[0] === 'unlink')
      .every((call) => call[1].length === 1 && call[1][0].startsWith('coc:test:learning:')),
  );
});

test('invalidates all matching keys when Redis returns more than the SCAN count hint', async () => {
  const clients = [];
  const prefix = 'coc:test:learning:v1:pub:catalog:';
  const store = new Map(Array.from({ length: 237 }, (_, index) => [`${prefix}r${index}`, 'old']));
  const cache = createRedisReadCache(config, factory(clients, store));

  await cache.invalidate(prefix);

  assert.equal(store.size, 0);
  const batches = clients[0].calls.filter((call) => call[0] === 'unlink');
  assert.equal(batches.length, 3);
  assert.ok(batches.every((call) => call[1].length <= 100));
  await cache.close();
});

test('bounds invalidation work and exposes the limit instead of claiming full invalidation', async () => {
  const clients = [];
  const prefix = 'coc:test:learning:v1:pub:catalog:';
  const store = new Map(Array.from({ length: 3201 }, (_, index) => [`${prefix}r${index}`, 'old']));
  const cache = createRedisReadCache(config, factory(clients, store));

  await cache.invalidate(prefix);

  assert.equal(store.size, 1);
  assert.equal(cache.health().reason, 'INVALIDATION_LIMIT');
  assert.equal(clients[0].calls.filter((call) => call[0] === 'unlink').length, 32);
  await cache.close();
});

test('fails open while down, then reconnects with a fresh client', async () => {
  const clients = [];
  const makeClient = factory(clients);
  const cache = createRedisReadCache(config, () => {
    const client = makeClient();
    if (clients.length === 1) client.connectError = new Error('secret host unavailable');
    return client;
  });

  assert.equal(await cache.get('coc:test:learning:v1:pub:x:r1'), undefined);
  assert.deepEqual(cache.health(), { kind: 'redis', connected: false, reason: 'UNAVAILABLE' });
  await cache.set('coc:test:learning:v1:pub:x:r1', 'ok', 10);
  assert.equal(await cache.get('coc:test:learning:v1:pub:x:r1'), 'ok');
  assert.equal(clients.length, 2);
  assert.equal(JSON.stringify(cache.health()).includes('secret'), false);
  clients[1].emit('end');
  assert.deepEqual(cache.health(), {
    kind: 'redis',
    connected: false,
    reason: 'DISCONNECTED',
  });
  assert.equal(await cache.get('coc:test:learning:v1:pub:x:r1'), 'ok');
  assert.equal(clients.length, 3);
  await cache.close();
});

test('command deadline destroys client so timed-out mutation cannot replay', async () => {
  const clients = [];
  const cache = createRedisReadCache({ ...config, timeoutMs: 20 }, factory(clients));
  await cache.get('coc:test:learning:v1:pub:x:r1');
  clients[0].set = async function (key, value, options) {
    this.calls.push(['set', key, value, options]);
    return new Promise((resolve) => this.pending.add(() => resolve('OK')));
  };

  await cache.set('coc:test:learning:v1:pub:late:r1', 'late', 10);
  assert.equal(clients[0].destroyed, true);
  assert.equal(clients[0].store.has('coc:test:learning:v1:pub:late:r1'), false);
  for (const resolve of clients[0].pending) resolve();
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(clients[0].store.has('coc:test:learning:v1:pub:late:r1'), false);
  assert.equal(cache.health().reason, 'TIMEOUT');
  await cache.close();
});

test('corrupt replies are misses and close destroys pending work safely', async () => {
  const clients = [];
  const cache = createRedisReadCache({ ...config, timeoutMs: 100 }, factory(clients));
  await cache.get('coc:test:ai:v1:pub:x:r1');
  clients[0].getValue = { not: 'a string' };
  assert.equal(await cache.get('coc:test:ai:v1:pub:x:r1'), undefined);
  clients[0].get = async () => new Promise(() => {});
  const pending = cache.get('coc:test:ai:v1:pub:pending:r1');

  await cache.close();
  assert.equal(await pending, undefined);
  assert.equal(clients[0].destroyed, true);
  assert.deepEqual(cache.health(), { kind: 'redis', connected: false, reason: 'CLOSED' });
  assert.equal(await cache.get('coc:test:ai:v1:pub:x:r1'), undefined);
});
