// Learner-administration proof (`src/server/ops/*` + `src/server/actions/users.ts`).
// The screen reads the app's own tables and writes exactly one thing back: the account status on
// Appwrite Auth. So this harness runs the real code against a stand-in Appwrite whose TablesDB
// REFUSES any createRow/updateRow/deleteRow on a table that is not `c_*` — a CMS that ever starts
// writing `l_*`/`p_*` fails here rather than corrupting a learner's progress. Filters are checked
// against the indexes declared in appwrite/schema/foundation.json, because an unindexed filter is a
// 400 that only appears on a live project. Offline: no project, no credentials, no network.
import { build } from 'esbuild';
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { mkdir, mkdtemp, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { HARNESS_ADMIN_SECRET, authCoreStub } from './harness-auth.mjs';

const appRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const repoRoot = path.resolve(appRoot, '..', '..');
const selfFile = fileURLToPath(import.meta.url);
const posix = (p) => p.replace(/\\/g, '/');

const STUB = `
export const world = {
  users: [],
  rows: {},
  calls: [],
  queries: [],
  reads: [],
  searchParams: [],
  // Every row write of the whole run, never reset: check G asks what the CMS touched in total.
  writes: [],
  unreachable: false,
  notFound: false,
};
export function resetWorld() {
  world.calls = [];
  world.queries = [];
  world.reads = [];
  world.searchParams = [];
  world.unreachable = false;
  world.notFound = false;
  // Each scenario starts from an empty audit trail, so "one row was written" means one row in THIS scenario.
  world.rows.c_admin_audit = [];
}
export class AppwriteException extends Error {
  constructor(message, code, type) {
    super(message);
    this.name = 'AppwriteException';
    this.code = code;
    this.type = type;
  }
}
export const ID = { unique: () => 'gen-' + (world.calls.push('id.unique') && 0), create: (v) => v };
export class Query {
  static equal(attribute, values) {
    return JSON.stringify({ method: 'equal', attribute, values });
  }
  static orderAsc(attribute) {
    return JSON.stringify({ method: 'orderAsc', attribute, values: [], indexes: [] });
  }
  static orderDesc(attribute) {
    return JSON.stringify({ method: 'orderDesc', attribute, values: [], indexes: [] });
  }
  static limit(n) {
    return JSON.stringify({ method: 'limit', attribute: null, values: [n], indexes: [] });
  }
}
const boom = () => {
  if (world.unreachable) throw new Error('fetch failed');
};
export class Client {
  constructor() { this.cfg = {}; }
  setEndpoint(v) { this.cfg.endpoint = v; return this; }
  setProject(v) { this.cfg.project = v; return this; }
  setKey(v) { this.cfg.key = v; return this; }
}
export class Users {
  constructor(client) { this.client = client; }
  async list({ queries = [], search } = {}) {
    boom();
    world.calls.push('users.list');
    world.queries.push({ table: 'users', queries });
    world.searchParams.push(search === undefined ? '(omitted)' : JSON.stringify(search));
    // A live project answers 400 to search="" — an empty term must never be sent as a param.
    if (search === '')
      throw new AppwriteException(
        'Invalid \`search\` param: Value must be a valid string and at least 1 chars and no longer than 256 chars',
        400,
        'search_invalid',
      );
    if (search) world.calls.push('users.list.search=' + search);
    return { total: world.users.length, users: world.users.map((u) => ({ ...u })) };
  }
  async get({ userId }) {
    boom();
    world.calls.push('users.get');
    const user = world.users.find((u) => u.$id === userId);
    if (!user || world.notFound)
      throw new AppwriteException('User not found', 404, 'user_not_found');
    return { ...user };
  }
  async updateStatus({ userId, status }) {
    boom();
    world.calls.push('users.updateStatus:' + status);
    const user = world.users.find((u) => u.$id === userId);
    if (!user) throw new AppwriteException('User not found', 404, 'user_not_found');
    user.status = status;
    return { ...user };
  }
}
export class TablesDB {
  constructor(client) { this.client = client; }
  async listRows({ databaseId, tableId, queries = [] }) {
    boom();
    world.calls.push('rows.list:' + tableId);
    world.reads.push(tableId);
    world.queries.push({ table: tableId, queries });
    let rows = [...(world.rows[tableId] ?? [])];
    for (const raw of queries) {
      const q = JSON.parse(raw);
      if (q.method === 'equal') rows = rows.filter((r) => q.values.includes(r[q.attribute]));
      if (q.method === 'orderAsc')
        rows.sort((a, b) => String(a[q.attribute]).localeCompare(String(b[q.attribute])));
      if (q.method === 'orderDesc')
        rows.sort((a, b) => String(b[q.attribute]).localeCompare(String(a[q.attribute])));
    }
    // Appwrite reports total for the whole filtered set, not for the page it just returned — the
    // overview counts rows by asking for one and reading this number, so the stub must behave the same.
    const total = rows.length;
    for (const raw of queries) {
      const q = JSON.parse(raw);
      if (q.method === 'limit') rows = rows.slice(0, q.values[0]);
    }
    return { total, rows };
  }
  async createRow({ tableId, rowId, data }) {
    boom();
    world.calls.push('rows.create:' + tableId);
    world.writes.push('create:' + tableId);
    if (!tableId.startsWith('c_'))
      throw new AppwriteException('Row Security: ' + tableId + ' is not writable by the CMS', 403, 'cross_table_permissions');
    (world.rows[tableId] ??= []).push({ $id: rowId, ...data });
    return { $id: rowId };
  }
  async updateRow({ tableId }) {
    boom();
    world.calls.push('rows.update:' + tableId);
    world.writes.push('update:' + tableId);
    if (!tableId.startsWith('c_'))
      throw new AppwriteException('Row Security: ' + tableId + ' is not writable by the CMS', 403, 'cross_table_permissions');
    return {};
  }
  async deleteRow({ tableId }) {
    boom();
    world.calls.push('rows.delete:' + tableId);
    world.writes.push('delete:' + tableId);
    if (!tableId.startsWith('c_'))
      throw new AppwriteException('Row Security: ' + tableId + ' is not writable by the CMS', 403, 'cross_table_permissions');
    return {};
  }
}
`;

const scratch = await mkdtemp(path.join(appRoot, 'node_modules', '.users-'));
// The bundle keeps `node-appwrite` external, so this stub is what the real modules resolve at run time.
const stubDir = path.join(scratch, 'node_modules', 'node-appwrite');
await mkdir(stubDir, { recursive: true });
await writeFile(
  path.join(stubDir, 'package.json'),
  '{"name":"node-appwrite","type":"module","main":"index.js"}',
  'utf8',
);
await writeFile(path.join(stubDir, 'index.js'), STUB, 'utf8');
await writeFile(path.join(scratch, 'stub-auth-core.mjs'), authCoreStub(), 'utf8');
await writeFile(
  path.join(scratch, 'stub-headers.mjs'),
  'export async function cookies() {\n' +
    '  return { get: () => ({ value: process.env.CMS_HARNESS_SECRET }), set: () => {}, delete: () => {} };\n' +
    '}\n',
  'utf8',
);

const bundled = await build({
  stdin: {
    contents:
      "export * from '@/server/ops/learners';\n" +
      "export * from '@/server/ops/overview';\n" +
      "export * from '@/server/actions/users';\n" +
      "export * from '@/server/config';\n" +
      "export * from '@/lib/activity';\n",
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
  },
});
const bundleFile = path.join(scratch, 'cms.mjs');
await writeFile(bundleFile, bundled.outputFiles[0].text, 'utf8');

Object.assign(process.env, {
  NODE_ENV: 'development',
  CMS_ADMIN_USER_IDS: 'harness-admin',
  CMS_HARNESS_SECRET: HARNESS_ADMIN_SECRET,
  CMS_DATA_DIR: path.join(scratch, 'data'),
  // A scratch repo root: the real .secrets/real.env must never decide the mode of a harness.
  CMS_REPO_ROOT: path.join(scratch, 'repo'),
  APPWRITE_ENDPOINT: 'https://appwrite.test/v1',
  APPWRITE_PROJECT_ID: 'harness-project',
  APPWRITE_API_KEY: 'harness-key',
  CMS_DATABASE_ID: 'cocenglish',
});

const { world, resetWorld } = await import(
  pathToFileURL(path.join(stubDir, 'index.js')).href
);

// The second pass of this file is the same scenario on a machine with no Appwrite pair at all. The
// variables are deleted rather than set to '': an empty value is not what a fresh clone looks like.
const offlineMode = process.env.CMS_HARNESS_OFFLINE === '1';
if (offlineMode)
  for (const key of ['APPWRITE_ENDPOINT', 'APPWRITE_PROJECT_ID', 'APPWRITE_API_KEY'])
    delete process.env[key];

const cms = await import(pathToFileURL(bundleFile).href);

let checks = 0;
const failures = [];
function assert(label, ok, detail = '') {
  checks += 1;
  if (!ok) failures.push(`${label}${detail ? `\n  ${detail}` : ''}`);
}
const errorFrom = (fn) => fn().then(() => null, (e) => e);
const learner = (userId, extra = {}) => ({
  $id: userId,
  $createdAt: '2026-10-13T08:51:18.399+00:00',
  email: `${userId}@example.test`,
  name: '',
  labels: [],
  status: true,
  ...extra,
});

const foundation = JSON.parse(
  readFileSync(path.join(repoRoot, 'appwrite', 'schema', 'foundation.json'), 'utf8'),
);
const indexColumns = new Map(
  foundation.tables.map((t) => [t.id, (t.indexes ?? []).map((i) => new Set(i.columns))]),
);
/** Appwrite rejects a filter on a column no index covers — and only a live project tells you. */
function filtersAreIndexed(entry) {
  const sets = indexColumns.get(entry.table) ?? [];
  for (const raw of entry.queries) {
    const q = JSON.parse(raw);
    if (q.method !== 'equal') continue;
    if (!sets.some((set) => set.has(q.attribute))) return `${entry.table}.${q.attribute}`;
  }
  return '';
}

// The accounts the test project really has: one with a full learning history, one anonymous, one bare.
const FULL = 'learner-full';
const ANON = '6accada81ff9e663e142';
const BARE = 'learner-bare';
function seedUsers() {
  world.users = [
    learner('harness-admin', { email: 'cms-admin@cocenglish.test' }),
    learner(FULL),
    learner(ANON, { email: '', name: '' }),
    learner(BARE),
  ];
  world.rows = {
    c_admin_audit: [],
    p_profiles: [
      {
        userId: FULL,
        username: 'mai_2011',
        nickname: 'Mai',
        publicOptIn: true,
        ageBand: 'TEEN',
        dailyGoal: 20,
        deletedAt: null,
        createdAt: '2026-10-13T09:00:00.000+00:00',
      },
    ],
    p_entitlements: [
      {
        userId: FULL,
        plan: 'SUPER',
        source: 'PURCHASE',
        status: 'ACTIVE',
        expiresAt: '2026-12-13T09:00:00.000+00:00',
      },
    ],
    l_enrollments: [
      {
        userId: FULL,
        courseId: 'vi_en',
        courseVersion: 'v2',
        frontierNodeOrder: 7,
        completedLessonsJson: JSON.stringify(['v2.u01n1l1', 'v2.u01n1l2', 'v2.u01n2l1']),
        masteredNodesJson: JSON.stringify(['u01n1']),
        legendaryNodesJson: JSON.stringify([]),
        placementUsed: true,
        active: true,
        proficiencyScore: 34,
      },
    ],
    p_day_activity: [
      { userId: FULL, day: '2026-11-05', studyXp: 30, replayXp: 10, completedLessons: 2 },
      { userId: FULL, day: '2026-11-06', studyXp: 20, replayXp: 0, completedLessons: 1 },
      { userId: BARE, day: '2026-11-01', studyXp: 5, replayXp: 0, completedLessons: 0 },
    ],
    p_feedback: [
      {
        userId: FULL,
        topic: 'AUDIO',
        message: 'Clip của bài 3 phát lại bị chậm.',
        platform: 'ANDROID',
        status: 'OPEN',
        createdAt: '2026-11-05T10:00:00.000+00:00',
      },
      {
        userId: BARE,
        topic: 'OTHER',
        message: 'Đã xử lý xong.',
        platform: 'IOS',
        status: 'CLOSED',
        createdAt: '2026-11-01T10:00:00.000+00:00',
      },
    ],
    p_user_reports: [
      {
        reporterId: BARE,
        targetUserId: FULL,
        reason: 'CHEATING',
        note: 'Tên hiển thị giả mạo.',
        status: 'OPEN',
        createdAt: '2026-11-06T07:00:00.000+00:00',
      },
      {
        reporterId: FULL,
        targetUserId: BARE,
        reason: 'SPAM',
        note: null,
        status: 'ACTIONED',
        createdAt: '2026-11-02T07:00:00.000+00:00',
      },
    ],
    l_reports: [
      {
        userId: FULL,
        exerciseId: 'v2.u03n1l2.i4',
        lessonVersion: 'v2.u03n1l2',
        category: 'ANSWER',
        note: 'Đáp án đúng bị sai.',
        status: 'OPEN',
        createdAt: '2026-11-04T12:00:00.000+00:00',
      },
    ],
  };
}

if (offlineMode) {
  // A machine with no Appwrite pair must not pretend to administer accounts.
  seedUsers();
  resetWorld();
  const refusedList = await errorFrom(() => cms.listLearners(''));
  const refusedQueue = await errorFrom(() => cms.learnerQueue());
  const refusedAction = await cms.setLearnerAccess(FULL, true);
  assert(
    'máy chưa nối Appwrite thì danh sách và hộp thư tài khoản cùng báo đúng một câu, không trả về rỗng giả',
    refusedList?.message === cms.LEARNERS_UNAVAILABLE &&
      refusedQueue?.message === cms.LEARNERS_UNAVAILABLE,
    `${refusedList?.message} / ${refusedQueue?.message}`,
  );
  assert('và khóa tài khoản bị từ chối trước khi gọi đi', refusedAction?.ok === false, JSON.stringify(refusedAction));
  assert('không có yêu cầu Appwrite nào được gửi', world.calls.length === 0, world.calls.join(','));
  const offlineStats = await cms.learnerOverview();
  assert(
    'máy chưa nối: tổng quan nói "chưa nối" thay vì in số 0 tự tin',
    offlineStats.connected === false && offlineStats.accounts === 0,
    JSON.stringify(offlineStats),
  );
  await rm(scratch, { recursive: true, force: true });
  if (failures.length) {
    console.error(`FAIL — ${failures.length}/${checks} offline checks failed:`);
    for (const f of failures) console.error(`  - ${f}`);
    process.exit(1);
  }
  console.log(`OK — ${checks} checks: máy chưa nối Appwrite thì màn người dùng từ chối rõ ràng.`);
  process.exit(0);
}

seedUsers();

// ---------- A. reading the account list ----------
resetWorld();
const accounts = await cms.listLearners('');
assert(
  'danh sách lấy từ Appwrite Users, đủ mọi tài khoản, mới nhất trước',
  accounts.length === 4 && accounts[0].userId === 'harness-admin',
  JSON.stringify(accounts.map((a) => a.userId)),
);
assert(
  'mỗi dòng có email, trạng thái và ngày tạo — không bịa thêm gì',
  accounts.every(
    (a) => typeof a.email === 'string' && typeof a.locked === 'boolean' && !!a.createdAt,
  ),
  JSON.stringify(accounts[0]),
);
assert(
  'tài khoản ẩn (không email) được đánh dấu để màn hình nói đúng',
  accounts.find((a) => a.userId === ANON)?.anonymous === true &&
    accounts.find((a) => a.userId === FULL)?.anonymous === false,
  JSON.stringify(accounts.map((a) => [a.userId, a.anonymous])),
);
assert('danh sách tài khoản không đọc bảng nào của app', world.reads.length === 0, world.reads.join(','));
assert(
  'không có từ khóa thì không gửi tham số search: Appwrite trả 400 cho chuỗi rỗng',
  world.searchParams.join(',') === '(omitted)',
  world.searchParams.join(','),
);

resetWorld();
await cms.listLearners('   ');
assert(
  'ô tìm kiếm toàn khoảng trắng cũng vậy, khoảng trắng bị bỏ trước khi gọi',
  world.searchParams.join(',') === '(omitted)',
  world.searchParams.join(','),
);

resetWorld();
await cms.listLearners('gmail');
assert(
  'từ khóa tìm kiếm được đưa cho Appwrite lọc, không lọc trong bộ nhớ',
  world.calls.includes('users.list.search=gmail'),
  world.calls.join(','),
);
resetWorld();
await cms.listLearners('x'.repeat(300));
assert(
  'từ khóa dài quá cỡ bị cắt còn đúng 256 ký tự thay vì bị từ chối',
  world.searchParams[0] === JSON.stringify('x'.repeat(256)),
  world.searchParams.join(','),
);

// ---------- B. one learner's own picture ----------
resetWorld();
const detail = await cms.learnerDetail(FULL);
assert(
  'học viên có hồ sơ: tên hiển thị, mã người dùng, mục tiêu mỗi ngày và ngày vào học',
  detail.profile.nickname === 'Mai' &&
    detail.profile.username === 'mai_2011' &&
    detail.profile.dailyGoal === 20 &&
    detail.profile.joinedAt === '2026-10-13T09:00:00.000+00:00' &&
    detail.profile.deleted === false,
  JSON.stringify(detail.profile),
);
assert(
  'gói đang dùng lấy từ p_entitlements, kèm hạn dùng',
  detail.entitlement.plan === 'SUPER' &&
    detail.entitlement.status === 'ACTIVE' &&
    detail.entitlement.expiresAt === '2026-12-13T09:00:00.000+00:00',
  JSON.stringify(detail.entitlement),
);
assert(
  'tiến độ đếm từ chính các cột Learning đã lưu: số bài hoàn thành, vị trí hiện tại',
  detail.enrollment.lessonsDone === 3 &&
    detail.enrollment.frontier === 7 &&
    detail.enrollment.courseVersion === 'v2' &&
    detail.enrollment.proficiency === 34,
  JSON.stringify(detail.enrollment),
);
assert(
  '14 ngày gần nhất, ngày mới nhất trước, XP cộng cả học lại',
  detail.days.length === 2 &&
    detail.days[0].day === '2026-11-06' &&
    detail.days[0].xp === 20 &&
    detail.days[1].xp === 40 &&
    detail.days[1].lessons === 2,
  JSON.stringify(detail.days),
);
assert(
  'góp ý của chính học viên này, lấy theo userId đã chỉ mục',
  detail.feedback.length === 1 &&
    detail.feedback[0].status === 'OPEN' &&
    detail.feedback[0].message.includes('bài 3'),
  JSON.stringify(detail.feedback),
);

resetWorld();
const bareDetail = await cms.learnerDetail(BARE);
assert(
  'người chưa có hồ sơ thì mọi mục là null, không phải con số 0 — app chưa từng ghi gì cho họ',
  bareDetail.profile === null &&
    bareDetail.entitlement === null &&
    bareDetail.enrollment === null &&
    bareDetail.feedback.length === 0 &&
    bareDetail.days.length === 1,
  JSON.stringify({
    profile: bareDetail.profile,
    enrollment: bareDetail.enrollment,
    days: bareDetail.days.length,
  }),
);

resetWorld();
const missing = await errorFrom(() => cms.learnerDetail('khong-co-tai-khoan'));
assert(
  'userId không có trong project → không có gì để hiện, và không đi đọc bảng học',
  missing === null && !world.reads.some((t) => t.startsWith('p_')),
  JSON.stringify({ missing, reads: world.reads }),
);

// ---------- C. every filter the code uses is indexed ----------
resetWorld();
await cms.listLearners('');
await cms.learnerDetail(FULL);
await cms.learnerQueue();
const unindexed = world.queries.map(filtersAreIndexed).filter(Boolean);
assert(
  'mọi bộ lọc đều nằm trên cột có chỉ mục trong sơ đồ Appwrite',
  unindexed.length === 0,
  join(unindexed),
);
assert(
  'màn hình chỉ đọc những bảng đã khai báo trong sơ đồ, không bảng nào khác',
  [...new Set(world.reads)].every((t) => indexColumns.has(t)),
  [...new Set(world.reads)].join(','),
);

// ---------- D. the learner queue ----------
resetWorld();
const queue = await cms.learnerQueue();
assert(
  'hộp thư người học: chỉ góp ý còn mở, mới nhất trước',
  queue.feedback.length === 1 &&
    queue.feedback[0].userId === FULL &&
    queue.feedback[0].createdAt.startsWith('2026-11-05'),
  JSON.stringify(queue.feedback),
);
assert(
  'báo cáo về người học: chỉ vụ còn mở, kèm ai báo và về ai',
  queue.userReports.length === 1 &&
    queue.userReports[0].targetUserId === FULL &&
    queue.userReports[0].reporterId === BARE &&
    queue.userReports[0].reason === 'CHEATING',
  JSON.stringify(queue.userReports),
);
assert(
  'báo lỗi bài học của người học: chỉ tin còn mở, kèm đúng câu hỏi',
  queue.contentReports.length === 1 &&
    queue.contentReports[0].exerciseId === 'v2.u03n1l2.i4' &&
    queue.contentReports[0].category === 'ANSWER',
  JSON.stringify(queue.contentReports),
);

// ---------- E. locking an account ----------
resetWorld();
const locked = await cms.setLearnerAccess(FULL, true);
assert(
  'khóa tài khoản gọi đúng Appwrite: status false',
  locked.ok === true && world.calls.includes('users.updateStatus:false'),
  JSON.stringify({ locked, calls: world.calls }),
);
assert(
  'trạng thái trong Appwrite đổi thật, và action báo về đúng trạng thái mới',
  world.users.find((u) => u.$id === FULL).status === false && locked.locked === true,
  JSON.stringify(locked),
);
assert(
  'một dòng nhật ký user.lock, ghi rõ ai khóa ai và trạng thái trước đó',
  world.rows.c_admin_audit.length === 1 &&
    world.rows.c_admin_audit[0].operation === 'user.lock' &&
    world.rows.c_admin_audit[0].targetId === FULL &&
    world.rows.c_admin_audit[0].actorId === 'harness-admin' &&
    JSON.parse(world.rows.c_admin_audit[0].beforeJson).locked === false,
  JSON.stringify(world.rows.c_admin_audit.map((e) => [e.operation, e.targetId, e.beforeJson])),
);

resetWorld();
const unlocked = await cms.setLearnerAccess(FULL, false);
assert(
  'mở khóa là thao tác ngược lại, ghi user.unlock',
  unlocked.ok === true &&
    world.calls.includes('users.updateStatus:true') &&
    world.rows.c_admin_audit[0].operation === 'user.unlock',
  JSON.stringify(world.rows.c_admin_audit.map((e) => e.operation)),
);

resetWorld();
// `/ops/audit` is the screen that answers "ai khóa ai, lúc nào": a lock it prints as a content update
// is a wrong sentence in the history, so the two verbs must be named and an unknown one must stay raw.
assert(
  'lịch sử hoạt động gọi đúng tên việc khóa/mở khóa, không gọi một lần khóa là "Cập nhật nội dung"',
  cms.operationLabel('user.lock') === 'Khóa tài khoản người học' &&
    cms.operationLabel('user.unlock') === 'Mở khóa tài khoản người học' &&
    cms.operationLabel('unit.update') === 'Cập nhật nội dung bài học' &&
    cms.operationLabel('mot.viec.moi') === 'mot.viec.moi',
  [
    cms.operationLabel('user.lock'),
    cms.operationLabel('user.unlock'),
    cms.operationLabel('mot.viec.moi'),
  ].join(' | '),
);

const again = await cms.setLearnerAccess(ANON, true);
const second = await cms.setLearnerAccess(ANON, true);
assert('lần đầu khóa thì có lệnh ghi', again.ok === true && world.calls.includes('users.updateStatus:false'));
assert(
  'khóa lại lần hai không ghi gì thêm và nói thẳng là đã khóa rồi',
  second.ok === true &&
    second.unchanged === true &&
    world.calls.filter((c) => c.startsWith('users.updateStatus')).length === 1 &&
    world.rows.c_admin_audit.length === 1,
  JSON.stringify({ second, calls: world.calls, audit: world.rows.c_admin_audit.length }),
);

// ---------- F. what the button must never do ----------
resetWorld();
const selfLock = await cms.setLearnerAccess('harness-admin', true);
assert(
  'không tự khóa tài khoản quản trị: bị từ chối, không gọi Appwrite, không ghi nhật ký',
  selfLock.ok === false &&
    (selfLock.message ?? '').includes('quản trị') &&
    !world.calls.some((c) => c.startsWith('users.updateStatus')) &&
    world.rows.c_admin_audit.length === 0,
  JSON.stringify({ selfLock, calls: world.calls }),
);

resetWorld();
for (const bad of ['', 'a b', 'x'.repeat(40), 'user/../etc', 'id!bad']) {
  const refused = await cms.setLearnerAccess(bad, true);
  if (refused.ok !== false || world.calls.length > 0) {
    assert(`userId "${bad}" phải bị chặn trước khi gọi đi`, false, JSON.stringify(refused));
    break;
  }
}
assert('mọi userId sai định dạng đều bị chặn mà không gọi Appwrite', world.calls.length === 0, world.calls.join(','));

resetWorld();
world.notFound = true;
const gone = await cms.setLearnerAccess(FULL, true);
assert(
  'tài khoản vừa bị xóa khỏi project → nói đúng, không ghi nhật ký cho một việc không xảy ra',
  gone.ok === false &&
    (gone.message ?? '') === cms.LEARNER_GONE &&
    world.rows.c_admin_audit.length === 0,
  JSON.stringify(gone),
);

resetWorld();
world.unreachable = true;
const offline = await cms.setLearnerAccess(FULL, true);
assert(
  'không gọi được Appwrite thì hỏng rõ ràng, không thành công giả',
  offline.ok === false &&
    (offline.message ?? '').includes('Appwrite') &&
    world.rows.c_admin_audit.length === 0,
  JSON.stringify(offline),
);

resetWorld();
process.env.CMS_HARNESS_SECRET = 'sess-harness-outsider';
const outsider = await errorFrom(() => cms.setLearnerAccess(FULL, true));
process.env.CMS_HARNESS_SECRET = HARNESS_ADMIN_SECRET;
assert(
  'người không có trong CMS_ADMIN_USER_IDS không khóa được ai, kể cả trước khi gọi Appwrite',
  outsider !== null && world.calls.length === 0,
  `${outsider?.message} / ${world.calls.join(',')}`,
);

// ---------- G. nothing but c_* was ever written ----------
assert(
  'CMS không ghi một dòng nào vào bảng của app (l_*/p_*): khóa tài khoản là việc của Appwrite Auth',
  world.writes.length > 0 && world.writes.every((w) => w.endsWith(':c_admin_audit')),
  world.writes.join(','),
);

// ---------- H. the overview numbers ----------
resetWorld();
const ovStats = await cms.learnerOverview();
assert(
  'tổng tài khoản lấy từ `total` của Appwrite Users, không đếm trang trả về',
  ovStats.connected && ovStats.accounts === 4,
  JSON.stringify({ connected: ovStats.connected, accounts: ovStats.accounts }),
);
assert(
  'gói trả phí đếm đúng dòng ACTIVE: 1 Super, 0 Max',
  ovStats.paying === 1 &&
    ovStats.plans.find((p) => p.plan === 'SUPER')?.count === 1 &&
    ovStats.plans.find((p) => p.plan === 'MAX')?.count === 0,
  JSON.stringify(ovStats.plans),
);
assert(
  'miễn phí = tổng tài khoản - gói trả phí, không âm',
  ovStats.free === 3,
  `free=${ovStats.free} accounts=${ovStats.accounts} paying=${ovStats.paying}`,
);
assert(
  'mỗi trạng thái gói có một con số, kể cả trạng thái chưa ai dùng',
  ovStats.statuses.length === 6 && ovStats.statuses.every((s) => typeof s.count === 'number'),
  JSON.stringify(ovStats.statuses),
);

resetWorld();
const ovRows = await cms.listLearnerRows('');
const fullRow = ovRows.find((r) => r.userId === FULL);
assert(
  'danh sách người học hiện tên thật và gói, không bắt đọc mã tài khoản',
  fullRow?.displayName === 'Mai' && fullRow?.plan === 'SUPER' && fullRow?.planStatus === 'ACTIVE',
  JSON.stringify(fullRow),
);
assert(
  'người chưa có hồ sơ vẫn có tên dự phòng từ email, không hiện chuỗi rỗng',
  ovRows.find((r) => r.userId === BARE)?.displayName === 'learner-bare@example.test',
  JSON.stringify(ovRows.map((r) => r.displayName)),
);

resetWorld();
const ovPlans = await cms.planRows(200);
assert(
  'trang gói nối tên người học vào dòng gói',
  ovPlans.length === 1 && ovPlans[0].userId === FULL && ovPlans[0].name === 'Mai' && ovPlans[0].plan === 'SUPER',
  JSON.stringify(ovPlans),
);
assert(
  'mọi bộ lọc của màn tổng quan và màn gói đều có index',
  world.queries.every((entry) => filtersAreIndexed(entry) === ''),
  world.queries.map((entry) => `${entry.table}:${filtersAreIndexed(entry)}`).join(' | '),
);

const ovQueue = await cms.openQueue();
assert(
  'hộp thư chờ đếm bằng `total` của từng bảng, không tải cả trang',
  ovQueue && ovQueue.feedback === 1 && ovQueue.userReports === 1 && ovQueue.contentReports === 1,
  JSON.stringify(ovQueue),
);

await rm(scratch, { recursive: true, force: true });

const child = spawnSync(process.execPath, [selfFile], {
  encoding: 'utf8',
  env: { ...process.env, CMS_HARNESS_OFFLINE: '1' },
});
const childOut = (child.stdout ?? '') + (child.stderr ?? '');
assert(
  'máy chưa nối Appwrite: màn người dùng từ chối, không trả về danh sách rỗng giả',
  child.status === 0 && childOut.includes('OK — 4 checks'),
  `status=${child.status}\n${childOut}`,
);

if (failures.length) {
  console.error(`FAIL — ${failures.length}/${checks} checks failed:`);
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log(
  `OK — ${checks} checks: the learner screen reads Appwrite Auth plus only indexed columns of the app's own tables, shows nothing invented for a learner without a profile, keeps a queue of open feedback / user reports / lesson reports, and the one thing it writes back is the account status — with a refusal for locking an admin out, for a malformed or already-deleted userId, for an unreachable Appwrite, for a second lock, for anyone outside CMS_ADMIN_USER_IDS, and for a machine with no Appwrite at all. The overview counts accounts, plans and the open queue from \`total\` (never by loading every row), names a learner from their profile instead of their id, and reports "chưa nối" rather than a confident zero when the project is unreachable.`,
);

function join(list) {
  return list.join(', ');
}
