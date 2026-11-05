// Phase 5.2 (ADR-0018): EventTransport and ReadCache ports. Off by default, fail closed when
// partly configured, and never present as fixture success.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { loadTransportKit, root } from './kit.mjs';

const kit = await loadTransportKit('ports');

test('event transport is the direct signed relay unless AMQP is fully configured', () => {
  assert.deepEqual(kit.eventTransportConfigFromEnv({}), { mode: 'direct', routes: [] });
  assert.deepEqual(kit.eventTransportConfigFromEnv({ COC_EVENT_TRANSPORT: 'direct' }), {
    mode: 'direct',
    routes: [],
  });
  // Asking for AMQP without a broker URL never silently falls back to a fake: it is refused.
  assert.deepEqual(kit.eventTransportConfigFromEnv({ COC_EVENT_TRANSPORT: 'amqp' }), {
    mode: 'refused',
    reason: 'AMQP_URL_MISSING',
    routes: [],
  });
  // Plain amqp:// needs the explicit private-network marker used by the local Compose topology.
  assert.equal(
    kit.eventTransportConfigFromEnv({
      COC_EVENT_TRANSPORT: 'amqp',
      COC_AMQP_URL: 'amqp://u:p@rabbitmq:5672/coc',
      COC_AMQP_ROUTES: 'learning->progress',
    }).reason,
    'AMQP_TLS_REQUIRED',
  );
  const local = kit.eventTransportConfigFromEnv({
    COC_EVENT_TRANSPORT: 'amqp',
    COC_AMQP_URL: 'amqp://u:p@rabbitmq:5672/coc',
    COC_AMQP_ALLOW_PLAINTEXT: 'private-compose-network',
    COC_AMQP_ROUTES: 'learning->progress',
  });
  assert.equal(local.mode, 'amqp');
  assert.deepEqual(local.routes, ['learning->progress']);
  const tls = kit.eventTransportConfigFromEnv({
    COC_EVENT_TRANSPORT: 'amqp',
    COC_AMQP_URL: 'amqps://u:p@broker.example:5671/coc',
    COC_AMQP_ROUTES: 'progress->learning, progress->ai',
  });
  assert.equal(tls.mode, 'amqp');
  assert.deepEqual(tls.routes, ['progress->learning', 'progress->ai']);
  // Unknown or self routes are refused rather than ignored.
  for (const routes of ['learning->learning', 'progress->billing', 'garbage', '']) {
    const config = kit.eventTransportConfigFromEnv({
      COC_EVENT_TRANSPORT: 'amqp',
      COC_AMQP_URL: 'amqps://u:p@broker.example/coc',
      COC_AMQP_ROUTES: routes,
    });
    assert.equal(config.mode, 'refused', routes);
  }
  assert.equal(kit.eventTransportConfigFromEnv({ COC_EVENT_TRANSPORT: 'kafka' }).mode, 'refused');
  // The broker URL (credentials) is never part of a printable description.
  assert.doesNotMatch(JSON.stringify(kit.describeEventTransport(tls)), /u:p|broker\.example/);
});

test('a route-gated transport only claims the routes it was configured for', () => {
  const config = kit.eventTransportConfigFromEnv({
    COC_EVENT_TRANSPORT: 'amqp',
    COC_AMQP_URL: 'amqps://u:p@broker.example/coc',
    COC_AMQP_ROUTES: 'progress->learning',
  });
  assert.equal(kit.usesAmqp(config, 'progress', 'learning'), true);
  assert.equal(kit.usesAmqp(config, 'progress', 'ai'), false);
  assert.equal(kit.usesAmqp(kit.eventTransportConfigFromEnv({}), 'progress', 'learning'), false);
});

