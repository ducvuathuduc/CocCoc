// Regenerates appwrite/schema/foundation.json from docs/data/DATA_MODEL.md and PERMISSIONS.md.
// Run after a reviewed data-model doc change: `pnpm schema:declare`, then `pnpm schema:plan && pnpm schema:test`.
// Keeps the declaration's metadata block (schemaVersion/scope/sources/conventions); tables and buckets are derived.
// Pure local file write: no network, no Appwrite environment access.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { CANONICAL_TABLE_COUNT, deriveDeclaration } from './schema-lib.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const file = path.join(root, 'appwrite/schema/foundation.json');
const read = (rel) => fs.readFileSync(path.join(root, rel), 'utf8');
const previous = JSON.parse(fs.readFileSync(file, 'utf8'));
const derived = deriveDeclaration(read('docs/data/DATA_MODEL.md'), read('docs/data/PERMISSIONS.md'));
if (derived.tables.length !== CANONICAL_TABLE_COUNT) throw new Error(`docs list ${derived.tables.length} tables; update CANONICAL_TABLE_COUNT (${CANONICAL_TABLE_COUNT}) in the same reviewed change`);
const scope = previous.scope.replace(/^All \d+ canonical/, `All ${CANONICAL_TABLE_COUNT} canonical`);
const j = (value) => JSON.stringify(value).replace(/":/g, '": ').replace(/,(?=["{[\]0-9tfn-])/g, ', ');
const head = { schemaVersion: previous.schemaVersion, databaseId: derived.databaseId, scope, sources: previous.sources, conventions: previous.conventions };
const lines = ['{'];
for (const [key, value] of Object.entries(head)) lines.push(`  "${key}": ${JSON.stringify(value, null, 2).replace(/\n/g, '\n  ')},`);
lines.push('  "tables": [');
derived.tables.forEach((table, i) => {
  const { columns, indexes, ...meta } = table;
  lines.push(`    ${j(meta).slice(0, -1)}, "columns": [`);
  lines.push(columns.map((c) => `      ${j(c)}`).join(',\n'));
  lines.push('    ], "indexes": [');
  if (indexes.length) lines.push(indexes.map((x) => `      ${j(x)}`).join(',\n'));
  lines.push(`    ]}${i < derived.tables.length - 1 ? ',' : ''}`);
});
lines.push('  ],');
lines.push(`  "buckets": [${derived.buckets.map(j).join(', ')}]`);
lines.push('}');
fs.writeFileSync(file, lines.join('\n') + '\n');
console.log(JSON.stringify({ status: 'WRITTEN', file: 'appwrite/schema/foundation.json', tables: derived.tables.length }));
