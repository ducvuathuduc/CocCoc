// Content-lifecycle proof. The five controls an admin presses every day — "Nhập bảng tác giả từ repo",
// "Tạo unit", Lưu unit, đổi Cấu trúc khóa, Xóa unit — live in src/server/actions/{import,course,unit}.ts.
// Their pure helpers (parse/render, order, structure, lint) have harnesses of their own; what nothing
// covered was the *actions*: which rows they write, in what order, and what they refuse to write. Those
// are exactly the places where a CMS silently loses content.
//
// This runs the real actions against a fake Appwrite TablesDB that enforces the c_* declaration from
// appwrite/schema/foundation.json (undeclared column → rejected, unique index → 409), and against the
// repository folder in read-only mode: the import action is allowed to run its own
// apps/cms/scripts/read-authored.mjs for real, because that script only reads authored .mjs tables. The
// repo folder is hashed before and after to prove none of this wrote into it. Nothing here contacts a
// project, writes a content file or runs a gate.
import { build } from 'esbuild';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { HARNESS_ADMIN_SECRET, authCoreStub } from './harness-auth.mjs';

const appRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const repoRoot = path.resolve(appRoot, '..', '..');
const COURSE = 'vi_en';
const sourceDir = path.join(repoRoot, 'content', COURSE, 'source', 'v2');

/** Content bytes + names of the folder the export action would write into. */
function fingerprint(dir, rel = '') {
  const out = [];
  for (const entry of readdirSync(path.join(dir, rel)).sort()) {
    const child = path.join(rel, entry);
    if (statSync(path.join(dir, child)).isDirectory()) out.push(...fingerprint(dir, child));
    else out.push(`${child}:${createHash('sha256').update(readFileSync(path.join(dir, child))).digest('hex')}`);
  }
  return out;
}
const repoBefore = fingerprint(sourceDir).join('\n');

// Independent oracle: read the authored tables once, outside the action, so every import assertion below
// compares the CMS against the repo rather than against a number typed into this file.
const repo = JSON.parse(
  execFileSync(process.execPath, [path.join(appRoot, 'scripts', 'read-authored.mjs'), COURSE, 'v2'], {
    cwd: repoRoot,
    maxBuffer: 32 * 1024 * 1024,
  }).toString(),
);

const scratch = await mkdtemp(path.join(appRoot, 'node_modules', '.lifecycle-'));
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
      "export * from '@/server/actions/import';\n" +
      "export * from '@/server/actions/course';\n" +
      "export * from '@/server/actions/unit';\n" +
      "export * from '@/cms/lint';\n" +
      "export * from '@/cms/structure';\n" +
      "export * from '@/cms/tables';\n" +
      "export * from '@/server/store';\n",
    resolveDir: appRoot,
    loader: 'ts',
  },
  bundle: true,
  format: 'esm',
  platform: 'node',
  write: false,
  external: ['node-appwrite'],
  alias: {
    '@': path.join(appRoot, 'src').replace(/\\/g, '/'),
    '@/server/auth-core': path.join(scratch, 'stub-auth-core.mjs').replace(/\\/g, '/'),
    'next/headers': path.join(scratch, 'stub-headers.mjs').replace(/\\/g, '/'),
  },
});
const bundleFile = path.join(scratch, 'cms.mjs');
await writeFile(bundleFile, bundled.outputFiles[0].text, 'utf8');

Object.assign(process.env, {
  NODE_ENV: 'development',
  CMS_ADMIN_USER_IDS: 'harness-lifecycle',
  CMS_HARNESS_SECRET: HARNESS_ADMIN_SECRET,
  CMS_DATA_DIR: path.join(scratch, 'data'),
  // The import action runs the repo's own reader, so this really is the repository folder.
  CMS_REPO_ROOT: repoRoot,
  APPWRITE_ENDPOINT: 'http://127.0.0.1:9',
  APPWRITE_PROJECT_ID: 'harness-project',
  APPWRITE_API_KEY: 'harness-key',
  CMS_DATABASE_ID: 'cocenglish',
});

const checks = [];
const failures = [];
const check = (label, ok, detail = '') => {
  checks.push(label);
  if (!ok) failures.push(`${label}${detail ? ` — ${detail}` : ''}`);
};
const join = (list) => list.join(', ');
const slice = (text, n = 220) => String(text).slice(0, n);

