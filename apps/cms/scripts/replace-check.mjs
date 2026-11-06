// Bulk replace proof. Search answers "where is this text"; `src/cms/replace.ts` answers "and may I write it
// back everywhere" (`src/app/(admin)/courses/[courseId]/search/page.tsx` shows the preview, the server action
// writes it). The harness checks the two column lists never drift apart, that the replacement matches the
// same folded text the search box highlighted and writes back exactly what the admin typed, that the two
// key columns are refused with a reason instead of silently skipped, that a cell edited in another window
// stops the whole batch, and finally that on the real course a plan is honest about what it would touch.
// Nothing here writes to the real `content/` tree: the store runs against a scratch data dir.
import { build } from 'esbuild';
import { execFileSync } from 'node:child_process';
import { mkdtemp, readdir, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { HARNESS_ADMIN_SECRET } from './harness-auth.mjs';

const appRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const realRepo = path.resolve(appRoot, '..', '..');
const posix = (p) => p.replace(/\\/g, '/');
for (const entry of await readdir(path.join(appRoot, 'node_modules')).catch(() => []))
  if (entry.startsWith('.replace-'))
    await rm(path.join(appRoot, 'node_modules', entry), { recursive: true, force: true });
const scratch = await mkdtemp(path.join(appRoot, 'node_modules', '.replace-'));
const dataDir = path.join(scratch, 'data');

await writeFile(
  path.join(scratch, 'stub-headers.mjs'),
  'export async function cookies() {\n' +
    '  return { get: () => ({ value: process.env.CMS_HARNESS_SECRET }), set: () => {}, delete: () => {} };\n' +
    '}\n',
);

const bundled = await build({
  stdin: {
    contents:
      "export * from '@/cms/replace';\n" +
      "export * from '@/cms/search';\n" +
      "export * from '@/cms/blank';\n" +
      "export * from '@/cms/lint';\n" +
      "export { tablesToUnit } from '@/cms/tables';\n" +
      "export * from '@/server/content-replace';\n" +
      "export * from '@/server/store/file-store';\n",
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
    'next/headers': posix(path.join(scratch, 'stub-headers.mjs')),
  },
});
const bundleFile = path.join(scratch, 'cms.mjs');
await writeFile(bundleFile, bundled.outputFiles[0].text, 'utf8');

for (const key of ['APPWRITE_ENDPOINT', 'APPWRITE_PROJECT_ID', 'APPWRITE_API_KEY'])
  delete process.env[key];
Object.assign(process.env, {
  NODE_ENV: 'development',
  CMS_ADMIN_USER_IDS: 'harness-replace',
  CMS_DATA_DIR: dataDir,
  CMS_REPO_ROOT: path.join(scratch, 'repo'),
  CMS_HARNESS_SECRET: HARNESS_ADMIN_SECRET,
});

const cms = await import(pathToFileURL(bundleFile).href);
const store = new cms.FileStore(dataDir);

const checks = [];
const failures = [];
const check = (label, ok, detail = '') => {
  checks.push(label);
  if (!ok) failures.push(`${label}${detail ? ` — ${detail}` : ''}`);
};
const join = (list) => list.join(', ');

const word = (en, vi, id = '', enAlts = [], forms = [], viAlts = []) => ({
  level: 1,
  en,
  enAlts,
  vi,
  viAlts,
  img: false,
  forms,
  id: id || en.toLowerCase().replace(/\s+/g, '_'),
});
const sentence = (en, vi, enAlts = [], viAlts = []) => ({ en, enAlts, vi, viAlts });

function unitFixture(overrides = {}) {
  const draft = cms.blankUnit(overrides.theme ?? 'greetings', 'A1');
  draft.title = overrides.title ?? 'Chào hỏi';
  draft.levels = overrides.levels ?? ['Giao tiếp', 'Từ vựng', 'Nghe', 'Nói', 'Đọc'];
  draft.guide = overrides.guide ?? 'Làm quen nhau.';
  draft.vocab = overrides.vocab ?? [
    word('hello', 'xin chào', 'hello', ['hi there'], ['greet', 'greeting'], ['chào hỏi']),
    word('best friend', 'bạn thân', 'best_friend', [], ['friend'], ['bạn tốt']),
  ];
  draft.sentences = overrides.sentences ?? [
    sentence('How are you?', 'Bạn khỏe không?', ['How do you do?'], ['Bạn có khỏe không?']),
  ];
  draft.dialogues = overrides.dialogues ?? [
    { line: 'Xin chào', reply: 'Chào bạn', replyAlts: ['Hello there'], vi: 'Hello' },
  ];
  draft.story = overrides.story ?? {
    title: 'Ngày đầu tiên',
    passage: 'Mai meets her friend. Her friend is Nam.',
    questions: [{ q: 'Where is Nam?', correct: 'At school', wrongs: ['At home', 'Outside'] }],
  };
  return draft;
}
const record = (unitId, order, draft) => ({
  courseId: 'vi_en',
  unitId,
  order,
  revision: 1,
  updatedAt: '2026-01-01T00:00:00.000Z',
  updatedBy: 'harness-replace',
  draft,
});
const allColumns = () =>
  cms
    .replaceColumns()
    .filter((c) => c.editable)
    .map((c) => ({ list: c.list, field: c.field }));
const plan = (units, find, to = '', targets = allColumns()) =>
  cms.planReplace(units, { find, to, targets });
const one = (units, find, to, targets) => plan(units, find, to, targets).edits[0];

// ---------- A. the column lists cannot drift apart ----------
const LIST_OF_TAB = Object.fromEntries(
  Object.entries(cms.TAB_KEY).map(([list, tab]) => [tab, list]),
);
const draftRecord = record('01-greetings', 0, unitFixture());
const entryKeys = [
  ...new Set(cms.unitEntries(draftRecord).map((e) => `${LIST_OF_TAB[e.tab]}.${e.field}`)),
];
const columnKeys = cms.replaceColumns().map((c) => `${c.list}.${c.field}`);
check(
  'cột mà ô tìm thấy cũng là cột mà bộ thay thế soi — không cột nào âm thầm biến mất',
  entryKeys.length === columnKeys.length && entryKeys.every((k) => columnKeys.includes(k)),
  `entries [${join(entryKeys)}] vs columns [${join(columnKeys)}]`,
);
check(
  'đúng hai cột bị khóa: id và chủ đề — vì media, section và các bài khác đang trỏ vào chúng',
  join(
    cms
      .replaceColumns()
      .filter((c) => !c.editable)
      .map((c) => `${c.list}.${c.field}`),
  ) === 'unit.chủ đề, vocab.id',
  join(
    cms
      .replaceColumns()
      .filter((c) => !c.editable)
      .map((c) => `${c.list}.${c.field}`),
  ),
);
check(
  'cột bị khóa vẫn có lý do để hiển thị, không phải bị ẩn đi',
  cms
    .replaceColumns()
    .filter((c) => !c.editable)
    .every((c) => (c.why ?? '').length > 20),
);

// ---------- B. what a replacement does to one string ----------
check(
  'bỏ dấu và hoa thường khi khớp, nhưng viết lại đúng chữ người soạn gõ',
  one([draftRecord], 'CHAO', 'Gặp').after === 'Gặp hỏi' &&
    one([draftRecord], 'ban than', 'Bạn thân').after === 'Bạn thân',
  JSON.stringify([one([draftRecord], 'CHAO', 'Gặp'), one([draftRecord], 'ban than', 'Bạn thân')]),
);
const viOnly = [{ list: 'vocab', field: 'nghĩa' }];
check(
  'để trống ô thay là xóa đúng phần khớp, kể cả khi nó là cả ô',
  one([draftRecord], 'xin chao', '', viOnly).after === '' &&
    one([draftRecord], 'chao', '', viOnly).after === 'xin ',
  JSON.stringify([
    one([draftRecord], 'xin chao', '', viOnly),
    one([draftRecord], 'chao', '', viOnly),
  ]),
);
check(
  'từ cần thay nằm trong từ thay thế không khiến bộ dựng lặp vô hạn',
  (() => {
    const edit = one([draftRecord], 'friend', 'best friend', [{ list: 'vocab', field: 'từ' }]);
    return edit.count === 1 && edit.after === 'best best friend';
  })(),
  JSON.stringify(one([draftRecord], 'friend', 'best friend', [{ list: 'vocab', field: 'từ' }])),
);
check(
  'một ô chứa hai lần khớp thì tính hai lần khớp nhưng vẫn là một dòng',
  (() => {
    const p = plan([draftRecord], 'friend', 'mate');
    const story = p.edits.find((e) => e.field === 'đoạn truyện');
    return story.count === 2 && p.rows === p.edits.length && p.matches > p.rows;
  })(),
  JSON.stringify(plan([draftRecord], 'friend', 'mate').edits.map((e) => `${e.field}x${e.count}`)),
);
check(
  'thay ra đúng chữ cũ thì không thành edit — không bản nháp nào bị đụng vì một thao tác vô nghĩa',
  plan([draftRecord], 'hello', 'hello', [{ list: 'vocab', field: 'từ' }]).rows === 0 &&
    plan([draftRecord], 'Hello', 'Hello', [{ list: 'dialogues', field: 'trả lời khác' }]).rows ===
      0,
);
check(
  'ô tìm trống thì kế hoạch rỗng, không phải "thay mọi thứ bằng rỗng"',
  plan([draftRecord], '', 'x').rows === 0 && plan([draftRecord], '   ', 'x').rows === 0,
);

// ---------- C. the plan points where the editor points ----------
const altPlan = plan([draftRecord], 'hi there', 'hey there');
check(
  'edit nói rõ nó ở tab nào, dòng nào, mục con nào — để nối thẳng vào editor',
  altPlan.rows === 1 &&
    altPlan.edits[0].tab === 'vocab' &&
    altPlan.edits[0].row === 0 &&
    altPlan.edits[0].alt === 0 &&
    altPlan.edits[0].field === 'cách nói khác' &&
    altPlan.edits[0].unitId === '01-greetings',
  JSON.stringify(altPlan.edits),
);
const fieldPlan = plan([draftRecord], 'lam quen', 'Giới thiệu');
check(
  'trường thông tin chung của unit không có số dòng',
  fieldPlan.rows === 1 &&
    fieldPlan.edits[0].list === 'unit' &&
    fieldPlan.edits[0].tab === 'basics' &&
    fieldPlan.edits[0].row === null,
  JSON.stringify(fieldPlan.edits),
);
const lockedPlan = plan([draftRecord], 'hello', 'xin chào', [{ list: 'vocab', field: 'id' }]);
check(
  'cột bị khóa không sinh edit, nhưng được báo lại kèm số dòng khớp để người soạn không đoán mò',
  lockedPlan.rows === 0 &&
    lockedPlan.skipped.length === 1 &&
    lockedPlan.skipped[0].field === 'id' &&
    lockedPlan.skipped[0].cells > 0 &&
    lockedPlan.skipped[0].reason.length > 20,
  JSON.stringify(lockedPlan.skipped),
);
check(
  'kế hoạch đếm số chuỗi đã soi, nên "không khớp" là một câu trả lời có thể kiểm chứng',
  plan([draftRecord], 'zzzqqq').scanned > 20 && plan([draftRecord], 'zzzqqq').rows === 0,
  `${plan([draftRecord], 'zzzqqq').scanned} chuỗi`,
);

// ---------- D. replay onto the live draft ----------
const live = unitFixture();
const replay = cms.applyReplace(live, plan([record('u', 0, live)], 'friend', 'mate').edits);
check(
  'áp lên bản nháp đang có, không dùng lại chuỗi đã xem trước',
  replay.applied > 0 &&
    replay.drift.length === 0 &&
    replay.draft.story.passage === 'Mai meets her mate. Her mate is Nam.',
  JSON.stringify({ applied: replay.applied, passage: replay.draft.story.passage }),
);
const moved = unitFixture();
const stale = plan([record('u', 0, live)], 'friend', 'mate').edits;
moved.story.passage = 'Mai meets her old friend from Hanoi. Her friend is Nam.';
const driftRun = cms.applyReplace(moved, stale);
check(
  'dòng bị sửa ở cửa sổ khác sau khi xem trước → báo drift, không ghi đè lên chữ của người khác',
  driftRun.drift.length === 1 &&
    driftRun.drift[0].field === 'đoạn truyện' &&
    driftRun.draft.story.passage === moved.story.passage &&
    driftRun.applied === stale.length - 1,
  JSON.stringify({ drift: driftRun.drift, applied: driftRun.applied }),
);
const deletedRow = unitFixture();
const afterDelete = cms.applyReplace({ ...deletedRow, vocab: [deletedRow.vocab[0]] }, stale);
check(
  'dòng bị xóa hẳn cũng thành drift với lý do rõ ràng, không phải một phép ghi im lặng',
  afterDelete.drift.filter((d) => d.found === '(dòng không còn tồn tại)').length === 2 &&
    afterDelete.draft.vocab.length === 1,
  JSON.stringify(afterDelete.drift),
);

// ---------- E. the service over stored drafts ----------
await store.saveCourse({
  courseId: 'vi_en',
  draft: {
    course: {
      courseId: 'vi_en',
      title: 'Khóa thử thay thế',
      sourceLocale: 'vi',
      targetLocale: 'en',
      status: 'DRAFT',
    },
    sections: [{ sectionId: 's1', title: 'Phần một', units: ['01-greetings', '02-daily'] }],
    version: 'v2',
  },
  actorId: 'harness-replace',
  expectedRevision: 0,
});
const clean = unitFixture();
const clash = unitFixture({
  theme: 'daily',
  title: 'Sinh hoạt',
  vocab: [word('hello', 'xin chào'), word('hero', 'anh hùng')],
});
for (const unit of [record('01-greetings', 0, clean), record('02-daily', 1, clash)])
  await store.saveUnit({
    courseId: 'vi_en',
    unitId: unit.unitId,
    order: unit.order,
    draft: unit.draft,
    actorId: 'harness-replace',
    expectedRevision: 0,
  });

const preview = await cms.previewReplace('vi_en', {
  find: 'hello',
  to: 'Hello',
  targets: [{ list: 'vocab', field: 'từ' }],
});
check(
  'xem trước đọc bản nháp đã lưu và nói đúng số unit nó soi',
  preview !== null &&
    preview.unitCount === 2 &&
    preview.plan.rows === 2 &&
    preview.plan.unitIds.join() === '01-greetings,02-daily' &&
    preview.choices.length === 5,
  JSON.stringify(preview?.plan.edits.map((e) => `${e.unitId}:${e.before}→${e.after}`)),
);
check(
  'khóa chưa có unit thì không có gì để xem trước, kể cả với bộ thay thế',
  (await cms.previewReplace('khong_ton_tai', { find: 'a', to: 'b', targets: allColumns() })) ===
    null,
);

const cleanRun = await cms.checkReplace('vi_en', {
  find: 'greet',
  to: 'salute',
  targets: [{ list: 'vocab', field: 'forms' }],
});
check(
  'lô sạch: đúng số unit sẽ ghi, và mỗi unit mang revision đang sống để khóa ghi đè',
  cleanRun.ok &&
    cleanRun.drafts.length === 1 &&
    cleanRun.drafts[0].unitId === '01-greetings' &&
    cleanRun.drafts[0].revision === 1 &&
    cleanRun.drift.length === 0 &&
    cleanRun.lint.length === 0,
  JSON.stringify(cleanRun.drafts.map((d) => `${d.unitId}@${d.revision}`)),
);
const beforeRevisions = (await store.listUnits('vi_en')).map((u) => `${u.unitId}:${u.revision}`);

const clashRun = await cms.checkReplace('vi_en', {
  find: 'hero',
  to: 'hello',
  targets: [{ list: 'vocab', field: 'từ' }],
});
check(
  'lô mà kết quả không lưu được (hai từ trùng nhau) bị chặn trước khi ghi, không ghi một nửa',
  clashRun.ok === false &&
    clashRun.drafts.length === 0 &&
    clashRun.lint.length === 1 &&
    clashRun.lint[0].issues.some((i) => i.message.includes('Trùng từ')),
  JSON.stringify(clashRun.lint),
);
const idRun = await cms.checkReplace('vi_en', {
  find: 'hello',
  to: 'x',
  targets: [{ list: 'vocab', field: 'id' }],
});
check(
  'kế hoạch chỉ chạm cột bị khóa → từ chối với lý do, không phải "đã sửa 0 dòng"',
  idRun.ok === false && idRun.plan.rows === 0 && idRun.plan.skipped.length === 1,
  JSON.stringify(idRun.plan.skipped),
);

const afterRevisions = (await store.listUnits('vi_en')).map((u) => `${u.unitId}:${u.revision}`);
check(
  'xem trước và kiểm tra lô không ghi gì xuống store',
  join(beforeRevisions) === join(afterRevisions),
  `${join(beforeRevisions)} → ${join(afterRevisions)}`,
);

// ---------- F. the real course ----------
const authored = JSON.parse(
  execFileSync(
    process.execPath,
    [path.join(appRoot, 'scripts', 'read-authored.mjs'), 'vi_en', 'v2'],
    {
      cwd: realRepo,
      maxBuffer: 32 * 1024 * 1024,
      encoding: 'utf8',
    },
  ),
);
const realUnits = authored.units.map((entry, order) =>
  record(
    entry.unitId ?? `u${order}`,
    order,
    cms.tablesToUnit({
      theme: entry.unit.theme,
      cefr: entry.unit.cefr,
      title: entry.unit.title,
      levels: entry.unit.levels,
      guide: entry.unit.guide,
      vocab: entry.unit.vocab,
      sentences: entry.unit.sentences,
      dialogues: entry.unit.dialogues,
      storyTitle: entry.unit.story.title,
      passage: entry.unit.story.passage,
      questions: entry.unit.story.questions,
    }),
  ),
);
const realKeys = [
  ...new Set(cms.courseEntries(realUnits).map((e) => `${LIST_OF_TAB[e.tab]}.${e.field}`)),
];
const columnKeySet = new Set(columnKeys);
check(
  `mọi cột có chữ trên khóa thật (${realKeys.length}) đều có khai báo thay được hoặc bị khóa`,
  realKeys.every((k) => columnKeySet.has(k)),
  join(realKeys.filter((k) => !columnKeySet.has(k))),
);
const probes = ['hello', 'friend', 'cam on', 'How are you', 'Mai'];
const realPlans = probes.map((q) => plan(realUnits, q, `${q} X`));
check(
  `${probes.length} probe trên ${realUnits.length} unit thật: mọi dòng trong kế hoạch thật sự chứa từ cần tìm`,
  realPlans.every((p) =>
    p.edits.every(
      (e) => cms.foldKey(e.before).includes(cms.foldKey(p.find)) && e.after.includes(`${p.find} X`),
    ),
  ),
  JSON.stringify(realPlans.map((p) => `${p.find}:${p.rows}/${p.matches}`)),
);
check(
  'kế hoạch trên khóa thật đếm đủ số chuỗi đã soi, nên "không thấy gì" là một câu trả lời có thể kiểm chứng',
  realPlans.every((p) => p.scanned > 0) &&
    plan(realUnits, 'zzzqqq', 'x').scanned === realPlans[0].scanned &&
    plan(realUnits, 'zzzqqq', 'x').rows === 0,
  `${realPlans[0].scanned} chuỗi / ${realUnits.length} unit`,
);
const realRun = await plan(realUnits, 'Mai', 'Nam');
check(
  `probe "Mai" chỉ ra ${realRun.rows} dòng ở ${realRun.unitIds.length} unit, không vượt quá số dòng của khóa`,
  realRun.rows > 0 && realRun.unitIds.length > 0 && realRun.rows >= realRun.unitIds.length,
  `${realRun.rows} dòng, ${realRun.matches} lần khớp`,
);

await rm(scratch, { recursive: true, force: true });

if (failures.length) {
  console.error(`FAIL — ${failures.length}/${checks.length} replace checks failed:`);
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log(
  `OK — ${checks.length} checks: the searchable columns and the replaceable columns are one list with exactly two locked keys (${join(
    cms
      .replaceColumns()
      .filter((c) => !c.editable)
      .map((c) => `${c.list}.${c.field}`),
  )}), a replacement folds case and dấu away like the search box but writes back the characters the admin typed, a no-op rewrite touches nothing, every edit names the tab/row/sub-item the editor shows, a cell changed or deleted after the preview stops the batch instead of overwriting it, an unwritable batch is refused before one byte is saved, and on the real course ${realPlans[0].scanned} strings across ${realUnits.length} units were scanned for ${probes.length} probes.`,
);
