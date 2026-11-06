// Store contract check: AppwriteStore runs against a fake TablesDB that enforces the rules Appwrite
// enforces, taken from the canonical declaration in appwrite/schema/foundation.json — every required
// column present, enum values legal, filters and sorts only on indexed attributes — plus the retry
// policy for a dropped connection. Offline: no project, no credentials, no network. It exists because
// a missing column or an unindexed lookup is invisible until a live save, a wrong $id lookup silently
// duplicates rows, and the hosted endpoint really does time out from here.
import { build } from 'esbuild';
import { mkdtemp, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { readFileSync } from 'node:fs';

const appRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const repoRoot = path.resolve(appRoot, '..', '..');

const bundled = await build({
  stdin: {
    contents: "export * from '@/server/store/appwrite-store'; export * from '@/server/store/port';",
    resolveDir: appRoot,
    loader: 'ts',
  },
  bundle: true,
  format: 'esm',
  platform: 'node',
  write: false,
  external: ['node-appwrite'],
  alias: { '@': path.join(appRoot, 'src') },
});

const dir = await mkdtemp(path.join(appRoot, 'node_modules', '.store-contract-'));
const bundleFile = path.join(dir, 'cms.mjs');
await writeFile(bundleFile, bundled.outputFiles[0].text, 'utf8');

const { AppwriteStore, ConflictError, StoreUnavailableError } = await import(
  pathToFileURL(bundleFile).href
);

const foundation = JSON.parse(
  readFileSync(path.join(repoRoot, 'appwrite', 'schema', 'foundation.json'), 'utf8'),
);
const tables = foundation.tables.filter((t) => t.id.startsWith('c_'));
const byId = new Map(tables.map((t) => [t.id, t]));

let checks = 0;
const failures = [];
// A rejected write is the interesting failure (missing or illegal column), so report it as a check
// result instead of an unhandled rejection stack.
process.on('unhandledRejection', (error) => {
  console.error(`FAIL — AppwriteStore write rejected by the declaration: ${error?.message ?? JSON.stringify(error)}`);
  process.exit(1);
});
function assert(label, ok, detail = '') {
  checks += 1;
  if (!ok) failures.push(`${label}${detail ? `\n  ${detail}` : ''}`);
}

const state = Object.fromEntries(tables.map((t) => [t.id, []]));
const queries = [];

/** Minimal Appwrite: rejects writes that break the declaration and remembers every read filter. */
function validate(tableId, data, { partial }) {
  const spec = byId.get(tableId);
  const declared = new Set(spec.columns.map((c) => c.key));
  for (const key of Object.keys(data)) {
    if (!declared.has(key)) return `${key} is written but not declared in DATA_MODEL.md`;
  }
  for (const column of spec.columns) {
    const missing = data[column.key] === undefined;
    if (missing && !partial) {
      if (column.required !== false) return `required column ${column.key} not written`;
      continue;
    }
    if (missing) continue;
    if (column.type === 'enum' && !column.elements.includes(data[column.key]))
      return `${column.key}="${data[column.key]}" outside ${column.elements.join('/')}`;
    if (column.type === 'string' && String(data[column.key]).length > column.size)
      return `${column.key} is ${String(data[column.key]).length} chars, size ${column.size}`;
  }
  return '';
}

const fakeTables = {
  async getRow({ tableId, rowId }) {
    const row = state[tableId].find((r) => r.$id === rowId);
    if (!row) throw { code: 404 };
    return row;
  },
  async listRows({ tableId, queries: qs }) {
    queries.push({ tableId, qs });
    let rows = [...state[tableId]];
    for (const raw of qs) {
      const q = JSON.parse(raw);
      if (q.method === 'equal') rows = rows.filter((r) => q.values.includes(r[q.attribute]));
      if (q.method === 'limit') rows = rows.slice(0, q.values[0]);
      if (q.method === 'orderAsc') rows.sort((a, b) => String(a[q.attribute]).localeCompare(String(b[q.attribute])));
      if (q.method === 'orderDesc') rows.sort((a, b) => String(b[q.attribute]).localeCompare(String(a[q.attribute])));
    }
    return { rows };
  },
  async createRow({ tableId, rowId, data }) {
    const problem = validate(tableId, data, { partial: false });
    if (problem) throw { code: 400, message: problem };
    for (const index of byId.get(tableId).indexes.filter((i) => i.type === 'unique')) {
      if (state[tableId].some((r) => index.columns.every((c) => r[c] === data[c])))
        throw { code: 409, message: `duplicate ${index.key}` };
    }
    state[tableId].push({ $id: rowId, ...data });
    return { $id: rowId };
  },
  async updateRow({ tableId, rowId, data }) {
    const row = state[tableId].find((r) => r.$id === rowId);
    if (!row) throw { code: 404 };
    const problem = validate(tableId, data, { partial: true });
    if (problem) throw { code: 400, message: problem };
    Object.assign(row, data);
    return row;
  },
  async deleteRow({ tableId, rowId }) {
    state[tableId] = state[tableId].filter((r) => r.$id !== rowId);
  },
};

const store = new AppwriteStore('http://127.0.0.1:9', 'project', 'key', 'cocenglish');
store.tables = fakeTables;

const courseDraft = {
  course: { courseId: 'vi_en', title: 'Tiếng Anh cho người Việt', sourceLocale: 'vi', targetLocale: 'en', status: 'ACTIVE' },
  sections: [{ sectionId: 's1', title: 'Chào hỏi', units: ['01-greetings'] }],
  version: 'v2',
};
const unitDraft = {
  theme: 'greetings',
  cefr: 'A1',
  title: 'Chào hỏi',
  levels: ['1'],
  guide: 'Guide',
  vocab: [{ level: 1, en: 'hello', enAlts: [], vi: 'xin chào', viAlts: [], img: false, forms: [], id: 'u1_greetings_v1_0001' }],
  sentences: [{ en: 'Hello.', enAlts: [], vi: 'Xin chào.', viAlts: [] }],
  dialogues: [{ line: 'Hi!', reply: 'Hello!', replyAlts: [], vi: 'Chào!' }],
  story: { title: 'Cuộc gặp', passage: 'A meets B.', questions: [{ q: 'Ai?', correct: 'A', wrongs: ['B'] }] },
};

const savedCourse = await store.saveCourse({ courseId: 'vi_en', draft: courseDraft, actorId: 'harness-store', expectedRevision: 0 });
const again = await store.saveCourse({ courseId: 'vi_en', draft: { ...courseDraft, version: 'v2' }, actorId: 'harness-store', expectedRevision: 1 });
assert('course saved once per courseId', state.c_courses.length === 1, `rows=${state.c_courses.length}`);
assert('course revision increments', savedCourse.revision === 1 && again.revision === 2, `${savedCourse.revision} -> ${again.revision}`);
const courseRow = state.c_courses[0];
assert('course createdAt survives update', Boolean(courseRow.createdAt) && courseRow.updatedAt >= courseRow.createdAt);
assert('getCourse reads the row back by courseId', (await store.getCourse('vi_en'))?.draft.course.title === courseDraft.course.title);
assert(
  'stale expectedRevision conflicts',
  await store
    .saveCourse({ courseId: 'vi_en', draft: courseDraft, actorId: 'harness-store', expectedRevision: 1 })
    .then(() => false, (e) => e instanceof ConflictError),
);

await store.saveUnit({ courseId: 'vi_en', unitId: '01-greetings', order: 1, draft: unitDraft, actorId: 'harness-store', expectedRevision: 0 });
await store.saveUnit({ courseId: 'vi_en', unitId: '01-greetings', order: 1, draft: { ...unitDraft, title: 'Xin chào' }, actorId: 'harness-store', expectedRevision: 1 });
assert('unit saved once per unitKey', state.c_units.length === 1, `rows=${state.c_units.length}`);
const unitRow = state.c_units[0];
assert('unit counts projected', unitRow.vocabCount === 1 && unitRow.sentenceCount === 1);
assert('unit revision increments', unitRow.revision === 2, `revision=${unitRow.revision}`);
assert('getUnit reads the row back', (await store.getUnit('vi_en', '01-greetings'))?.draft.title === 'Xin chào');
await store.deleteUnit('vi_en', '01-greetings');
assert('deleteUnit removes the row', state.c_units.length === 0);
assert('getUnit after delete is null', (await store.getUnit('vi_en', '01-greetings')) === null);

const run = {
  runId: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
  courseId: 'vi_en',
  versionId: 'v2',
  kind: 'GATES',
  status: 'RUNNING',
  message: 'Đang chạy gate…',
  log: [],
  actorId: 'harness-store',
  createdAt: new Date().toISOString(),
};
await store.saveBuildRun(run);
const createdAtRun = state.c_build_runs[0].createdAt;
await store.saveBuildRun({ ...run, kind: 'PUBLISH', status: 'SUCCEEDED', message: 'Xong', log: ['$ node x'] });
assert('build run upserts by runId', state.c_build_runs.length === 1);
const runRow = state.c_build_runs[0];
assert('run revision and updatedAt written', runRow.revision === 2 && Boolean(runRow.updatedAt));
assert('run createdAt stays', runRow.createdAt === createdAtRun);
assert('run reads back through the index', (await store.listBuildRuns('vi_en'))[0].kind === 'PUBLISH');

const longJson = 'x'.repeat(25000);
await store.appendAudit({
  entryId: 'entry-1',
  actorId: 'harness-store',
  operation: 'unit.save',
  targetId: 'vi_en/01-greetings',
  beforeJson: longJson,
  afterJson: longJson,
  requestId: 'req-1',
  createdAt: new Date().toISOString(),
});
assert('audit truncates to the declared size', state.c_admin_audit[0].beforeJson.length === 20000, `${state.c_admin_audit[0].beforeJson.length} chars`);
assert('audit has no mutable columns', !('revision' in state.c_admin_audit[0]) && !('updatedAt' in state.c_admin_audit[0]));
assert('listAudit returns newest first', (await store.listAudit(10))[0].entryId === 'entry-1');

// Every filter and sort must be backed by a declared index, otherwise Appwrite rejects the read.
for (const { tableId, qs } of queries) {
  const indexed = new Set(byId.get(tableId).indexes.flatMap((i) => i.columns));
  for (const raw of qs) {
    const q = JSON.parse(raw);
    if (!['equal', 'orderAsc', 'orderDesc'].includes(q.method)) continue;
    assert(`${tableId}: ${q.method}(${q.attribute}) needs an index`, indexed.has(q.attribute), `indexes ${[...indexed].join(',')}`);
  }
}
assert('store issued indexed reads', queries.length >= 6, `${queries.length} listRows calls`);

// A dropped socket must not cost the admin a save, but a request Appwrite rejected must not be
// hammered either.
const timeout = { cause: { code: 'UND_ERR_CONNECT_TIMEOUT' } };
const auditEntry = {
  entryId: 'entry-retry',
  actorId: 'harness-store',
  operation: 'unit.save',
  targetId: 'vi_en/01-greetings',
  beforeJson: '',
  afterJson: '{}',
  requestId: '',
  createdAt: new Date().toISOString(),
};

const flaky = new AppwriteStore('http://127.0.0.1:9', 'project', 'key', 'cocenglish');
let flakyTries = 0;
flaky.tables = {
  async createRow(input) {
    flakyTries += 1;
    if (flakyTries < 3) throw timeout;
    return fakeTables.createRow(input);
  },
};
await flaky.appendAudit(auditEntry);
assert('a dropped connection is retried', flakyTries === 3, `${flakyTries} attempts`);

const gone = new AppwriteStore('http://127.0.0.1:9', 'project', 'key', 'cocenglish');
let goneTries = 0;
gone.tables = {
  async createRow() {
    goneTries += 1;
    throw timeout;
  },
};
let outage;
try {
  await gone.appendAudit(auditEntry);
} catch (error) {
  outage = error;
}
assert(
  'an unreachable store answers with StoreUnavailableError',
  outage instanceof StoreUnavailableError && goneTries === 3,
  `${outage?.name} after ${goneTries} attempts`,
);
assert('the outage message says the draft is not saved', /chưa lưu/.test(outage?.message ?? ''), outage?.message);

const rejected = new AppwriteStore('http://127.0.0.1:9', 'project', 'key', 'cocenglish');
let rejectedTries = 0;
rejected.tables = {
  async createRow() {
    rejectedTries += 1;
    throw { code: 400, message: 'row not found' };
  },
};
let rejection;
try {
  await rejected.appendAudit(auditEntry);
} catch (error) {
  rejection = error;
}
assert(
  'a rejected request is not retried',
  rejectedTries === 1 && rejection?.code === 400,
  `${rejectedTries} attempts`,
);

// A refused port is the same class of failure as a dropped socket: the admin must not see "fetch failed".
const refused = new AppwriteStore('http://127.0.0.1:9', 'project', 'key', 'cocenglish');
let refusedTries = 0;
refused.tables = {
  async createRow() {
    refusedTries += 1;
    throw Object.assign(new TypeError('fetch failed'), { cause: { code: 'ECONNREFUSED' } });
  },
};
let refusedError;
try {
  await refused.appendAudit(auditEntry);
} catch (error) {
  refusedError = error;
}
assert(
  'a refused connection is reported as unavailable',
  refusedError instanceof StoreUnavailableError && refusedTries === 3,
  `${refusedError?.name} after ${refusedTries} attempts`,
);

// A plain exception is a bug in this app, not a network problem: it must reach the log unchanged.
const buggy = new AppwriteStore('http://127.0.0.1:9', 'project', 'key', 'cocenglish');
buggy.tables = {
  async createRow() {
    throw new TypeError('cannot read properties of undefined');
  },
};
let bugError;
try {
  await buggy.appendAudit(auditEntry);
} catch (error) {
  bugError = error;
}
assert(
  'an internal exception is not disguised as unavailable',
  bugError instanceof TypeError && !(bugError instanceof StoreUnavailableError),
  bugError?.name,
);

if (failures.length) {
  console.error(`FAIL ${failures.length}/${checks} checks\n`);
  for (const f of failures) console.error(`- ${f}`);
  process.exit(1);
}
console.log(
  `OK — ${checks} checks: AppwriteStore matches the c_* declaration in foundation.json and its retry policy.`,
);
