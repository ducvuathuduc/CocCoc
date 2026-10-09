import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Client, TablesDB, TablesDBIndexType } from 'node-appwrite';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const schema = JSON.parse(fs.readFileSync(path.join(root, 'appwrite/schema/foundation.json'), 'utf8'));
const canonical = fs.readFileSync(path.join(root, 'docs/data/DATA_MODEL.md'), 'utf8');
const prefixes = { learning: 'l_', progress: 'p_', ai: 'a_' };
for (const table of schema.tables) {
  if (!table.id.startsWith(prefixes[table.owner]) || !canonical.includes(`| ${table.id} /`)) throw new Error(`Unknown owner/table ${table.id}`);
  const keys = new Set(table.columns.map((column) => column.key));
  if (keys.size !== table.columns.length) throw new Error(`Duplicate column ${table.id}`);
  for (const index of table.indexes) if (index.columns.some((key) => !keys.has(key))) throw new Error(`Index column absent ${table.id}`);
}
if (!process.argv.includes('--apply')) {
  console.log(JSON.stringify({ status: 'PASS', mode: 'DRY_RUN_NO_NETWORK', declaredTables: schema.tables.length, canonicalTables: 37, operations: schema.tables.map((table) => ({ createTable: table.id, columns: table.columns.length, indexes: table.indexes.length, clientPermissions: [] })), remainingSchema: 'P1 gated; no full migration claim' }, null, 2));
} else {
  if (process.env.APPWRITE_PROJECT_ENV !== 'test' || process.env.ALLOW_SCHEMA_APPLY !== 'reviewed-test-project') throw new Error('Apply only to an explicitly admitted test project.');
  const { APPWRITE_ENDPOINT: endpoint, APPWRITE_PROJECT_ID: project, APPWRITE_API_KEY: key } = process.env;
  if (!endpoint?.startsWith('https://') || !project || !key) throw new Error('Missing private Appwrite test configuration.');
  const tables = new TablesDB(new Client().setEndpoint(endpoint).setProject(project).setKey(key));
  const databaseId = schema.databaseId;
  async function createIfAbsent(get, create) { try { return await get(); } catch (error) { if (error.code !== 404) throw error; return create(); } }
  await createIfAbsent(() => tables.get({ databaseId }), () => tables.create({ databaseId, name: 'CocEnglish', enabled: true }));
  for (const table of schema.tables) {
    const args = { databaseId, tableId: table.id };
    await createIfAbsent(() => tables.getTable(args), () => tables.createTable({ ...args, name: table.id, permissions: [], rowSecurity: true }));
    for (const column of table.columns) {
      let existing;
      try { existing = await tables.getColumn({ ...args, key: column.key }); } catch (error) { if (error.code !== 404) throw error; }
      if (existing) {
        if (existing.type !== column.type || existing.required !== (column.required !== false) || (column.type === 'string' && existing.size !== column.size)) throw new Error(`Schema drift requires review: ${table.id}.${column.key}`);
        continue;
      }
      const common = { ...args, key: column.key, required: column.required !== false };
      const methods = { string: () => tables.createStringColumn({ ...common, size: column.size }), integer: () => tables.createIntegerColumn(common), boolean: () => tables.createBooleanColumn(common), datetime: () => tables.createDatetimeColumn(common) };
      if (!methods[column.type]) throw new Error('Unsupported column type.');
      await methods[column.type]();
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
  console.log(JSON.stringify({ status: 'APPLIED', tables: schema.tables.map((table) => table.id), scope: 'test foundation only' }));
}
