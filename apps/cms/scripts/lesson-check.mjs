// Built-lesson proof. The screen answers "what will the learner actually be asked", and the only honest
// source for that is `content/<course>/dist/<version>/bundles/*.json` — the files the last build handed the
// app. The harness feeds `parseLesson` one exercise per drill type the generator emits (`build-course.mjs`
// has exactly twelve `type:` strings), so every answer line is checked against the field the app grades;
// then it reads the real unit 1 of `vi_en` through `unitLessons` and proves the drill set never grew past
// the labels, that each `u1.<word>` traces to the draft row that printed it, and that a draft which has
// moved on is reported as stale instead of silently agreeing. Part C writes synthetic builds into a scratch
// repo: a manifest that names a missing file, a file that is not a lesson, a version that was never built,
// and a unit number the manifest does not teach. The real `content/` tree is only ever read.
import { build } from 'esbuild';
import { execFileSync } from 'node:child_process';
import { cp, mkdir, mkdtemp, readFile, readdir, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { HARNESS_ADMIN_SECRET } from './harness-auth.mjs';

const appRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const realRepo = path.resolve(appRoot, '..', '..');
const posix = (p) => p.replace(/\\/g, '/');
for (const entry of await readdir(path.join(appRoot, 'node_modules')).catch(() => []))
  if (entry.startsWith('.lesson-'))
    await rm(path.join(appRoot, 'node_modules', entry), { recursive: true, force: true });
const scratch = await mkdtemp(path.join(appRoot, 'node_modules', '.lesson-'));
const dataDir = path.join(scratch, 'data');
const repoRoot = path.join(scratch, 'repo');
const realBundles = path.join(realRepo, 'content/vi_en/dist/v2/bundles');

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
      "export * from '@/cms/lessons';\n" +
      "export * from '@/cms/blank';\n" +
      "export * from '@/cms/tables';\n" +
      "export * from '@/server/lesson-service';\n" +
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
  CMS_ADMIN_USER_IDS: 'harness-lesson',
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

// ---------- A. one exercise per drill the generator emits ----------
const draft = cms.blankUnit('greetings', 'A1');
draft.title = 'Chào hỏi';
const row = (id, en, vi) => ({
  level: 1,
  en,
  enAlts: [],
  vi,
  viAlts: [],
  img: false,
  forms: [],
  id,
});
draft.vocab = [
  row('hello', 'hello', 'xin chào'),
  row('goodbye', 'goodbye', 'tạm biệt'),
  row('yes', 'yes', 'vâng'),
  row('no', 'no', 'không'),
  row('morning', 'morning', 'buổi sáng'),
  { ...row('name', 'name', 'tên'), id: '' },
];
const words = cms.wordIndex(draft, 'u1');
// A review lesson of unit 1 that asks about a word unit 2 taught: the index is the course's, not one draft's.
for (const [key, ref] of cms.wordIndex(
  { ...draft, vocab: [row('mother', 'mother', 'mẹ')] },
  'u2',
))
  words.set(key, ref);

const choice = (correct, list) => ({
  content: { choices: list.map((text, i) => ({ id: `c${i + 1}`, text })) },
  gradingRule: { correctChoiceId: `c${correct}`, caseSensitive: false },
});
const exercise = (id, type, body) => {
  const { prompt, skillIds, vocabularyIds, hint, explanation, content, gradingRule, ...rest } = body;
  return {
    id,
    type,
    prompt: prompt ?? { locale: 'vi-VN', text: 'Đề bài' },
    skillIds: skillIds ?? ['vocab', 'u1.grammar'],
    vocabularyIds: vocabularyIds ?? [`u1.${type}`],
    content,
    gradingRule,
    hint: hint ?? null,
    explanation: explanation ?? null,
    ...rest,
  };
};

const fixtures = [
  exercise('e-choice', 'choice', {
    ...choice(2, ['tạm biệt', 'xin chào', 'vâng', 'không']),
    vocabularyIds: ['u1.hello'],
    prompt: { locale: 'vi-VN', text: 'Từ mới! Chọn nghĩa đúng của "hello"' },
  }),
  exercise('e-image', 'imageChoice', {
    content: {
      choices: [
        { id: 'c1', text: 'student', imageAssetId: 'i.u1.student' },
        { id: 'c2', text: 'morning', imageAssetId: 'i.u1.morning' },
      ],
    },
    gradingRule: { correctChoiceId: 'c2' },
    vocabularyIds: ['u1.morning'],
  }),
  exercise('e-listen', 'listenChoice', {
    ...choice(3, ['Hello, Mai!', 'Goodbye, Linh!', 'Hello, I am Anna.']),
    vocabularyIds: ['u1.hello'],
    prompt: { locale: 'vi-VN', text: 'Nghe và chọn câu bạn nghe được', audioAssetId: 'a.u1.s6.n' },
    nonAudioAlternative: {
      id: 'e-listena',
      type: 'choice',
      prompt: { locale: 'vi-VN', text: 'Chọn câu tiếng Anh có nghĩa: "Xin chào, tôi là Anna."' },
      content: { choices: [{ id: 'c3', text: 'Hello, I am Anna.' }] },
      gradingRule: { correctChoiceId: 'c3' },
      vocabularyIds: ['u1.hello'],
    },
  }),
  exercise('e-pairs', 'matchPairs', {
    content: {
      pairs: [
        { id: 'p3', left: { id: 'p3l', text: 'hello' }, right: { id: 'p3r', text: 'xin chào' } },
        { id: 'p1', left: { id: 'p1l', text: 'goodbye' }, right: { id: 'p1r', text: 'tạm biệt' } },
        { id: 'p2', left: { id: 'p2l', text: 'yes' }, right: { id: 'p2r', text: 'vâng' } },
      ],
    },
    gradingRule: { correctPairIds: ['p1', 'p2', 'p3'] },
    vocabularyIds: ['u1.goodbye', 'u1.yes', 'u1.hello'],
  }),
  exercise('e-bank', 'wordBank', {
    content: {
      tokens: [
        { id: 't1', text: 'Linh' },
        { id: 't2', text: 'Goodbye' },
        { id: 't3', text: '!' },
      ],
    },
    gradingRule: { correctTokenIds: ['t2', 't1', 't3'] },
    vocabularyIds: ['u1.goodbye'],
  }),
  exercise('e-order', 'sentenceOrder', {
    content: { tokens: [{ id: 't1', text: 'name' }, { id: 't2', text: 'My' }] },
    gradingRule: { correctTokenIds: ['t2', 't1'] },
    vocabularyIds: ['u1.name'],
  }),
  exercise('e-blank', 'fillBlank', {
    content: { maxChars: 40, placeholder: 'Điền từ còn thiếu' },
    gradingRule: { acceptedText: ['No'] },
    vocabularyIds: ['u1.no'],
  }),
  exercise('e-translate', 'textTranslation', {
    content: { maxChars: 200, placeholder: 'Viết bằng tiếng Anh' },
    gradingRule: { acceptedText: ['Hello, Mai!', 'Hi, Mai!'] },
    vocabularyIds: ['u1.hello'],
  }),
  exercise('e-dictation', 'dictation', {
    content: { maxChars: 200, placeholder: 'Viết những gì bạn nghe' },
    gradingRule: { acceptedText: ['Yes, I am Tom.', "Yes, I'm Tom."] },
    vocabularyIds: ['u1.yes'],
    prompt: { locale: 'vi-VN', text: 'Nghe và viết lại bằng tiếng Anh', audioAssetId: 'a.u1.s4.n' },
    nonAudioAlternative: {
      id: 'e-dictationa',
      type: 'textTranslation',
      prompt: { locale: 'vi-VN', text: 'Vâng, tôi là Tom.' },
      content: { maxChars: 200 },
      gradingRule: { acceptedText: ['Yes, I am Tom.'] },
      vocabularyIds: ['u1.gone'],
    },
  }),
  exercise('e-repeat', 'speakRepeat', {
    content: { locale: 'en-US', maxSeconds: 5, referenceText: 'Bye, Tom!' },
    gradingRule: { acceptedText: ['Bye, Tom!', 'Goodbye, Tom!'] },
    vocabularyIds: ['u1.goodbye'],
    prompt: { locale: 'en-US', text: 'Nói câu sau: "Bye, Tom!"', audioAssetId: 'a.u1.s7.n' },
  }),
  exercise('e-dialogue', 'dialogueTurn', {
    content: { locale: 'en-US', maxSeconds: 12, referenceText: 'My name is Mai.' },
    gradingRule: { acceptedText: ['My name is Mai.', "I'm Mai."] },
    vocabularyIds: ['u1.hello', 'u1.name'],
    prompt: { locale: 'en-US', text: 'Hi! What is your name?', audioAssetId: 'a.u1.d2.n' },
    nonSpeechAlternative: {
      id: 'e-dialoguea',
      type: 'choice',
      prompt: { locale: 'vi-VN', text: '"Hi! What is your name?" — chọn câu trả lời phù hợp' },
      content: { choices: [{ id: 'c1', text: 'Hi!' }, { id: 'c2', text: 'My name is Mai.' }] },
      gradingRule: { correctChoiceId: 'c2' },
      vocabularyIds: ['u1.hello'],
    },
  }),
  exercise('e-story', 'storyQuestion', {
    content: {
      passage: 'It is Monday morning. Mai is a student.',
      question: 'Who is Tom?',
      choices: [{ id: 'c1', text: 'A new student' }, { id: 'c2', text: 'A teacher' }],
    },
    gradingRule: { correctChoiceId: 'c1' },
    vocabularyIds: [],
    prompt: { locale: 'en-US', text: 'Who is Tom?' },
  }),
  exercise('e-new', 'quizLoop', {
    content: { choices: [{ id: 'c1', text: 'one' }] },
    gradingRule: { correctChoiceId: 'c9' },
    vocabularyIds: ['u1.gone'],
  }),
  exercise('e-review', 'choice', {
    ...choice(1, ['mẹ', 'bố']),
    vocabularyIds: ['u2.mother', 'u1.hello'],
    prompt: { locale: 'vi-VN', text: 'Ôn lại: "mother" nghĩa là gì?' },
  }),
];

const lesson = cms.parseLesson(
  { lessonId: 'u1n1l1', title: 'Xin chào', nodeId: 'u1n1', order: 0, exercises: fixtures },
  { nodeId: 'u1n1', title: 'Xin chào', kind: 'lesson', lessonIds: ['u1n1l1'] },
  words,
);
const byId = new Map(lesson.exercises.map((e) => [e.id, e]));
const get = (id) => byId.get(id);

check(
  'bộ dạng bài đã biết đúng 12 loại',
  cms.knownDrills().length === 12,
  `${cms.knownDrills().length}: ${join(cms.knownDrills())}`,
);
const unnamed = fixtures
  .filter((f) => f.type !== 'quizLoop')
  .map((f) => f.type)
  .filter((t) => cms.drillLabel(t).startsWith('dạng '));
check('cả 12 loại đều có nhãn tiếng Việt', unnamed.length === 0, join(unnamed));
check(
  'loại chưa ai biết vẫn hiện ra đúng tên nó thay vì mất câu',
  get('e-new').label === 'dạng quizLoop' && get('e-new').id === 'e-new',
  get('e-new').label,
);

check(
  'bài chọn chữ in ra đáp án là chữ của ô đúng, không phải id',
  get('e-choice').answer === 'xin chào' &&
    join(get('e-choice').choices.filter((c) => c.correct).map((c) => c.text)) === 'xin chào' &&
    get('e-choice').choices.length === 4,
  `${get('e-choice').answer} / ${join(get('e-choice').choices.map((c) => `${c.id}${c.correct ? '*' : ''}`))}`,
);
check(
  'bài chọn ảnh giữ id ảnh để màn hình nói được ảnh nào',
  join(get('e-image').choices.map((c) => c.imageAssetId)) === 'i.u1.student,i.u1.morning' &&
    get('e-image').answer === 'morning',
  join(get('e-image').choices.map((c) => c.imageAssetId)),
);
check(
  'nối cặp theo thứ tự bản dựng chấm, không theo thứ tự xáo trong file',
  get('e-pairs').answer === 'goodbye → tạm biệt; yes → vâng; hello → xin chào' &&
    join(get('e-pairs').pairs.map((p) => p.left)) === 'goodbye,yes,hello',
  get('e-pairs').answer,
);
check(
  'xếp từ in đúng câu đã sắp xếp',
  get('e-bank').answer === 'Goodbye Linh !' && get('e-order').answer === 'My name',
  `${get('e-bank').answer} / ${get('e-order').answer}`,
);
check(
  'điền từ và dịch lấy đáp án từ danh sách chấp nhận, phần còn lại để màn hình liệt kê riêng',
  get('e-blank').answer === 'No' &&
    get('e-translate').answer === 'Hello, Mai!' &&
    join(get('e-translate').accepted) === 'Hello, Mai!,Hi, Mai!',
  `${get('e-blank').answer} / ${get('e-translate').answer} / ${join(get('e-translate').accepted)}`,
);
check(
  'nói lại và lượt thoại lấy câu mẫu, không in cả ba cách chấp nhận',
  get('e-repeat').answer === 'Bye, Tom!' &&
    get('e-dialogue').answer === 'My name is Mai.' &&
    get('e-dialogue').accepted.length === 2,
  `${get('e-repeat').answer} / ${get('e-dialogue').answer}`,
);
check(
  'bốn bài nghe/nói mang id clip để biết app phát gì',
  join(['e-listen', 'e-dictation', 'e-repeat', 'e-dialogue'].map((i) => get(i).audioAssetId)) ===
    'a.u1.s6.n,a.u1.s4.n,a.u1.s7.n,a.u1.d2.n',
  join(['e-listen', 'e-dictation', 'e-repeat', 'e-dialogue'].map((i) => get(i).audioAssetId)),
);
check(
  'hỏi truyện mang theo đoạn truyện và in đáp án là chữ của ô đúng',
  get('e-story').passage === 'It is Monday morning. Mai is a student.' &&
    get('e-story').answer === 'A new student' &&
    get('e-story').wordIds.length === 0,
  `${get('e-story').answer} / ${get('e-story').wordIds.length} từ`,
);
check(
  'bài thay thế của dictation là dịch câu, của lượt thoại là chọn chữ',
  get('e-dictation').variant.type === 'textTranslation' &&
    get('e-dictation').variant.answer === 'Yes, I am Tom.' &&
    get('e-dialogue').variant.type === 'choice' &&
    get('e-dialogue').variant.answer === 'My name is Mai.' &&
    get('e-choice').variant === null,
  `${get('e-dictation').variant.type} / ${get('e-dialogue').variant.type}`,
);
check(
  'id từ trỏ về đúng dòng trong editor',
  eq(get('e-choice').refs, [{ tab: 'vocab', row: 0, label: 'hello', unitNumber: 'u1' }]) &&
    eq(get('e-pairs').refs.map((r) => r.row), [1, 2, 0]) &&
    join(get('e-pairs').refs.map((r) => r.label)) === 'goodbye,yes,hello',
  JSON.stringify(get('e-choice').refs),
);
check(
  'bài ôn mượn từ của unit khác trỏ về unit ấy chứ không bị báo là mất',
  join(get('e-review').wordIds) === 'u2.mother,u1.hello' &&
    join(get('e-review').refs.map((r) => `${r.unitNumber}:${r.row}:${r.label}`)) === 'u2:0:mother,u1:0:hello' &&
    get('e-review').unknown.length === 0,
  `${join(get('e-review').wordIds)} / ${JSON.stringify(get('e-review').refs)}`,
);
check(
  'dòng không id không được tính là trỏ được',
  get('e-order').wordIds.join() === 'u1.name' &&
    join(get('e-order').unknown) === 'u1.name' &&
    get('e-order').refs.length === 0,
  `${join(get('e-order').unknown)} / ${get('e-order').refs.length} refs`,
);
check(
  'từ bản dựng hỏi mà không nháp nào có bị gọi tên ở cả bài chính lẫn bài thay thế',
  join(get('e-new').unknown) === 'u1.gone' &&
    join(get('e-dictation').variantUnknown) === 'u1.gone' &&
    join(get('e-dialogue').variantUnknown) === '',
  `${join(get('e-new').unknown)} / ${join(get('e-dictation').variantUnknown)}`,
);
const stale = cms.staleWordIds([lesson]);
check(
  'danh sách stale giữ nguyên id bản dựng ghi, sắp xếp và không trùng',
  eq(stale, ['u1.gone', 'u1.name']) && cms.staleWordIds([lesson, lesson]).join() === 'u1.gone,u1.name',
  join(stale),
);
check(
  'file không phải bài học thì từ chối chứ không báo 0 câu',
  cms.parseLesson(null, undefined, words) === null &&
    cms.parseLesson({ lessonId: 'x' }, undefined, words) === null &&
    cms.parseLesson({ exercises: [] }, undefined, words) === null,
);
check(
  'bản dựng thiếu id bài thì màn hình không đoán',
  cms.parseLesson(
    { lessonId: 'u1n1l2', exercises: [{ type: 'choice', ...choice(1, ['a']) }] },
    undefined,
    words,
  ).exercises[0].id === 'u1n1l2' &&
    cms.parseLesson({ lessonId: 'u1n1l2', exercises: [{}] }, undefined, words).exercises[0].type === '',
);
check(
  'ngôn ngữ đề bài đi kèm để biết app hỏi bằng thứ tiếng nào',
  join(['e-choice', 'e-repeat', 'e-story'].map((i) => get(i).locale)) === 'vi-VN,en-US,en-US',
  join(['e-choice', 'e-repeat', 'e-story'].map((i) => get(i).locale)),
);
check(
  'kỹ năng và gợi ý của bản dựng hiện ra nguyên văn',
  join(get('e-choice').skills) === 'vocab,u1.grammar' && get('e-choice').hint === null,
  join(get('e-choice').skills),
);

// ---------- B. the real build of unit 1, read through the service ----------
const realManifest = JSON.parse(
  await readFile(path.join(realRepo, 'content/vi_en/dist/v2/manifest.json'), 'utf8'),
);
const u1Nodes = realManifest.nodes.filter((n) => n.unitId === 'u1');
const u1Lessons = u1Nodes.flatMap((n) => n.lessonIds);
const distV2 = path.join(repoRoot, 'content/vi_en/dist/v2');
await mkdir(path.join(distV2, 'bundles'), { recursive: true });
await writeFile(path.join(distV2, 'manifest.json'), JSON.stringify(realManifest), 'utf8');
for (const lessonId of u1Lessons)
  await cp(path.join(realBundles, `${lessonId}.json`), path.join(distV2, 'bundles', `${lessonId}.json`));

const authored = JSON.parse(
  execFileSync(process.execPath, [path.join(appRoot, 'scripts', 'read-authored.mjs'), 'vi_en', 'v2'], {
    cwd: realRepo,
    maxBuffer: 32 * 1024 * 1024,
    encoding: 'utf8',
  }),
);
const authoredU1 = authored.units[0].unit;
const draftOf = (u) =>
  cms.tablesToUnit({
    theme: u.theme,
    cefr: u.cefr,
    title: u.title,
    levels: u.levels,
    guide: u.guide,
    vocab: u.vocab,
    sentences: u.sentences,
    dialogues: u.dialogues,
    storyTitle: u.story.title,
    passage: u.story.passage,
    questions: u.story.questions,
  });
const realDraft = draftOf(authoredU1);
const unitIdOf = (entry) => entry.fileName.replace(/^u/, '').replace(/\.mjs$/, '');

await store.saveCourse({
  courseId: 'vi_en',
  draft: { course: { id: 'vi_en', title: 'Tiếng Anh cho người Việt' }, sections: [], version: 'v2' },
  actorId: 'harness-lesson',
  expectedRevision: 0,
});
await store.saveUnit({
  courseId: 'vi_en',
  unitId: '01-greetings',
  order: 0,
  draft: realDraft,
  actorId: 'harness-lesson',
  expectedRevision: 0,
});

const report = await cms.unitLessons('vi_en', '01-greetings');
const rawBundles = new Map();
for (const lessonId of u1Lessons)
  rawBundles.set(
    lessonId,
    JSON.parse(await readFile(path.join(realBundles, `${lessonId}.json`), 'utf8')).exercises,
  );
const rawCount = [...rawBundles.values()].reduce((n, list) => n + list.length, 0);
const rawTally = {};
for (const list of rawBundles.values()) for (const e of list) rawTally[e.type] = (rawTally[e.type] ?? 0) + 1;

check(
  `đọc hết ${u1Nodes.length} node / ${u1Lessons.length} bài của unit 1 mà không thiếu file nào`,
  report.manifestFound &&
    report.nodes.length === u1Nodes.length &&
    report.lessons.length === u1Lessons.length &&
    report.missing.length === 0 &&
    report.unreadable.length === 0,
  `${report.nodes.length} node, ${report.lessons.length} bài, ${join(report.missing)}, ${join(report.unreadable)}`,
);
check(
  `đếm câu của màn hình đúng bằng số câu trong bundle thật (${rawCount})`,
  report.exerciseCount === rawCount &&
    report.lessons.reduce((n, l) => n + l.exercises.length, 0) === rawCount,
  `${report.exerciseCount} vs ${rawCount}`,
);
const buildTypes = Object.keys(report.types).sort();
const unknownTypes = buildTypes.filter((t) => !cms.knownDrills().includes(t));
check(
  `${buildTypes.length} dạng bài bản dựng thật sinh ra đều có nhãn (${buildTypes.join(' ')})`,
  unknownTypes.length === 0 && buildTypes.length === 12,
  `${buildTypes.length} types, unknown: ${join(unknownTypes)}`,
);
check(
  'đếm theo từng dạng khớp hẳn với file bundle',
  Object.keys(rawTally).every((t) => report.types[t] === rawTally[t]) &&
    Object.keys(report.types).length === Object.keys(rawTally).length,
  `${JSON.stringify(report.types)} vs ${JSON.stringify(rawTally)}`,
);
check(
  'mỗi bài mang đúng node của nó trong manifest',
  report.lessons.every((l) => {
    const node = u1Nodes.find((n) => n.lessonIds.includes(l.lessonId));
    return node && l.nodeId === node.nodeId && l.nodeTitle === node.title && l.nodeKind === node.kind;
  }),
  join(report.lessons.filter((l) => !l.nodeTitle).map((l) => l.lessonId)),
);
const kinds = [...new Set(report.nodes.map((n) => n.kind))].sort();
check(
  `manifest kể ${kinds.join(' ')} nên màn hình nhóm bài theo loại node thật`,
  kinds.length >= 2 && report.lessons.every((l) => kinds.includes(l.nodeKind)),
  join(kinds),
);
const emptyPrompt = report.lessons.flatMap((l) => l.exercises).filter((e) => !e.prompt.trim());
check('không câu nào hiện ra với đề bài rỗng', emptyPrompt.length === 0, join(emptyPrompt.map((e) => e.id)));
const realWords = cms.wordIndex(realDraft, 'u1');
const refIssues = [];
const traced = new Set();
for (const l of report.lessons)
  for (const e of l.exercises)
    for (const id of e.wordIds) {
      const want = realWords.get(id);
      if (!want) continue;
      traced.add(id);
      const got = e.refs.find((r) => r.tab === want.tab && r.row === want.row);
      if (!got || got.label !== want.label) refIssues.push(`${e.id}:${id}`);
    }
check(
  `${traced.size}/${realWords.size} dòng từ của unit đầu được bản dựng hỏi, mỗi lần đều trỏ lại đúng dòng ấy`,
  refIssues.length === 0 && traced.size >= 15,
  `${join(refIssues)} / traced ${traced.size} of ${realWords.size}`,
);
const audioDrills = report.lessons
  .flatMap((l) => l.exercises)
  .filter((e) => ['listenChoice', 'dictation', 'speakRepeat', 'dialogueTurn'].includes(e.type));
check(
  `${audioDrills.length} bài nghe/nói thật đều có clip kèm theo`,
  audioDrills.every((e) => e.audioAssetId),
  join(audioDrills.filter((e) => !e.audioAssetId).map((e) => e.id)),
);
const choiceDrills = report.lessons
  .flatMap((l) => l.exercises)
  .filter((e) => ['choice', 'imageChoice', 'listenChoice', 'storyQuestion'].includes(e.type));
check(
  `${choiceDrills.length} bài chọn đều có đúng một ô đúng`,
  choiceDrills.every((e) => e.choices.filter((c) => c.correct).length === 1 && !!e.answer),
  join(choiceDrills.filter((e) => e.choices.filter((c) => c.correct).length !== 1).map((e) => e.id)),
);
const pairDrills = report.lessons.flatMap((l) => l.exercises).filter((e) => e.type === 'matchPairs');
check(
  `${pairDrills.length} bài nối cặp hiện đủ số cặp bản dựng chấm`,
  pairDrills.every((e) => e.pairs.length > 1 && e.answer.split(';').length === e.pairs.length),
  join(pairDrills.filter((e) => e.pairs.length < 2).map((e) => e.id)),
);
const variants = report.lessons.flatMap((l) => l.exercises).filter((e) => e.variant);
check(
  `${variants.length} bài có đường thay thế khi điện thoại không có mic/loa, và đường ấy là dạng đã biết`,
  variants.length > 0 && variants.every((e) => cms.knownDrills().includes(e.variant.type) && !!e.variant.answer),
  join(variants.filter((e) => !cms.knownDrills().includes(e.variant.type)).map((e) => e.id)),
);
check(
  'bản nháp hiện hành chưa bỏ dòng nào mà bản dựng còn hỏi',
  report.stale.length === 0 && join(report.stale) === '',
  `${report.stale.length}: ${join(report.stale)}`,
);

// The course read whole. Unit 16's build reviews words taught by thirteen other units (275 of its 399
// exercises), so a screen that indexed only the draft it was handed would call every borrowed word lost.
const u16Lessons = realManifest.nodes.filter((n) => n.unitId === 'u16').flatMap((n) => n.lessonIds);
for (const lessonId of u16Lessons)
  await cp(path.join(realBundles, `${lessonId}.json`), path.join(distV2, 'bundles', `${lessonId}.json`));
const courseWords = new Map(realWords);
for (const [index, entry] of authored.units.slice(1).entries()) {
  const number = `u${index + 2}`;
  const unitDraft = draftOf(entry.unit);
  for (const [key, ref] of cms.wordIndex(unitDraft, number)) if (!courseWords.has(key)) courseWords.set(key, ref);
  await store.saveUnit({
    courseId: 'vi_en',
    unitId: unitIdOf(entry),
    order: index + 1,
    draft: unitDraft,
    actorId: 'harness-lesson',
    expectedRevision: 0,
  });
}
const last = await cms.unitLessons('vi_en', '16-plans');
const lastExercises = last.lessons.flatMap((l) => l.exercises);
const borrowed = lastExercises.filter((e) => e.refs.some((r) => r.unitNumber !== 'u16'));
const badRefs = [];
const borrowedUnits = new Set();
for (const e of lastExercises)
  for (const id of e.wordIds) {
    const want = courseWords.get(id);
    if (!want) {
      badRefs.push(`${e.id}:${id} không có nháp nào mà không bị báo mất`);
      continue;
    }
    if (want.unitNumber !== 'u16') borrowedUnits.add(want.unitNumber);
    if (!e.refs.some((r) => r.unitNumber === want.unitNumber && r.row === want.row && r.label === want.label))
      badRefs.push(`${e.id}:${id} trỏ sai dòng`);
  }
check(
  `unit 16 dựng lại ${last.exerciseCount} câu, ${borrowed.length} câu trong số đó ôn từ của ${borrowedUnits.size} unit khác`,
  last.stale.length === 0 &&
    borrowed.length === 275 &&
    badRefs.length === 0 &&
    borrowedUnits.size === 13 &&
    join(borrowed.map((e) => e.refs.find((r) => r.unitNumber !== 'u16')?.unitNumber)).includes('u1'),
  `${last.stale.length} stale / ${borrowed.length} borrowed / ${join(badRefs)}`,
);
check(
  'màn hình biết số unit nào là của trang soạn nào để nối đúng ô',
  Object.keys(last.unitIds).length === 16 &&
    last.unitIds.u1 === '01-greetings' &&
    last.unitIds.u16 === '16-plans',
  JSON.stringify(last.unitIds),
);

// ---------- C. a build the draft has outgrown, and builds with holes ----------
const drifted = structuredClone(realDraft);
const dropped = drifted.vocab.findIndex((r) => r.id === 'hello');
drifted.vocab.splice(dropped, 1);
await store.saveUnit({
  courseId: 'vi_en',
  unitId: '01-greetings',
  order: 0,
  draft: drifted,
  actorId: 'harness-lesson',
  expectedRevision: 1,
});
const driftReport = await cms.unitLessons('vi_en', '01-greetings');
const askedHello = driftReport.lessons
  .flatMap((l) => l.exercises)
  .filter((e) => e.unknown.includes('u1.hello'));
check(
  `xóa dòng "hello" khỏi nháp thì màn hình bảo ${askedHello.length} câu còn hỏi nó chứ không âm thầm bỏ`,
  driftReport.stale.includes('u1.hello') &&
    askedHello.length > 0 &&
    askedHello.every((e) => e.refs.every((r) => r.label !== 'hello')) &&
    driftReport.exerciseCount === report.exerciseCount,
  `${driftReport.stale.length} stale, ${askedHello.length} câu, ${driftReport.exerciseCount} câu hỏi`,
);

await store.saveCourse({
  courseId: 'vi_en',
  draft: { course: { id: 'vi_en', title: '' }, sections: [], version: 'v9' },
  actorId: 'harness-lesson',
  expectedRevision: 1,
});
const distV9 = path.join(repoRoot, 'content/vi_en/dist/v9');
await mkdir(path.join(distV9, 'bundles'), { recursive: true });
await writeFile(
  path.join(distV9, 'manifest.json'),
  JSON.stringify({
    nodes: [
      { nodeId: 'u1n1', unitId: 'u1', kind: 'lesson', title: 'Thiếu file', lessonIds: ['u1n1l1', 'u1n1l9'] },
      { nodeId: 'u1n2', unitId: 'u1', kind: 'story', title: 'Không phải bài học', lessonIds: ['u1n2l1'] },
      { nodeId: 'u9n1', unitId: 'u9', kind: 'lesson', title: 'Unit khác', lessonIds: ['u9n1l1'] },
    ],
  }),
  'utf8',
);
await writeAt(
  path.join(distV9, 'bundles/u1n1l1.json'),
  JSON.stringify({
    lessonId: 'u1n1l1',
    title: 'Một câu',
    nodeId: 'u1n1',
    order: 0,
    exercises: [exercise('e-choice', 'choice', choice(1, ['xin chào']))],
  }),
);
await writeAt(path.join(distV9, 'bundles/u1n2l1.json'), JSON.stringify({ manifestHash: 'x' }));
await writeAt(
  path.join(distV9, 'bundles/u9n1l1.json'),
  JSON.stringify({
    lessonId: 'u9n1l1',
    title: 'Bài của unit 9',
    nodeId: 'u9n1',
    order: 0,
    exercises: [exercise('e-u9', 'choice', choice(1, ['xin chào']))],
  }),
);
const holes = await cms.unitLessons('vi_en', '01-greetings');
check(
  'manifest hứa bài không có file thì báo thiếu đúng id đó, không giảm tổng',
  holes.missing.join() === 'u1n1l9' && holes.lessons.length === 1 && holes.exerciseCount === 1,
  `${join(holes.missing)} / ${holes.lessons.length} bài / ${holes.exerciseCount} câu`,
);
check(
  'file bundle đọc được nhưng không phải bài học thì kể tên là không đọc được',
  holes.unreadable.join() === 'u1n2l1' && holes.nodes.length === 2,
  `${join(holes.unreadable)} / ${holes.nodes.length} node`,
);
await store.saveUnit({
  courseId: 'vi_en',
  unitId: '09-something',
  order: 8,
  draft: realDraft,
  actorId: 'harness-lesson',
  expectedRevision: 0,
});
const other = await cms.unitLessons('vi_en', '09-something');
check(
  'unit ở vị trí 9 mang số u9 và không nhận bài của unit khác',
  other.unitNumber === 'u9' && other.nodes.length === 1 && other.lessons[0]?.lessonId === 'u9n1l1',
  `${other.unitNumber} / ${other.nodes.length} node`,
);

await store.saveCourse({
  courseId: 'vi_en',
  draft: { course: { id: 'vi_en', title: '' }, sections: [], version: 'v7' },
  actorId: 'harness-lesson',
  expectedRevision: 2,
});
const never = await cms.unitLessons('vi_en', '01-greetings');
check(
  'chưa từng dựng bản đó thì màn hình nói chưa có manifest chứ không báo 0 câu vì hết bài, và đọc đúng thư mục bản nháp chỉ ra',
  never.manifestFound === false &&
    never.version === 'v7' &&
    never.nodes.length === 0 &&
    never.lessons.length === 0 &&
    never.missing.length === 0,
  `${never.version} / ${never.manifestFound} / ${never.missing.length}`,
);
check(
  'unit không tồn tại thì màn hình 404 chứ không phải trang trống',
  (await cms.unitLessons('vi_en', 'khong-co')) === null &&
    (await cms.unitLessons('khong_khoa', '01-greetings')) === null,
);

await rm(scratch, { recursive: true, force: true });

if (failures.length) {
  console.error(`FAIL — ${failures.length} of ${checks.length} checks`);
  for (const f of failures) console.error(`  ✗ ${f}`);
  process.exit(1);
}
console.log(`OK — ${checks.length} checks: ${join(checks)}`);
