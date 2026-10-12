import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { CANONICAL_TABLE_COUNT, PREFIXES, VARCHAR_MAX, buildPlan, columnDrift, deriveDeclaration, diffLive, parseColumnToken, parseTableRows, storageFor, validateDeclaration } from '../scripts/schema-lib.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');
const dataModel = read('docs/data/DATA_MODEL.md');
const permissions = read('docs/data/PERMISSIONS.md');
const declaration = () => JSON.parse(read('appwrite/schema/foundation.json'));
const derived = deriveDeclaration(dataModel, permissions);
const table = (decl, id) => decl.tables.find((t) => t.id === id);
const column = (decl, id, key) => table(decl, id).columns.find((c) => c.key === key);
const cleanEnv = Object.fromEntries(Object.entries(process.env).filter(([key]) => !key.startsWith('APPWRITE_') && key !== 'ALLOW_SCHEMA_APPLY' && key !== 'ALLOW_LIVE_PROBE'));
const runScript = (args, env = {}) => spawnSync(process.execPath, ['appwrite/scripts/schema.mjs', ...args], { cwd: root, env: { ...cleanEnv, ...env }, encoding: 'utf8' });

test('committed declaration matches every canonical table, column, index and permission in docs/data', () => {
  assert.deepEqual(validateDeclaration(declaration(), derived), []);
  const docIds = parseTableRows(dataModel).map((row) => row.id);
  assert.equal(docIds.length, CANONICAL_TABLE_COUNT);
  assert.deepEqual(declaration().tables.map((t) => t.id), docIds);
  for (const t of declaration().tables) assert.ok(t.id.startsWith(PREFIXES[t.owner]), t.id);
});

test('doc-explicit constraints are carried exactly', () => {
  const decl = declaration();
  assert.deepEqual(column(decl, 'l_sessions', 'bundleSnapshotJson'), { key: 'bundleSnapshotJson', type: 'string', size: 65536, required: false });
  assert.deepEqual(column(decl, 'l_enrollments', 'frontierNodeOrder'), { key: 'frontierNodeOrder', type: 'integer', min: 0, max: 9999 });
  assert.deepEqual(column(decl, 'p_profiles', 'dailyGoal'), { key: 'dailyGoal', type: 'integer', min: 5, max: 20, allowed: [5, 10, 15, 20] });
  assert.deepEqual(column(decl, 'l_content_versions', 'manifestSha256'), { key: 'manifestSha256', type: 'string', size: 64 });
  assert.deepEqual(column(decl, 'a_jobs', 'dispatchState').elements, ['NOT_SENT', 'CLAIMED', 'SENT', 'AMBIGUOUS']);
  assert.deepEqual(column(decl, 'a_voice_sessions', 'consumedSeconds'), { key: 'consumedSeconds', type: 'integer', min: 0, max: 180 });
  assert.deepEqual(table(decl, 'p_league_members').indexes.find((i) => i.type === 'key').columns, ['weekId', 'cohortId', 'eligibleXp', 'lastXpAt', 'userId']);
  assert.deepEqual(table(decl, 'p_reward_ledger').indexes.filter((i) => i.type === 'unique').map((i) => i.columns), [['eventId', 'kind'], ['userId', 'completionId', 'kind']]);
});

test('shape references resolve to the documented source table', () => {
  const decl = declaration();
  const keys = (id) => table(decl, id).columns.map((c) => c.key);
  assert.deepEqual(keys('p_outbox'), keys('l_outbox'));
  for (const id of ['l_outbox', 'p_outbox', 'a_outbox']) assert.ok(table(decl, id).indexes.some((i) => i.type === 'unique' && i.columns.join() === 'eventId'), `${id} unique(eventId)`);
  assert.deepEqual(keys('a_outbox'), keys('l_outbox'));
  assert.deepEqual(keys('p_receipts'), keys('l_receipts'));
  assert.deepEqual(keys('a_receipts'), keys('l_receipts'));
  assert.deepEqual(keys('a_inbox'), ['eventId', 'bodyHash', 'appliedAt', 'revision', 'createdAt', 'updatedAt']);
});

