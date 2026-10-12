// Gated LIVE tests of the durable Learning adapter against the Appwrite TEST project
// (P1-FOUND-002 learning half). Never part of deterministic CI. Enable with:
//   COC_LIVE_LEARNING_APPWRITE=1 APPWRITE_ENDPOINT=https://... APPWRITE_PROJECT_ID=... APPWRITE_API_KEY=...
// (NODE_USE_ENV_PROXY=1 when the key is injected by an egress proxy). Every row created here uses a
// synthetic user/event ID and is deleted in `after`.
import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { Client, Query, TablesDB } from 'node-appwrite';
import { loadKit } from './helpers/kit.mjs';

const enabled = process.env.COC_LIVE_LEARNING_APPWRITE === '1';
const skip = enabled
  ? false
  : 'live Appwrite gated: set COC_LIVE_LEARNING_APPWRITE=1 and APPWRITE_* env';
const endpoint = process.env.APPWRITE_ENDPOINT ?? 'https://sgp.cloud.appwrite.io/v1';
const projectId = process.env.APPWRITE_PROJECT_ID ?? '';
const apiKey = process.env.APPWRITE_API_KEY ?? '';
const databaseId = 'cocenglish';
const runId = `t${Date.now().toString(36)}${randomUUID().slice(0, 6)}`;
const created = [];
let tables;
const now = () => new Date().toISOString();

async function kitAndStore(nowMs) {
  const kit = await loadKit('appwrite-live');
  tables ??= new TablesDB(new Client().setEndpoint(endpoint).setProject(projectId).setKey(apiKey));
  const store = kit.createAppwriteLearningPersistence(
    {
      endpoint,
      projectId,
      apiKey,
      databaseId,
      admittedForHosting: false,
      ...(nowMs ? { nowMs } : {}),
    },
    tables,
  );
  return { kit, store };
}
const track = (tableId, rowId) => created.push({ tableId, rowId });
const slotRow = (userId, sessionId, revision = 0) => ({
  userId,
  courseId: 'vi_en',
  sessionId,
  expiresAt: new Date(Date.now() + 3600_000).toISOString(),
  revision,
  createdAt: now(),
  updatedAt: now(),
});

after(async () => {
  if (!enabled || !tables) return;
  for (const { tableId, rowId } of created) {
    await tables.deleteRow({ databaseId, tableId, rowId }).catch(() => undefined);
  }
  // Safety net: anything this run created under its synthetic user prefix.
  for (const tableId of ['l_active_slots', 'l_receipts']) {
    const rows = await tables
      .listRows({
        databaseId,
        tableId,
        queries: [Query.startsWith('userId', runId), Query.limit(100)],
      })
      .catch(() => ({ rows: [] }));
    for (const row of rows.rows)
      await tables.deleteRow({ databaseId, tableId, rowId: row.$id }).catch(() => undefined);
  }
});

test(
  'live: ping, create, read-your-writes, update, list and delete through transactions',
  { skip },
  async () => {
    const { kit, store } = await kitAndStore();
    await store.ping();
    const userId = `${runId}-a`;
    const id = kit.ids.slot(userId, 'vi_en');
    track('l_active_slots', id);
    await store.transact(async (tx) => {
      assert.equal(await tx.get('l_active_slots', id), null);
      tx.put('l_active_slots', id, slotRow(userId, 's1'));
      assert.equal((await tx.get('l_active_slots', id)).sessionId, 's1');
    });
    const row = await store.read('l_active_slots', id);
    assert.equal(row.sessionId, 's1');
    assert.match(row.expiresAt, /Z$/, 'datetimes normalized to ISO Z');
    assert.equal(
      Object.keys(row).some((k) => k.startsWith('$')),
      false,
    );
    await store.transact(async (tx) => {
      const current = await tx.get('l_active_slots', id);
      tx.put('l_active_slots', id, { ...current, sessionId: 's2', revision: current.revision + 1 });
    });
    assert.equal((await store.read('l_active_slots', id)).sessionId, 's2');
    const listed = await store.list('l_active_slots', { equal: { userId }, limit: 10 });
    assert.equal(listed.total, 1);
    assert.equal(listed.items[0].id, id);
    await store.transact(async (tx) => tx.remove('l_active_slots', id));
    assert.equal(await store.read('l_active_slots', id), null);
  },
);

