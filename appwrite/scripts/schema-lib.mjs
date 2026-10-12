// Derives the Appwrite TablesDB declaration from docs/data/DATA_MODEL.md and
// docs/data/PERMISSIONS.md, and checks a committed declaration against it.
// Pure functions only: no network, no environment access.
import crypto from 'node:crypto';

export const OWNERS = { Learning: 'learning', Progress: 'progress', AI: 'ai' };
export const PREFIXES = { learning: 'l_', progress: 'p_', ai: 'a_' };
export const CANONICAL_TABLE_COUNT = 62;
// Appwrite varchar maximum (node-appwrite 29.2.0 createVarcharColumn: "Maximum size is 16381").
export const VARCHAR_MAX = 16381;
// Appwrite index key length limit (same as other Appwrite keys).
export const INDEX_KEY_MAX = 36;

// Cells that refer to another table's shape instead of listing columns.
// Each reference is matched exactly so a doc rewording fails closed.
const SHAPE_REFERENCES = [
  { pattern: /^same structural fields as (l_outbox)\b/, source: (m) => m[1] },
  { pattern: /^same receipt shape\b/, source: () => 'l_receipts' },
  { pattern: /^own receipt shape\b/, source: () => 'l_receipts' },
];
// "Every mutable row has revision, createdAt, updatedAt" (DATA_MODEL.md, Types).
// A table is treated as immutable only when its retention cell says so explicitly.
const IMMUTABLE_MARKER = /append-only|immutable history|immutable until account deletion/i;
const MUTABLE_FIELDS = [
  { key: 'revision', type: 'integer', min: 0 },
  { key: 'createdAt', type: 'datetime' },
  { key: 'updatedAt', type: 'datetime' },
];

/** Splits the "## Tables" markdown table into raw rows. */
export function parseTableRows(markdown) {
  const rows = [];
  for (const line of markdown.split('\n')) {
    const match = /^\| ([lpa]_[a-z_]+) \/ (Learning|Progress|AI) \| (.*) \| (.*) \|$/.exec(line);
    if (match) rows.push({ id: match[1], owner: OWNERS[match[2]], columnsCell: match[3].trim(), indexCell: match[4].trim() });
  }
  return rows;
}

/** Parses one column token such as `stage0..4`, `status A/B`, `resultJson nullable≤8192`. */
export function parseColumnToken(token) {
  const match = /^([a-z][A-Za-z]*Sha256|[a-z][A-Za-z]*)(.*)$/.exec(token.trim());
  if (!match) throw new Error(`Unparseable column token: "${token}"`);
  const [, key, restRaw] = match;
  let rest = restRaw;
  const hints = { key };
  const take = (regex, apply) => {
    const found = regex.exec(rest);
    if (found) {
      apply(found);
      rest = rest.replace(found[0], ' ');
    }
  };
  take(/\bnullable\b/, () => (hints.nullable = true));
  take(/\bbool\b/, () => (hints.bool = true));
  take(/\bint(?=$|[\s\d≥])/, () => (hints.int = true));
  take(/\((\d+)\)/, (m) => (hints.size = Number(m[1])));
  take(/≤(\d+)/, (m) => (hints.size = Number(m[1])));
  take(/≥(\d+)/, (m) => (hints.min = Number(m[1])));
  take(/(\d+)\.\.(\d+)/, (m) => ((hints.min = Number(m[1])), (hints.max = Number(m[2]))));
  take(/\b([A-Z][A-Z_]+(?:\/[A-Z][A-Z_]+)+)\b/, (m) => (hints.elements = m[1].split('/')));
  take(/^\s*(\d+(?:\/\d+)*)\s*$/, (m) => (hints.allowed = m[1].split('/').map(Number)));
  if (rest.trim()) throw new Error(`Unrecognised column annotation "${rest.trim()}" in "${token}"`);
  return hints;
}