test('mutable rows carry revision/createdAt/updatedAt; append-only/immutable rows do not get invented fields', () => {
  const decl = declaration();
  for (const id of ['p_reward_ledger', 'p_freeze_ledger', 'p_zone_history', 'p_achievements', 'p_item_ledger', 'p_year_reviews']) {
    assert.equal(table(decl, id).mutable, false, id);
    assert.ok(!table(decl, id).columns.some((c) => c.key === 'revision'), id);
  }
  for (const t of decl.tables.filter((x) => x.mutable)) for (const key of ['revision', 'createdAt', 'updatedAt']) assert.ok(t.columns.some((c) => c.key === key), `${t.id}.${key}`);
});

test('permissions: no client table grants, row security everywhere, only owner read on p_notifications', () => {
  const decl = declaration();
  for (const t of decl.tables) {
    assert.deepEqual(t.permissions, [], t.id);
    assert.equal(t.rowSecurity, true, t.id);
    assert.deepEqual(t.rowPermissions, t.id === 'p_notifications' ? [{ action: 'read', role: 'user', valueFrom: 'userId' }] : [], t.id);
  }
  assert.deepEqual(decl.buckets, derived.buckets);
  assert.equal(decl.buckets[0].fileSecurity, true);
});

test('validator rejects drift from docs (fail closed)', () => {
  const cases = [
    ['invented column', (d) => table(d, 'l_courses').columns.push({ key: 'slug', type: 'string', size: 36 }), /invented column/],
    ['missing column', (d) => table(d, 'a_usage').columns.pop(), /documented column missing/],
    ['wrong size', (d) => (column(d, 'p_profiles', 'nickname').size = 64), /p_profiles\.nickname/],
    ['nullable dropped', (d) => delete column(d, 'a_jobs', 'resultJson').required, /a_jobs\.resultJson/],
    ['table grant', (d) => table(d, 'p_rewards').permissions.push('read("any")'), /table-level client permissions/],
    ['row security off', (d) => (table(d, 'l_answers').rowSecurity = false), /rowSecurity/],
    ['client row write', (d) => table(d, 'p_notifications').rowPermissions.push({ action: 'update', role: 'user', valueFrom: 'userId' }), /client row write grant/],
    ['missing index', (d) => table(d, 'l_outbox').indexes.pop(), /l_outbox: indexes/],
    ['index on absent column', (d) => table(d, 'l_inbox').indexes.push({ key: 'k_x', type: 'key', columns: ['nope'] }), /absent column/],
    ['non-canonical table', (d) => d.tables.push({ ...table(d, 'l_inbox'), id: 'l_cache' }), /not canonical/],
    ['missing table', (d) => d.tables.splice(5, 1), /missing table/],
    ['wrong owner', (d) => (table(d, 'a_usage').owner = 'progress'), /owner/],
    ['bucket opened', (d) => d.buckets[0].permissions.push('read("any")'), /learning-assets/],
  ];
  for (const [name, mutate, expected] of cases) {
    const d = declaration();
    mutate(d);
    const problems = validateDeclaration(d, derived);
    assert.ok(problems.some((p) => expected.test(p)), `${name}: ${problems.join(' | ')}`);
  }
});

test('doc parser fails closed on unknown annotations and reworded references', () => {
  assert.deepEqual(parseColumnToken('stage0..4'), { key: 'stage', min: 0, max: 4 });
  assert.deepEqual(parseColumnToken('resultJson nullable≤32768'), { key: 'resultJson', nullable: true, size: 32768 });
  assert.deepEqual(parseColumnToken('target10'), { key: 'target', allowed: [10] });
  assert.throws(() => parseColumnToken('score float'), /Unrecognised column annotation/);
  assert.throws(() => deriveDeclaration(dataModel.replace('| same receipt shape, own commands only |', '| receipt-like |'), permissions), /convention|annotation|Unparseable/);
  assert.throws(() => deriveDeclaration(dataModel, permissions.replace('read(Role.user(userId)); no client writes', 'read(Role.users())')), /p_notifications/);
});