test(
  'live: concurrent writers on one row -> exactly one commit per attempt, loser retries on fresh state',
  { skip },
  async () => {
    const { kit, store } = await kitAndStore();
    const userId = `${runId}-b`;
    const id = kit.ids.slot(userId, 'vi_en');
    track('l_active_slots', id);
    await store.transact(async (tx) => tx.put('l_active_slots', id, slotRow(userId, 'start')));
    let runs = 0;
    const bump = (label) =>
      store.transact(async (tx) => {
        runs++;
        const current = await tx.get('l_active_slots', id);
        await new Promise((r) => setTimeout(r, 50));
        tx.put('l_active_slots', id, {
          ...current,
          sessionId: `${current.sessionId}+${label}`,
          revision: current.revision + 1,
        });
      });
    await Promise.all([bump('x'), bump('y')]);
    const final = await store.read('l_active_slots', id);
    assert.equal(final.revision, 2, 'both increments applied, none lost');
    assert.ok(/start\+(x\+y|y\+x)$/.test(final.sessionId), final.sessionId);
    assert.ok(runs >= 3, `loser re-ran its effect (runs=${runs})`);
  },
);

test(
  'live: receipts — concurrent same key commits once; replay; changed body conflicts; failed effect leaves nothing',
  { skip },
  async () => {
    const { kit, store } = await kitAndStore();
    const userId = `${runId}-c`;
    const key = { userId, operation: 'liveProbe', key: randomUUID() };
    track('l_receipts', kit.ids.receipt(userId, key.operation, key.key));
    const slot = kit.ids.slot(userId, 'vi_en');
    track('l_active_slots', slot);
    let effects = 0;
    const effect = async (tx) => {
      effects++;
      tx.put('l_active_slots', slot, slotRow(userId, 'receipt'));
      return { statusCode: 200, response: { ok: true } };
    };
    const [a, b] = await Promise.all([
      store.commitWithReceipt(key, 'hash-1', effect),
      store.commitWithReceipt(key, 'hash-1', effect),
    ]);
    assert.deepEqual([a.status, b.status].sort(), ['created', 'replayed']);
    assert.deepEqual(a.receipt.response, { ok: true });
    assert.equal(effects, 1);
    // A second process (fresh adapter, no shared lock) still replays from the durable receipt.
    const { store: other } = await kitAndStore();
    assert.equal((await other.commitWithReceipt(key, 'hash-1', effect)).status, 'replayed');
    await assert.rejects(other.commitWithReceipt(key, 'hash-2', effect), {
      code: 'IDEMPOTENCY_CONFLICT',
    });
    const failingKey = { ...key, key: randomUUID() };
    track('l_receipts', kit.ids.receipt(userId, failingKey.operation, failingKey.key));
    await assert.rejects(
      store.commitWithReceipt(failingKey, 'h', async (tx) => {
        tx.put('l_active_slots', slot, slotRow(userId, 'must-not-persist', 9));
        throw new Error('boom');
      }),
      /boom/,
    );
    assert.equal((await store.read('l_active_slots', slot)).sessionId, 'receipt');
    assert.equal(
      await store.read('l_receipts', kit.ids.receipt(userId, failingKey.operation, failingKey.key)),
      null,
    );
  },
);

test(
  'live: cross-process race on a fresh receipt key (no shared lock) -> one effect commits',
  { skip },
  async () => {
    const { kit, store: p1 } = await kitAndStore();
    const { store: p2 } = await kitAndStore();
    const userId = `${runId}-d`;
    const key = { userId, operation: 'liveRace', key: randomUUID() };
    track('l_receipts', kit.ids.receipt(userId, key.operation, key.key));
    const slot = kit.ids.slot(userId, 'vi_en');
    track('l_active_slots', slot);
    const effect = (label) => async (tx) => {
      const current = await tx.get('l_active_slots', slot);
      tx.put('l_active_slots', slot, {
        ...(current ?? slotRow(userId, '')),
        sessionId: `${current?.sessionId ?? ''}${label}`,
        revision: (current?.revision ?? -1) + 1,
      });
      return { statusCode: 200, response: { label } };
    };
    const results = await Promise.all([
      p1.commitWithReceipt(key, 'same', effect('A')),
      p2.commitWithReceipt(key, 'same', effect('B')),
    ]);
    assert.deepEqual(results.map((r) => r.status).sort(), ['created', 'replayed']);
    assert.deepEqual(results[0].receipt.response, results[1].receipt.response);
    const row = await p1.read('l_active_slots', slot);
    assert.equal(row.revision, 0, 'exactly one effect committed');
    assert.ok(['A', 'B'].includes(row.sessionId));
  },
);

test('live: inbox — duplicate event applies once, substitution rejected', { skip }, async () => {
  const { store } = await kitAndStore();
  const eventId = randomUUID();
  track('l_inbox', eventId);
  const entry = { eventId, type: 'account.deleted.v1', bodyHash: 'h1' };
  let effects = 0;
  const effect = async () => {
    effects++;
  };
  assert.equal(await store.applyInboxEvent(entry, effect), 'accepted');
  assert.equal(await store.applyInboxEvent(entry, effect), 'replayed');
  await assert.rejects(store.applyInboxEvent({ ...entry, bodyHash: 'h2' }, effect), {
    code: 'IDEMPOTENCY_CONFLICT',
  });
  assert.equal(effects, 1);
});
