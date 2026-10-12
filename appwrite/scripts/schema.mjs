// Appwrite TablesDB schema plan/apply for all canonical tables.
// Default: offline dry run that validates appwrite/schema/foundation.json against docs/data and prints the plan.
// --apply: additive create-if-absent on an explicitly admitted TEST project only (never run by CI).
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Client, Storage, TablesDB, TablesDBIndexType } from 'node-appwrite';
import { buildPlan, deriveDeclaration, storageFor, validateDeclaration } from './schema-lib.mjs';

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
const requiredMethods = new Set(['get', 'create', 'getTable', 'createTable', 'getColumn', 'listColumns', 'listIndexes', 'createIndex']);
for (const table of plan.tables) for (const column of table.columns) requiredMethods.add(column.method);
const missing = [...requiredMethods].filter((name) => typeof TablesDB.prototype[name] !== 'function');
for (const name of ['getBucket', 'createBucket']) if (typeof Storage.prototype[name] !== 'function') missing.push(`Storage.${name}`);
if (missing.length || !TablesDBIndexType.Unique || !TablesDBIndexType.Key) {
  console.error(JSON.stringify({ status: 'FAIL', mode: 'SDK_RESOLUTION', missing }));
  process.exit(1);
}

if (!process.argv.includes('--apply')) {
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
  process.exit(0);
}

if (process.env.APPWRITE_PROJECT_ENV !== 'test' || process.env.ALLOW_SCHEMA_APPLY !== 'reviewed-test-project') throw new Error('Apply only to an explicitly admitted test project.');
const { APPWRITE_ENDPOINT: endpoint, APPWRITE_PROJECT_ID: project, APPWRITE_API_KEY: key } = process.env;
if (!endpoint?.startsWith('https://') || !project || !key) throw new Error('Missing private Appwrite test configuration.');
const client = new Client().setEndpoint(endpoint).setProject(project).setKey(key);
const tables = new TablesDB(client);
const storage = new Storage(client);
const databaseId = declaration.databaseId;
async function createIfAbsent(get, create) {
  try {
    return await get();
  } catch (error) {
    if (error.code !== 404) throw error;
    return create();
  }
}
// Reported column types differ between Appwrite versions; accept the documented family only.
const acceptedTypes = { createVarcharColumn: ['varchar', 'string'], createTextColumn: ['text', 'string'], createMediumtextColumn: ['mediumtext', 'string'], createEnumColumn: ['string', 'enum'], createIntegerColumn: ['integer'], createBooleanColumn: ['boolean'], createDatetimeColumn: ['datetime'] };
await createIfAbsent(() => tables.get({ databaseId }), () => tables.create({ databaseId, name: 'CocEnglish', enabled: true }));
for (const table of declaration.tables) {
  const args = { databaseId, tableId: table.id };
  await createIfAbsent(() => tables.getTable(args), () => tables.createTable({ ...args, name: table.id, permissions: table.permissions, rowSecurity: table.rowSecurity }));
  for (const column of table.columns) {
    const target = storageFor(column);
    const required = column.required !== false;
    let existing;
    try {
      existing = await tables.getColumn({ ...args, key: column.key });
    } catch (error) {
      if (error.code !== 404) throw error;
    }
    if (existing) {
      const drift =
        !acceptedTypes[target.method].includes(existing.type) ||
        existing.required !== required ||
        (target.size && existing.size !== target.size) ||
        (column.type === 'enum' && JSON.stringify(existing.elements) !== JSON.stringify(column.elements)) ||
        (column.type === 'integer' && ((column.min !== undefined && Number(existing.min) !== column.min) || (column.max !== undefined && Number(existing.max) !== column.max)));
      if (drift) throw new Error(`Schema drift requires review: ${table.id}.${column.key}`);
      continue;
    }
    const common = { ...args, key: column.key, required };
    const create = {
      createVarcharColumn: () => tables.createVarcharColumn({ ...common, size: target.size }),
      createTextColumn: () => tables.createTextColumn(common),
      createMediumtextColumn: () => tables.createMediumtextColumn(common),
      createEnumColumn: () => tables.createEnumColumn({ ...common, elements: column.elements }),
      createIntegerColumn: () => tables.createIntegerColumn({ ...common, ...(column.min !== undefined ? { min: column.min } : {}), ...(column.max !== undefined ? { max: column.max } : {}) }),
      createBooleanColumn: () => tables.createBooleanColumn(common),
      createDatetimeColumn: () => tables.createDatetimeColumn(common),
    }[target.method];
    await create();
  }
  const columns = await tables.listColumns(args);
  if (columns.columns.some((column) => column.status !== 'available')) throw new Error(`${table.id}: columns pending; retry after availability; matching columns resume without modification.`);
  const existingIndexes = await tables.listIndexes(args);
  for (const index of table.indexes) {
    const existing = existingIndexes.indexes.find((value) => value.key === index.key);
    if (existing) {
      if (existing.type !== index.type || JSON.stringify(existing.columns) !== JSON.stringify(index.columns)) throw new Error(`Index drift requires review: ${table.id}.${index.key}`);
      continue;
    }
    await tables.createIndex({ ...args, key: index.key, type: index.type === 'unique' ? TablesDBIndexType.Unique : TablesDBIndexType.Key, columns: index.columns });
  }
}
for (const bucket of declaration.buckets) {
  await createIfAbsent(() => storage.getBucket({ bucketId: bucket.id }), () => storage.createBucket({ bucketId: bucket.id, name: bucket.id, permissions: bucket.permissions, fileSecurity: bucket.fileSecurity }));
}
console.log(JSON.stringify({ status: 'APPLIED', declarationSha256: plan.declarationSha256, tables: declaration.tables.map((table) => table.id), buckets: declaration.buckets.map((b) => b.id), scope: 'admitted test project; await index availability and run permission probes next' }));
