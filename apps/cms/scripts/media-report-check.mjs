// Course-wide media report proof. The unit panel answers "what does this unit owe?"; this harness proves
// the course page answers the same question consistently: one shared read of catalog + media tree +
// manifest + built bundles feeds every unit, the aggregated counts equal what the per-unit derivation
// reports, the work list is shaped for `generate-audio.mjs --only`, a stale catalog is called out instead
// of looking green, the exercise shapes and unused pictures come from the build rather than from wishful
// reading of the draft, and a reorder moves the debt with the unit number instead of deleting any file.
// Everything runs against a scratch repo root; the real content/ tree is never written.
import { build } from 'esbuild';
import { createHash } from 'node:crypto';
import { mkdir, mkdtemp, readFile, readdir, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { HARNESS_ADMIN_SECRET, authCoreStub } from './harness-auth.mjs';

const appRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const realRepo = path.resolve(appRoot, '..', '..');
for (const entry of await readdir(path.join(appRoot, 'node_modules')))
  if (entry.startsWith('.media-report-'))
    await rm(path.join(appRoot, 'node_modules', entry), { recursive: true, force: true });
const scratch = await mkdtemp(path.join(appRoot, 'node_modules', '.media-report-'));
const dataDir = path.join(scratch, 'data');
const repoRoot = path.join(scratch, 'repo');
const posix = (p) => p.replace(/\\/g, '/');

await writeFile(
  path.join(scratch, 'stub-headers.mjs'),
  'export async function cookies() {\n' +
    '  return { get: () => ({ value: process.env.CMS_HARNESS_SECRET }), set: () => {}, delete: () => {} };\n' +
    '}\n',
);
await writeFile(path.join(scratch, 'stub-auth-core.mjs'), authCoreStub());
await writeFile(
  path.join(scratch, 'stub-navigation.mjs'),
  'export function redirect(to) {\n  throw new Error(`redirect:${to}`);\n}\n',
);

const bundled = await build({
  stdin: {
    contents:
      "export * from '@/cms/media';\n" +
      "export * from '@/cms/blank';\n" +
      "export * from '@/server/media-service';\n" +
      "export * from '@/server/actions/unit';\n" +
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
    '@/server/auth-core': posix(path.join(scratch, 'stub-auth-core.mjs')),
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
  CMS_ADMIN_USER_IDS: 'harness-report',
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
const sorted = (list) => [...list].sort().join();
const writeAt = async (file, text) => {
  await mkdir(path.dirname(file), { recursive: true });
  await writeFile(file, text, 'utf8');
};

const courseId = 'vi_en';
const mediaRoot = path.join(repoRoot, 'content', courseId, 'media');
const realClip = new Uint8Array(
  await readFile(path.join(realRepo, 'content/vi_en/media/audio/a.u1.s1.n.aac')),
);
const realImage = new Uint8Array(
  await readFile(path.join(realRepo, 'content/vi_en/media/images/i.u1.friend.webp')),
);

check(
  'khóa chưa có bản nháp trong CMS thì không có báo cáo',
  (await cms.courseMediaReport('khong_ton_tai')) === null,
);

const row = (id, en, vi, img) => ({
  level: 1,
  en,
  enAlts: [],
  vi,
  viAlts: [],
  img,
  forms: [],
  id,
});
const draftFor = (theme, sentences, dialogues, vocab) => {
  const draft = cms.blankUnit(theme, 'A1');
  draft.title = `Bài ${theme}`;
  draft.levels = ['L1', 'L2', '', '', ''];
  draft.guide = `Hướng dẫn ${theme}`;
  draft.vocab = vocab;
  draft.sentences = sentences.map((en) => ({ en, enAlts: [], vi: 'Một.', viAlts: [] }));
  draft.dialogues = dialogues.map((line) => ({ line, reply: `${line} b`, replyAlts: [], vi: 'Chào.' }));
  return draft;
};

const drafts = {
  '01-alpha': draftFor('alpha', ['Alpha one.', 'Alpha two.'], ['alpha talk'], [
    row('w_alpha', 'alpha', 'an-pha', true),
    row('w_shared', 'shared', 'chung', false),
  ]),
  '02-beta': draftFor('beta', ['Beta one.'], ['beta talk'], [
    row('w_beta', 'beta', 'bê-ta', true),
  ]),
  '03-gamma': draftFor('gamma', ['Gamma one.'], [], [
    row('w_gamma', 'gamma', 'gam-ma', true),
    row('w_shared', 'shared', 'chung', false),
  ]),
};

await store.saveCourse({
  courseId,
  draft: {
    course: {
      courseId,
      title: 'Khóa thử báo cáo media',
      sourceLocale: 'vi',
      targetLocale: 'en',
      status: 'DRAFT',
    },
    sections: [{ sectionId: 's1', title: 'Phần một', units: ['alpha', 'beta', 'gamma'] }],
    version: 'v2',
  },
  actorId: 'harness-report',
  expectedRevision: 0,
});
const orders = { '01-alpha': 0, '02-beta': 1, '03-gamma': 2 };
for (const [unitId, draft] of Object.entries(drafts))
  await store.saveUnit({
    courseId,
    unitId,
    order: orders[unitId],
    draft,
    actorId: 'harness-report',
    expectedRevision: 0,
  });

// The catalog is what `generate-audio.mjs` walks. alpha's keys are in it; beta and gamma are newer, so the
// honest report must say "build first" instead of handing the tool keys it would silently ignore.
const catalog = {
  courseId,
  versionId: 'v2',
  locale: 'en-US',
  speeds: { n: 1, s: 0.75 },
  items: [
    { key: 'a.u1.s1', kind: 'sentence', text: 'Alpha one.' },
    { key: 'a.u1.s2', kind: 'sentence', text: 'Alpha two.' },
    { key: 'a.u1.d1', kind: 'dialogueLine', text: 'alpha talk' },
    { key: 'a.w.w_shared', kind: 'word', text: 'shared' },
  ],
};
await writeAt(
  path.join(repoRoot, 'content', courseId, 'dist', 'v2', 'audio-catalog.json'),
  JSON.stringify(catalog),
);

// ---------- the report and the unit panel must be one and the same derivation ----------
const report = await cms.courseMediaReport(courseId);
check('báo cáo liệt kê đủ 3 unit', report.units.length === 3, JSON.stringify(report.units));
check(
  'unit đầu báo cáo là 01-alpha mang mã u1',
  report.units[0].unitId === '01-alpha' && report.units[0].genUnitId === 'u1',
  JSON.stringify(report.units.map((u) => [u.unitId, u.genUnitId])),
);
check('số key catalog bản dựng được báo đúng', report.catalogSize === 4, `${report.catalogSize}`);
check('chưa có manifest thì manifestSize = 0', report.manifestSize === 0, `${report.manifestSize}`);

const perUnit = new Map();
for (const [unitId, draft] of Object.entries(drafts))
  perUnit.set(unitId, (await cms.unitAssets(courseId, 'v2', orders[unitId], draft)).assets);
check(
  'tổng tài nguyên báo cáo = cộng từng panel unit',
  report.totals.total === [...perUnit.values()].reduce((a, list) => a + list.length, 0) &&
    report.totals.total === 15,
  `${report.totals.total}`,
);
check(
  'số mục của từng unit trong báo cáo khớp panel',
  report.units.every((u) => u.total === perUnit.get(u.unitId).length),
  JSON.stringify(report.units.map((u) => [u.unitId, u.total])),
);
check(
  'tập key đi nợ = tập key panel suy ra (từ chung hai unit chỉ tính một việc)',
  sorted(report.gaps.map((g) => g.fileId)) ===
    sorted(new Set([...perUnit.values()].flat().map((a) => a.fileId))) &&
    report.gaps.length === 15 &&
    report.totals.missing === 15,
  `${report.gaps.length} gap / ${report.totals.missing} missing`,
);
check(
  'chưa có file nào: toàn bộ là missing, ready = 0',
  report.totals.ready === 0 && report.totals.missing === report.totals.total,
  JSON.stringify(report.totals),
);
check(
  'phân loại audio/ảnh đúng theo panel',
  report.units.every(
    (u) =>
      u.audio === perUnit.get(u.unitId).filter((a) => a.kind === 'audio').length &&
      u.image === perUnit.get(u.unitId).filter((a) => a.kind === 'image').length &&
      u.audio + u.image === u.total,
  ),
  JSON.stringify(report.units),
);
check(
  'mọi asset báo cáo đều có flag drift để panel và trang khóa dùng chung',
  [...perUnit.values()].flat().every((a) => typeof a.drift === 'boolean'),
);

// ---------- work list shaped for the generator ----------
check(
  'danh sách ảnh = đúng 3 key ô có ảnh trong bảng từ',
  sorted(cms.imageTask(report.gaps)) === sorted(['i.u1.w_alpha', 'i.u2.w_beta', 'i.u3.w_gamma']),
  cms.imageTask(report.gaps).join(),
);
let task = cms.audioTask(report.gaps);
check(
  'key đã có trong catalog → đưa thẳng vào --only',
  sorted(task.keys) === sorted(['a.u1.s1', 'a.u1.s2', 'a.u1.d1']),
  task.keys.join(),
);
check(
  'key bản nháp mới thêm, catalog chưa có → bảo phải dựng trước',
  sorted(task.needsBuild) === sorted(['a.u2.s1', 'a.u2.d1', 'a.u3.s1']),
  task.needsBuild.join(),
);
check('chưa sửa lời thoại nào nên chưa có lệch catalog', task.drift.length === 0, task.drift.join());
check(
  'một hàng thoại hiện một lần dù cần cả 1× lẫn 0.75×',
  task.keys.filter((k) => k === 'a.u1.d1').length === 1,
  task.keys.join(),
);
check(
  'gap không tự bịa sha256/độ dài clip — manifest vẫn là việc của generate-audio',
  report.gaps.every((g) => !('sha256' in g) && !('durationMs' in g)),
  JSON.stringify(Object.keys(report.gaps[0] ?? {})),
);
check(
  'từ chung hai unit: một việc phải làm, nhưng mỗi unit vẫn tính nợ của mình',
  report.gaps.length === new Set(report.gaps.map((g) => g.fileId)).size &&
    report.units.every((u) => u.missing === perUnit.get(u.unitId).filter((a) => !a.present).length),
  JSON.stringify(report.units.map((u) => [u.unitId, u.missing])),
);

/**
 * Word clips only exist once a build has named them, so this phase has none: without
 * `dist/v2/bundles/` the honest report lists sentences, dialogue and pictures and nothing more.
 */
check(
  'chưa có bundle thì không bịa clip từ vựng',
  report.gaps.every((g) => !g.fileId.startsWith('a.w.')),
  JSON.stringify(report.gaps.filter((g) => g.fileId.startsWith('a.w.')).map((g) => g.fileId)),
);
check(
  'chưa có bản dựng thì chưa so được với gì: không bài nào có dạng bài, không ảnh nào bị cho là thừa',
  report.units.every((u) => Object.keys(u.exerciseTypes).length === 0) &&
    report.totals.unused === 0 &&
    report.totals.picturesWithoutDrill === 0 &&
    [...perUnit.values()].flat().every((a) => a.unused === false && a.drilledWithPicture === false),
  JSON.stringify(report.units.map((u) => [u.genUnitId, u.exerciseTypes, u.unused])),
);

// ---------- fill part of the debt exactly the way the generators do ----------
const spec = (fileId, kind, text, inCatalog) => ({
  fileId,
  kind,
  ext: kind === 'audio' ? 'aac' : 'webp',
  group: kind === 'audio' ? 'sentence' : 'word',
  label: fileId,
  text,
  draft: text,
  inCatalog,
  speed: fileId.endsWith('.s') ? 0.75 : 1,
});
const entry = (text, speed) => ({
  text,
  voice: 'en-US-AvaNeural',
  speed,
  provider: 'azure-tts',
  sha256: createHash('sha256').update(realClip).digest('hex'),
  bytes: realClip.length,
  durationMs: 900,
});
const writeClip = (fileId) =>
  cms.writeMediaFile(courseId, spec(fileId, 'audio', '', true), realClip, false);
const manifestFile = path.join(mediaRoot, 'audio-manifest.json');
const writeManifest = (files) =>
  writeAt(manifestFile, JSON.stringify({ courseId, format: 'audio/aac', files }));

await writeClip('a.u1.s1.n');
await writeClip('a.u1.s1.s');
await writeClip('a.u1.d1.n');
await writeManifest({
  'a.u1.s1.n': entry('Alpha one.', 1),
  'a.u1.s1.s': entry('Alpha one. Old take.', 0.75),
});

const filled = await cms.courseMediaReport(courseId);
const gapOf = (list, fileId) => list.gaps.find((g) => g.fileId === fileId);
check(
  'clip có file + manifest khớp lời → hết nợ',
  gapOf(filled, 'a.u1.s1.n') === undefined,
  JSON.stringify(gapOf(filled, 'a.u1.s1.n')),
);
check(
  'clip có file nhưng manifest còn lời cũ → unmanifested',
  gapOf(filled, 'a.u1.s1.s')?.state === 'unmanifested',
  JSON.stringify(gapOf(filled, 'a.u1.s1.s')),
);
check(
  'clip có file mà manifest chưa có entry → unmanifested',
  gapOf(filled, 'a.u1.d1.n')?.state === 'unmanifested',
  JSON.stringify(gapOf(filled, 'a.u1.d1.n')),
);
check(
  'chưa sửa lời thì không bị gọi là lệch catalog',
  filled.totals.drift === 0 && filled.gaps.every((g) => g.state !== 'drift'),
  `${filled.totals.drift}`,
);
check('manifest được đếm đúng số entry thật', filled.manifestSize === 2, `${filled.manifestSize}`);
check(
  'còn một speed chưa xong thì key vẫn nằm trong --only',
  cms.audioTask(filled.gaps).keys.includes('a.u1.s1'),
  cms.audioTask(filled.gaps).keys.join(),
);
check(
  'ready tăng đúng số mục đã hết thiếu',
  filled.totals.ready === 1 && filled.totals.missing === filled.totals.total - 3,
  JSON.stringify(filled.totals),
);

await writeClip('a.u1.s2.n');
await writeClip('a.u1.s2.s');
await cms.writeMediaFile(
  courseId,
  spec('i.u1.w_alpha', 'image', 'an-pha', false),
  realImage,
  false,
);
await writeManifest({
  ...(JSON.parse(await readFile(manifestFile, 'utf8')).files ?? {}),
  'a.u1.s2.n': entry('Alpha two.', 1),
  'a.u1.s2.s': entry('Alpha two.', 0.75),
});
const bothDone = await cms.courseMediaReport(courseId);
check(
  'key đã xong cả hai speed bị rút khỏi --only',
  !cms.audioTask(bothDone.gaps).keys.includes('a.u1.s2') &&
    gapOf(bothDone, 'a.u1.d1.s')?.state === 'missing',
  cms.audioTask(bothDone.gaps).keys.join(),
);
check(
  'ảnh nạp đúng key thì không còn là nợ',
  gapOf(bothDone, 'i.u1.w_alpha') === undefined,
  JSON.stringify(gapOf(bothDone, 'i.u1.w_alpha')),
);
check(
  'ready đếm đúng 4 mục đã hết nợ',
  bothDone.totals.ready === 4,
  `${bothDone.totals.ready}`,
);

// ---------- a reorder carries the debt with the unit number, and deletes nothing ----------
const listing = async (dir) => sorted(await readdir(path.join(mediaRoot, dir)));
const filesBefore = { audio: await listing('audio'), images: await listing('images') };
const moved = await cms.moveUnitDraft(courseId, '03-gamma', 0);
check('đổi thứ tự qua action thật: ok', moved.ok === true, moved.message ?? '');
const reordered = await cms.courseMediaReport(courseId);
check(
  'gamma thành u1, alpha lùi u2, beta lùi u3 ngay trong báo cáo',
  sorted(reordered.units.map((u) => u.genUnitId)) === 'u1,u2,u3' &&
    reordered.units.map((u) => u.unitId).join() === '03-gamma,01-alpha,02-beta',
  JSON.stringify(reordered.units.map((u) => [u.unitId, u.genUnitId])),
);
check(
  'alpha mang nợ sang số mới: clip u2 chưa có file',
  reordered.gaps.some((g) => g.unitId === '01-alpha' && g.fileId === 'a.u2.s1.n' && g.state === 'missing'),
  JSON.stringify(reordered.gaps.filter((g) => g.unitId === '01-alpha').map((g) => g.fileId)),
);
check(
  'file clip cũ giờ nằm dưới số của gamma nhưng catalog còn ghi lời alpha → drift, không phải đủ',
  gapOf(reordered, 'a.u1.s1.n')?.state === 'drift' &&
    gapOf(reordered, 'a.u1.s1.s')?.state === 'drift',
  JSON.stringify(reordered.gaps.filter((g) => g.fileId.startsWith('a.u1.s1')).map((g) => [g.fileId, g.state])),
);
check(
  'đúng một key lệch catalog được báo, và nó không nằm trong --only',
  sorted(cms.audioTask(reordered.gaps).drift) === 'a.u1.s1' &&
    !cms.audioTask(reordered.gaps).keys.includes('a.u1.s1'),
  JSON.stringify(cms.audioTask(reordered.gaps)),
);
check(
  'báo cáo cho biết phải dựng lại catalog trước khi thu âm cho 5 key lùi số',
  sorted(cms.audioTask(reordered.gaps).needsBuild) ===
    sorted(['a.u2.s1', 'a.u2.s2', 'a.u2.d1', 'a.u3.s1', 'a.u3.d1']),
  cms.audioTask(reordered.gaps).needsBuild.join(),
);
check(
  'ảnh cũng đổi chủ: alpha cần i.u2.w_alpha còn i.u1.w_alpha không unit nào hỏi nữa',
  gapOf(reordered, 'i.u2.w_alpha')?.state === 'missing' &&
    gapOf(reordered, 'i.u1.w_alpha') === undefined &&
    filesBefore.images.includes('i.u1.w_alpha.webp'),
  JSON.stringify(reordered.gaps.filter((g) => g.kind === 'image').map((g) => [g.fileId, g.unitId])),
);
check(
  'đổi thứ tự không xóa file media nào, kể cả file không còn unit nào hỏi',
  (await listing('audio')) === filesBefore.audio &&
    (await listing('images')) === filesBefore.images,
);
check(
  'tổng tài nguyên không đổi sau đổi thứ tự, phân loại vẫn nhất quán',
  reordered.totals.total === report.totals.total &&
    reordered.units.every((u) => u.audio + u.image === u.total) &&
    reordered.units.every((u) => u.missing + u.unmanifested + u.drift + u.ready === u.total),
  JSON.stringify(reordered.totals),
);
check(
  'unit.reorder vào nhật ký vận hành',
  (await store.listAudit(50)).some((e) => e.operation === 'unit.reorder'),
);

// ---------- word clips: only the build knows them, so the report has to read the build ----------
const bundleDir = path.join(repoRoot, 'content', courseId, 'dist', 'v2', 'bundles');
const bundle = (unitId, assets, exercises = [], lessonId = undefined) => ({
  unitId,
  ...(lessonId ? { lessonId } : {}),
  assets,
  exercises,
});
const wordAsset = (fileId, text, mime = 'audio/aac') => ({ fileId, mime, altText: text });
const pictureAsset = (fileId, text) => ({ fileId, mime: 'image/webp', altText: text });
const ex = (...types) => types.map((type) => ({ type }));
await writeAt(
  path.join(repoRoot, 'content', courseId, 'dist', 'v2', 'audio-catalog.json'),
  JSON.stringify({
    ...catalog,
    items: [
      ...catalog.items,
      { key: 'a.w.hello', kind: 'word', text: 'hello' },
      { key: 'a.w.gamma_take', kind: 'word', text: 'gamma take' },
      { key: 'a.w.shared', kind: 'word', text: 'shared' },
    ],
  }),
);
await writeAt(path.join(bundleDir, 'u1n1l1.json'), JSON.stringify(bundle('u1', [
  wordAsset('a.w.hello.n', 'hello'),
  wordAsset('a.w.w_shared.n', 'shared'),
  wordAsset('a.w.gamma_take.n', 'gamma take'),
  wordAsset('a.u1.s1.n', 'Alpha one.'),
  pictureAsset('i.u1.w_gamma', 'gam-ma'),
], [
  { type: 'listenChoice' },
  { type: 'listenChoice' },
  { type: 'imageChoice', vocabularyIds: ['u1.w_gamma'] },
])));
// The placement test borrows unit 1's number (`build-course.mjs:1035`) without being a unit lesson: its
// drills must not look like lessons unit 1 teaches, while the picture it does show must count as used.
await writeAt(path.join(bundleDir, 'u1placement.json'), JSON.stringify(bundle('u1', [
  pictureAsset('i.u2.w_alpha', 'an-pha'),
], ex('matchPairs', 'matchPairs', 'fillBlank'), 'placement')));
await writeAt(path.join(bundleDir, 'u2n1l1.json'), JSON.stringify(bundle('u2', [
  wordAsset('a.w.shared.n', 'shared'),
  wordAsset('a.u2.s99.n', 'A sentence the draft deleted.'),
], ex('textTranslation', 'wordBank'))));
await writeAt(path.join(bundleDir, 'u3n1l1.json'), JSON.stringify(bundle('u3', [
  wordAsset('a.w.hello.n', 'hello'),
], ex('wordBank'))));
await writeAt(path.join(bundleDir, 'broken.json'), JSON.stringify({ lessonId: 'u3n1l1' }));
const withBuild = await cms.courseMediaReport(courseId);
check(
  'clip từ vựng chỉ bản dựng biết nay hiện ra trong báo cáo, gắn đúng unit mang số đó',
  gapOf(withBuild, 'a.w.hello.n')?.state === 'missing' &&
    gapOf(withBuild, 'a.w.hello.n')?.unitId === '03-gamma' &&
    gapOf(withBuild, 'a.w.shared.n')?.unitId === '01-alpha',
  JSON.stringify(withBuild.gaps.filter((g) => g.fileId.startsWith('a.w.')
  ).map((g) => [g.fileId, g.unitId, g.state])),
);
check(
  'clip từ vựng tính theo unit: u1 và u3 cùng hỏi một file thì mỗi unit một dòng, khóa chỉ một việc',
  withBuild.totals.total === reordered.totals.total + 5 &&
    withBuild.gaps.length === reordered.gaps.length + 4 &&
    withBuild.units.filter((u) => u.unitId === '03-gamma' || u.unitId === '02-beta').every((u) =>
      u.total > 0,
    ),
  `${reordered.totals.total} → ${withBuild.totals.total}, gaps ${reordered.gaps.length} → ${withBuild.gaps.length}`,
);
check(
  'clip câu của bản dựng cũ mà nháp không hỏi nữa không bị coi là nợ',
  withBuild.gaps.every((g) => g.fileId !== 'a.u2.s99.n'),
  JSON.stringify(withBuild.gaps.map((g) => g.fileId).filter((f) => f.includes('s99'))),
);
check(
  'bundle không đọc được bị gọi tên thay vì âm thầm bỏ qua',
  sorted(withBuild.unreadableBundles) === 'broken.json',
  JSON.stringify(withBuild.unreadableBundles),
);
check(
  'clip từ vựng đã có trong catalog thì vào thẳng --only',
  ['a.w.hello', 'a.w.gamma_take', 'a.w.shared'].every((k) =>
    cms.audioTask(withBuild.gaps).keys.includes(k),
  ) && cms.audioTask(withBuild.gaps).needsBuild.every((k) => !k.startsWith('a.w.')),
  JSON.stringify(cms.audioTask(withBuild.gaps)),
);
const gammaAssets = (await cms.unitAssets(courseId, 'v2', 0, drafts['03-gamma'])).assets;
check(
  'panel unit cũng thấy clip bản dựng và đánh dấu fromBuild để giải thích được',
  gammaAssets.some((a) => a.fileId === 'a.w.hello.n' && a.fromBuild === true) &&
    gammaAssets.some((a) => a.fileId === 'a.u1.s1.n' && a.fromBuild === false),
  JSON.stringify(gammaAssets.filter((a) => a.group === 'word').map((a) => [a.fileId, a.fromBuild])),
);
check(
  'upload nhận đúng key mà chỉ bản dựng nêu ra',
  (await cms.courseAssets(courseId)).has('a.w.hello.n'),
);
await writeClip('a.w.hello.n');
const clipUploaded = await cms.courseMediaReport(courseId);
check(
  'clip từ vựng có file nhưng manifest chưa có entry → unmanifested, vẫn chưa hết nợ',
  gapOf(clipUploaded, 'a.w.hello.n')?.state === 'unmanifested' &&
    cms.audioTask(clipUploaded.gaps).keys.includes('a.w.hello'),
  JSON.stringify(gapOf(clipUploaded, 'a.w.hello.n')),
);
await writeManifest({
  ...(JSON.parse(await readFile(manifestFile, 'utf8')).files ?? {}),
  'a.w.hello.n': entry('hello', 1),
});
const clipDone = await cms.courseMediaReport(courseId);
check(
  'manifest khớp lời thì clip từ vựng không còn là nợ',
  gapOf(clipDone, 'a.w.hello.n') === undefined &&
    !cms.audioTask(clipDone.gaps).keys.includes('a.w.hello'),
  JSON.stringify(cms.audioTask(clipDone.gaps).keys),
);

const tallyOf = (tally) =>
  Object.entries(tally)
    .sort((a, b) => a[0].localeCompare(b[0]))
    .map(([type, count]) => `${type}=${count}`)
    .join(',');
check(
  'báo cáo nêu đúng dạng bài bản dựng đã sinh cho từng unit',
  tallyOf(withBuild.units.find((u) => u.genUnitId === 'u1').exerciseTypes) ===
    'imageChoice=1,listenChoice=2' &&
    tallyOf(withBuild.units.find((u) => u.genUnitId === 'u2').exerciseTypes) ===
      'textTranslation=1,wordBank=1' &&
    tallyOf(withBuild.units.find((u) => u.genUnitId === 'u3').exerciseTypes) === 'wordBank=1',
  JSON.stringify(withBuild.units.map((u) => [u.genUnitId, u.exerciseTypes])),
);
check(
  'bài kiểm tra xếp lớp mang số u1 không được tính vào số bài unit 1 dạy: khóa có 6 bài, không phải 9',
  withBuild.units.every(
    (u) => !('matchPairs' in u.exerciseTypes) && !('fillBlank' in u.exerciseTypes),
  ) &&
    tallyOf(withBuild.totals.exerciseTypes) ===
      'imageChoice=1,listenChoice=2,textTranslation=1,wordBank=2' &&
    Object.values(withBuild.totals.exerciseTypes).reduce((a, n) => a + n, 0) ===
      withBuild.units.reduce(
        (a, u) => a + Object.values(u.exerciseTypes).reduce((x, n) => x + n, 0),
        0,
      ),
  JSON.stringify([withBuild.totals.exerciseTypes, withBuild.unreadableBundles]),
);
const gammaPanel = await cms.unitAssets(courseId, 'v2', 0, drafts['03-gamma']);
check(
  'panel unit cũng nhận được dạng bài bản dựng, nên người sửa nội dung thấy thứ app thật sự đưa ra',
  tallyOf(gammaPanel.exerciseTypes) === 'imageChoice=1,listenChoice=2' &&
    gammaPanel.hasBuild === true,
  JSON.stringify(gammaPanel.exerciseTypes),
);
check(
  'ba trạng thái của một tấm ảnh phân biệt được rõ: có bài đố tới, có bài chở nhưng chưa câu hỏi nào đố, và không bài nào chở',
  gammaPanel.assets.some(
    (a) => a.fileId === 'i.u1.w_gamma' && a.drilledWithPicture === true && a.unused === false,
  ) &&
    withBuild.units.find((u) => u.genUnitId === 'u1').picturesWithoutDrill === 0 &&
    withBuild.units.find((u) => u.genUnitId === 'u2').picturesWithoutDrill === 1 &&
    withBuild.units.find((u) => u.genUnitId === 'u3').picturesWithoutDrill === 0 &&
    sorted(withBuild.picturesWithoutDrill) === 'i.u2.w_alpha' &&
    withBuild.totals.picturesWithoutDrill === 1,
  JSON.stringify(
    withBuild.units.map((u) => [u.genUnitId, u.image, u.unused, u.picturesWithoutDrill]),
  ),
);
check(
  'ảnh bản dựng chở rồi không bị báo thừa, kể cả ảnh chỉ bài xếp lớp đưa lên; chỉ ảnh không lesson nào chở bị gọi tên',
  gammaPanel.assets.some((a) => a.fileId === 'i.u1.w_gamma' && a.unused === false) &&
    (await cms.unitAssets(courseId, 'v2', 1, drafts['01-alpha'])).assets.some(
      (a) => a.fileId === 'i.u2.w_alpha' && a.unused === false,
    ) &&
    sorted(withBuild.unusedImages) === 'i.u3.w_beta' &&
    withBuild.units.filter((u) => u.genUnitId !== 'u3').every((u) => u.unused === 0),
  JSON.stringify(withBuild.units.map((u) => [u.genUnitId, u.unused])),
);
await cms.writeMediaFile(courseId, spec('i.u3.w_beta', 'image', 'bê-ta', false), realImage, false);
const pictureOnDisk = await cms.courseMediaReport(courseId);
check(
  'ảnh đã có file và không còn là nợ, nhưng bản dựng không chở → báo "chưa bài nào dùng" thay vì im lặng',
  gapOf(pictureOnDisk, 'i.u3.w_beta') === undefined &&
    pictureOnDisk.units.find((u) => u.genUnitId === 'u3').unused === 1 &&
    pictureOnDisk.totals.unused === 1 &&
    sorted(pictureOnDisk.unusedImages) === 'i.u3.w_beta',
  JSON.stringify([pictureOnDisk.totals.unused, pictureOnDisk.unusedImages]),
);
check(
  'ảnh thừa không biến thành việc vẽ: nó không có trong danh sách key cần sinh',
  cms.imageTask(pictureOnDisk.gaps).every((k) => k !== 'i.u3.w_beta') &&
    (await cms.unitAssets(courseId, 'v2', 2, drafts['02-beta'])).assets.some(
      (a) => a.fileId === 'i.u3.w_beta' && a.unused === true,
    ),
  JSON.stringify([cms.imageTask(pictureOnDisk.gaps), pictureOnDisk.totals.ready]),
);

if (failures.length) {
  console.error(`FAIL — ${failures.length}/${checks.length} checks:\n`);
  for (const f of failures.slice(0, 25)) console.error(`• ${f}\n`);
  await rm(scratch, { recursive: true, force: true });
  process.exit(1);
}
await rm(scratch, { recursive: true, force: true });
console.log(
  `OK — ${checks.length} checks: báo cáo media toàn khóa suy ra từ cùng một lượt đọc catalog/kho media/manifest/bundle như panel unit, clip từ vựng và dạng bài app thật sự nhận lấy từ bản dựng vì nháp không tự nêu được, bài xếp lớp không bị tính vào unit nào, ảnh không lesson nào chở bị gọi tên thay vì báo đủ, danh sách việc đưa thẳng vào generate-audio.mjs --only, catalog lệch bản nháp bị gọi tên thay vì báo đủ, và đổi thứ tự unit chỉ chuyển nợ chứ không xóa file.`,
);