const foundation = JSON.parse(
  readFileSync(path.join(repoRoot, 'appwrite', 'schema', 'foundation.json'), 'utf8'),
);
const cTables = foundation.tables.filter((t) => t.id.startsWith('c_'));
const byId = new Map(cTables.map((t) => [t.id, t]));

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

const queries = [];
const state = Object.fromEntries(cTables.map((t) => [t.id, []]));
const tables = {
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
      if (q.method === 'orderAsc')
        rows.sort((a, b) =>
          typeof a[q.attribute] === 'number' && typeof b[q.attribute] === 'number'
            ? a[q.attribute] - b[q.attribute]
            : String(a[q.attribute]).localeCompare(String(b[q.attribute])),
        );
      if (q.method === 'orderDesc')
        rows.sort((a, b) =>
          typeof a[q.attribute] === 'number' && typeof b[q.attribute] === 'number'
            ? b[q.attribute] - a[q.attribute]
            : String(b[q.attribute]).localeCompare(String(a[q.attribute])),
        );
    }
    return { rows };
  },
  async createRow({ tableId, rowId, data }) {
    const problem = validate(tableId, data, { partial: false });
    if (problem) throw { code: 400, message: problem };
    for (const index of byId.get(tableId).indexes.filter((i) => i.type === 'unique')) {
      if (state[tableId].some((r) => index.columns.every((c) => r[c] === data[c])))
        throw { code: 409, message: `duplicate ${index.key} in ${tableId}` };
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

const cms = await import(pathToFileURL(bundleFile).href);
const store = cms.getStore();
store.tables = tables;

const courseRow = () => state.c_courses[0];
const courseDraft = () => JSON.parse(courseRow().draftJson);
const auditOps = () => state.c_admin_audit.map((e) => e.operation);
const lastAudit = () => state.c_admin_audit.at(-1);
const unitRows = () => state.c_units;

// ---------- A. import: the repo's authored tables become drafts, one row per unit ----------
const imported = await cms.importCourseFromRepo(COURSE);
check(
  'nút nhập tạo đúng một hàng unit cho mỗi file tác giả, không hàng nào thừa',
  imported.ok === true &&
    imported.units === repo.units.length &&
    unitRows().length === repo.units.length,
  `${JSON.stringify(imported)} / ${unitRows().length} hàng / ${repo.units.length} file repo`,
);
const importedUnits = await store.listUnits(COURSE);
check(
  'mã unit nhập vào do repo quyết định: NN theo đúng index file tác giả, theme theo file',
  importedUnits.every(
    (u, i) =>
      u.order === i &&
      u.unitId === `${String(i + 1).padStart(2, '0')}-${repo.units[i].unit.theme}` &&
      u.draft.theme === repo.units[i].unit.theme,
  ),
  join(importedUnits.map((u) => `${u.order}:${u.unitId}`)),
);
check(
  'section nhập nguyên văn từ course.mjs của repo',
  JSON.stringify(courseDraft().sections) === JSON.stringify(repo.sections),
  `${courseDraft().sections.length} section so với ${repo.sections.length} của repo`,
);
check(
  'theme của mọi unit nhập vào thuộc đúng một section, nên lần xuất kế tiếp build-course không chết',
  cms.structureIssues(courseDraft().sections, importedUnits.map((u) => u.draft.theme)).length === 0,
  join(cms.structureIssues(courseDraft().sections, importedUnits.map((u) => u.draft.theme))),
);
check(
  'thông tin khóa lấy từ repo chứ không bịa, kèm trạng thái ACTIVE và version mà CMS đang xuất',
  courseDraft().course.courseId === repo.course.courseId &&
    courseDraft().course.title === repo.course.title &&
    courseDraft().course.sourceLocale === repo.course.sourceLocale &&
    courseDraft().course.targetLocale === repo.course.targetLocale &&
    courseDraft().course.status === 'ACTIVE' &&
    courseDraft().version === 'v2',
  slice(JSON.stringify(courseDraft().course)),
);
check(
  'bản nháp nhập vào có nội dung thật, và cột đếm trên hàng unit trùng với độ dài nháp',
  importedUnits.every(
    (u, i) =>
      u.draft.vocab.length > 0 &&
      u.draft.sentences.length > 0 &&
      u.draft.title === repo.units[i].unit.title,
  ) &&
    unitRows().every((r) => {
      const d = JSON.parse(r.draftJson);
      return r.vocabCount === d.vocab.length && r.sentenceCount === d.sentences.length;
    }),
  slice(JSON.stringify(unitRows().slice(0, 3).map((r) => `${r.unitId}:${r.vocabCount}/${r.sentenceCount}`))),
);
const blocked = importedUnits
  .map((u) => [u.unitId, cms.lintUnit(u.draft).filter((i) => i.level === 'error')])
  .filter(([, list]) => list.length > 0);
check(
  'cả 16 unit nhập từ repo đều ở trạng thái bấm Lưu được — không unit nào cổng lint của editor chặn',
  blocked.length === 0,
  join(blocked.map(([id, list]) => `${id}: ${list[0].message}`)),
);
check(
  'mỗi dòng từ nhập vào đều có id, nên key media và câu hỏi trỏ về đúng dòng',
  importedUnits.every((u) => u.draft.vocab.every((v) => typeof v.id === 'string' && v.id.length > 0)),
  join(importedUnits.filter((u) => u.draft.vocab.some((v) => !v.id)).map((u) => u.unitId)),
);
const createdAtByRow = new Map(unitRows().map((r) => [r.$id, r.createdAt]));
const revisionAfterFirstImport = new Map(unitRows().map((r) => [r.unitId, r.revision]));
const reimported = await cms.importCourseFromRepo(COURSE);
check(
  'nhập lại lần hai ghi đè chứ không nhân đôi: vẫn đúng một hàng cho mỗi đơn vị',
  reimported.units === repo.units.length && unitRows().length === repo.units.length,
  `${unitRows().length} hàng`,
);
check(
  'nhập lại tăng revision thêm 1 trên từng hàng và giữ nguyên ngày tạo',
  unitRows().every(
    (r) =>
      r.revision === revisionAfterFirstImport.get(r.unitId) + 1 &&
      r.createdAt === createdAtByRow.get(r.$id),
  ),
  slice(JSON.stringify(unitRows().slice(0, 3).map((r) => `${r.unitId}@${r.revision}`))),
);
check(
  'mỗi lần nhập ghi một mục audit course.import kèm số unit',
  auditOps().filter((o) => o === 'course.import').length === 2 &&
    JSON.parse(lastAudit().afterJson).units === repo.units.length,
  join(auditOps()),
);

const logged = [];
const realError = console.error;
console.error = (...args) => void logged.push(args);
const missing = await cms.importCourseFromRepo('khong_co_trong_repo');
console.error = realError;
check(
  'khóa không có bảng tác giả thì hành động trả về lỗi thay vì ném: server action ném lỗi bị Next thay bằng digest, trình duyệt mất luôn câu hướng dẫn',
  missing.ok === false && typeof missing.message === 'string' && missing.units === undefined,
  slice(JSON.stringify(missing), 300),
);
check(
  'người vận hành nhận một câu tiếng Việt chỉ đúng folder cần kiểm tra',
  missing.message.includes('khong_co_trong_repo') &&
    missing.message.includes('content/khong_co_trong_repo/source/v2') &&
    !missing.message.includes('Command failed') &&
    !missing.message.includes('ERR_MODULE_NOT_FOUND') &&
    missing.message.split('\n').length === 1,
  slice(missing.message, 300),
);
check(
  'và Node stack trace vẫn xuống log server, không biến mất theo câu chữ trên toast',
  logged.some((args) =>
    args.some((a) => String(a?.stderr ?? a?.message ?? a).includes('ERR_MODULE_NOT_FOUND')),
  ),
  slice(JSON.stringify(logged.map((a) => a.map(String))), 200),
);
check(
  'và lỗi đó không để lại hàng dở: khóa lạ vẫn chưa có bản nháp, các hàng khác không đổi',
  (await store.getCourse('khong_co_trong_repo')) === null &&
    state.c_courses.length === 1 &&
    unitRows().length === repo.units.length,
  `${state.c_courses.length} hàng khóa / ${unitRows().length} hàng unit`,
);

// ---------- B. saveCourseMeta: editing a title must not touch the structure ----------
const sectionsBeforeMeta = JSON.stringify(courseDraft().sections);
const metaOk = await cms.saveCourseMeta({
  courseId: COURSE,
  title: '  Tiếng Anh cho người Việt (biên tập)  ',
  sourceLocale: ' vi-VN ',
  targetLocale: 'en-US',
  status: 'DRAFT',
  version: '',
  expectedRevision: courseRow().revision,
});
const revisionAfterMeta = courseRow().revision;
check(
  'lưu thông tin khóa tự cắt khoảng trắng thừa, và version để trống thì giữ bản đang có chứ không thành rỗng',
  metaOk.ok &&
    courseDraft().course.title === 'Tiếng Anh cho người Việt (biên tập)' &&
    courseDraft().course.sourceLocale === 'vi-VN' &&
    courseDraft().version === 'v2',
  slice(JSON.stringify({ reply: metaOk, course: courseDraft().course })),
);
check(
  'lưu thông tin khóa không được phép viết lại cấu trúc section — đó là việc của panel Cấu trúc khóa',
  JSON.stringify(courseDraft().sections) === sectionsBeforeMeta,
  `${courseDraft().sections.length} section sau khi lưu meta`,
);
check(
  'meta ghi kèm audit course.update với revision trước và sau để lần điều tra sau đọc được',
  auditOps().at(-1) === 'course.update' &&
    JSON.parse(lastAudit().beforeJson).revision === revisionAfterMeta - 1 &&
    JSON.parse(lastAudit().afterJson).revision === revisionAfterMeta,
  slice(JSON.stringify({ op: lastAudit().operation, before: lastAudit().beforeJson, after: lastAudit().afterJson })),
);
const metaInvalid = await cms.saveCourseMeta({
  courseId: COURSE,
  title: '   ',
  sourceLocale: 'vi-VN',
  targetLocale: 'en-US',
  status: 'ACTIVE',
  version: 'v2',
  expectedRevision: revisionAfterMeta,
});
check(
  'tên khóa rỗng bị từ chối bằng lời, không bằng một hàng trống',
  metaInvalid.ok === false && (metaInvalid.message ?? '').includes('chưa hợp lệ'),
  slice(JSON.stringify(metaInvalid)),
);
check(
  'và cú bị từ chối đó không ghi thêm revision, không đổi tên đang lưu',
  courseRow().revision === revisionAfterMeta &&
    courseDraft().course.title === 'Tiếng Anh cho người Việt (biên tập)',
  `${courseRow().revision} / ${courseDraft().course.title}`,
);
const metaStale = await cms.saveCourseMeta({
  courseId: COURSE,
  title: 'Tiếng Anh cho người Việt',
  sourceLocale: 'vi-VN',
  targetLocale: 'en-US',
  status: 'ACTIVE',
  version: 'v2',
  expectedRevision: 1,
});
check(
  'revision cũ thì hành động trả một câu tiếng Việt về xung đột thay vì ném 500 và ghi đè bản của người khác',
  metaStale.ok === false &&
    (metaStale.message ?? '').length > 10 &&
    !metaStale.warning &&
    courseDraft().course.title === 'Tiếng Anh cho người Việt (biên tập)',
  slice(JSON.stringify(metaStale)),
);
const metaNoCourse = await cms.saveCourseMeta({
  courseId: 'chua_nhap',
  title: 'Khóa mới',
  sourceLocale: 'vi-VN',
  targetLocale: 'en-US',
  status: 'ACTIVE',
  version: 'v1',
  expectedRevision: 0,
});
check(
  'chưa nhập mà đã lưu thông tin thì được hướng dẫn nhập từ repo trước, không phải một hàng khóa cô đơn',
  metaNoCourse.ok === false &&
    (metaNoCourse.message ?? '').includes('nhập từ repo') &&
    state.c_courses.length === 1,
  slice(JSON.stringify(metaNoCourse)),
);

// ---------- C. createUnitDraft: a new unit is born inside a section ----------
const themeNew = cms.slug('Kiểm tra vòng đời');
const created = await cms.createUnitDraft(COURSE, 'Kiểm tra vòng đời', 'B1');
const createdRow = unitRows().find((r) => r.unitId === created.unitId);
check(
  'tạo unit: mã là NN-theme sinh từ tên, vị trí cuối khóa, và hàng unit thật sự tồn tại',
  created.ok && created.unitId === `17-${themeNew}` && createdRow?.order === 16 && unitRows().length === 17,
  slice(JSON.stringify({ reply: created, order: createdRow?.order, rows: unitRows().length })),
);
check(
  'unit mới mang theme vào section cuối *trước khi* hàng unit được ghi, vì build-course ném lỗi với theme mồ côi',
  courseDraft().sections.at(-1).units.includes(themeNew) &&
    courseDraft().sections.at(-1).units.filter((t) => t === themeNew).length === 1,
  slice(JSON.stringify(courseDraft().sections.map((s) => s.units.length))),
);
const freshDraft = (await store.getUnit(COURSE, created.unitId)).draft;
check(
  'bản nháp khởi đầu đúng khuôn editor: 5 mức trống, một dòng từ chưa id, cefr như người chọn',
  freshDraft.levels.length === 5 &&
    freshDraft.levels.every((l) => l === '') &&
    freshDraft.vocab.length === 1 &&
    freshDraft.vocab[0].id === '' &&
    freshDraft.cefr === 'B1' &&
    freshDraft.theme === themeNew,
  slice(JSON.stringify(freshDraft)),
);
const rowsBeforeDup = unitRows().length;
const sectionsBeforeDup = JSON.stringify(courseDraft().sections);
const dup = await cms.createUnitDraft(COURSE, 'Greetings');
check(
  'trùng theme với unit đã có thì bị chặn trước khi ghi, kể cả cấu trúc section',
  dup.ok === false &&
    (dup.message ?? '').includes('greetings') &&
    unitRows().length === rowsBeforeDup &&
    JSON.stringify(courseDraft().sections) === sectionsBeforeDup,
  slice(JSON.stringify(dup)),
);
const noLetters = await cms.createUnitDraft(COURSE, '—•…!?');
check(
  'tên không sinh được theme nào (toàn dấu câu) thì báo rõ cần chữ cái, không tạo unit “18-” rỗng',
  noLetters.ok === false && (noLetters.message ?? '').includes('chữ cái'),
  slice(JSON.stringify(noLetters)),
);
check(
  'cả hai lần bị từ chối đều không để lại audit unit.create',
  auditOps().filter((o) => o === 'unit.create').length === 1,
  join(auditOps().filter((o) => o === 'unit.create')),
);

// ---------- D. saveCourseStructure: only what the repo gates accept ----------
// Built from the repo oracle rather than the stored draft, so a bug in an earlier action shows up as a
// failed check here instead of a crash several statements later.
const dirtySections = repo.sections.map((s, i) => ({
  ...s,
  sectionId: i === 0 ? ' sec1 ' : s.sectionId,
  title: `  ${s.title} `,
  units: [...s.units, ...(i === 1 ? [themeNew, themeNew, '  '] : [])],
}));
const structureOk = await cms.saveCourseStructure({
  courseId: COURSE,
  sections: dirtySections,
  expectedRevision: courseRow().revision,
});
const cleanSaved = courseDraft().sections;
check(
  'lưu cấu trúc tự cắt khoảng trắng và bỏ unit trùng trong một section trước khi ghi',
  structureOk.ok &&
    cleanSaved[0].sectionId === 'sec1' &&
    cleanSaved[1].title === dirtySections[1].title.trim() &&
    cleanSaved[1].units.filter((t) => t === themeNew).length === 1 &&
    cleanSaved.every((s) => s.units.every((t) => t.trim().length > 0)),
  slice(JSON.stringify(cleanSaved.map((s) => [s.sectionId, s.units.length]))),
);
check(
  'cấu trúc mới ghi kèm audit course.structure có trước và sau',
  auditOps().at(-1) === 'course.structure' &&
    JSON.parse(lastAudit().beforeJson).length === repo.sections.length &&
    JSON.parse(lastAudit().afterJson)[0].sectionId === 'sec1',
  slice(JSON.stringify({ op: lastAudit().operation, after: lastAudit().afterJson })),
);
const sectionsAfterGoodSave = JSON.stringify(cleanSaved);
// The five broken shapes are built from the repo's own structure, not from whatever is stored now, so a
// bug in an earlier action fails its own check instead of crashing these five.
const validSections = repo.sections.map((s, i) => (i === 1 ? { ...s, units: [...s.units, themeNew] } : s));
const revisionAfterStructure = courseRow().revision;
for (const [label, sections] of [
  ['unit rơi khỏi mọi section', validSections.map((s) => ({ ...s, units: s.units.filter((t) => t !== 'plans') }))],
  [
    'một unit nằm ở hai section',
    [
      { ...validSections[0], units: [...validSections[0].units, 'greetings'] },
      { ...validSections[1], units: [...validSections[1].units, 'greetings'] },
    ],
  ],
  ['chỉ còn một section', [validSections[0]]],
  ['trùng mã section', [validSections[0], { ...validSections[1], sectionId: validSections[0].sectionId }]],
  ['section chưa đặt tên', validSections.map((s, i) => ({ ...s, title: i === 0 ? '  ' : s.title }))],
]) {
  const refused = await cms.saveCourseStructure({
    courseId: COURSE,
    sections,
    expectedRevision: revisionAfterStructure,
  });
  const expected = cms
    .structureIssues(
      sections.map((s) => ({
        sectionId: s.sectionId.trim(),
        title: s.title.trim(),
        units: [...new Set(s.units.map((t) => t.trim()).filter(Boolean))],
      })),
      (await store.listUnits(COURSE)).map((u) => u.draft.theme),
    )
    .join(' ');
  check(
    `cấu trúc “${label}” bị từ chối bằng *đúng* câu mà panel cấu trúc sẽ hiển thị, và không ghi gì`,
    refused.ok === false &&
      refused.message === expected &&
      courseRow().revision === revisionAfterStructure &&
      JSON.stringify(courseDraft().sections) === sectionsAfterGoodSave,
    `${slice(refused.message, 160)} vs ${slice(expected, 160)}`,
  );
}
const structureStale = await cms.saveCourseStructure({
  courseId: COURSE,
  sections: cleanSaved,
  expectedRevision: 1,
});
check(
  'cấu trúc gửi đi với revision cũ thì trả lời xung đột thay vì đè',
  structureStale.ok === false &&
    !structureStale.warning &&
    JSON.stringify(courseDraft().sections) === sectionsAfterGoodSave,
  slice(JSON.stringify(structureStale)),
);

// ---------- E. saveUnitDraft: the editor's own gate ----------
const target = await store.getUnit(COURSE, '01-greetings');
const editDraft = structuredClone(target.draft);
editDraft.vocab[0].id = '';
editDraft.vocab[0].en = 'xin chào lại';
const savedUnit = await cms.saveUnitDraft({
  courseId: COURSE,
  unitId: '01-greetings',
  order: target.order,
  draft: editDraft,
  expectedRevision: target.revision,
});
const savedBack = await store.getUnit(COURSE, '01-greetings');
check(
  'lưu unit: dòng từ không id thì CMS tự sinh id từ chữ tiếng Anh, đúng luật của parser repo',
  savedUnit.ok && savedBack.draft.vocab[0].id === cms.slug('xin chào lại'),
  slice(JSON.stringify(savedBack.draft.vocab[0])),
);
check(
  'và audit phân biệt được đây là sửa (unit.update) chứ không phải tạo mới',
  auditOps().at(-1) === 'unit.update' &&
    JSON.parse(lastAudit().beforeJson).revision === target.revision,
  slice(JSON.stringify({ op: lastAudit().operation, before: lastAudit().beforeJson })),
);
const brokenDraft = structuredClone(savedBack.draft);
brokenDraft.vocab[1] = { ...brokenDraft.vocab[0] };
const refusedSave = await cms.saveUnitDraft({
  courseId: COURSE,
  unitId: '01-greetings',
  order: target.order,
  draft: brokenDraft,
  expectedRevision: savedBack.revision,
});
check(
  'nháp có lỗi chặn lưu thì action trả về đúng danh sách lỗi để editor gạch chân, và không ghi nửa bản',
  refusedSave.ok === false &&
    (refusedSave.issues ?? []).length > 0 &&
    refusedSave.issues.some((i) => i.level === 'error'),
  slice(JSON.stringify({ issues: (refusedSave.issues ?? []).slice(0, 2), message: refusedSave.message })),
);
const afterRefused = await store.getUnit(COURSE, '01-greetings');
check(
  'bản nháp trên hàng vẫn là bản tốt: chữ cũ không bị lô lỗi đè lên, revision không tăng',
  afterRefused.revision === savedBack.revision &&
    afterRefused.draft.vocab[0].en === 'xin chào lại' &&
    afterRefused.draft.vocab.length === savedBack.draft.vocab.length,
  slice(JSON.stringify({ rev: afterRefused.revision, n: afterRefused.draft.vocab.length })),
);

// ---------- F. deleteUnitDraft: the row and its theme go together ----------
const toDelete = await store.getUnit(COURSE, created.unitId);
const deleted = await cms.deleteUnitDraft(COURSE, created.unitId);
check(
  'xóa unit: hàng unit biến mất và audit unit.delete mang theo theme đã xóa',
  deleted.ok &&
    unitRows().find((r) => r.unitId === created.unitId) === undefined &&
    unitRows().length === repo.units.length &&
    auditOps().at(-1) === 'unit.delete' &&
    JSON.parse(lastAudit().beforeJson).theme === toDelete.draft.theme,
  slice(JSON.stringify({ reply: deleted, rows: unitRows().length })),
);
check(
  'xóa unit cũng gỡ theme khỏi section — nếu không course.mjs còn một theme không unit nào và cổng lint từ chối',
  courseDraft().sections.every((s) => !s.units.includes(themeNew)) &&
    cms.structureIssues(courseDraft().sections, (await store.listUnits(COURSE)).map((u) => u.draft.theme)).length === 0,
  slice(JSON.stringify(courseDraft().sections.map((s) => s.units.filter((t) => t === themeNew)))),
);
const deletedAgain = await cms.deleteUnitDraft(COURSE, created.unitId);
check(
  'xóa lần hai (cửa sổ khác đã xóa trước) thì báo mất rồi, không âm thầm thành công',
  deletedAgain.ok === false && (deletedAgain.message ?? '').includes('không còn tồn tại'),
  slice(JSON.stringify(deletedAgain)),
);
check(
  'khóa sau cả vòng đời nhập→tạo→sửa→xóa vẫn còn đúng số unit của repo, vị trí liền mạch, cấu trúc sạch',
  unitRows().length === repo.units.length &&
    (await store.listUnits(COURSE)).every((u, i) => u.order === i) &&
    cms.structureIssues(courseDraft().sections, (await store.listUnits(COURSE)).map((u) => u.draft.theme)).length === 0,
  `${unitRows().length} unit`,
);

// ---------- G. nothing was written outside the CMS's own tables, or into the repo ----------
const touched = new Set();
for (const table of cTables) if (state[table.id].length) touched.add(table.id);
check(
  'cả vòng đời nội dung chỉ ghi vào bảng c_* đã khai báo',
  [...touched].every((id) => id.startsWith('c_')),
  join([...touched]),
);
const indexedAttrs = new Map(cTables.map((t) => [t.id, new Set(t.indexes.flatMap((i) => i.columns))]));
const unindexed = [];
for (const { tableId, qs } of queries) {
  for (const raw of qs) {
    const q = JSON.parse(raw);
    if (!['equal', 'orderAsc', 'orderDesc'].includes(q.method)) continue;
    if (!indexedAttrs.get(tableId).has(q.attribute)) unindexed.push(`${tableId}:${q.method}(${q.attribute})`);
  }
}
check(
  'mọi bộ lọc/sắp xếp gửi lên Appwrite đều có index khai báo sẵn — thiếu là Appwrite từ chối đọc',
  unindexed.length === 0 && queries.length >= 12,
  `${join(unindexed)} / ${queries.length} lượt đọc`,
);
check(
  'hành động import chỉ đọc repo: không file tác giả nào trong content/vi_en/source/v2 thay đổi',
  fingerprint(sourceDir).join('\n') === repoBefore,
  `${repo.units.length} file đã soi`,
);

await rm(scratch, { recursive: true, force: true });

if (failures.length) {
  console.error(`FAIL — ${failures.length}/${checks.length} lifecycle checks failed:`);
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log(
  `OK — ${checks.length} checks: nhập ${repo.units.length} unit từ bảng tác giả thật sinh đúng mã NN-theme theo index file, section nguyên văn từ course.mjs, vị trí liền mạch, lint sạch và id đầy đủ nên bấm Lưu được ngay, nhập lại ghi đè chứ không nhân đôi; lưu thông tin khóa không đụng tới cấu trúc section và bị chặn khi revision cũ; tạo unit đưa theme vào section cuối trước khi ghi hàng, chặn trùng theme trước khi ghi; cấu trúc tự cắt-trùng và từ chối unit mồ côi / trùng section / dưới 2 section / section vô tên bằng đúng câu của panel; lưu unit tự sinh id từ headword và trả danh sách lỗi thay vì ghi nửa bản; xóa unit mang theo theme của nó khỏi section; chỉ bảng c_* được ghi, mọi lượt đọc có index, và folder tác giả không đổi một byte nào.`,
);