test('storage mapping never exceeds the pinned SDK varchar maximum', () => {
  for (const t of declaration().tables)
    for (const c of t.columns) {
      const s = storageFor(c);
      assert.ok(s.method, `${t.id}.${c.key}`);
      if (s.method === 'createVarcharColumn') assert.ok(s.size <= VARCHAR_MAX && s.size === c.size);
    }
  assert.equal(storageFor({ type: 'string', size: 16384 }).method, 'createMediumtextColumn');
  assert.equal(storageFor({ type: 'string', size: 8192 }).method, 'createTextColumn');
  const plan = buildPlan(declaration());
  assert.equal(plan.totals.tables, CANONICAL_TABLE_COUNT);
  assert.match(plan.declarationSha256, /^[0-9a-f]{64}$/);
});

test('dry run is the default, offline and ignores Appwrite environment', () => {
  const result = runScript([], { APPWRITE_PROJECT_ENV: 'test', ALLOW_SCHEMA_APPLY: 'reviewed-test-project', APPWRITE_ENDPOINT: 'https://127.0.0.1:9/v1', APPWRITE_PROJECT_ID: 'x', APPWRITE_API_KEY: 'x' });
  assert.equal(result.status, 0, result.stderr);
  const output = JSON.parse(result.stdout);
  assert.equal(output.mode, 'DRY_RUN_NO_NETWORK');
  assert.equal(output.totals.tables, CANONICAL_TABLE_COUNT);
});

test('apply path stays guarded before any client is created', () => {
  const denied = [
    [{}, /explicitly admitted test project/],
    [{ APPWRITE_PROJECT_ENV: 'production', ALLOW_SCHEMA_APPLY: 'reviewed-test-project' }, /explicitly admitted test project/],
    [{ APPWRITE_PROJECT_ENV: 'test' }, /explicitly admitted test project/],
    [{ APPWRITE_PROJECT_ENV: 'test', ALLOW_SCHEMA_APPLY: 'reviewed-test-project' }, /Missing private Appwrite test configuration/],
    [{ APPWRITE_PROJECT_ENV: 'test', ALLOW_SCHEMA_APPLY: 'reviewed-test-project', APPWRITE_ENDPOINT: 'http://insecure.invalid/v1', APPWRITE_PROJECT_ID: 'p' }, /Missing private Appwrite test configuration/],
  ];
  for (const [env, expected] of denied) {
    const result = runScript(['--apply'], env);
    assert.notEqual(result.status, 0, JSON.stringify(env));
    assert.match(result.stderr, expected);
  }
});

// Live snapshot exactly as Appwrite Cloud 1.8 (TablesDB, sgp region) reported it for the admitted test project:
// varchar columns report type "varchar" with size, text/mediumtext report their own type, enums report
// type "string" + format "enum", indexes report key/type/columns/status.
function liveFrom(decl, mutate = () => {}) {
  const live = { database: true, tables: {}, buckets: {} };
  for (const t of decl.tables) {
    live.tables[t.id] = {
      permissions: [],
      rowSecurity: true,
      columns: t.columns.map((c) => {
        const target = storageFor(c);
        const type = { createVarcharColumn: 'varchar', createTextColumn: 'text', createMediumtextColumn: 'mediumtext', createEnumColumn: 'string', createIntegerColumn: 'integer', createBooleanColumn: 'boolean', createDatetimeColumn: 'datetime' }[target.method];
        return {
          key: c.key,
          type,
          status: 'available',
          required: c.required !== false,
          array: false,
          ...(target.size ? { size: target.size } : {}),
          ...(c.type === 'enum' ? { format: 'enum', elements: c.elements } : {}),
          ...(c.type === 'integer' ? { min: c.min ?? -9223372036854775808, max: c.max ?? 9223372036854775807 } : {}),
        };
      }),
      indexes: t.indexes.map((i) => ({ key: i.key, type: i.type, columns: i.columns, status: 'available', lengths: i.columns.map(() => 0) })),
    };
  }
  for (const b of decl.buckets) live.buckets[b.id] = { permissions: [], fileSecurity: true };
  mutate(live);
  return live;
}