test('disabled EventTransport fails closed and is never healthy', async () => {
  const transport = kit.createDisabledEventTransport('AMQP_URL_MISSING');
  assert.equal(transport.kind, 'disabled');
  assert.deepEqual(transport.health(), {
    kind: 'disabled',
    connected: false,
    reason: 'AMQP_URL_MISSING',
  });
  const event = {
    eventId: '7f1d0e8a-1111-4222-8333-444455556666',
    type: 'lesson.completed.v1',
    schemaVersion: 1,
    producer: 'learning',
    aggregateId: 'c1',
    occurredAt: new Date().toISOString(),
    requestId: 'r1',
    payload: {},
  };
  await assert.rejects(transport.publish('progress', event), { code: 'SERVICE_NOT_CONFIGURED' });
  await assert.rejects(
    transport.consume('progress', async () => 'ack'),
    { code: 'SERVICE_NOT_CONFIGURED' },
  );
  await transport.close();
});

test('read cache is disabled by default and when Redis is half configured', async () => {
  assert.deepEqual(kit.readCacheConfigFromEnv({}), { mode: 'disabled', reason: 'NOT_ENABLED' });
  assert.deepEqual(kit.readCacheConfigFromEnv({ COC_READ_CACHE: 'redis' }), {
    mode: 'disabled',
    reason: 'REDIS_URL_MISSING',
  });
  assert.equal(
    kit.readCacheConfigFromEnv({ COC_READ_CACHE: 'redis', COC_REDIS_URL: 'redis://redis:6379' })
      .reason,
    'REDIS_TLS_REQUIRED',
  );
  const local = kit.readCacheConfigFromEnv({
    COC_READ_CACHE: 'redis',
    COC_REDIS_URL: 'redis://default:pw@redis:6379/0',
    COC_REDIS_ALLOW_PLAINTEXT: 'private-compose-network',
    COC_CACHE_ENV: 'test',
  });
  assert.equal(local.mode, 'redis');
  assert.equal(local.environment, 'test');
  // Private snapshots bypass the distributed cache by default (ADR-0018 cache policy).
  assert.equal(local.privateSnapshots, false);
  assert.equal(
    kit.readCacheConfigFromEnv({
      COC_READ_CACHE: 'redis',
      COC_REDIS_URL: 'rediss://default:pw@cache.example:6380',
    }).mode,
    'redis',
  );
  const cache = kit.createDisabledReadCache('NOT_ENABLED');
  assert.equal(cache.kind, 'disabled');
  assert.equal(await cache.get('coc:x'), undefined);
  await cache.set('coc:x', '1', 30);
  assert.equal(await cache.get('coc:x'), undefined);
  await cache.invalidate('coc:');
  assert.equal(cache.health().connected, false);
});

test('cache-aside falls back to the owner for malformed envelopes and cache failures', async () => {
  const read = kit.createCacheAside();
  let loads = 0;
  const cache = {
    kind: 'redis',
    get: async () => '{}',
    set: async () => {
      throw new Error('cache write failed');
    },
  };
  const options = {
    cache,
    key: 'coc:test:learning:v1:pub:catalog:r1',
    ttlSeconds: 30,
    load: async () => {
      loads++;
      return { lessons: 2 };
    },
  };
  assert.deepEqual(await read(options), { lessons: 2 });
  assert.equal(loads, 1);
  cache.get = async () => {
    throw new Error('cache read failed');
  };
  assert.deepEqual(await read(options), { lessons: 2 });
  assert.equal(loads, 2);
});

test('cache-aside never coalesces requests across different cache instances', async () => {
  const read = kit.createCacheAside();
  let release;
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  const cache = () => ({ kind: 'redis', get: async () => undefined, set: async () => undefined });
  const first = read({
    cache: cache(),
    key: 'same',
    ttlSeconds: 10,
    load: async () => {
      await gate;
      return 'one';
    },
  });
  const second = read({ cache: cache(), key: 'same', ttlSeconds: 10, load: async () => 'two' });
  await new Promise((resolve) => setImmediate(resolve));
  release();
  assert.deepEqual(await Promise.all([first, second]), ['one', 'two']);
});

test('hosted bundles contain no fake broker or memory cache code', () => {
  for (const service of ['learning', 'progress', 'ai']) {
    for (const entry of ['function', 'http', 'worker']) {
      const file = path.join(root, `services/${service}/dist/${entry}.mjs`);
      const text = fs.readFileSync(file, 'utf8');
      assert.doesNotMatch(text, /FAKE_AMQP_BROKER|MEMORY_READ_CACHE/, `${service}/${entry}`);
    }
  }
});
