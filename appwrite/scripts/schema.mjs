// Appwrite TablesDB schema plan/apply for all canonical tables.
// Default: offline dry run that validates appwrite/schema/foundation.json against docs/data and prints the plan.
// --apply: additive create-if-absent on an explicitly admitted TEST project only (never run by CI).
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Client, Query, Storage, TablesDB, TablesDBIndexType } from 'node-appwrite';
import { buildPlan, deriveDeclaration, diffLive, storageFor, validateDeclaration } from './schema-lib.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');
const declaration = JSON.parse(read('appwrite/schema/foundation.json'));
const derived = deriveDeclaration(read('docs/data/DATA_MODEL.md'), read('docs/data/PERMISSIONS.md'));
const problems = validateDeclaration(declaration, derived);
if (problems.length) {
  console.error(JSON.stringify({ status: 'FAIL', mode: 'VALIDATION', problems }, null, 2));
  process.exit(1);
}
const plan = buildPlan(declaration);
// Resolve every SDK method the apply path would call against the pinned node-appwrite API (offline introspection).
const requiredMethods = new Set(['get', 'create', 'listTables', 'createTable', 'listColumns', 'listIndexes', 'createIndex']);
for (const table of plan.tables) for (const column of table.columns) requiredMethods.add(column.method);
const missing = [...requiredMethods].filter((name) => typeof TablesDB.prototype[name] !== 'function');
for (const name of ['getBucket', 'listBuckets', 'createBucket']) if (typeof Storage.prototype[name] !== 'function') missing.push(`Storage.${name}`);
if (missing.length || !TablesDBIndexType.Unique || !TablesDBIndexType.Key) {
  console.error(JSON.stringify({ status: 'FAIL', mode: 'SDK_RESOLUTION', missing }));
  process.exit(1);
}

const apply = process.argv.includes('--apply');
const checkLive = process.argv.includes('--check-live');
if (!apply && !checkLive) {
  console.log(
    JSON.stringify(
      {
        status: 'PASS',
        mode: 'DRY_RUN_NO_NETWORK',
        docsMatch: 'declaration equals tables/columns/indexes/permissions derived from docs/data',
        sdkMethodsResolved: [...requiredMethods].sort(),
        ...plan,
        notProven: 'live column/index availability, row-width limits, API-key scopes and permission probes require an admitted test project',
      },
      null,
      2,
    ),
  );
  process.exitCode = 0;
} else {
  await live();
}