/** Explicit, documented conventions for columns whose type/size the doc leaves implicit. */
export function conventionFor(key) {
  if (/(At|Until)$/.test(key)) return { type: 'datetime', basis: 'timestamp=UTC ISO8601 datetime' };
  if (key === 'schemaVersion') return { type: 'integer', basis: 'l_content_versions.schemaVersion int' };
  if (/(Hash|Sha256)$/.test(key)) return { type: 'string', size: 64, basis: 'SHA-256 hex' };
  if (/(Id|Identity|Version)$/.test(key)) return { type: 'string', size: 36, basis: 'id=ASCII opaque string≤36' };
  if (/(^d|D)ay$/.test(key) || key === 'periodKey') return { type: 'string', size: 10, basis: 'day key like learningDay≤10' };
  if (/[zZ]one$/.test(key)) return { type: 'string', size: 64, basis: 'zone≤64' };
  if (key === 'locale') return { type: 'string', size: 16, basis: 'sourceLocale≤16' };
  if (['type', 'operation', 'key', 'providerAlias', 'leaseOwner'].includes(key))
    return { type: 'string', size: 64, basis: 'short identifier; matches reviewed foundation type≤64' };
  if (
    ['attempt', 'statusCode', 'epoch', 'eligibleXp', 'rank', 'metricValue', 'target', 'count', 'revision', 'completedLessons', 'originalCorrect', 'reviewSessions'].includes(key) ||
    /(Delta|Seconds|Grants|Requests|Revision|Xp)$/.test(key)
  )
    return { type: 'integer', basis: 'counter/ordinal' };
  throw new Error(`No documented convention for column "${key}"; add a doc constraint or convention.`);
}

function columnFromHints(hints) {
  const column = { key: hints.key };
  const convention = (() => {
    try {
      return conventionFor(hints.key);
    } catch (error) {
      if (hints.bool || hints.int || hints.elements || hints.size || hints.min !== undefined || hints.allowed) return undefined;
      throw error;
    }
  })();
  if (hints.bool) column.type = 'boolean';
  else if (hints.elements) Object.assign(column, { type: 'enum', elements: hints.elements });
  else if (hints.int || hints.min !== undefined || hints.max !== undefined || hints.allowed) column.type = 'integer';
  else if (hints.size) Object.assign(column, { type: 'string', size: hints.size });
  else Object.assign(column, { type: convention.type }, convention.size ? { size: convention.size } : {});
  if (column.type === 'string' && !column.size) column.size = hints.size ?? convention?.size;
  if (column.type === 'integer') {
    if (hints.allowed) Object.assign(column, { min: Math.min(...hints.allowed), max: Math.max(...hints.allowed), allowed: hints.allowed });
    if (hints.min !== undefined) column.min = hints.min;
    if (hints.max !== undefined) column.max = hints.max;
  }
  if (column.type === 'string' && !column.size) throw new Error(`String column ${hints.key} has no size`);
  if (hints.nullable) column.required = false;
  return column;
}

export function indexKey(type, columns) {
  const prefix = type === 'unique' ? 'u_' : 'k_';
  const full = prefix + columns.join('_');
  return full.length <= INDEX_KEY_MAX ? full : prefix + columns.map((c) => c.slice(0, 4)).join('_');
}

