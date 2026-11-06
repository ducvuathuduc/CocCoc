// Placement proof. The app's placement test has no editor: `build-course.mjs:1005-1028` harvests ten
// items from fixed positions in the first unit. The harness shows the CMS mirror of those slots agrees
// with the generator (types, word ids, prompt text), that a shortened unit is reported as a build that
// stops instead of a lesson that quietly loses questions, that item 10 really does turn into a text
// choice under four pictures, that a saved draft and the shipped `bundles/placement.json` are compared
// row by row, that the `#N` badges the unit editor prints sit on the rows those same slots read, and
// finally that the mirror still describes the real course build.
// Part B runs against a scratch repo root; the real `content/` tree is only ever read.
import { build } from 'esbuild';
import { execFileSync } from 'node:child_process';
import { mkdir, mkdtemp, readFile, readdir, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { HARNESS_ADMIN_SECRET } from './harness-auth.mjs';

const appRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const realRepo = path.resolve(appRoot, '..', '..');
const posix = (p) => p.replace(/\\/g, '/');
for (const entry of await readdir(path.join(appRoot, 'node_modules')))
  if (entry.startsWith('.placement-'))
    await rm(path.join(appRoot, 'node_modules', entry), { recursive: true, force: true });
const scratch = await mkdtemp(path.join(appRoot, 'node_modules', '.placement-'));
const dataDir = path.join(scratch, 'data');
const repoRoot = path.join(scratch, 'repo');

await writeFile(
  path.join(scratch, 'stub-headers.mjs'),
  'export async function cookies() {\n' +
    '  return { get: () => ({ value: process.env.CMS_HARNESS_SECRET }), set: () => {}, delete: () => {} };\n' +
    '}\n',
);
await writeFile(
  path.join(scratch, 'stub-navigation.mjs'),
  'export function redirect(to) {\n  throw new Error(`redirect:${to}`);\n}\n',
);

const bundled = await build({
  stdin: {
    contents:
      "export * from '@/cms/placement';\n" +
      "export * from '@/cms/blank';\n" +
      "export * from '@/server/placement-service';\n" +
      "export { tablesToUnit } from '@/cms/tables';\n" +
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
    'next/navigation': posix(path.join(scratch, 'stub-navigation.mjs')),
  },
});
const bundleFile = path.join(scratch, 'cms.mjs');
await writeFile(bundleFile, bundled.outputFiles[0].text, 'utf8');

for (const key of ['APPWRITE_ENDPOINT', 'APPWRITE_PROJECT_ID', 'APPWRITE_API_KEY'])
  delete process.env[key];
Object.assign(process.env, {
  NODE_ENV: 'development',
  CMS_ADMIN_USER_IDS: 'harness-placement',
  CMS_DATA_DIR: dataDir,
  CMS_REPO_ROOT: repoRoot,
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
const writeAt = async (file, text) => {
  await mkdir(path.dirname(file), { recursive: true });
  await writeFile(file, text, 'utf8');
};
const join = (list) => list.join(',');
const eq = (a, b) => JSON.stringify(a) === JSON.stringify(b);

const word = (id, en, vi, img = false) => ({
  level: 1,
  en,
  enAlts: [],
  vi,
  viAlts: [],
  img,
  forms: [],
  id,
});
const sentence = (en, vi) => ({ en, enAlts: [], vi, viAlts: [] });
const question = (q, correct, ...wrongs) => ({ q, correct, wrongs });

/** The smallest first unit the generator can still harvest ten items from. */
function completeDraft() {
  const draft = cms.blankUnit('greetings', 'A1');
  draft.title = 'Chào hỏi';
  draft.levels = ['L1', 'L2', 'L3', 'L4', 'L5'];
  draft.vocab = Array.from({ length: 15 }, (_, i) =>
    word(`w${i}`, `word ${i}`, `nghĩa ${i}`, i % 4 === 0),
  );
  draft.sentences = Array.from({ length: 22 }, (_, i) =>
    sentence(`Sentence number ${i}.`, `Câu ${i}.`),
  );
  draft.dialogues = [
    { line: 'Xin chào', reply: 'Chào bạn', replyAlts: [], vi: 'Hello' },
    { line: 'Bạn tên gì?', reply: 'Tôi là Nam', replyAlts: [], vi: 'I am Nam' },
    { line: 'Hẹn gặp lại', reply: 'Tạm biệt', replyAlts: [], vi: 'Goodbye' },
  ];
  draft.story = {
    title: 'Ngày đầu tiên',
    passage: 'Nam đi học.',
    questions: [
      question('Where is Nam?', 'At school', 'At home'),
      question('Who is with him?', 'His teacher', 'His sister'),
      question('Who is Mr. Long?', 'His teacher', 'His father'),
    ],
  };
  return draft;
}

const itemsOf = (draft) => cms.placementItems(draft, 'u1');
const DRILLS = [
  'choice',
  'textTranslation',
  'wordBank',
  'fillBlank',
  'matchPairs',
  'sentenceOrder',
  'choice',
  'textTranslation',
  'storyQuestion',
  'imageChoice',
];

// ---------- A. the slot table, read out of a draft the harness controls ----------
const full = itemsOf(completeDraft());
check('mười câu, đúng thứ tự dạng bài của build-course.mjs:1011-1028', full.length === 10 && join(full.map((i) => i.drill)) === join(DRILLS), join(full.map((i) => i.drill)));
check('bản nháp đủ dài thì không câu nào thiếu dòng', full.every((i) => i.present), full.filter((i) => !i.present).map((i) => i.id).join());
check('ids câu là placement-e01..e10 như app nhận', join(full.map((i) => i.id)) === join(DRILLS.map((_, n) => `placement-e${String(n + 1).padStart(2, '0')}`)), join(full.map((i) => i.id)));

const one = full[0];
check('câu 1 đọc từ vựng dòng 4 và mang id từ đó', one.reads.index === 3 && one.reads.list === 'vocab' && join(one.vocabularyIds) === 'u1.w3' && one.marker === 'word 3', `${join(one.vocabularyIds)} / ${one.marker}`);
check('câu 2 đọc câu dòng 5 và in nghĩa tiếng Việt của nó vào đề bài', full[1].reads.list === 'sentences' && full[1].reads.index === 4 && full[1].marker === 'Câu 4.', full[1].marker);
check('câu 5 nối cặp đọc từ dòng 9 trở đi, tối đa 5 cặp', join(full[4].vocabularyIds) === 'u1.w8,u1.w9,u1.w10,u1.w11,u1.w12', join(full[4].vocabularyIds));
check('câu 5 không có marker vì đề bài là chữ cố định', full[4].marker === '' && full[4].reads.needed === 9, `${full[4].marker} / ${full[4].reads.needed}`);
check('câu 7 đọc từ dòng 15 theo nghĩa tiếng Việt', join(full[6].vocabularyIds) === 'u1.w14' && full[6].marker === 'nghĩa 14', `${join(full[6].vocabularyIds)} / ${full[6].marker}`);
check('câu 8 là dòng cuối cùng bộ dựng đọc: câu 22', full[7].reads.index === 21 && full[7].marker === 'Câu 21.', full[7].marker);
check('câu 9 đọc câu hỏi truyện thứ ba', full[8].reads.list === 'story' && full[8].marker === 'Who is Mr. Long?', full[8].marker);
check('câu 10 là ảnh khi đã có 4 từ đánh dấu ảnh, và lấy từ có ảnh thứ hai', full[9].drill === 'imageChoice' && full[9].reads.picturesOnly && full[9].reads.index === 1 && join(full[9].vocabularyIds) === 'u1.w4', `${full[9].drill} ${join(full[9].vocabularyIds)}`);

const thin = completeDraft();
thin.vocab = thin.vocab.slice(0, 5);
thin.sentences = thin.sentences.slice(0, 3);
thin.story.questions = [thin.story.questions[0]];
const thinItems = itemsOf(thin);
const gone = thinItems.filter((i) => !i.present).map((i) => i.id);
check(
  'unit bị cắt ngắn: chỉ còn câu 1 đọc được, 9 câu kia là build sẽ lỗi chứ không phải bài ít đi',
  join(gone) === 'placement-e02,placement-e03,placement-e04,placement-e05,placement-e06,placement-e07,placement-e08,placement-e09,placement-e10',
  join(gone),
);
check('dòng đã mất thì không còn label hay id dự đoán', thinItems.every((i) => i.present || (i.label === '' && i.vocabularyIds.length === 0 && i.marker === '')));
check(
  'câu 10 báo rõ nó là bài chọn chữ vì số từ có ảnh chưa đủ 4',
  thinItems[9].drill === 'choice' &&
    thinItems[9].note.includes(`Mới có ${thin.vocab.filter((row) => row.img).length} từ`),
  `${thinItems[9].drill} / ${thinItems[9].note}`,
);

const noPictures = completeDraft();
noPictures.vocab = noPictures.vocab.map((row) => ({ ...row, img: false }));
const degraded = itemsOf(noPictures)[9];
check('rút hết ảnh thì câu 10 đọc từ vựng dòng 7 thay vì ảnh thứ hai', degraded.drill === 'choice' && degraded.reads.index === 6 && !degraded.reads.picturesOnly && join(degraded.vocabularyIds) === 'u1.w6', `${degraded.drill} ${degraded.reads.index}`);
check('cảnh báo đó nói đúng số từ có ảnh hiện có', degraded.note.includes('Mới có 0 từ'), degraded.note);

const moved = completeDraft();
[moved.vocab[3], moved.vocab[9]] = [moved.vocab[9], moved.vocab[3]];
const movedItems = itemsOf(moved);
check(
  'đổi chỗ hai dòng trong unit là viết lại câu 1 và câu 5 — không có bảng nào để sửa',
  join(movedItems[0].vocabularyIds) === 'u1.w9' && join(movedItems[4].vocabularyIds) === 'u1.w8,u1.w3,u1.w10,u1.w11,u1.w12',
  `${join(movedItems[0].vocabularyIds)} / ${join(movedItems[4].vocabularyIds)}`,
);

const dupes = completeDraft();
dupes.vocab[9] = { ...dupes.vocab[9], en: 'word 8' };
dupes.vocab[10] = { ...dupes.vocab[10], vi: 'nghĩa 8' };
check('bài nối bỏ từ trùng cả chiều Anh lẫn chiều Việt y như bộ dựng', join(itemsOf(dupes)[4].vocabularyIds) === 'u1.w8,u1.w11,u1.w12,u1.w13,u1.w14', join(itemsOf(dupes)[4].vocabularyIds));

const single = completeDraft();
single.vocab = single.vocab.slice(0, 9);
check('chỉ còn một cặp để nối thì panel nói bài nối vô nghĩa', itemsOf(single)[4].note.includes('một cặp'), itemsOf(single)[4].note);

// ---------- A′. the row badges the unit editor prints ----------
const marksOf = (draft) => cms.placementMarks(draft);
const allBadges = (marks) =>
  [...marks.marks.entries()].flatMap(([key, list]) => list.map((m) => `${key}=${m.badge}`)).sort();

/** `placementMarks` and `placementItems` are two readings of one slot table; they must never split. */
function markAgreement(draft) {
  const { marks, missing } = marksOf(draft);
  const items = itemsOf(draft);
  const imgRows = [];
  draft.vocab.forEach((row, i) => {
    if (row.img) imgRows.push(i);
  });
  const problems = [];
  const gone = items.filter((i) => !i.present).map((i) => i.item);
  if (!eq(missing, gone)) problems.push(`missing ${join(missing)} ≠ build lỗi ${join(gone)}`);
  for (const item of items) {
    if (!item.present) {
      for (const [key, list] of marks)
        if (list.some((m) => m.item === item.item)) problems.push(`${key} mang #${item.item} hết dòng`);
      continue;
    }
    if (item.drill === 'matchPairs') {
      const swept = [...marks.values()].filter((list) => list.some((m) => m.item === item.item));
      if (swept.length !== item.vocabularyIds.length)
        problems.push(`#${item.item} đánh dấu ${swept.length} dòng, bộ dựng lấy ${item.vocabularyIds.length} cặp`);
      continue;
    }
    const index = item.reads.picturesOnly ? imgRows[item.reads.index] : item.reads.index;
    const bucket = marks.get(`${item.reads.list}:${index}`);
    if (!bucket?.some((m) => m.item === item.item))
      problems.push(`thiếu #${item.item} ở ${item.reads.list}:${index}`);
  }
  return problems;
}

const fullMarks = marksOf(completeDraft());
const agreementCases = { full: completeDraft(), thin, noPictures, moved, dupes, single };
const agreement = Object.entries(agreementCases)
  .map(([name, d]) => `${name}:${JSON.stringify(markAgreement(d))}`)
  .filter((s) => !s.endsWith(':[]'));
check(
  'badge in ra đúng những dòng bộ dựng đọc, trên mọi bản nháp thử',
  agreement.length === 0,
  agreement.join(' | '),
);
check(
  'câu 5 đánh dấu cả dải dòng nó quét, chứ không chỉ dòng nó bắt đầu',
  join(allBadges(fullMarks).filter((b) => b.startsWith('vocab:') && b.includes('#5')))
    === 'vocab:10=#5·cặp 3,vocab:11=#5·cặp 4,vocab:12=#5·cặp 5,vocab:8=#5·cặp 1,vocab:9=#5·cặp 2',
  join(allBadges(fullMarks).filter((b) => b.includes('#5'))),
);
check(
  'bài nối chỉ đánh dấu tối đa 5 cặp nên dòng 13 của từ vựng còn tự do',
  !fullMarks.marks.has('vocab:13'),
  join(allBadges(fullMarks)),
);
const lastMark = fullMarks.marks.get('vocab:4');
check(
  'câu 10 gắn trên dòng có ảnh thứ hai thật, không phải trên dòng 2 của bảng',
  lastMark.length === 1 && lastMark[0].item === 10 && lastMark[0].badge === '#10·ảnh 2' && lastMark[0].byPictureOrder,
  JSON.stringify(lastMark),
);
check(
  'hết ảnh thì câu 10 rơi về đúng dòng 7 của từ vựng',
  (() => {
    const m = marksOf(noPictures);
    return m.marks.get('vocab:6')[0].item === 10 && !m.marks.get('vocab:6')[0].byPictureOrder && !m.marks.has('vocab:4');
  })(),
  join(allBadges(marksOf(noPictures)).filter((b) => b.includes('#10'))),
);
check(
  'unit bị cắt thì badge biến mất đúng ở những câu build sẽ lỗi',
  join(marksOf(thin).missing) === '2,3,4,5,6,7,8,9,10' &&
    join(allBadges(marksOf(thin))) === 'vocab:3=#1',
  `${join(marksOf(thin).missing)} / ${join(allBadges(marksOf(thin)))}`,
);

const shared = completeDraft();
// One picture moved onto the row item 1 already reads, so `vocab:3` answers for two questions.
shared.vocab = shared.vocab.map((row, i) => ({ ...row, img: i === 3 || (i !== 4 && row.img) }));
const sharedMark = marksOf(shared).marks.get('vocab:3');
check(
  'một dòng có thể trả lời hai câu thì editor hiện đủ hai badge',
  sharedMark.length === 2 && join(sharedMark.map((m) => m.item)) === '1,10',
  JSON.stringify(sharedMark),
);
check(
  'mỗi badge tự giải thích là câu nào và hỏi gì, không cần mở panel',
  join(sharedMark.map((m) => m.title.startsWith(`Câu ${m.item} của bài kiểm tra trình độ`))) ===
    'true,true' &&
    sharedMark.some((m) => m.title.includes('Chọn nghĩa tiếng Việt')) &&
    sharedMark.some((m) => m.title.includes('Chọn ảnh đúng với nghĩa')),
  sharedMark.map((m) => m.title).join(' | '),
);

// ---------- B. draft against the shipped lesson, through the service ----------
const courseId = 'vi_en';
const bundlePath = path.join(repoRoot, 'content', courseId, 'dist', 'v2', 'bundles', 'placement.json');
/** Prompt text copied from the shapes `build-course.mjs` emits, not generated from the prediction. */
const builtItems = [
  { id: 'placement-e01', type: 'choice', prompt: 'Chọn nghĩa đúng của "word 3"', vocabularyIds: ['u1.w3'] },
  { id: 'placement-e02', type: 'textTranslation', prompt: 'Câu 4.', vocabularyIds: ['u1.w9'] },
  { id: 'placement-e03', type: 'wordBank', prompt: 'Dịch câu này: "Câu 9."', vocabularyIds: ['u1.w9'] },
  { id: 'placement-e04', type: 'fillBlank', prompt: 'Sentence number 13 is a ___ too. — "Câu 13."', vocabularyIds: [] },
  { id: 'placement-e05', type: 'matchPairs', prompt: 'Nối các cặp từ tương ứng', vocabularyIds: ['u1.w8', 'u1.w9', 'u1.w10', 'u1.w11', 'u1.w12'] },
  { id: 'placement-e06', type: 'sentenceOrder', prompt: 'Sắp xếp thành câu đúng: "Câu 17."', vocabularyIds: [] },
  { id: 'placement-e07', type: 'choice', prompt: '"nghĩa 14" trong tiếng Anh là gì?', vocabularyIds: ['u1.w14'] },
  { id: 'placement-e08', type: 'textTranslation', prompt: 'Câu 21.', vocabularyIds: [] },
  { id: 'placement-e09', type: 'storyQuestion', prompt: 'Who is Mr. Long?', vocabularyIds: [] },
  { id: 'placement-e10', type: 'imageChoice', prompt: 'Hình nào là "nghĩa 4"?', vocabularyIds: ['u1.w4'] },
];
await writeAt(
  bundlePath,
  JSON.stringify({
    schemaVersion: 1,
    courseId,
    unitId: 'u1',
    nodeId: 'placement',
    lessonId: 'placement',
    title: 'Kiểm tra trình độ',
    guideText: 'Trả lời đúng ít nhất 8/10 câu để bắt đầu từ Unit 2.',
    assets: [],
    exercises: builtItems.map((item) => ({ ...item, prompt: { text: item.prompt, locale: 'vi-VN' } })),
  }),
);

await store.saveCourse({
  courseId,
  draft: {
    course: { courseId, title: 'Khóa thử placement', sourceLocale: 'vi', targetLocale: 'en', status: 'DRAFT' },
    sections: [{ sectionId: 's1', title: 'Phần một', units: ['01-greetings', '02-daily'] }],
    version: 'v2',
  },
  actorId: 'harness-placement',
  expectedRevision: 0,
});
const donor = completeDraft();
await store.saveUnit({
  courseId,
  unitId: '01-greetings',
  order: 0,
  draft: donor,
  actorId: 'harness-placement',
  expectedRevision: 0,
});
await store.saveUnit({
  courseId,
  unitId: '02-daily',
  order: 1,
  draft: (() => {
    const second = completeDraft();
    second.title = 'Sinh hoạt';
    return second;
  })(),
  actorId: 'harness-placement',
  expectedRevision: 0,
});

const report = await cms.placementReport(courseId);
check('panel lấy unit đầu tiên theo thứ tự, không lấy theo id', report.unitId === '01-greetings' && report.genUnitId === 'u1', `${report.unitId} ${report.genUnitId}`);
check('đếm đúng nội dung unit làm bài kiểm tra', report.counts.vocab === 15 && report.counts.sentences === 22 && report.counts.questions === 3 && report.counts.pictures === 4, JSON.stringify(report.counts));
check('có bản dựng thì panel nói được điều app đang hỏi', report.hasBuild && report.rows.every((r) => r.built), `${report.hasBuild}`);
check('toàn bộ 10 câu khớp bản dựng nên không có việc phải dựng lại', join(report.blockers) === '' && join(report.changed) === '', `${join(report.blockers)} / ${join(report.changed)}`);
check('thông báo điều kiện thắng lấy từ chính bài đã dựng', report.guideText.startsWith('Trả lời đúng ít nhất 8/10'), report.guideText);

const edited = completeDraft();
edited.sentences = edited.sentences.slice(0, 21);
edited.vocab[3] = { ...edited.vocab[3], en: 'word 3 đã đổi' };
await store.saveUnit({
  courseId,
  unitId: '01-greetings',
  order: 0,
  draft: edited,
  actorId: 'harness-placement',
  expectedRevision: 1,
});
const afterEdit = await cms.placementReport(courseId);
check('xóa một câu cuối là unit không còn đủ dòng cho câu 8 — báo là build sẽ lỗi', join(afterEdit.blockers) === 'placement-e08', join(afterEdit.blockers));
check('sửa chữ một dòng đã đọc là bài kiểm tra trong app còn hỏi câu cũ', join(afterEdit.changed) === 'placement-e01', join(afterEdit.changed));
check('các câu còn nguyên thì vẫn báo khớp', afterEdit.rows.filter((r) => r.state === 'same').length === 8 && afterEdit.rows[7].state === 'unknown', `${afterEdit.rows.filter((r) => r.state === 'same').length} same / ${afterEdit.rows[7].state}`);

await writeAt(bundlePath, '{ not json');
const broken = await cms.placementReport(courseId);
check('bundle hỏng thì panel nói chưa có bản dựng thay vì bịa', broken.hasBuild === false && broken.rows.every((r) => r.state === 'unknown') && broken.guideText === '', `${broken.hasBuild} ${broken.guideText}`);

await rm(bundlePath, { force: true });
const noBuild = await cms.placementReport(courseId);
check('chưa dựng gì thì không câu nào bị gọi là lệch', noBuild.hasBuild === false && noBuild.changed.length === 0 && join(noBuild.rows.map((r) => r.state)) === join(Array(10).fill('unknown')));

await writeAt(bundlePath, JSON.stringify({ exercises: [{ id: 'placement-e01', type: 'choice', prompt: { text: 'Một câu khác hẳn' }, vocabularyIds: ['u1.w7'] }] }));
const singleItem = await cms.placementReport(courseId);
check('bản dựng chỉ có một câu thì chín câu kia là "bản dựng không có câu này", không phải khớp', singleItem.rows.filter((r) => r.state === 'unknown').length === 9 && singleItem.rows[0].state === 'changed', `${singleItem.rows.filter((r) => r.state === 'unknown').length} unknown / ${singleItem.rows[0].state}`);

check(
  'khóa chưa có bản nháp thì không có panel',
  (await cms.placementReport('khong_ton_tai')) === null,
);

// ---------- C. the mirror against the real course ----------
const authored = JSON.parse(
  execFileSync(process.execPath, [path.join(appRoot, 'scripts', 'read-authored.mjs'), 'vi_en', 'v2'], {
    cwd: realRepo,
    maxBuffer: 32 * 1024 * 1024,
    encoding: 'utf8',
  }),
);
const u1 = authored.units[0].unit;
const realDraft = cms.tablesToUnit({
  theme: u1.theme,
  cefr: u1.cefr,
  title: u1.title,
  levels: u1.levels,
  guide: u1.guide,
  vocab: u1.vocab,
  sentences: u1.sentences,
  dialogues: u1.dialogues,
  storyTitle: u1.story.title,
  passage: u1.story.passage,
  questions: u1.story.questions,
});
const realItems = cms.placementItems(realDraft, 'u1');
const realBundle = JSON.parse(
  await readFile(path.join(realRepo, 'content/vi_en/dist/v2/bundles/placement.json'), 'utf8'),
);
const realBuilt = realBundle.exercises.map((e) => ({
  id: e.id,
  type: e.type,
  prompt: e.prompt.text,
  vocabularyIds: e.vocabularyIds ?? [],
}));

check('unit đầu thật có đủ dòng cho cả mười câu', realItems.every((i) => i.present), realItems.filter((i) => !i.present).map((i) => i.id).join());
check(
  `mười câu của bản dựng thật vẫn đúng dạng bài bộ dựng sinh (${realBuilt.map((e) => e.type).join(' → ')})`,
  join(realItems.map((i) => i.drill)) === join(realBuilt.map((e) => e.type)),
  `mirror ${join(realItems.map((i) => i.drill))}`,
);
const idSlots = realItems.filter((i) => i.vocabularyIds.length);
const idMismatch = idSlots.filter((i) => !eq(i.vocabularyIds, realBuilt[realItems.indexOf(i)].vocabularyIds));
check(
  `${idSlots.length} câu dự đoán được id từ thì bản dựng mang đúng những id ấy (${idSlots.map((i) => i.item).join(', ')})`,
  idSlots.length === 4 && idMismatch.length === 0,
  `${idSlots.length} predictable, ${idMismatch.length} mismatched`,
);
const markerMisses = realItems.filter(
  (i) => i.marker && !realBuilt[realItems.indexOf(i)].prompt.includes(i.marker),
);
check(
  'chín câu có đề bài in nội dung dòng thì đề bài bản dựng thật đang chứa đúng dòng đó',
  markerMisses.length === 0 && realItems.filter((i) => i.marker).length === 9,
  `${markerMisses.length} misses`,
);
check(
  'bản dựng thật của khóa hiện hành khớp từng câu với bản nháp trong repo',
  realItems.every((i, n) => cms.placementState(i, realBuilt[n]) === 'same'),
  realItems.map((i, n) => `${i.item}:${cms.placementState(i, realBuilt[n])}`).join(' '),
);
const pictures = realDraft.vocab.filter((row) => row.img).map((row) => row.id);
check(
  `${pictures.length} từ có ảnh ở unit đầu, đủ cho cổng 4 ảnh nên câu 10 thật là bài chọn ảnh`,
  pictures.length >= 4 && realItems[9].drill === 'imageChoice' && join(realItems[9].vocabularyIds) === `u1.${pictures[1]}`,
  `${pictures.length} pictures, câu 10 ${realItems[9].drill} ${join(realItems[9].vocabularyIds)}`,
);

const realMarks = marksOf(realDraft);
check(
  'unit đầu của khóa thật: badge phủ đúng những dòng bộ dựng đang đọc, không câu nào thiếu dòng',
  markAgreement(realDraft).length === 0 && realMarks.missing.length === 0,
  JSON.stringify(markAgreement(realDraft)),
);
const lastKey = [...realMarks.marks.entries()].find(([, list]) =>
  list.some((m) => m.item === 10),
)?.[0];
const lastRow = realDraft.vocab[Number(lastKey.split(':')[1])];
check(
  `câu 10 in badge trên đúng từ "${pictures[1]}" mà app đang hiện ảnh, không phải trên dòng 2 của bảng`,
  lastRow.id === pictures[1] &&
    realMarks.marks.get(lastKey).find((m) => m.item === 10).badge === '#10·ảnh 2',
  `${lastKey} → ${lastRow.id}`,
);

await rm(scratch, { recursive: true, force: true });

if (failures.length) {
  console.error(`FAIL — ${failures.length}/${checks.length} placement checks failed:`);
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
const realBadges = [...realMarks.marks.values()].flat().length;
console.log(
  `OK — ${checks.length} checks: the CMS mirror of \`build-course.mjs:1005-1028\` names the same ten drills, word ids and prompt texts the shipped placement lesson carries (${realBuilt
    .map((e) => e.type)
    .join(', ')}), a shortened first unit is reported as a build that stops instead of a test that quietly lost questions, item 10 really does turn into a text choice under four pictures, a saved draft is compared row by row with what the app already asks, and the ${realBadges} \`#N\` badges the unit editor prints sit on exactly the rows those ten slots read.`,
);
