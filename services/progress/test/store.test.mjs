import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { kit, repoRoot } from './kit.mjs';

test('schema.ts mirrors appwrite/schema/foundation.json for every p_ table', () => {
  const foundation = JSON.parse(
    fs.readFileSync(path.join(repoRoot, 'appwrite/schema/foundation.json'), 'utf8'),
  );
  const tables = foundation.tables.filter((t) => t.owner === 'progress');
  assert.deepEqual(Object.keys(kit.PROGRESS_SCHEMA).sort(), tables.map((t) => t.id).sort());
  assert.deepEqual([...kit.PROGRESS_TABLES].sort(), tables.map((t) => t.id).sort());
  for (const table of tables) {
    const spec = kit.PROGRESS_SCHEMA[table.id];
    assert.equal(spec.mutable, Boolean(table.mutable), table.id);
    for (const c of table.columns) {
      const col = spec.columns[c.key];
      assert.ok(col, `${table.id}.${c.key}`);
      assert.deepEqual(
        [col.type, col.required, col.size, col.min, col.max, col.elements],
        [c.type, c.required !== false, c.size, c.min, c.max, c.elements],
        `${table.id}.${c.key}`,
      );
    }
    assert.equal(Object.keys(spec.columns).length, table.columns.length);
  }
});

test('strict store rejects undeclared columns, bad enums and missing required values', async () => {
  const store = kit.createMemoryProgressPersistence(Date.now, { strictSchema: true });
  const bad = async (row) =>
    assert.rejects(
      store.transact(async (tx) => tx.put('p_blocks', 'x', row)),
      (e) => e.code === 'INTERNAL_ERROR' && e.details.reason === 'ROW_SCHEMA_VIOLATION',
    );
  await bad({ blockerId: 'a' });
  await bad({ blockerId: 'a', blockedId: 'b', extra: 1 });
  await assert.rejects(
    store.transact(async (tx) =>
      tx.put('p_follows', 'f', { fromUserId: 'a', toUserId: 'b', status: 'BLOCKED' }),
    ),
    { code: 'INTERNAL_ERROR' },
  );
  await store.transact(async (tx) => tx.put('p_blocks', 'x', { blockerId: 'a', blockedId: 'b' }));
  const row = await store.read('p_blocks', 'x');
  assert.equal(row.revision, 0);
  assert.ok(row.createdAt && row.updatedAt);
  await assert.rejects(store.read('l_sessions', 'x'), { code: 'FORBIDDEN' });
});

test('optimistic conflict: concurrent read-modify-write never loses an update', async () => {
  const store = kit.createMemoryProgressPersistence(Date.now, { strictSchema: true });
  const id = kit.rowId('p_rewards', 'alice');
  const bump = () =>
    store.transact(async (tx) => {
      const row = await tx.get('p_rewards', id);
      const gems = Number(row?.gems ?? 0);
      tx.put('p_rewards', id, {
        userId: 'alice',
        studyXp: 0,
        leagueXpLifetime: 0,
        gems: gems + 1,
        freezeSlots: 0,
        currentStreak: 0,
        bestStreak: 0,
        streakStartDay: null,
        lastQualifiedDay: null,
        lostStreak: 0,
        lostStreakDay: null,
        streakGoal: 0,
        streakGoalStartDay: null,
      });
    });
  await bump();
  let injected = false;
  store.beforeCommit = async () => {
    if (injected) return;
    injected = true;
    store.beforeCommit = undefined;
    await bump(); // a competing writer commits between this attempt's read and commit
  };
  await bump();
  const row = await store.read('p_rewards', id);
  assert.equal(row.gems, 3);
  assert.equal(row.revision, 2);
});

test('hosted entry selects the disabled adapter unless explicitly opted into Appwrite', () => {
  const source = fs.readFileSync(path.join(repoRoot, 'services/progress/src/index.ts'), 'utf8');
  assert.match(source, /COC_PROGRESS_PERSISTENCE'\] === 'appwrite'/);
  assert.doesNotMatch(source, /memory|testing\//);
  const off = kit.createDisabledProgressPersistence();
  assert.deepEqual([off.kind, off.admittedForHosting], ['disabled', false]);
  assert.throws(() =>
    kit.createAppwriteProgressPersistence({
      endpoint: 'http://x',
      projectId: 'p',
      apiKey: 'k',
      admitted: true,
    }),
  );
});
