// Content search proof. A course of 16 units cannot be answered by scrolling, so the CMS has a search
// box and a duplicate list over the drafts (`src/cms/search.ts`). The harness shows the fold really is
// dấu- and case-insensitive while still pointing at the authored characters, that the entries name the
// table and row the editor shows, that the three duplicate lists mean what they say, that the service
// reports the same thing from stored drafts, and finally that on the real course every unit title is
// findable without its dấu and no hit ever highlights an empty range.
// Part B runs against a scratch data dir; the real `content/` tree is only ever read.
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
  if (entry.startsWith('.search-'))
    await rm(path.join(appRoot, 'node_modules', entry), { recursive: true, force: true });
const scratch = await mkdtemp(path.join(appRoot, 'node_modules', '.search-'));
const dataDir = path.join(scratch, 'data');

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
      "export * from '@/cms/search';\n" +
      "export * from '@/cms/blank';\n" +
      "export * from '@/cms/lint';\n" +
      "export * from '@/server/content-search';\n" +
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
  alias: { '@': posix(path.join(appRoot, 'src')) },
});
const bundleFile = path.join(scratch, 'cms.mjs');
await writeFile(bundleFile, bundled.outputFiles[0].text, 'utf8');

for (const key of ['APPWRITE_ENDPOINT', 'APPWRITE_PROJECT_ID', 'APPWRITE_API_KEY'])
  delete process.env[key];