/** Derives the full canonical declaration (tables, columns, indexes, permissions) from the docs. */
export function deriveDeclaration(dataModel, permissionsDoc) {
  const rows = parseTableRows(dataModel);
  const byId = new Map(rows.map((row) => [row.id, row]));
  const docColumns = (row) => {
    for (const ref of SHAPE_REFERENCES) {
      const m = ref.pattern.exec(row.columnsCell);
      if (m) {
        const source = byId.get(ref.source(m));
        if (!source) throw new Error(`${row.id}: referenced shape ${ref.source(m)} missing`);
        return { columns: docColumns(source).columns, derivedFrom: source.id };
      }
    }
    if (row.columnsCell.startsWith('deletion ')) return { columns: row.columnsCell.slice('deletion '.length).split('/').map(parseColumnToken).map(columnFromHints) };
    return { columns: row.columnsCell.split(',').map(parseColumnToken).map(columnFromHints) };
  };
  if (!/p_notifications \| no broad table grant, Row Security enabled \| read\(Role\.user\(userId\)\); no client writes/.test(permissionsDoc))
    throw new Error('PERMISSIONS.md p_notifications row changed; review row permission declaration.');
  if (!/learning-assets bucket \| no broad bucket read\/write, File Security enabled/.test(permissionsDoc) || !/Bucket learning-assets, fileSecurity enabled/.test(dataModel))
    throw new Error('learning-assets bucket security statement changed; review bucket declaration.');
  const tables = rows.map((row) => {
    const { columns, derivedFrom } = docColumns(row);
    const keys = new Set(columns.map((c) => c.key));
    if (keys.size !== columns.length) throw new Error(`${row.id}: duplicate column in doc`);
    const mutable = !IMMUTABLE_MARKER.test(row.indexCell);
    if (mutable) for (const field of MUTABLE_FIELDS) if (!keys.has(field.key)) columns.push({ ...field });
    const indexes = [...row.indexCell.matchAll(/\b(unique|key)\(([^)]+)\)/g)].map((m) => {
      const cols = m[2].split(',').map((c) => c.trim());
      return { key: indexKey(m[1], cols), type: m[1], columns: cols };
    });
    const table = { id: row.id, owner: row.owner, mutable };
    if (derivedFrom) table.columnsFrom = derivedFrom;
    Object.assign(table, { permissions: [], rowSecurity: true, rowPermissions: [] });
    if (row.id === 'p_notifications') table.rowPermissions = [{ action: 'read', role: 'user', valueFrom: 'userId' }];
    table.columns = columns;
    table.indexes = indexes;
    return table;
  });
  return {
    databaseId: 'cocenglish',
    tables,
    buckets: [{ id: 'learning-assets', permissions: [], fileSecurity: true, note: 'Published l_ files get file-level read(Role.any()) at publish time; drafts and a_ audio get none.' }],
  };
}

/** Returns a list of human-readable problems; empty means the declaration matches docs and invariants. */
export function validateDeclaration(declaration, derived) {
  const problems = [];
  const expect = (ok, message) => ok || problems.push(message);
  expect(declaration.databaseId === derived.databaseId, `databaseId ${declaration.databaseId} != ${derived.databaseId}`);
  expect(derived.tables.length === CANONICAL_TABLE_COUNT, `docs list ${derived.tables.length} tables, expected ${CANONICAL_TABLE_COUNT}`);
  const declared = new Map((declaration.tables ?? []).map((t) => [t.id, t]));
  expect(declared.size === (declaration.tables ?? []).length, 'duplicate table id in declaration');
  for (const table of derived.tables) if (!declared.has(table.id)) problems.push(`missing table ${table.id}`);
  for (const table of declaration.tables ?? []) {
    const doc = derived.tables.find((t) => t.id === table.id);
    if (!doc) {
      problems.push(`table ${table.id} is not canonical in DATA_MODEL.md`);
      continue;
    }
    expect(table.id.startsWith(PREFIXES[table.owner]) && table.owner === doc.owner, `${table.id}: owner ${table.owner} != ${doc.owner}`);
    expect(Array.isArray(table.permissions) && table.permissions.length === 0, `${table.id}: table-level client permissions must be empty`);
    expect(table.rowSecurity === true, `${table.id}: rowSecurity must be enabled`);
    expect(JSON.stringify(table.rowPermissions) === JSON.stringify(doc.rowPermissions), `${table.id}: row permissions differ from PERMISSIONS.md`);
    for (const grant of table.rowPermissions ?? []) expect(grant.action === 'read', `${table.id}: client row write grant forbidden`);
    const docCols = new Map(doc.columns.map((c) => [c.key, c]));
    const keys = new Set();
    for (const column of table.columns ?? []) {
      if (keys.has(column.key)) problems.push(`${table.id}.${column.key}: duplicate column`);
      keys.add(column.key);
      const expected = docCols.get(column.key);
      if (!expected) problems.push(`${table.id}.${column.key}: invented column (not in DATA_MODEL.md)`);
      else if (JSON.stringify(column) !== JSON.stringify(expected)) problems.push(`${table.id}.${column.key}: ${JSON.stringify(column)} != docs ${JSON.stringify(expected)}`);
      if (column.type === 'string') expect(Number.isInteger(column.size) && column.size > 0, `${table.id}.${column.key}: string needs size`);
    }
    for (const key of docCols.keys()) if (!keys.has(key)) problems.push(`${table.id}.${key}: documented column missing`);
    const indexKeys = new Set();
    for (const index of table.indexes ?? []) {
      expect(!indexKeys.has(index.key), `${table.id}: duplicate index key ${index.key}`);
      indexKeys.add(index.key);
      expect(index.key.length <= INDEX_KEY_MAX, `${table.id}: index key too long ${index.key}`);
      for (const col of index.columns) expect(keys.has(col), `${table.id}: index ${index.key} references absent column ${col}`);
    }
    const sig = (list) => (list ?? []).map((i) => `${i.type}(${i.columns.join(',')})`).sort().join(';');
    expect(sig(table.indexes) === sig(doc.indexes), `${table.id}: indexes ${sig(table.indexes)} != docs ${sig(doc.indexes)}`);
  }
  const bucket = (declaration.buckets ?? []).find((b) => b.id === 'learning-assets');
  expect(bucket && bucket.fileSecurity === true && bucket.permissions.length === 0, 'learning-assets bucket must have fileSecurity and no bucket permissions');
  return problems;
}

