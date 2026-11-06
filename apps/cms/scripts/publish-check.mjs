// Build-and-publish proof. `runContentGates` and `publishCourseVersion` (src/server/actions) are the only
// two places in the CMS that shell out, and the publisher is the only button that writes to a shared
// Appwrite project — so this harness runs them against a fake `node:child_process` that records every
// invocation instead of executing it, and a fake Appwrite TablesDB that enforces the c_* declaration from
// appwrite/schema/foundation.json. Nothing here contacts a project, uploads a file or runs a real gate.
// What it proves is the order of operations: readiness is checked before a process starts, the run row
// exists while the process runs, `--dry-run` is what the default button means, the live button needs
// CMS_ALLOW_PUBLISH=1, and the CMS never touches an `l_*` table.
import { build } from 'esbuild';
import { readFileSync } from 'node:fs';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { HARNESS_ADMIN_SECRET, authCoreStub } from './harness-auth.mjs';

const appRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const repoRoot = path.resolve(appRoot, '..', '..');
const posix = (p) => p.replace(/\\/g, '/');

const scratch = await mkdtemp(path.join(appRoot, 'node_modules', '.publish-'));
const dataDir = path.join(scratch, 'data');
const callsFile = path.join(scratch, 'calls.jsonl');
const repoDir = path.join(scratch, 'repo');

// The publisher and the three gates are recorded, never run. Failing labels come from CMS_HARNESS_FAIL so
// one stub can serve both the green and the red scenario.
await writeFile(
  path.join(scratch, 'stub-child-process.mjs'),
  `import { appendFileSync } from 'node:fs';
import { promisify } from 'node:util';

const LOG = ${JSON.stringify(posix(callsFile))};

// execFile is the one Node API that promisify() special-cases: the real function carries
// promisify.custom and resolves with { stdout, stderr }. A plain callback stub would resolve with the
// stdout string, and every caller here destructures an object off it — so the stub copies that detail
// instead of pretending the two shapes are the same.
export function execFile(file, args, options, callback) {
  if (typeof options === 'function') {
    callback = options;
    options = {};
  }
  const line = args.join(' ');
  const env = options.env ?? {};
  appendFileSync(
    LOG,
    JSON.stringify({
      line,
      cwd: options.cwd,
      endpoint: env.APPWRITE_ENDPOINT,
      projectId: env.APPWRITE_PROJECT_ID,
      apiKey: env.APPWRITE_API_KEY,
      databaseId: env.COC_DATABASE_ID,
      timeout: options.timeout,
    }) + '\\n',
  );
  const stdout = Array.from({ length: 55 }, (_, i) => 'out ' + (i + 1)).join('\\n');
  const failing = (process.env.CMS_HARNESS_FAIL ?? '').split(',').filter(Boolean);
  if (failing.some((f) => line.includes(f))) {
    const error = new Error('Command failed: node ' + line);
    callback(error, process.env.CMS_HARNESS_OUT ?? '', process.env.CMS_HARNESS_ERR ?? 'boom in ' + line);
    return;
  }
  callback(null, stdout, '');
}

execFile[promisify.custom] = (file, args, options) =>
  new Promise((resolve, reject) =>
    execFile(file, args, options, (error, stdout, stderr) => {
      if (error) {
        error.stdout = stdout;
        error.stderr = stderr;
        reject(error);
        return;
      }
      resolve({ stdout, stderr });
    }),
  );

export default { execFile };
`,
  'utf8',
);
await writeFile(
  path.join(scratch, 'stub-headers.mjs'),
  'export async function cookies() {\n' +
    '  return { get: () => ({ value: process.env.CMS_HARNESS_SECRET }), set: () => {}, delete: () => {} };\n' +
    '}\n',
  'utf8',
);
await writeFile(path.join(scratch, 'stub-auth-core.mjs'), authCoreStub(), 'utf8');