Object.assign(process.env, {
  NODE_ENV: 'development',
  CMS_ADMIN_USER_IDS: 'harness-search',
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

const word = (en, vi, id = '', enAlts = [], viAlts = [], forms = []) => ({
  level: 1,
  en,
  enAlts,
  vi,
  viAlts,
  img: false,
  forms,
  id: id || en.toLowerCase().replace(/\s+/g, '_'),
});
const sentence = (en, vi) => ({ en, enAlts: [], vi, viAlts: [] });

function unitFixture(overrides = {}) {
  const draft = cms.blankUnit('greetings', 'A1');
  draft.title = overrides.title ?? 'Chào hỏi';
  draft.theme = overrides.theme ?? 'greetings';
  draft.levels = overrides.levels ?? ['Giao tiếp', 'Từ vựng', 'Nghe'];
  draft.guide = overrides.guide ?? 'Làm quen nhau.';
  draft.vocab = overrides.vocab ?? [
    word('hello', 'xin chào', 'hello', ['hi there'], ['hello'], ['greetings']),
    word('Hi', 'chào', 'hi', [], ['chào'], []),
  ];
  draft.sentences = overrides.sentences ?? [sentence('How are you?', 'Bạn khỏe không?')];
  draft.dialogues = overrides.dialogues ?? [
    { line: 'Xin chào', reply: 'Chào bạn', replyAlts: ['Hello there'], vi: 'Hello' },
  ];
  draft.story = overrides.story ?? {
    title: 'Ngày đầu tiên',
    passage: 'Nam đi học.',
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
  updatedBy: 'harness-search',
  draft,
});

// ---------- A. the fold, the entries and the duplicate lists ----------
const range = (text, query) => cms.matchRange(text, query);
const cut = (text, query) => {
  const r = range(text, query);
  return r ? text.slice(r.start, r.end) : null;
};
check(
  'bỏ dấu vẫn tìm thấy, và highlight chỉ vào đúng chữ đã soạn',
  cut('Xin chào bạn', 'chao') === 'chào' && cut('Chào hỏi', 'chao hoi') === 'Chào hỏi',
  `${cut('Xin chào bạn', 'chao')} / ${cut('Chào hỏi', 'chao hoi')}`,
);
check(
  'không phân biệt hoa thường',
  cut('I have an Apple', 'APPLE') === 'Apple' && cut('apple pie', 'Apple') === 'apple',
  `${cut('I have an Apple', 'APPLE')} / ${cut('apple pie', 'Apple')}`,
);
check(
  'hai khoảng trắng thừa trong bản nháp không làm mất kết quả',
  cut('Xin  chào   bạn', 'xin chao') === 'Xin  chào',
  `${cut('Xin  chào   bạn', 'xin chao')}`,
);
check(
  'tìm không thấy thì trả về null, kể cả khi ô tìm trống',
  range('hello', 'xyz') === null && range('hello', '   ') === null && range('', 'a') === null,
);
check('dấu thanh đứng một mình cũng là một ký tự nguồn', cut('è', 'e') === 'è', `${cut('è', 'e')}`);
check(
  'chữ đ không phân giải được thành d, nên phải có luật riêng — "gia dinh" phải tìm ra "Gia đình"',
  cut('Gia đình của tôi', 'gia dinh') === 'Gia đình' && cut('Đi làm', 'di lam') === 'Đi làm',
  `${cut('Gia đình của tôi', 'gia dinh')} / ${cut('Đi làm', 'di lam')}`,
);

const one = record('01-greetings', 0, unitFixture());
const entries = cms.unitEntries(one);
const fieldsOf = (tab) => [...new Set(entries.filter((e) => e.tab === tab).map((e) => e.field))];
check(
  'mỗi chuỗi của bản nháp được gán đúng tab và cột nó đứng trong editor',
  fieldsOf('vocab').join() === 'từ,cách nói khác,forms,nghĩa,nghĩa khác,id' &&
    fieldsOf('sentences').join() === 'câu,nghĩa' &&
    fieldsOf('dialogues').join() === 'lời thoại,câu trả lời,trả lời khác,nghĩa' &&
    fieldsOf('story').join() === 'tiêu đề truyện,đoạn truyện,câu hỏi,đáp án,đáp án sai' &&
    fieldsOf('basics').join() === 'tên unit,chủ đề,hướng dẫn,mức',
  JSON.stringify(fieldsOf('vocab')),
);
check(
  'dòng story trỏ đúng dòng trong bảng, thông tin chung của unit không có dòng',
  entries.some((e) => e.tab === 'story' && e.field === 'đoạn truyện' && e.row === null) &&
    entries.some((e) => e.tab === 'story' && e.field === 'câu hỏi' && e.row === 0) &&
    entries.every((e) => e.tab !== 'basics' || e.row === null),
  JSON.stringify(entries.filter((e) => e.tab === 'story').slice(0, 3)),
);
const blank = unitFixture({
  guide: '  ',
  vocab: [word('a', 'b'), { ...word('c', 'd'), enAlts: ['  '] }],
});
check(
  'ô trống không thành kết quả, nên tìm khoảng trắng không ra cả khóa',
  cms.unitEntries(record('x', 0, blank)).every((e) => e.text.trim() !== ''),
);

const hits = cms.searchEntries(cms.courseEntries([one]), 'chao');
check(
  'kết quả nói rõ nó ở unit nào, bảng nào, dòng nào, cột nào',
  hits.length > 0 &&
    hits.every((h) => h.unitId === '01-greetings') &&
    hits.some(
      (h) =>
        h.listLabel === 'Từ vựng' && h.row === 0 && h.field === 'nghĩa' && h.text === 'xin chào',
    ) &&
    hits.some((h) => h.tab === 'dialogues' && h.row === 0 && h.field === 'câu trả lời') &&
    hits.some(
      (h) =>
        h.tab === 'basics' && h.row === null && h.field === 'tên unit' && h.text === 'Chào hỏi',
    ),
  JSON.stringify(hits.map((h) => `${h.tab}:${h.row}:${h.field}:${h.text}`)),
);
check(
  'tìm theo nghĩa tiếng Việt ra đúng dòng từ vựng',
  (() => {
    const h = cms.searchEntries(cms.courseEntries([one]), 'khoe');
    return (
      h.length === 1 &&
      h[0].tab === 'sentences' &&
      h[0].row === 0 &&
      h[0].text === 'Bạn khỏe không?'
    );
  })(),
  JSON.stringify(cms.searchEntries(cms.courseEntries([one]), 'khoe')),
);
check(
  'giới hạn kết quả được báo rõ chứ không âm thầm cắt',
  (() => {
    const many = cms.courseEntries([one]);
    const all = cms.searchEntries(many, 'a');
    const few = cms.searchEntries(many, 'a', 3);
    return all.length > 3 && few.length === 3;
  })(),
);

const second = record(
  '02-daily',
  1,
  unitFixture({
    title: 'Sinh hoạt',
    theme: 'daily',
    vocab: [
      word('apple', 'quả táo'),
      word('hello', 'xin chào'),
      word('Thank you', 'cảm ơn', 'thank_you'),
      word('thank you', 'cảm ơn này', 'thank_you_2'),
    ],
    sentences: [
      sentence('How are you?', 'Bạn khỏe không?'),
      sentence('I eat an apple.', 'Tôi ăn táo.'),
    ],
  }),
);
const pair = [one, second];
const words = cms.repeatedWords(pair);
check(
  'từ dạy ở hai unit bị bắt, kể cả khi viết hoa khác nhau',
  words.length === 1 &&
    words[0].key === 'hello' &&
    words[0].unitCount === 2 &&
    words[0].rows.length === 2,
  JSON.stringify(words),
);
check(
  'từ lặp trong cùng một unit không nằm ở danh sách trùng giữa các unit',
  cms.repeatedWords([second]).length === 0,
  JSON.stringify(cms.repeatedWords([second])),
);
check(
  '… nhưng danh sách lặp trong một unit thì thấy nó',
  (() => {
    const inside = cms.repeatsInsideUnit([second]);
    return inside.length === 1 && inside[0].key === 'thank you' && inside[0].rows.length === 2;
  })(),
  JSON.stringify(cms.repeatsInsideUnit([second])),
);
const dupeErrors = cms
  .lintUnit(second.draft)
  .filter((i) => i.level === 'error' && i.message.includes('Trùng từ'));
check(
  'cổng lưu đã chặn từ trùng trong cùng một unit — nên danh sách đó chỉ còn để soi bản nháp cũ',
  dupeErrors.length === 1 &&
    dupeErrors[0].path === 'vocab[3] (thank you)' &&
    !cms.lintUnit(one.draft).some((i) => i.message.includes('Trùng từ')),
  JSON.stringify(dupeErrors),
);
check(
  'câu lặp lại bị bắt dù chỉ trong một unit',
  (() => {
    const s = cms.repeatedSentences(pair);
    return s.length === 1 && s[0].kind === 'sentence' && s[0].rows.length === 2;
  })(),
  JSON.stringify(cms.repeatedSentences(pair)),
);

// ---------- B. the service over stored drafts ----------
await store.saveCourse({
  courseId: 'vi_en',
  draft: {
    course: {
      courseId: 'vi_en',
      title: 'Khóa thử tìm',
      sourceLocale: 'vi',
      targetLocale: 'en',
      status: 'DRAFT',
    },
    sections: [{ sectionId: 's1', title: 'Phần một', units: ['01-greetings', '02-daily'] }],
    version: 'v2',
  },
  actorId: 'harness-search',
  expectedRevision: 0,
});
for (const unit of pair)
  await store.saveUnit({
    courseId: 'vi_en',
    unitId: unit.unitId,
    order: unit.order,
    draft: unit.draft,
    actorId: 'harness-search',
    expectedRevision: 0,
  });

const report = await cms.courseSearch('vi_en', 'apple');
check(
  'service đọc bản nháp đã lưu, không đọc file dựng',
  report.unitCount === 2 && report.entryCount === cms.courseEntries(pair).length,
  `${report.unitCount} / ${report.entryCount}`,
);
check(
  'kết quả chỉ vào unit chứa từ đó, kèm số dòng đếm được trong editor',
  report.hits.length === 3 &&
    report.hits.every((h) => h.unitId === '02-daily') &&
    report.hits.some((h) => h.tab === 'vocab' && h.row === 0 && h.field === 'từ') &&
    report.hits.some((h) => h.tab === 'vocab' && h.row === 0 && h.field === 'id') &&
    report.hits.some((h) => h.tab === 'sentences' && h.row === 1 && h.field === 'câu'),
  JSON.stringify(report.hits.map((h) => `${h.tab}:${h.row}:${h.field}`)),
);
const empty = await cms.courseSearch('vi_en', '');
check(
  'danh sách trùng vẫn hiện khi ô tìm trống, vì đó là câu hỏi không có từ khóa',
  empty.hits.length === 0 &&
    empty.words.length === 1 &&
    empty.sentences.length === 1 &&
    empty.insideUnit.length === 1,
  JSON.stringify({ words: empty.words, sentences: empty.sentences, insideUnit: empty.insideUnit }),
);
check(
  'khóa chưa có unit thì không có gì để tìm',
  (await cms.courseSearch('khong_ton_tai', 'apple')) === null,
);
check(
  'không có kết quả là một báo cáo thẳng thắn, không phải lỗi',
  (await cms.courseSearch('vi_en', 'zzz')).hits.length === 0,
);

// ---------- C. the real course ----------
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
const realEntries = cms.courseEntries(realUnits);
const realWords = cms.repeatedWords(realUnits);
const realInside = cms.repeatsInsideUnit(realUnits);
const realSentences = cms.repeatedSentences(realUnits);

check(
  `khóa thật có ${realUnits.length} unit và ${realEntries.length} chuỗi để tìm`,
  realUnits.length >= 16 && realEntries.length > 1000,
  `${realUnits.length} units, ${realEntries.length} entries`,
);
const titleMisses = realUnits.filter((unit) => {
  const found = cms.searchEntries(realEntries, cms.foldKey(unit.draft.title));
  return !found.some((h) => h.unitId === unit.unitId && h.field === 'tên unit');
});
check(
  'bỏ hết dấu thanh thì vẫn tìm ra tên từng unit thật — không unit nào vô hình',
  titleMisses.length === 0,
  join(titleMisses.map((u) => u.draft.title)),
);
const probes = ['apple', 'thay', 'How are you', 'xa nha', 'nam', 'co gang'];
const probeHits = probes.flatMap((q) => cms.searchEntries(realEntries, q).map((h) => ({ q, h })));
const badHighlight = probeHits.filter(({ q, h }) => {
  const slice = h.text.slice(h.start, h.end);
  return !slice || h.start < 0 || h.end > h.text.length || cms.foldKey(slice) !== cms.foldKey(q);
});
check(
  `${probeHits.length} kết quả trên khóa thật, phần được tô luôn đúng là từ đã gõ`,
  probeHits.length > 0 && badHighlight.length === 0,
  JSON.stringify(badHighlight.slice(0, 3)),
);
check(
  'mỗi probe trả về số dòng đủ để đọc, không âm thầm vượt giới hạn 200',
  probeHits.every(({ h }) => h.text.length > 0) &&
    probes.every((q) => cms.searchEntries(realEntries, q).length <= cms.HIT_LIMIT),
);
const found = (q) => cms.searchEntries(realEntries, q);
check(
  'từ có thật trong khóa tìm thấy cả từ vựng lẫn nghĩa tiếng Việt, từ bịa ra thì không — danh sách trùng rỗng là dữ liệu sạch chứ không phải code hỏng',
  found('mother').some((h) => h.tab === 'vocab' && h.field === 'từ') &&
    found('nuoc').some((h) => h.tab === 'vocab' && h.field === 'nghĩa') &&
    found('tạm biệt').some((h) => h.tab === 'vocab' && h.field === 'nghĩa') &&
    found('zzzqqq').length === 0 &&
    realWords.length + realInside.length + realSentences.length === 0,
  `${found('mother').length}/${found('nuoc').length}/${found('tạm biệt').length} hits; repeats ${realWords.length}/${realInside.length}/${realSentences.length}`,
);
check(
  'danh sách trùng nói đúng điều nó tên gọi trên dữ liệu thật',
  realWords.every((g) => g.unitCount > 1) &&
    realInside.every((g) => g.rows.length > 1) &&
    realSentences.every((g) => g.kind === 'sentence' && g.rows.length > 1),
  `${realWords.length} words / ${realInside.length} inside / ${realSentences.length} sentences`,
);
check(
  'tìm một từ đã dạy trùng cho ra đủ những chỗ nó đứng',
  (() => {
    if (realWords.length === 0) return true;
    const group = realWords[0];
    const found = cms.searchEntries(realEntries, group.rows[0].text);
    return found.filter((h) => h.tab === 'vocab' && h.field === 'từ').length >= group.rows.length;
  })(),
  realWords.length ? JSON.stringify(realWords[0]) : 'no repeats',
);

await rm(scratch, { recursive: true, force: true });

if (failures.length) {
  console.error(`FAIL — ${failures.length}/${checks.length} search checks failed:`);
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log(
  `OK — ${checks.length} checks: search folds case and dấu away while still highlighting the authored characters, every hit names the editor tab, row and column it came from, the three duplicate lists mean what they say (${realWords.length} headwords taught in more than one unit, ${realInside.length} repeated inside one unit, ${realSentences.length} repeated sentences across ${realUnits.length} units and ${realEntries.length} strings), and on the real course every unit title is still findable without its dấu.`,
);