/** Storage method mapping for the pinned node-appwrite SDK (column sizes stay enforced in services). */
export function storageFor(column) {
  if (column.type === 'string') {
    if (column.size <= 2048) return { method: 'createVarcharColumn', size: column.size };
    if (column.size <= 16383) return { method: 'createTextColumn' };
    return { method: 'createMediumtextColumn' };
  }
  return { method: { enum: 'createEnumColumn', integer: 'createIntegerColumn', boolean: 'createBooleanColumn', datetime: 'createDatetimeColumn' }[column.type] };
}

export function buildPlan(declaration) {
  const checksum = crypto.createHash('sha256').update(JSON.stringify(declaration)).digest('hex');
  const tables = declaration.tables.map((table) => ({
    createTable: table.id,
    owner: table.owner,
    rowSecurity: table.rowSecurity,
    clientPermissions: table.permissions,
    rowPermissions: table.rowPermissions,
    columns: table.columns.map((c) => ({ key: c.key, ...storageFor(c), required: c.required !== false })),
    indexes: table.indexes.map((i) => ({ key: i.key, type: i.type, columns: i.columns })),
  }));
  return {
    declarationSha256: checksum,
    totals: {
      tables: tables.length,
      columns: tables.reduce((n, t) => n + t.columns.length, 0),
      indexes: tables.reduce((n, t) => n + t.indexes.length, 0),
      uniqueIndexes: tables.reduce((n, t) => n + t.indexes.filter((i) => i.type === 'unique').length, 0),
      buckets: declaration.buckets.length,
    },
    tables,
    buckets: declaration.buckets.map((b) => ({ createBucket: b.id, fileSecurity: b.fileSecurity, bucketPermissions: b.permissions })),
  };
}

// Column type names Appwrite reports differ by server version (1.8+ reports varchar/text/mediumtext;
// older servers report string, enums report type string + format enum). Accept the documented family only.
export const ACCEPTED_LIVE_TYPES = {
  createVarcharColumn: ['varchar', 'string'],
  createTextColumn: ['text', 'string'],
  createMediumtextColumn: ['mediumtext', 'string'],
  createEnumColumn: ['enum', 'string'],
  createIntegerColumn: ['integer'],
  createBooleanColumn: ['boolean'],
  createDatetimeColumn: ['datetime'],
};

/** Returns a drift reason for a live column against its declaration, or '' when it matches. */
export function columnDrift(column, live) {
  const target = storageFor(column);
  const reasons = [];
  if (!ACCEPTED_LIVE_TYPES[target.method].includes(live.type)) reasons.push(`type ${live.type} not in ${ACCEPTED_LIVE_TYPES[target.method].join('/')}`);
  if (column.type === 'enum' && live.format !== 'enum' && live.type !== 'enum') reasons.push('not an enum column');
  if (column.type === 'string' && live.format === 'enum') reasons.push('unexpected enum format');
  if (Boolean(live.required) !== (column.required !== false)) reasons.push(`required ${live.required}`);
  if (live.array) reasons.push('array column');
  if (target.size && Number(live.size) !== target.size) reasons.push(`size ${live.size} != ${target.size}`);
  if (column.type === 'enum' && JSON.stringify(live.elements) !== JSON.stringify(column.elements)) reasons.push(`elements ${JSON.stringify(live.elements)}`);
  if (column.type === 'integer') {
    if (column.min !== undefined && Number(live.min) !== column.min) reasons.push(`min ${live.min} != ${column.min}`);
    if (column.max !== undefined && Number(live.max) !== column.max) reasons.push(`max ${live.max} != ${column.max}`);
  }
  return reasons.join('; ');
}

