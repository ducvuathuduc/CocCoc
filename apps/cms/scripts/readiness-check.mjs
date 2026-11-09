// Readiness checklist proof. The page's promise is that it owns no numbers: every row must equal what the
// screen that owns that fact reports, and the Publish button's verdict must equal the checklist's block set.
// Part A runs on a scratch repo with a three-unit course and a hand-written build (manifest + bundles +
// catalog) so each condition can be broken and repaired one at a time; Part B reads the REAL `vi_en` build —
// every bundle the generator shipped and all sixteen authored units — and proves the same equalities hold
// there, including that no exercise of the 6384 the app plays points at a row no draft owns. The real
// content/ tree is only ever read.
import { build } from 'esbuild';
import { execFileSync } from 'node:child_process';
import { cp, mkdir, mkdtemp, readdir, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { HARNESS_ADMIN_SECRET } from './harness-auth.mjs';

const appRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const realRepo = path.resolve(appRoot, '..', '..');
const posix = (p) => p.replace(/\\/g, '/');
for (const entry of await readdir(path.join(appRoot, 'node_modules')).catch(() => []))
  if (entry.startsWith('.readiness-'))
    await rm(path.join(appRoot, 'node_modules', entry), { recursive: true, force: true });
const scratch = await mkdtemp(path.join(appRoot, 'node_modules', '.readiness-'));
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
      "export * from '@/cms/blank';\n" +
      "export * from '@/cms/tables';\n" +
      "export * from '@/cms/lint';\n" +
      "export * from '@/cms/structure';\n" +
      "export * from '@/cms/search';\n" +
      "export * from '@/server/readiness';\n" +
      "export * from '@/server/lesson-service';\n" +
      "export * from '@/server/media-service';\n" +
      "export * from '@/server/placement-service';\n" +
      "export * from '@/server/publish-state';\n" +
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
  CMS_ADMIN_USER_IDS: 'harness-readiness',
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
const row = (report, id) =>
  report.items.find((i) => i.id === id) ?? {
    id: `—${id}—`,
    state: 'missing',
    count: -1,
    detail: '',
    href: null,
  };
const actor = 'harness-readiness';

const rowVocab = (id, en, vi, img = false) => ({
  level: 1,
  en,
  enAlts: [],
  vi,
  viAlts: [],
  img,
  forms: [],
  id,
});
const sentence = (en) => ({ en, enAlts: [], vi: 'Một câu.', viAlts: [] });
const exercise = (id, type, text, vocabularyIds, extra = {}) => ({
  id,
  type,
  prompt: { locale: 'en-US', text },
  vocabularyIds,
  ...extra,
});

// ---------- fixtures: one course, three units, a hand-written build ----------
const SYN = 'syn';
const ALPHA = '01-alpha';
const BETA = '02-beta';
const GAMMA = '03-gamma';

const alphaDraft = () => {
  const draft = cms.blankUnit('alpha', 'A1');
  draft.title = 'An-pha';
  draft.guide = 'Hướng dẫn an-pha';
  draft.levels = ['L1', 'L2', 'L3', 'L4', 'L5'];
  draft.vocab = [
    rowVocab('w_alpha', 'alpha', 'an-pha', true),
    rowVocab('w_shared', 'shared', 'chung'),
    ...Array.from({ length: 18 }, (_, i) =>
      rowVocab(`w_a${i + 3}`, `alpha item ${i + 3}`, `mục ${i + 3}`),
    ),
  ];
  draft.sentences = Array.from({ length: 24 }, (_, i) => sentence(`Alpha sentence ${i + 1}.`));
  draft.dialogues = Array.from({ length: 4 }, (_, i) => ({
    line: `alpha talk ${i + 1}`,
    reply: `alpha reply ${i + 1}`,
    replyAlts: [],
    vi: 'Chào.',
  }));
  draft.story = {
    title: 'Chuyện an-pha',
    passage: 'Alpha met beta.',
    questions: Array.from({ length: 6 }, (_, i) => ({
      q: `Which ${i + 1}?`,
      correct: 'yes',
      wrongs: ['no', 'maybe'],
    })),
  };
  return draft;
};
const betaDraft = () => {
  const draft = cms.blankUnit('beta', 'A1');
  draft.title = 'Bê-ta';
  draft.levels = ['L1', 'L2', 'L3', 'L4', 'L5'];
  draft.vocab = [
    rowVocab('w_beta', 'beta', 'bê-ta', true),
    rowVocab('w_shared', 'shared', 'chung'),
  ];
  draft.sentences = [sentence('Beta one.'), sentence('Beta two.')];
  draft.dialogues = [{ line: 'beta talk', reply: 'beta reply', replyAlts: [], vi: 'Chào.' }];
  return draft;
};
const gammaDraft = () => {
  const draft = cms.blankUnit('gamma', 'A1');
  draft.title = 'Gam-ma';
  draft.levels = ['L1', 'L2', 'L3', 'L4', 'L5'];
  draft.vocab = [rowVocab('w_gamma', 'gamma', 'gam-ma', true)];
  draft.sentences = [sentence('Gamma one.')];
  // Only one wrong answer: `lintUnit` calls this an error, and the repo's gate would refuse the export.
  draft.story = {
    title: 'Chuyện gam-ma',
    passage: 'Gamma ran.',
    questions: [{ q: 'Who?', correct: 'gamma', wrongs: ['nope'] }],
  };
  return draft;
};

const synSections = [
  { sectionId: 'sec1', title: 'Phần một', units: ['alpha', 'beta'] },
  { sectionId: 'sec2', title: 'Phần hai', units: ['gamma'] },
];

const saveSynCourse = async () => {
  await store.saveCourse({
    courseId: SYN,
    draft: {
      course: {
        courseId: SYN,
        title: 'Khóa thử checklist',
        sourceLocale: 'vi',
        targetLocale: 'en',
        status: 'DRAFT',
      },
      sections: synSections,
      version: 'v2',
    },
    actorId: actor,
    expectedRevision: 0,
  });
};
const saveUnit = async (unitId, order, draft, revision = 0) =>
  store.saveUnit({
    courseId: SYN,
    unitId,
    order,
    draft,
    actorId: actor,
    expectedRevision: revision,
  });

const synManifest = {
  nodes: [
    {
      nodeId: 'u1n1',
      unitId: 'u1',
      kind: 'lesson',
      title: 'An-pha 1',
      lessonIds: ['u1n1l1', 'u1n1l2'],
    },
    { nodeId: 'u2n1', unitId: 'u2', kind: 'lesson', title: 'Bê-ta 1', lessonIds: ['u2n1l1'] },
    { nodeId: 'u2n2', unitId: 'u2', kind: 'mastery', title: 'Ôn an-pha', lessonIds: ['u2n2l1'] },
    { nodeId: 'u3n1', unitId: 'u3', kind: 'story', title: 'Chuyện', lessonIds: ['u3n1l1'] },
  ],
};
const synBundles = {
  u1n1l1: {
    lessonId: 'u1n1l1',
    title: 'An-pha 1',
    nodeId: 'u1n1',
    unitId: 'u1',
    order: 1,
    exercises: [
      exercise('e1', 'choice', 'Which is alpha?', ['u1.w_alpha'], {
        content: {
          choices: [
            { id: 'c1', text: 'alpha' },
            { id: 'c2', text: 'beta' },
          ],
        },
        gradingRule: { correctChoiceId: 'c1' },
      }),
      exercise('e2', 'matchPairs', 'Nối', ['u1.w_shared'], {
        content: {
          pairs: [
            { id: 'p2', left: { id: 'l2', text: 'shared' }, right: { id: 'r2', text: 'chung' } },
            { id: 'p1', left: { id: 'l1', text: 'alpha' }, right: { id: 'r1', text: 'an-pha' } },
          ],
        },
        gradingRule: { correctPairIds: ['p1', 'p2'] },
      }),
    ],
  },
  u1n1l2: {
    lessonId: 'u1n1l2',
    title: 'An-pha 2',
    nodeId: 'u1n1',
    unitId: 'u1',
    order: 2,
    exercises: [
      exercise('e3', 'textTranslation', 'Dịch: an-pha', ['u1.w_alpha'], {
        gradingRule: { acceptedText: ['alpha', 'an alpha'] },
      }),
    ],
  },
  u2n1l1: {
    lessonId: 'u2n1l1',
    title: 'Bê-ta 1',
    nodeId: 'u2n1',
    unitId: 'u2',
    order: 1,
    exercises: [
      exercise('e4', 'choice', 'Which is beta?', ['u2.w_beta'], {
        content: {
          choices: [
            { id: 'c1', text: 'beta' },
            { id: 'c2', text: 'gamma' },
          ],
        },
        gradingRule: { correctChoiceId: 'c1' },
      }),
      exercise('e5', 'wordBank', 'Điền: ___ is shared', ['u1.w_shared'], {
        content: {
          tokens: [
            { id: 't1', text: 'shared' },
            { id: 't2', text: 'beta' },
          ],
        },
        gradingRule: { correctTokenIds: ['t1'] },
      }),
    ],
  },
  u2n2l1: {
    lessonId: 'u2n2l1',
    title: 'Ôn an-pha',
    nodeId: 'u2n2',
    unitId: 'u2',
    order: 1,
    exercises: [
      exercise('e6', 'sentenceOrder', 'Sắp xếp', ['u1.w_alpha', 'u2.w_beta'], {
        content: {
          tokens: [
            { id: 't1', text: 'beta' },
            { id: 't2', text: 'alpha' },
          ],
        },
        gradingRule: { correctTokenIds: ['t2', 't1'] },
      }),
    ],
  },
  u3n1l1: {
    lessonId: 'u3n1l1',
    title: 'Chuyện',
    nodeId: 'u3n1',
    unitId: 'u3',
    order: 1,
    exercises: [
      exercise('e7', 'storyQuestion', 'Who ran?', ['u3.w_gamma'], {
        content: {
          passage: 'Gamma ran.',
          question: 'Who ran?',
          choices: [{ id: 'c1', text: 'gamma' }],
        },
        gradingRule: { correctChoiceId: 'c1' },
      }),
      // The build still asks about a word the drafts no longer carry.
      exercise('e8', 'listenChoice', 'Nghe và chọn', ['u1.gone'], {
        prompt: { locale: 'en-US', text: 'Nghe và chọn', audioAssetId: 'a.u3.s1.n' },
        content: { choices: [{ id: 'c1', text: 'Gamma one.' }] },
        gradingRule: { correctChoiceId: 'c1' },
      }),
    ],
  },
};

const synDist = path.join(repoRoot, 'content', SYN, 'dist', 'v2');
const writeSynBuild = async () => {
  await writeAt(path.join(synDist, 'manifest.json'), JSON.stringify(synManifest));
  for (const [lessonId, bundle] of Object.entries(synBundles))
    await writeAt(path.join(synDist, 'bundles', `${lessonId}.json`), JSON.stringify(bundle));
  await writeAt(
    path.join(synDist, 'audio-catalog.json'),
    JSON.stringify({
      courseId: SYN,
      versionId: 'v2',
      locale: 'en-US',
      speeds: { n: 1, s: 0.75 },
      items: [
        { key: 'a.u1.s1', kind: 'sentence', text: 'Alpha sentence 1.' },
        { key: 'a.w.w_shared', kind: 'word', text: 'shared' },
      ],
    }),
  );
};

const gateRun = async (courseId, minutes = 5) => {
  await store.saveBuildRun({
    runId: `run-${courseId}-${Date.now()}-${minutes}`,
    courseId,
    versionId: 'v2',
    kind: 'GATES',
    status: 'SUCCEEDED',
    message: 'gate ok',
    log: ['build-course: ok'],
    actorId: actor,
    createdAt: new Date(Date.now() + minutes * 60_000).toISOString(),
  });
};
/** `listBuildRuns` sorts newest-first, so a passing gate is stamped now and later edits are simply newer. */
const passGate = (courseId) => gateRun(courseId, 0);
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * Writes the exact files the CMS media upload writes (`writeMediaFile` is the storage call the upload
 * route makes) for every asset the readiness report flags as a missing required file. Proves the upload
 * flow can clear the "thiếu file" block without anyone editing source: after this, the block is gone.
 */
const seedMedia = async (courseId) => {
  const report = await cms.courseMediaReport(courseId);
  for (const gap of report.gaps.filter((g) => g.state === 'missing')) {
    const ext = gap.kind === 'image' ? 'webp' : 'aac';
    // Minimal valid container bytes so the file is not empty; the readiness `present` check only needs
    // the file to exist, while a real publish gate would also hash/signature-check it.
    const body =
      ext === 'webp'
        ? new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
        : new Uint8Array([0xff, 0xf0, 0x00, 0x00]);
    await cms.writeMediaFile(
      courseId,
      {
        fileId: gap.fileId,
        kind: gap.kind,
        ext,
        group: 'word',
        label: gap.label ?? '',
        text: gap.text ?? '',
        draft: gap.draft ?? '',
        inCatalog: false,
        speed: 1,
      },
      body,
      false,
    );
  }
};

// ---------- A. the page refuses to answer for a course it does not have ----------
check(
  'khóa không tồn tại thì trang 404 chứ không phải checklist trống',
  (await cms.courseReadiness('khong_ton_tai')) === null,
);

await saveSynCourse();
const empty = await cms.courseReadiness(SYN);
check(
  'khóa chưa có unit: dòng unit, dòng gate và dòng bundle cùng chặn, không crash',
  row(empty, 'units').state === 'block' &&
    row(empty, 'gate').state === 'block' &&
    row(empty, 'build-found').state === 'block' &&
    empty.publishable === false &&
    empty.blocked >= 3,
  JSON.stringify(empty?.items.map((i) => [i.id, i.state])),
);
check(
  'chưa có unit thì không bịa ra dòng placement (bảng placement cần unit đầu để soi)',
  !empty.items.some((i) => i.id.startsWith('placement-')),
  join(empty.items.map((i) => i.id)),
);

// ---------- B. three units, one broken row at a time ----------
await saveUnit(ALPHA, 0, alphaDraft());
await saveUnit(BETA, 1, betaDraft());
await saveUnit(GAMMA, 2, gammaDraft());
await writeSynBuild();

const base = await cms.courseReadiness(SYN);
const units = await store.listUnits(SYN);
const course = await store.getCourse(SYN);

check(
  'dòng cấu trúc = đúng structureIssues của panel khóa',
  row(base, 'structure').count ===
    cms.structureIssues(
      course.draft.sections,
      units.map((u) => u.draft.theme),
    ).length && row(base, 'structure').state === 'ok',
  `${row(base, 'structure').count}: ${row(base, 'structure').detail}`,
);

const lintErrors = units.filter((u) => cms.lintUnit(u.draft).some((i) => i.level === 'error'));
const lintWarnings = units.filter(
  (u) => !lintErrors.includes(u) && cms.lintUnit(u.draft).some((i) => i.level === 'warning'),
);
check(
  'dòng lỗi chặn lưu đếm đúng unit có error, và gọi tên từng unit',
  row(base, 'lint-errors').count === lintErrors.length &&
    row(base, 'lint-errors').count === 1 &&
    lintErrors[0].unitId === GAMMA &&
    row(base, 'lint-errors').detail.includes(GAMMA) &&
    row(base, 'lint-errors').state === 'block',
  `${row(base, 'lint-errors').count}: ${row(base, 'lint-errors').detail}`,
);
check(
  'dòng cảnh báo tách khỏi dòng lỗi, dùng đúng bộ lint của editor',
  row(base, 'lint-warnings').count === lintWarnings.length &&
    row(base, 'lint-warnings').state === (lintWarnings.length ? 'warn' : 'ok'),
  `${row(base, 'lint-warnings').count}`,
);

const media = await cms.courseMediaReport(SYN);
check(
  'dòng media-missing = đúng số media bắt buộc thiếu của báo cáo toàn khóa, và chặn publish',
  row(base, 'media-missing').count === media.totals.missing &&
    media.totals.missing > 0 &&
    row(base, 'media-missing').state === 'block' &&
    row(base, 'media-missing').href === `/courses/${SYN}/media`,
  `${row(base, 'media-missing').count} vs ${JSON.stringify(media.totals)}`,
);
check(
  'dòng media-warn = clip chưa ghi nhận + catalog lệch, không chặn publish',
  row(base, 'media-warn').count === media.totals.unmanifested + media.totals.drift &&
    row(base, 'media-warn').state === (media.totals.unmanifested + media.totals.drift ? 'warn' : 'ok'),
  `${row(base, 'media-warn').count}`,
);
check(
  'dòng ảnh = ảnh không bundle nào chở + ảnh chưa bài nào đố',
  row(base, 'pictures').count === media.totals.unused + media.totals.picturesWithoutDrill,
  `${row(base, 'pictures').count}`,
);

const perUnitStale = [];
for (const u of units) {
  const r = await cms.unitLessons(SYN, u.unitId);
  if (r.stale.length)
    perUnitStale.push({ unitId: u.unitId, unitNumber: r.unitNumber, ids: r.stale });
}
check(
  'cộng stale từng màn unit = đúng số của checklist toàn khóa (một vòng đọc bundle dùng chung)',
  row(base, 'build-drift').count === perUnitStale.reduce((s, u) => s + u.ids.length, 0) &&
    base.items.find((i) => i.id === 'build-drift').detail.includes('u3 (1)') &&
    eq(
      perUnitStale.map((u) => [u.unitId, u.ids]),
      [[GAMMA, ['u1.gone']]],
    ),
  JSON.stringify(perUnitStale),
);
check(
  'id lạ được quy cho unit mà bản dựng đang hỏi, và ô sửa nối về editor của unit ấy',
  row(base, 'build-drift').href === `/courses/${SYN}/units/${GAMMA}/lesson`,
  row(base, 'build-drift').href,
);
check(
  'bundle nào manifest nêu mà màn unit đọc được thì checklist cũng đọc được',
  row(base, 'build-found').count === 0 && row(base, 'build-found').state === 'ok',
  `${row(base, 'build-found').count}: ${row(base, 'build-found').detail}`,
);

const placement = await cms.placementReport(SYN);
check(
  'dòng placement = đúng blockers/changed của bảng placement khóa',
  row(base, 'placement-blockers').count === placement.blockers.length &&
    row(base, 'placement-changed').count === placement.changed.length,
  `${placement.blockers.length}/${placement.changed.length} vs ${row(base, 'placement-blockers').count}`,
);
check(
  'unit đầu đủ 20 từ · 24 câu · 6 câu hỏi nên 10 vị trí bộ dựng còn đọc được',
  placement.blockers.length === 0 && row(base, 'placement-blockers').state === 'ok',
  join(placement.blockers),
);

const dupWords = cms.repeatedWords(units);
const dupInside = cms.repeatsInsideUnit(units);
const dupSentences = cms.repeatedSentences(units);
check(
  'dòng trùng = đúng ba danh sách của màn tìm kiếm',
  row(base, 'repeats').count === dupWords.length + dupInside.length + dupSentences.length &&
    dupWords.length === 1 &&
    dupWords[0].key === 'shared' &&
    row(base, 'repeats').href === `/courses/${SYN}/search`,
  `${row(base, 'repeats').count} vs ${dupWords.length}/${dupInside.length}/${dupSentences.length}`,
);

const publish = await cms.publishReadiness(SYN);
check(
  'checklist và nút Publish trả lời cùng một câu hỏi như nhau',
  base.publishable === publish.gatesOk && base.publishable === false,
  `${base.publishable} vs ${publish.gatesOk}`,
);
check(
  'nút Publish chỉ nêu một lý do, checklist nêu cùng lúc mọi lý do — đó là lý do trang này tồn tại',
  (publish.blocking ?? '').length > 0 &&
    base.blocked >= 1 &&
    base.items.filter((i) => i.state === 'block').length === base.blocked,
  `${publish.blocking} / blocked=${base.blocked}`,
);

// ---------- C. every row flips back, then breaks again, one at a time ----------
const cleanDraft = gammaDraft();
cleanDraft.story.questions = [{ q: 'Who?', correct: 'gamma', wrongs: ['nope', 'maybe'] }];
await saveUnit(GAMMA, 2, cleanDraft, 1);

// Required media is still absent: the readiness checklist must show a hard block, and the Publish
// button must agree — the offline gate (verifyMediaAssets) would also refuse a missing asset.
const beforeMedia = await cms.courseReadiness(SYN);
check(
  'thiếu media bắt buộc thì checklist chặn và nút Publish cũng chặn (nhất quán với máy kiểm tra nội dung)',
  row(beforeMedia, 'media-missing').state === 'block' &&
    row(beforeMedia, 'media-missing').count > 0 &&
    beforeMedia.publishable === false,
  JSON.stringify(beforeMedia.items.filter((i) => i.state !== 'ok').map((i) => [i.id, i.state])),
);

// The CMS media upload writes exactly these files (no source edit): after seeding them, the block clears.
await seedMedia(SYN);
await passGate(SYN);
const ready = await cms.courseReadiness(SYN);
check(
  'nạp file media (đúng quy trình upload) xong thì hết chặn media, nút Publish bật',
  ready.blocked === 0 && ready.publishable === true && row(ready, 'gate').state === 'ok',
  JSON.stringify(ready.items.filter((i) => i.state !== 'ok').map((i) => [i.id, i.state])),
);
check(
  'vẫn còn việc nên làm (media chưa ghi nhận + từ trùng + id lạ) dù đã publish được',
  ready.warned === ready.items.filter((i) => i.state === 'warn').length &&
    ready.warned >= 3 &&
    row(ready, 'build-drift').count === 1,
  `warned=${ready.warned}`,
);
check(
  'mọi dòng ok đều mang số 0 — không có dòng nào "xong" mà còn việc',
  ready.items.every((i) => !i.debt || i.state !== 'ok' || i.count === 0),
  JSON.stringify(
    ready.items
      .filter((i) => i.debt && i.state === 'ok' && i.count !== 0)
      .map((i) => [i.id, i.count]),
  ),
);

await rm(path.join(synDist, 'manifest.json'));
const noManifest = await cms.courseReadiness(SYN);
check(
  'xóa manifest: checklist chặn và nói chưa từng dựng, còn nút Publish vẫn bật (bảng này khắt khe hơn)',
  row(noManifest, 'build-found').state === 'block' &&
    noManifest.publishable === true &&
    row(noManifest, 'build-found').detail.includes('manifest.json') &&
    row(noManifest, 'build-drift').count === 0,
  `${row(noManifest, 'build-found').detail} / ${row(noManifest, 'build-drift').count}`,
);

await writeAt(path.join(synDist, 'manifest.json'), JSON.stringify(synManifest));
await rm(path.join(synDist, 'bundles', 'u2n1l1.json'));
const missingFile = await cms.courseReadiness(SYN);
check(
  'manifest hứa bài không có file: dòng bundle nêu đúng id đó',
  row(missingFile, 'build-found').count === 1 &&
    row(missingFile, 'build-found').state === 'warn' &&
    row(missingFile, 'build-found').detail.includes('u2n1l1'),
  row(missingFile, 'build-found').detail,
);

await writeAt(
  path.join(synDist, 'bundles', 'u2n1l1.json'),
  JSON.stringify({ nodeId: 'u2n1', exercises: [] }),
);
const notALesson = await cms.courseReadiness(SYN);
check(
  'file không phải bundle bài học thì bị kể tên, không âm thầm trừ khỏi tổng',
  row(notALesson, 'build-found').detail.includes('u2n1l1') &&
    row(notALesson, 'build-found').count === 1,
  row(notALesson, 'build-found').detail,
);

await writeAt(path.join(synDist, 'bundles', 'u2n1l1.json'), JSON.stringify(synBundles['u2n1l1']));
await sleep(20);
await saveUnit(BETA, 1, betaDraft(), 1);
const edited = await cms.courseReadiness(SYN);
check(
  'sửa nháp sau lần gate: dòng gate gọi đúng unit và chặn publish',
  row(edited, 'gate').state === 'block' &&
    row(edited, 'gate').count === 1 &&
    row(edited, 'gate').detail.includes(BETA) &&
    edited.publishable === false,
  row(edited, 'gate').detail,
);

const noWord = gammaDraft();
noWord.story.questions = [{ q: 'Who?', correct: 'gamma', wrongs: ['nope', 'maybe'] }];
noWord.vocab = [];
await saveUnit(GAMMA, 2, noWord, 2);
const lostWord = await cms.courseReadiness(SYN);
check(
  'xóa dòng từ mà bản dựng còn hỏi: id hiện ra ở checklist với đúng số lượng',
  row(lostWord, 'build-drift').count === 2 &&
    row(lostWord, 'build-drift').detail.includes('u3 (2)') &&
    row(lostWord, 'build-drift').href.includes(GAMMA),
  `${row(lostWord, 'build-drift').count}: ${row(lostWord, 'build-drift').detail}`,
);

const orphan = await store.getCourse(SYN);
const sections = orphan.draft.sections.map((s) => ({
  ...s,
  units: s.units.filter((t) => t !== 'gamma'),
}));
await store.saveCourse({
  courseId: SYN,
  draft: { ...orphan.draft, sections },
  actorId: actor,
  expectedRevision: orphan.revision,
});
const brokenStructure = await cms.courseReadiness(SYN);
check(
  'theme rơi khỏi mọi section: dòng cấu trúc chặn và chép nguyên văn câu của panel',
  row(brokenStructure, 'structure').state === 'block' &&
    row(brokenStructure, 'structure').count > 0 &&
    row(brokenStructure, 'structure').detail ===
      cms.structureIssues(sections, ['alpha', 'beta', 'gamma']).join(' ') &&
    brokenStructure.publishable === false,
  row(brokenStructure, 'structure').detail,
);

const restored = await store.getCourse(SYN);
await store.saveCourse({
  courseId: SYN,
  draft: { ...restored.draft, sections: synSections },
  actorId: actor,
  expectedRevision: restored.revision,
});
const short = alphaDraft();
short.sentences = short.sentences.slice(0, 5);
short.vocab = short.vocab.slice(0, 4);
await saveUnit(ALPHA, 0, short, 1);
const placementDead = await cms.courseReadiness(SYN);
check(
  'unit đầu bị cắt: checklist báo build chết ở đúng những slot, không gọi đó là "bài kiểm tra thiếu câu"',
  row(placementDead, 'placement-blockers').state === 'block' &&
    row(placementDead, 'placement-blockers').count > 0 &&
    (await cms.placementReport(SYN)).blockers.every((id) =>
      row(placementDead, 'placement-blockers').detail.includes(id),
    ),
  row(placementDead, 'placement-blockers').detail,
);

await saveUnit(ALPHA, 0, alphaDraft(), 2);
await writeAt(
  path.join(synDist, 'bundles', 'placement.json'),
  JSON.stringify({
    lessonId: 'placement',
    unitId: 'u1',
    guideText: 'Làm 10 câu để xếp lớp.',
    exercises: [
      {
        id: 'placement-e01',
        type: 'choice',
        prompt: { text: 'Which is an-pha?' },
        vocabularyIds: ['u1.w_alpha'],
      },
    ],
  }),
);
const afterGate = await cms.courseReadiness(SYN);
check(
  'câu app đang hỏi khác nháp: thành việc nên làm, kèm đúng id câu',
  row(afterGate, 'placement-changed').count === 1 &&
    row(afterGate, 'placement-changed').state === 'warn' &&
    row(afterGate, 'placement-changed').detail.includes('placement-e01') &&
    row(afterGate, 'placement-blockers').count === 0,
  row(afterGate, 'placement-changed').detail,
);
check(
  'mọi lối "sửa →" đều trỏ tới một màn hình thật của chính khóa này',
  afterGate.items.every(
    (i) =>
      i.href === null ||
      i.href.startsWith(`/courses/${SYN}`) ||
      i.href === '/ops/reports' ||
      i.href === `/builds?course=${SYN}`,
  ),
  join(
    afterGate.items
      .filter((i) => i.href && !i.href.startsWith(`/courses/${SYN}`))
      .map((i) => i.href),
  ),
);

// ---------- D. the real course, every bundle it ships ----------
const VI = 'vi_en';
const realDist = path.join(repoRoot, 'content', VI, 'dist', 'v2');
const realSource = path.join(realRepo, 'content', VI, 'dist', 'v2');
await mkdir(path.join(realDist, 'bundles'), { recursive: true });
await cp(path.join(realSource, 'manifest.json'), path.join(realDist, 'manifest.json'));
await cp(path.join(realSource, 'audio-catalog.json'), path.join(realDist, 'audio-catalog.json'));
const realBundleNames = await readdir(path.join(realSource, 'bundles'));
for (const name of realBundleNames)
  await cp(path.join(realSource, 'bundles', name), path.join(realDist, 'bundles', name));

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
const unitIdOf = (entry) => entry.fileName.replace(/^u/, '').replace(/\.mjs$/, '');

await store.saveCourse({
  courseId: VI,
  draft: {
    course: {
      courseId: VI,
      title: 'Tiếng Anh cho người Việt',
      sourceLocale: 'vi',
      targetLocale: 'en',
      status: 'DRAFT',
    },
    sections: authored.sections ?? [],
    version: 'v2',
  },
  actorId: actor,
  expectedRevision: 0,
});
for (const [index, entry] of authored.units.entries())
  await store.saveUnit({
    courseId: VI,
    unitId: unitIdOf(entry),
    order: index,
    draft: draftOf(entry.unit),
    actorId: actor,
    expectedRevision: 0,
  });

const real = await cms.courseReadiness(VI);
const realUnits = await store.listUnits(VI);
const drift = await cms.courseLessonDrift(VI);
check(
  `bản dựng thật đọc hết ${drift.lessonCount} bài mà không thiếu file nào`,
  row(real, 'build-found').count === 0 && row(real, 'build-found').state === 'ok',
  row(real, 'build-found').detail,
);
check(
  `6384 câu app thật phát đều trỏ lại một dòng nháp (${drift.exerciseCount} câu)`,
  drift.exerciseCount === 16 * 399 && row(real, 'build-drift').count === 0,
  `${drift.exerciseCount} / ${row(real, 'build-drift').count}: ${join(drift.stale.map((s) => s.unitId))}`,
);
for (const sample of ['01-greetings', '16-plans']) {
  const one = await cms.unitLessons(VI, sample);
  check(
    `màn hình unit ${one.unitNumber} hết stale y như checklist toàn khóa`,
    one.stale.length === 0 && one.exerciseCount === 399,
    `${one.stale.length}/${one.exerciseCount}`,
  );
}
check(
  'cấu trúc thật của khóa sạch, 16 unit đều thuộc một section',
  row(real, 'structure').state === 'ok' && realUnits.length === 16,
  row(real, 'structure').detail,
);
check(
  '16 bản nháp thật không unit nào có lỗi chặn lưu',
  row(real, 'lint-errors').count === 0 && row(real, 'lint-warnings').count === 0,
  `${row(real, 'lint-errors').count}/${row(real, 'lint-warnings').count}`,
);
check(
  'khóa thật chưa chạy gate trong CMS này nên trang chặn publish',
  row(real, 'gate').state === 'block' && real.publishable === false,
  row(real, 'gate').detail,
);
const realMedia = await cms.courseMediaReport(VI);
check(
  'nợ media-missing của khóa thật = đúng báo cáo toàn khóa, không phải số tự đếm lại',
  row(real, 'media-missing').count === realMedia.totals.missing &&
    row(real, 'media-missing').count > 1000,
  `${row(real, 'media-missing').count} vs ${JSON.stringify(realMedia.totals)}`,
);
check(
  'nợ media-warn (clip chưa ghi nhận + catalog lệch) của khóa thật = đúng báo cáo',
  row(real, 'media-warn').count ===
    realMedia.totals.unmanifested + realMedia.totals.drift,
  `${row(real, 'media-warn').count} vs ${JSON.stringify(realMedia.totals)}`,
);
check(
  'chưa có file nào nên chưa ảnh nào "đủ": dòng ảnh cũng lấy số từ báo cáo',
  row(real, 'pictures').count === realMedia.totals.unused + realMedia.totals.picturesWithoutDrill,
  `${row(real, 'pictures').count}`,
);
const realPlacement = await cms.placementReport(VI);
check(
  '10 vị trí placement của unit đầu thật vẫn còn dòng để đọc',
  realPlacement.blockers.length === 0 && row(real, 'placement-blockers').state === 'ok',
  join(realPlacement.blockers),
);
check(
  'khóa thật không dạy trùng: dòng trùng bằng 0 đúng như màn tìm kiếm đo',
  row(real, 'repeats').count === 0 &&
    cms.repeatedWords(realUnits).length === 0 &&
    cms.repeatsInsideUnit(realUnits).length === 0 &&
    cms.repeatedSentences(realUnits).length === 0,
  row(real, 'repeats').detail,
);
await passGate(VI);
const realReady = await cms.courseReadiness(VI);
check(
  'khóa thật thiếu media thật nên vẫn bị chặn publish (nhất quán với máy kiểm tra nội dung)',
  realReady.blocked >= 1 &&
    realReady.publishable === false &&
    row(realReady, 'media-missing').state === 'block' &&
    row(realReady, 'media-missing').count === realMedia.totals.missing,
  JSON.stringify(realReady.items.filter((i) => i.state !== 'ok').map((i) => [i.id, i.count])),
);
check(
  'mọi dòng của bản thật đều có label + detail để bấm, không có dòng rỗng href sai chỗ',
  realReady.items.every((i) => i.label && i.detail.length > 0 && i.href),
  join(realReady.items.filter((i) => !i.label || !i.detail || !i.href).map((i) => i.id)),
);

await rm(scratch, { recursive: true, force: true });

if (failures.length > 0) {
  console.error(`FAILED ${failures.length}/${checks.length}: ${join(failures)}`);
  process.exit(1);
}
console.log(
  `OK — ${checks.length} checks: ${join(checks)} (đọc ${drift.lessonCount} bài · ${drift.exerciseCount} câu của bản dựng thật, ${realMedia.totals.total} tài nguyên app cần)`,
);