test('live diff: a fully applied project reports no changes (idempotent apply)', () => {
  const diff = diffLive(declaration(), liveFrom(declaration()));
  assert.deepEqual(diff, { missing: [], drift: [], extra: [], pending: [] });
});

test('live diff: empty project plans every resource as additive work', () => {
  const decl = declaration();
  const diff = diffLive(decl, { database: false, tables: {}, buckets: {} });
  const plan = buildPlan(decl).totals;
  assert.equal(diff.missing.length, 1 + plan.tables + plan.columns + plan.indexes + plan.buckets);
  assert.deepEqual(diff.drift, []);
});

test('live diff: drift and extras are reported, never treated as additive', () => {
  const decl = declaration();
  const cases = [
    ['varchar size', (l) => (l.tables.p_profiles.columns.find((c) => c.key === 'nickname').size = 64), 'drift', /size/],
    ['required flipped', (l) => (l.tables.a_jobs.columns.find((c) => c.key === 'resultJson').required = true), 'drift', /required/],
    ['enum elements', (l) => (l.tables.a_jobs.columns.find((c) => c.key === 'dispatchState').elements = ['NOT_SENT']), 'drift', /elements/],
    ['enum lost format', (l) => delete l.tables.a_jobs.columns.find((c) => c.key === 'dispatchState').format, 'drift', /not an enum/],
    ['integer bound', (l) => (l.tables.p_profiles.columns.find((c) => c.key === 'dailyGoal').max = 50), 'drift', /max/],
    ['wrong family', (l) => (l.tables.l_sessions.columns.find((c) => c.key === 'bundleSnapshotJson').type = 'varchar'), 'drift', /type varchar/],
    ['table grant', (l) => l.tables.p_rewards.permissions.push('read("any")'), 'drift', /permissions/],
    ['row security off', (l) => (l.tables.l_answers.rowSecurity = false), 'drift', /rowSecurity/],
    ['index columns', (l) => (l.tables.l_outbox.indexes[0].columns = ['status']), 'drift', /\(status\)/],
    ['bucket opened', (l) => l.buckets['learning-assets'].permissions.push('read("any")'), 'drift', /fileSecurity/],
    ['extra table', (l) => (l.tables.l_cache = { permissions: [], rowSecurity: true, columns: [], indexes: [] }), 'extra', /l_cache/],
    ['extra column', (l) => l.tables.l_courses.columns.push({ key: 'slug', type: 'varchar', size: 36, status: 'available', required: true }), 'extra', /slug/],
    ['missing index', (l) => l.tables.l_inbox.indexes.pop(), 'missing', /index/],
    ['pending column', (l) => (l.tables.l_inbox.columns[0].status = 'processing'), 'pending', /processing/],
  ];
  for (const [name, mutate, bucket, expected] of cases) {
    const diff = diffLive(decl, liveFrom(decl, mutate));
    assert.ok(diff[bucket].some((item) => expected.test(JSON.stringify(item))), `${name}: ${JSON.stringify(diff)}`);
  }
});

test('columnDrift accepts the older generic "string" family but rejects cross-family types', () => {
  assert.equal(columnDrift({ key: 'k', type: 'string', size: 36 }, { type: 'string', size: 36, required: true }), '');
  assert.equal(columnDrift({ key: 'k', type: 'string', size: 8192 }, { type: 'text', required: true }), '');
  assert.match(columnDrift({ key: 'k', type: 'string', size: 36 }, { type: 'integer', required: true }), /type integer/);
  assert.match(columnDrift({ key: 'k', type: 'string', size: 36 }, { type: 'string', format: 'enum', size: 36, required: true }), /enum/);
});