/**
 * Compares a live snapshot with the declaration. Pure: the snapshot shape is
 * { database: boolean, tables: { [id]: { permissions, rowSecurity, columns: [...], indexes: [...] } }, buckets: { [id]: { permissions, fileSecurity } } }.
 * missing = additive work apply may do; drift = existing resources that differ (review, never dropped);
 * extra = live resources absent from the declaration (reported, never dropped); pending = not yet available.
 */
export function diffLive(declaration, live) {
  const out = { missing: [], drift: [], extra: [], pending: [] };
  if (!live.database) out.missing.push({ kind: 'database', id: declaration.databaseId });
  const declaredIds = new Set(declaration.tables.map((t) => t.id));
  for (const id of Object.keys(live.tables ?? {})) if (!declaredIds.has(id)) out.extra.push({ kind: 'table', id });
  for (const table of declaration.tables) {
    const lt = live.tables?.[table.id];
    if (!lt) {
      out.missing.push({ kind: 'table', id: table.id });
      for (const column of table.columns) out.missing.push({ kind: 'column', table: table.id, key: column.key });
      for (const index of table.indexes) out.missing.push({ kind: 'index', table: table.id, key: index.key });
      continue;
    }
    if (JSON.stringify([...(lt.permissions ?? [])].sort()) !== JSON.stringify([...table.permissions].sort())) out.drift.push({ kind: 'table', id: table.id, reason: `permissions ${JSON.stringify(lt.permissions)}` });
    if (lt.rowSecurity !== table.rowSecurity) out.drift.push({ kind: 'table', id: table.id, reason: `rowSecurity ${lt.rowSecurity}` });
    const liveCols = new Map((lt.columns ?? []).map((c) => [c.key, c]));
    const declaredCols = new Set(table.columns.map((c) => c.key));
    for (const column of table.columns) {
      const lc = liveCols.get(column.key);
      if (!lc) out.missing.push({ kind: 'column', table: table.id, key: column.key });
      else {
        const reason = columnDrift(column, lc);
        if (reason) out.drift.push({ kind: 'column', table: table.id, key: column.key, reason });
        else if (lc.status !== 'available') out.pending.push({ kind: 'column', table: table.id, key: column.key, status: lc.status, error: lc.error || undefined });
      }
    }
    for (const key of liveCols.keys()) if (!declaredCols.has(key)) out.extra.push({ kind: 'column', table: table.id, key });
    const liveIdx = new Map((lt.indexes ?? []).map((i) => [i.key, i]));
    const declaredIdx = new Set(table.indexes.map((i) => i.key));
    for (const index of table.indexes) {
      const li = liveIdx.get(index.key);
      if (!li) out.missing.push({ kind: 'index', table: table.id, key: index.key });
      else if (li.type !== index.type || JSON.stringify(li.columns) !== JSON.stringify(index.columns))
        out.drift.push({ kind: 'index', table: table.id, key: index.key, reason: `${li.type}(${(li.columns ?? []).join(',')})` });
      else if (li.status !== 'available') out.pending.push({ kind: 'index', table: table.id, key: index.key, status: li.status, error: li.error || undefined });
    }
    for (const key of liveIdx.keys()) if (!declaredIdx.has(key)) out.extra.push({ kind: 'index', table: table.id, key });
  }
  for (const bucket of declaration.buckets) {
    const lb = live.buckets?.[bucket.id];
    if (!lb) out.missing.push({ kind: 'bucket', id: bucket.id });
    else if (lb.fileSecurity !== bucket.fileSecurity || JSON.stringify(lb.permissions ?? []) !== JSON.stringify(bucket.permissions))
      out.drift.push({ kind: 'bucket', id: bucket.id, reason: `fileSecurity ${lb.fileSecurity} permissions ${JSON.stringify(lb.permissions)}` });
  }
  return out;
}