// Live modes. --check-live is read-only (drift check); --apply is additive create-if-absent and
// never drops or modifies existing resources: drift aborts for human review.
async function live() {
  if (process.env.APPWRITE_PROJECT_ENV !== 'test' || (apply && process.env.ALLOW_SCHEMA_APPLY !== 'reviewed-test-project')) throw new Error('Apply only to an explicitly admitted test project.');
  const { APPWRITE_ENDPOINT: endpoint, APPWRITE_PROJECT_ID: project, APPWRITE_API_KEY: key } = process.env;
  if (!endpoint?.startsWith('https://') || !project || !key) throw new Error('Missing private Appwrite test configuration.');
  const client = new Client().setEndpoint(endpoint).setProject(project).setKey(key);
  const tables = new TablesDB(client);
  const storage = new Storage(client);
  const databaseId = declaration.databaseId;
  const log = (event) => console.error(JSON.stringify({ t: new Date().toISOString(), ...event }));
  const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
  const page = async (fetch, field) => {
    const items = [];
    for (let offset = 0; ; offset += 100) {
      const res = await fetch([Query.limit(100), Query.offset(offset)]);
      items.push(...res[field]);
      if (res[field].length < 100) return items;
    }
  };
  async function snapshot() {
    const snap = { database: false, tables: {}, buckets: {} };
    try {
      await tables.get({ databaseId });
      snap.database = true;
    } catch (error) {
      if (error.code !== 404) throw error;
    }
    if (snap.database) {
      const list = await page((queries) => tables.listTables({ databaseId, queries }), 'tables');
      await pool(list, 6, async (t) => {
        const args = { databaseId, tableId: t.$id };
        const [columns, indexes] = await Promise.all([page((queries) => tables.listColumns({ ...args, queries }), 'columns'), page((queries) => tables.listIndexes({ ...args, queries }), 'indexes')]);
        snap.tables[t.$id] = { permissions: t.$permissions, rowSecurity: t.rowSecurity, columns, indexes };
      });
    }
    for (const bucket of declaration.buckets) {
      try {
        const b = await storage.getBucket({ bucketId: bucket.id });
        snap.buckets[bucket.id] = { permissions: b.$permissions, fileSecurity: b.fileSecurity };
      } catch (error) {
        if (error.code !== 404) throw error;
      }
    }
    return snap;
  }
  async function pool(items, size, fn) {
    const queue = [...items];
    await Promise.all(Array.from({ length: size }, async () => { while (queue.length) await fn(queue.shift()); }));
  }
  const retrying = async (fn, label) => {
    for (let attempt = 0; ; attempt++) {
      try {
        return await fn();
      } catch (error) {
        if (error.code === 409) return log({ already: label });
        if ((error.code === 429 || error.code >= 500) && attempt < 5) { await sleep(2000 * (attempt + 1)); continue; }
        throw new Error(`${label}: ${error.code} ${error.type ?? ''} ${error.message}`);
      }
    }
  };
  const report = (diff) => ({ missing: diff.missing.length, drift: diff.drift, extra: diff.extra, pending: diff.pending.length });
  let diff = diffLive(declaration, await snapshot());
  if (checkLive && !apply) {
    const ok = !diff.missing.length && !diff.drift.length && !diff.extra.length && !diff.pending.length;
    console.log(JSON.stringify({ status: ok ? 'PASS' : 'DRIFT', mode: 'LIVE_DRIFT_CHECK', declarationSha256: plan.declarationSha256, project, ...report(diff), missingItems: diff.missing.slice(0, 50), pendingItems: diff.pending.slice(0, 50) }, null, 2));
    process.exitCode = ok ? 0 : 1;
    return;
  }
  if (diff.drift.length) throw new Error(`Schema drift requires review (nothing was changed): ${JSON.stringify(diff.drift)}`);
  const created = { database: 0, tables: 0, columns: 0, indexes: 0, buckets: 0 };
  const byTable = new Map(declaration.tables.map((t) => [t.id, t]));
  if (diff.missing.some((m) => m.kind === 'database')) {
    await retrying(() => tables.create({ databaseId, name: 'CocEnglish', enabled: true }), 'database');
    created.database++;
  }
  const missingTables = diff.missing.filter((m) => m.kind === 'table');
  await pool(missingTables, 4, async (m) => {
    const table = byTable.get(m.id);
    await retrying(() => tables.createTable({ databaseId, tableId: table.id, name: table.id, permissions: table.permissions, rowSecurity: table.rowSecurity, enabled: true }), `table ${table.id}`);
    created.tables++;
  });
  const missingColumns = diff.missing.filter((m) => m.kind === 'column');
  const columnsByTable = Object.groupBy(missingColumns, (m) => m.table);
  await pool(Object.entries(columnsByTable), 6, async ([tableId, list]) => {
    const table = byTable.get(tableId);
    for (const m of list) {
      const column = table.columns.find((c) => c.key === m.key);
      const target = storageFor(column);
      const common = { databaseId, tableId, key: column.key, required: column.required !== false };
      const call = {
        createVarcharColumn: () => tables.createVarcharColumn({ ...common, size: target.size }),
        createTextColumn: () => tables.createTextColumn(common),
        createMediumtextColumn: () => tables.createMediumtextColumn(common),
        createEnumColumn: () => tables.createEnumColumn({ ...common, elements: column.elements }),
        createIntegerColumn: () => tables.createIntegerColumn({ ...common, ...(column.min !== undefined ? { min: column.min } : {}), ...(column.max !== undefined ? { max: column.max } : {}) }),
        createBooleanColumn: () => tables.createBooleanColumn(common),
        createDatetimeColumn: () => tables.createDatetimeColumn(common),
      }[target.method];
      await retrying(call, `column ${tableId}.${column.key}`);
      created.columns++;
    }
  });
  if (created.columns) log({ createdColumns: created.columns });
  // Indexes need available columns: wait (bounded) for columns, then create missing indexes.
  const waitAvailable = async (kind) => {
    for (let i = 0; i < 90; i++) {
      diff = diffLive(declaration, await snapshot());
      const failed = diff.pending.filter((p) => p.kind === kind && ['failed', 'stuck'].includes(p.status));
      if (failed.length) throw new Error(`${kind} failed: ${JSON.stringify(failed)}`);
      const waiting = diff.pending.filter((p) => p.kind === kind);
      if (!waiting.length) return;
      log({ waiting: kind, count: waiting.length });
      await sleep(4000);
    }
    throw new Error(`${kind}s still pending; rerun apply to resume (idempotent).`);
  };
  if (created.columns || diff.pending.some((p) => p.kind === 'column')) await waitAvailable('column');
  else diff = diffLive(declaration, await snapshot());
  const missingIndexes = diff.missing.filter((m) => m.kind === 'index');
  await pool(Object.entries(Object.groupBy(missingIndexes, (m) => m.table)), 4, async ([tableId, list]) => {
    for (const m of list) {
      const index = byTable.get(tableId).indexes.find((i) => i.key === m.key);
      await retrying(() => tables.createIndex({ databaseId, tableId, key: index.key, type: index.type === 'unique' ? TablesDBIndexType.Unique : TablesDBIndexType.Key, columns: index.columns }), `index ${tableId}.${index.key}`);
      created.indexes++;
    }
  });
  if (created.indexes || diff.pending.some((p) => p.kind === 'index')) await waitAvailable('index');
  for (const bucket of declaration.buckets) {
    if (!diff.missing.some((m) => m.kind === 'bucket' && m.id === bucket.id)) continue;
    await retrying(() => storage.createBucket({ bucketId: bucket.id, name: bucket.id, permissions: bucket.permissions, fileSecurity: bucket.fileSecurity, enabled: true }), `bucket ${bucket.id}`);
    created.buckets++;
  }
  const final = diffLive(declaration, await snapshot());
  const changes = Object.values(created).reduce((a, b) => a + b, 0);
  const ok = !final.missing.length && !final.drift.length && !final.pending.length;
  console.log(JSON.stringify({ status: ok ? (changes ? 'APPLIED' : 'NO_CHANGES') : 'INCOMPLETE', declarationSha256: plan.declarationSha256, project, created, changes, final: report(final), scope: 'admitted test project only; additive; drift is never dropped' }, null, 2));
  process.exitCode = ok ? 0 : 1;
}