const bundled = await build({
  stdin: {
    contents:
      "export * from '@/server/actions/build';\n" +
      "export * from '@/server/actions/publish';\n" +
      "export * from '@/server/publish-state';\n" +
      "export * from '@/server/store';\n" +
      "export * from '@/server/config';\n" +
      "export * from '@/cms/blank';\n",
    resolveDir: appRoot,
    loader: 'ts',
  },
  bundle: true,
  format: 'esm',
  platform: 'node',
  write: false,
  external: ['node-appwrite'],
  alias: {
    '@': posix(path.join(appRoot, 'src')),
    '@/server/auth-core': posix(path.join(scratch, 'stub-auth-core.mjs')),
    'next/headers': posix(path.join(scratch, 'stub-headers.mjs')),
    'node:child_process': posix(path.join(scratch, 'stub-child-process.mjs')),
  },
});
const bundleFile = path.join(scratch, 'cms.mjs');
await writeFile(bundleFile, bundled.outputFiles[0].text, 'utf8');

Object.assign(process.env, {
  NODE_ENV: 'development',
  CMS_ADMIN_USER_IDS: 'harness-publish',
  CMS_HARNESS_SECRET: HARNESS_ADMIN_SECRET,
  CMS_DATA_DIR: dataDir,
  CMS_REPO_ROOT: repoDir,
  APPWRITE_ENDPOINT: 'http://127.0.0.1:9',
  APPWRITE_PROJECT_ID: 'harness-project',
  APPWRITE_API_KEY: 'harness-key',
  CMS_DATABASE_ID: 'cocenglish',
});
delete process.env.CMS_ALLOW_PUBLISH;

const checks = [];
const failures = [];
const check = (label, ok, detail = '') => {
  checks.push(label);
  if (!ok) failures.push(`${label}${detail ? ` — ${detail}` : ''}`);
};
const join = (list) => list.join(', ');

const foundation = JSON.parse(readFileSync(path.join(repoRoot, 'appwrite', 'schema', 'foundation.json'), 'utf8'));
const cTables = foundation.tables.filter((t) => t.id.startsWith('c_'));
const byId = new Map(cTables.map((t) => [t.id, t]));

/** The declaration is the contract: an undeclared or oversized column is a rejected write. */
function validate(tableId, data, { partial }) {
  const declared = new Set(byId.get(tableId).columns.map((c) => c.key));
  for (const key of Object.keys(data))
    if (!declared.has(key)) return `${key} is written but not declared in DATA_MODEL.md`;
  for (const column of byId.get(tableId).columns) {
    const missing = data[column.key] === undefined;
    if (missing && !partial && column.required !== false) return `required column ${column.key} not written`;
    if (missing) continue;
    if (column.type === 'enum' && !column.elements.includes(data[column.key]))
      return `${column.key}="${data[column.key]}" outside ${column.elements.join('/')}`;
    if (column.type === 'string' && String(data[column.key]).length > column.size)
      return `${column.key} is ${String(data[column.key]).length} chars, size ${column.size}`;
  }
  return '';
}

const calls = () =>
  readFileSync(callsFile, 'utf8')
    .split('\n')
    .filter(Boolean)
    .map((l) => JSON.parse(l));

/**
 * One pass = one process's worth of config, because `config()` caches per module instance. Importing the
 * same bundle under a different query string gives a fresh cache, so the CMS_ALLOW_PUBLISH scenarios run
 * back to back without a real subprocess.
 */
