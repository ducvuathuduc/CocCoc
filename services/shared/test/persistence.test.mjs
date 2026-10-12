import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  AI_TABLES,
  LEARNING_TABLES,
  PROGRESS_TABLES,
  createDisabledAiPersistence,
  createDisabledLearningPersistence,
  createDisabledProgressPersistence,
  createMemoryAiPersistence,
  createMemoryLearningPersistence,
  createMemoryProgressPersistence,
} from '../../../.cache/backend-fixtures/foundation-testkit.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const owners = [
  [
    'learning',
    'l_',
    LEARNING_TABLES,
    createMemoryLearningPersistence,
    createDisabledLearningPersistence,
  ],
  [
    'progress',
    'p_',
    PROGRESS_TABLES,
    createMemoryProgressPersistence,
    createDisabledProgressPersistence,
  ],
  ['ai', 'a_', AI_TABLES, createMemoryAiPersistence, createDisabledAiPersistence],
];
const key = {
  userId: 'alice',
  operation: 'completeSession',
  key: '7f1d0e8a-1111-4222-8333-444455556666',
};

for (const [service, prefix, tables, memory, disabled] of owners) {
  test(`${service}: owner table allowlist matches DATA_MODEL prefix and refuses foreign tables`, async () => {
    const store = memory();
    assert.equal(store.service, service);
    assert.ok(tables.length > 0 && tables.every((t) => t.startsWith(prefix)));
    assert.ok(tables.includes(`${prefix}inbox`) && tables.includes(`${prefix}receipts`));
    const foreign = service === 'progress' ? 'l_sessions' : 'p_rewards';
    await assert.rejects(
      store.commitWithReceipt(key, 'h', async (tx) => {
        tx.put(foreign, 'x', {});
        return { statusCode: 200, response: {} };
      }),
      { code: 'FORBIDDEN' },
    );
    await assert.rejects(store.read(foreign, 'x'), { code: 'FORBIDDEN' });
  });

  test(`${service}: memory adapter is never admitted; disabled adapter fails closed`, async () => {
    const store = memory();
    assert.equal(store.kind, 'memory');
    assert.equal(store.admittedForHosting, false);
    await store.ping();
    store.unreachable = true;
    await assert.rejects(store.ping(), { code: 'DB_UNAVAILABLE' });
    const off = disabled();
    assert.deepEqual([off.kind, off.admittedForHosting, off.service], ['disabled', false, service]);
    await assert.rejects(off.ping(), { code: 'DB_UNAVAILABLE' });
    await assert.rejects(
      off.commitWithReceipt(key, 'h', async () => ({ statusCode: 200, response: {} })),
      { code: 'SERVICE_NOT_CONFIGURED' },
    );
    await assert.rejects(
      off.applyInboxEvent({ eventId: 'e', type: 't', bodyHash: 'h' }, async () => {}),
      { code: 'SERVICE_NOT_CONFIGURED' },
    );
  });
}

test('receipts: concurrent same key commits once; same hash replays; changed hash conflicts', async () => {
  const store = createMemoryLearningPersistence();
  let effects = 0;
  const effect = async (tx) => {
    effects++;
    const session = (await tx.get('l_sessions', 's1')) ?? { revision: 0 };
    tx.put('l_sessions', 's1', { revision: session.revision + 1 });
    return { statusCode: 200, response: { revision: session.revision + 1 } };
  };
  const [a, b] = await Promise.all([
    store.commitWithReceipt(key, 'hash-1', effect),
    store.commitWithReceipt(key, 'hash-1', effect),
  ]);
  assert.deepEqual([a.status, b.status].sort(), ['created', 'replayed']);
  assert.deepEqual(a.receipt.response, b.receipt.response);
  assert.equal(effects, 1);
  assert.deepEqual(await store.read('l_sessions', 's1'), { revision: 1 });
  await assert.rejects(store.commitWithReceipt(key, 'hash-2', effect), {
    code: 'IDEMPOTENCY_CONFLICT',
  });
  // Key is scoped by user: another user with the same key is independent.
  assert.equal(
    (await store.commitWithReceipt({ ...key, userId: 'bob' }, 'hash-2', effect)).status,
    'created',
  );
});

test('receipts: failed commit persists neither rows nor receipt; expired receipts are not replayed', async () => {
  let now = 1760000000000;
  const store = createMemoryProgressPersistence(() => now);
  const effect = async (tx) => {
    tx.put('p_rewards', 'alice', { gems: 20 });
    return { statusCode: 201, response: { ok: true } };
  };
  store.failNextCommit = true;
  await assert.rejects(store.commitWithReceipt(key, 'h', effect), { code: 'DB_UNAVAILABLE' });
  assert.equal(store.receiptCount, 0);
  assert.equal(await store.read('p_rewards', 'alice'), null);
  assert.equal((await store.commitWithReceipt(key, 'h', effect)).status, 'created');
  assert.equal((await store.commitWithReceipt(key, 'h', effect)).status, 'replayed');
  now += 31 * 24 * 60 * 60 * 1000;
  assert.equal((await store.commitWithReceipt(key, 'h', effect)).status, 'created');
});

test('inbox: concurrent duplicate applies once; failed effect leaves nothing', async () => {
  const store = createMemoryAiPersistence();
  let effects = 0;
  const entry = {
    eventId: '8a1d0e8a-1111-4222-8333-444455556666',
    type: 'account.deleted.v1',
    bodyHash: 'h1',
  };
  const effect = async (tx) => {
    effects++;
    tx.put('a_usage', 'alice', { purged: true });
  };
  const results = await Promise.all([
    store.applyInboxEvent(entry, effect),
    store.applyInboxEvent(entry, effect),
  ]);
  assert.deepEqual(results.sort(), ['accepted', 'replayed']);
  assert.equal(effects, 1);
  await assert.rejects(store.applyInboxEvent({ ...entry, bodyHash: 'h2' }, effect), {
    code: 'IDEMPOTENCY_CONFLICT',
  });
  const other = { ...entry, eventId: '9a1d0e8a-1111-4222-8333-444455556666' };
  await assert.rejects(
    store.applyInboxEvent(other, async () => {
      throw new Error('boom');
    }),
    /boom/,
  );
  assert.equal(store.inboxSize, 1);
  assert.equal((await store.applyInboxEvent(other, effect)).valueOf(), 'accepted');
});

test('hosted entrypoints and artifacts never import mock or memory fixtures', () => {
  for (const service of ['learning', 'progress', 'ai']) {
    const source = fs.readFileSync(path.join(root, `services/${service}/src/index.ts`), 'utf8');
    assert.doesNotMatch(source, /mock-|memory|testing\//, `${service} index imports a fixture`);
    const bundle = fs.readFileSync(
      path.join(root, `services/${service}/dist/function.mjs`),
      'utf8',
    );
    for (const marker of [
      'MockCompletionStore',
      'MockRewardStore',
      'createMemoryOwnerStore',
      'LOCAL TEST ADAPTER',
      'failNextCommit',
    ]) {
      assert.equal(bundle.includes(marker), false, `${service} artifact contains ${marker}`);
    }
    assert.match(bundle, /SERVICE_NOT_CONFIGURED/);
  }
});