test('live drift check is guarded like apply (test project + private config required)', () => {
  for (const [env, expected] of [
    [{}, /explicitly admitted test project/],
    [{ APPWRITE_PROJECT_ENV: 'production' }, /explicitly admitted test project/],
    [{ APPWRITE_PROJECT_ENV: 'test' }, /Missing private Appwrite test configuration/],
  ]) {
    const result = runScript(['--check-live'], env);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, expected);
  }
});

test('live probes refuse to run without the explicit test-project admission', () => {
  for (const env of [{}, { APPWRITE_PROJECT_ENV: 'test' }, { APPWRITE_PROJECT_ENV: 'production', ALLOW_LIVE_PROBE: 'reviewed-test-project' }]) {
    const result = spawnSync(process.execPath, ['appwrite/scripts/live-probe.mjs'], { cwd: root, env: { ...cleanEnv, ...env }, encoding: 'utf8' });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /explicitly admitted test project/);
  }
});

test('M003 promo codes and mock ads: server-only, one redemption per user, idempotent capped ad events', () => {
  const decl = declaration();
  for (const id of ['p_promo_codes', 'p_promo_redemptions', 'p_ad_events']) {
    const t = table(decl, id);
    assert.equal(t.owner, 'progress', id);
    assert.deepEqual([t.permissions, t.rowPermissions, t.rowSecurity], [[], [], true], `${id} must have no client grant`);
  }
  assert.deepEqual(column(decl, 'p_promo_codes', 'codeHash'), { key: 'codeHash', type: 'string', size: 64 });
  assert.equal(column(decl, 'p_promo_codes', 'code'), undefined, 'plaintext promo code must never be stored');
  assert.deepEqual(column(decl, 'p_promo_codes', 'rewardType').elements, ['SUPER_DAYS', 'GEMS', 'ITEM']);
  assert.deepEqual(table(decl, 'p_promo_codes').indexes.filter((i) => i.type === 'unique').map((i) => i.columns), [['promoId'], ['codeHash']]);
  assert.equal(column(decl, 'p_promo_codes', 'maxRedemptions').required, false);
  assert.deepEqual(table(decl, 'p_promo_redemptions').indexes.filter((i) => i.type === 'unique').map((i) => i.columns), [['redemptionId'], ['userId', 'promoId']]);
  assert.equal(table(decl, 'p_promo_redemptions').mutable, false);
  assert.deepEqual(column(decl, 'p_ad_events', 'placement').elements, ['LESSON_END_INTERSTITIAL', 'REWARDED_GEMS', 'REWARDED_ENERGY_REFILL']);
  assert.deepEqual(column(decl, 'p_ad_events', 'kind').elements, ['IMPRESSION', 'REWARDED_COMPLETION']);
  assert.deepEqual(column(decl, 'p_ad_events', 'dailyIndex'), { key: 'dailyIndex', type: 'integer', min: 1, max: 20 });
  assert.deepEqual(table(decl, 'p_ad_events').indexes.filter((i) => i.type === 'unique').map((i) => i.columns), [['adEventId'], ['userId', 'learningDay', 'placement', 'kind', 'dailyIndex']]);
  assert.equal(table(decl, 'p_ad_events').mutable, false);
  // Rewards reuse existing ledger kinds so M003 stays additive (no enum change on applied tables).
  assert.ok(column(decl, 'p_reward_ledger', 'kind').elements.includes('ADJUST'));
  assert.ok(column(decl, 'p_entitlements', 'source').elements.includes('PROMO'));
  assert.ok(column(decl, 'p_purchases', 'platform').elements.includes('SIMULATION'));
});