async function pass(tag, env) {
  // Every pass is a fresh process, so the knobs from the previous one must not survive it — a gate that
  // was supposed to fail in the last scenario would otherwise stay broken in this one.
  for (const key of ['CMS_HARNESS_FAIL', 'CMS_HARNESS_ERR', 'CMS_HARNESS_OUT', 'CMS_ALLOW_PUBLISH'])
    delete process.env[key];
  for (const [key, value] of Object.entries(env)) if (value !== undefined) process.env[key] = value;
  await writeFile(callsFile, '', 'utf8');
  const state = Object.fromEntries(cTables.map((t) => [t.id, []]));
  const tables = {
    async getRow({ tableId, rowId }) {
      const row = state[tableId].find((r) => r.$id === rowId);
      if (!row) throw { code: 404 };
      return row;
    },
    async listRows({ tableId, queries: qs }) {
      let rows = [...state[tableId]];
      for (const raw of qs) {
        const q = JSON.parse(raw);
        if (q.method === 'equal') rows = rows.filter((r) => q.values.includes(r[q.attribute]));
        if (q.method === 'limit') rows = rows.slice(0, q.values[0]);
        if (q.method === 'orderAsc')
          rows.sort((a, b) => String(a[q.attribute]).localeCompare(String(b[q.attribute])));
        if (q.method === 'orderDesc')
          rows.sort((a, b) => String(b[q.attribute]).localeCompare(String(a[q.attribute])));
      }
      return { rows };
    },
    async createRow({ tableId, rowId, data }) {
      const problem = validate(tableId, data, { partial: false });
      if (problem) throw { code: 400, message: problem };
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
  const cms = await import(`${pathToFileURL(bundleFile).href}?p=${tag}`);
  const store = cms.getStore();
  store.tables = tables;
  return { cms, store, state };
}

const courseDraft = {
  course: {
    courseId: 'vi_en',
    title: 'Tiếng Anh cho người Việt',
    sourceLocale: 'vi-VN',
    targetLocale: 'en-US',
    status: 'ACTIVE',
  },
  // The repo's own linter refuses a one-section course, so the fixture has to look like a course that
  // could really be published — otherwise every publish here would be blocked for the wrong reason.
  sections: [
    { sectionId: 'sec1', title: 'Phần 1', units: ['greetings'] },
    { sectionId: 'sec2', title: 'Phần 2', units: [] },
  ],
  version: 'v2',
};
function unitDraft(title = 'Chào hỏi') {
  const draft = cmsBlank();
  draft.theme = 'greetings';
  draft.title = title;
  draft.levels = ['Giao tiếp', 'Từ vựng', 'Nghe', 'Nói', 'Đọc'];
  draft.guide = 'Làm quen nhau.';
  draft.vocab = [
    { level: 1, en: 'hello', enAlts: [], vi: 'xin chào', viAlts: [], img: false, forms: [], id: 'hello' },
  ];
  draft.sentences = [{ en: 'Hello, Mai!', enAlts: [], vi: 'Xin chào, Mai!', viAlts: [] }];
  draft.dialogues = [{ line: 'Hi!', reply: 'Hello!', replyAlts: [], vi: 'Chào!' }];
  draft.story = {
    title: 'Ngày đầu tiên',
    passage: 'Mai meets Tom.',
    questions: [{ q: 'Who?', correct: 'Mai', wrongs: ['Tom', 'Nam'] }],
  };
  return draft;
}
let blankRef;
const cmsBlank = () => blankRef();

async function seed(ctx) {
  await ctx.store.saveCourse({
    courseId: 'vi_en',
    draft: courseDraft,
    actorId: 'harness-publish',
    expectedRevision: 0,
  });
  await ctx.store.saveUnit({
    courseId: 'vi_en',
    unitId: '01-greetings',
    order: 0,
    draft: unitDraft(),
    actorId: 'harness-publish',
    expectedRevision: 0,
  });
}

// ---------- A. gates: three repo commands, one run row, no project writes ----------
const a = await pass('gates-ok', {});
blankRef = a.cms.blankUnit;
await seed(a);

const gateRun = await a.cms.runContentGates('vi_en');
const gateCalls = calls();
check(
  'gate chạy đúng ba cổng của repo, theo thứ tự, bằng tool của repo chứ không phải bản tái hiện trong CMS',
  join(gateCalls.map((c) => c.line)) ===
    'tools/content/build-course.mjs, tools/content/lint-course.mjs, content/tools/check-content.mjs',
  join(gateCalls.map((c) => c.line)),
);
check(
  'gate chạy ở thư mục repo, không phải thư mục của CMS',
  gateCalls.every((c) => c.cwd === posix(repoDir) || c.cwd === repoDir),
  JSON.stringify(gateCalls.map((c) => c.cwd)),
);
check(
  'gate thành công: một dòng lịch sử, RUNNING rồi được ghi đè bằng chính runId đó',
  a.state.c_build_runs.length === 1 &&
    gateRun.status === 'SUCCEEDED' &&
    a.state.c_build_runs[0].kind === 'GATES' &&
    a.state.c_build_runs[0].revision === 2,
  JSON.stringify(a.state.c_build_runs.map((r) => `${r.kind}/${r.status}@${r.revision}`)),
);
check(
  'nhật ký gate giữ phần cuối của stdout và đánh dấu từng cổng đã qua',
  gateRun.log.filter((l) => l.startsWith('out ')).length === 120 &&
    gateRun.log.some((l) => l.startsWith('✓ build-course')) &&
    gateRun.log.some((l) => l.startsWith('✓ check-content')) &&
    !gateRun.log.some((l) => l.startsWith('✗')),
  `${gateRun.log.length} dòng log`,
);
check(
  'gate ghi một dòng audit content.gates kèm trạng thái',
  a.state.c_admin_audit.length === 1 &&
    a.state.c_admin_audit[0].operation === 'content.gates' &&
    JSON.parse(a.state.c_admin_audit[0].afterJson).status === 'SUCCEEDED',
  JSON.stringify(a.state.c_admin_audit.map((e) => e.operation)),
);

const readinessAfterGate = await a.cms.publishReadiness('vi_en');
check(
  'vừa chạy gate xong thì khóa sẵn sàng publish, kèm đúng version của bản nháp khóa',
  readinessAfterGate.gatesOk &&
    readinessAfterGate.version === 'v2' &&
    readinessAfterGate.unitCount === 1 &&
    !readinessAfterGate.blocking,
  JSON.stringify(readinessAfterGate),
);

// ---------- B. dry run is the default, live needs the flag ----------
const beforeDry = calls().length;
const dry = await a.cms.publishCourseVersion('vi_en', false);
const dryCalls = calls().slice(beforeDry);
const dryRunTotal = calls().length;
check(
  'nút mặc định là chạy thử: bộ publish của repo được gọi với --dry-run',
  dry.ok &&
    dryCalls.length === 1 &&
    dryCalls[0].line === 'tools/content/publish-appwrite.mjs --course vi_en --version v2 --dry-run',
  JSON.stringify(dryCalls.map((c) => c.line)),
);
check(
  'chạy thử vẫn ghi một dòng PUBLISH, không lẫn với GATES',
  a.state.c_build_runs.length === 2 &&
    a.state.c_build_runs[1].kind === 'PUBLISH' &&
    a.state.c_build_runs[1].status === 'SUCCEEDED',
  JSON.stringify(a.state.c_build_runs.map((r) => `${r.kind}/${r.status}`)),
);
check(
  'bộ publish nhận đúng cặp khóa Appwrite của CMS, không tự bịa credential',
  dryCalls[0].endpoint === 'http://127.0.0.1:9' &&
    dryCalls[0].projectId === 'harness-project' &&
    dryCalls[0].apiKey === 'harness-key' &&
    dryCalls[0].databaseId === 'cocenglish',
  JSON.stringify(dryCalls[0]),
);
check(
  'chỉ bộ publish được CMS đưa khóa một cách tường minh; gate là tool của repo, chạy bằng những gì repo có',
  calls()
    .slice(0, beforeDry)
    .every((c) => c.endpoint === undefined && c.apiKey === undefined),
  JSON.stringify(calls().slice(0, beforeDry).map((c) => Object.keys(c))),
);
check(
  'chạy thử ghi audit content.publish_dry_run, phân biệt với publish thật',
  a.state.c_admin_audit.some((e) => e.operation === 'content.publish_dry_run') &&
    !a.state.c_admin_audit.some((e) => e.operation === 'content.publish'),
  join(a.state.c_admin_audit.map((e) => e.operation)),
);

const liveRefused = await a.cms.publishCourseVersion('vi_en', true);
check(
  'publish thật bị chặn khi chưa đặt CMS_ALLOW_PUBLISH=1',
  liveRefused.ok === false &&
    (liveRefused.message ?? '').includes('CMS_ALLOW_PUBLISH=1') &&
    calls().length === dryRunTotal,
  `${liveRefused.message} / ${calls().length} lệnh`,
);
check(
  'bị chặn là bị chặn trước khi ghi: không có dòng lịch sử publish thứ hai',
  a.state.c_build_runs.length === 2 && a.state.c_admin_audit.length === 2,
  `${a.state.c_build_runs.length} runs / ${a.state.c_admin_audit.length} audit`,
);
check(
  'cờ publish được đọc từ môi trường, không phải hard-code',
  a.cms.readConfig({ ...process.env, CMS_ALLOW_PUBLISH: '1' }).publishAllowed &&
    !a.cms.readConfig({ ...process.env, CMS_ALLOW_PUBLISH: '0' }).publishAllowed &&
    !a.cms.readConfig({ ...process.env, CMS_ALLOW_PUBLISH: undefined }).publishAllowed,
);

// ---------- C. an edit after the gate stops the publisher ----------
await a.store.saveUnit({
  courseId: 'vi_en',
  unitId: '01-greetings',
  order: 0,
  draft: unitDraft('Chào hỏi và làm quen'),
  actorId: 'harness-publish',
  expectedRevision: 1,
});
const staleReadiness = await a.cms.publishReadiness('vi_en');
const stalePublish = await a.cms.publishCourseVersion('vi_en', false);
check(
  'unit sửa sau lần gate gần nhất → publish bị chặn và chỉ đúng unit đó',
  staleReadiness.gatesOk === false &&
    (staleReadiness.blocking ?? '').includes('01-greetings') &&
    stalePublish.ok === false &&
    (stalePublish.message ?? '') === staleReadiness.blocking,
  JSON.stringify(staleReadiness),
);
check(
  'bị chặn vì gate cũ thì không có lệnh nào được gọi thêm',
  calls().length === dryRunTotal,
  `${calls().length} lệnh`,
);

const noDraft = await a.cms.publishCourseVersion('khong_ton_tai', false);
check(
  'khóa chưa có bản nháp thì câu trả lời là "chưa có", không phải một hàng đợi chạy thử',
  noDraft.ok === false &&
    (noDraft.message ?? '').includes('chưa có bản nháp') &&
    calls().length === dryRunTotal,
  noDraft.message,
);

// ---------- D. a failing gate is reported, not swallowed ----------
const b = await pass('gate-fail', {
  CMS_HARNESS_FAIL: 'lint-course.mjs',
  CMS_HARNESS_ERR: 'lint-course: 02-family sentence 4 lacks a Vietnamese meaning\n',
});
blankRef = b.cms.blankUnit;
await seed(b);
const failedGates = await b.cms.runContentGates('vi_en');
check(
  'gate giữa đường chết thì dừng lại: cổng thứ ba không được gọi',
  join(calls().map((c) => c.line)) ===
    'tools/content/build-course.mjs, tools/content/lint-course.mjs',
  join(calls().map((c) => c.line)),
);
check(
  'thất bại mang tên cổng và dòng lỗi thật từ stderr, không phải "lỗi không rõ"',
  failedGates.status === 'FAILED' &&
    failedGates.message.includes('lint-course') &&
    failedGates.message.includes('lacks a Vietnamese meaning') &&
    failedGates.log.some((l) => l.startsWith('✗ lint-course')),
  JSON.stringify({ message: failedGates.message, log: failedGates.log.slice(-3) }),
);
const blockedByGate = await b.cms.publishCourseVersion('vi_en', false);
check(
  'gate đỏ thì publish từ chối trước khi khởi động tiến trình',
  blockedByGate.ok === false &&
    (blockedByGate.message ?? '').includes('kiểm tra') &&
    calls().length === 2,
  `${blockedByGate.message} / ${calls().length} lệnh`,
);

// ---------- E. live publish, and a publisher that dies ----------
const c = await pass('publish-live', { CMS_ALLOW_PUBLISH: '1' });
blankRef = c.cms.blankUnit;
await seed(c);
await c.cms.runContentGates('vi_en');
const beforeLive = calls().length;
const live = await c.cms.publishCourseVersion('vi_en', true);
const liveCall = calls()[beforeLive];
check(
  'publish thật gọi đúng tool, không gắn --dry-run',
  live.ok && liveCall?.line === 'tools/content/publish-appwrite.mjs --course vi_en --version v2',
  liveCall?.line ?? `không có lệnh thứ ${beforeLive}: ${live.message ?? JSON.stringify(live.run?.status)}`,
);
check(
  'publish thật ghi audit content.publish, không phải bản chạy thử',
  c.state.c_admin_audit.some((e) => e.operation === 'content.publish'),
  join(c.state.c_admin_audit.map((e) => e.operation)),
);

const d = await pass('publish-fail', {
  CMS_ALLOW_PUBLISH: '1',
  CMS_HARNESS_FAIL: 'publish-appwrite.mjs',
  CMS_HARNESS_ERR: 'uploading bundle 07: bucket rejected the file\n',
});
blankRef = d.cms.blankUnit;
await seed(d);
await d.cms.runContentGates('vi_en');
const failedPublish = await d.cms.publishCourseVersion('vi_en', true);
check(
  'bộ publish chết giữa chừng → dòng PUBLISH FAILED với lý do, không phải thành công giả',
  failedPublish.ok === false &&
    failedPublish.run?.status === 'FAILED' &&
    (failedPublish.message ?? '').includes('bucket rejected the file'),
  JSON.stringify({ message: failedPublish.message, status: failedPublish.run?.status }),
);
check(
  'thất bại vẫn được ghi xuống lịch sử để lần sau nhìn thấy',
  d.state.c_build_runs.some((r) => r.kind === 'PUBLISH' && r.status === 'FAILED'),
  join(d.state.c_build_runs.map((r) => `${r.kind}/${r.status}`)),
);

// ---------- F. the CMS never writes the app's own tables ----------
const touched = new Set();
for (const ctx of [a, b, c, d])
  for (const table of cTables) if (ctx.state[table.id].length) touched.add(table.id);
check(
  'mọi bảng CMS đụng tới đều là bảng c_* đã khai báo',
  [...touched].every((id) => id.startsWith('c_')) && !touched.has('undefined'),
  join([...touched]),
);
const lTables = foundation.tables.filter((t) => t.id.startsWith('l_'));
check(
  `không có bảng l_* nào trong sơ đồ (${join(lTables.map((t) => t.id))}) bị CMS ghi: publish là việc của service Learning`,
  lTables.length > 0 && [...touched].every((id) => !id.startsWith('l_')),
  join([...touched]),
);

await rm(scratch, { recursive: true, force: true });

if (failures.length) {
  console.error(`FAIL — ${failures.length}/${checks.length} publish checks failed:`);
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log(
  `OK — ${checks.length} checks: the gate button runs the repo's own three gates in the repo folder and keeps one run row (120 log lines, ✓ per gate), the default publish button passes --dry-run to tools/content/publish-appwrite.mjs with the CMS's own Appwrite pair, a live publish needs CMS_ALLOW_PUBLISH=1 and is refused before any process starts without it, an edit after the last green gate blocks publishing naming the unit, a red middle gate stops the loop and the button, a dying publisher lands as PUBLISH/FAILED with its stderr, and across all four passes only declared c_* tables were ever written.`,
);
