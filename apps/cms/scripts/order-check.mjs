// Reorder proof. Drives the real `moveUnitDraft` server action and the real `exportCourseToRepo`
// against the file store in a scratch directory, then replays the repo rules that decide what the app
// sees: build-course.mjs numbers every unit by its position in course.mjs (`u{index+1}`), every media
// key inherits that number, and sections map units by theme. Nothing under the real content/ or
// .cms-data/ is touched, and no project or network is needed.
import { build } from 'esbuild';
import { mkdtemp, readFile, readdir, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { HARNESS_ADMIN_SECRET, authCoreStub } from './harness-auth.mjs';

const appRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
// A crashed run leaves its scratch tree behind; node_modules is not the archive for it.
for (const entry of await readdir(path.join(appRoot, 'node_modules')))
  if (entry.startsWith('.order-'))
    await rm(path.join(appRoot, 'node_modules', entry), { recursive: true, force: true });
const scratch = await mkdtemp(path.join(appRoot, 'node_modules', '.order-'));
const dataDir = path.join(scratch, 'data');
const repoRoot = path.join(scratch, 'repo');
const posix = (p) => p.replace(/\\/g, '/');

// next/headers and next/navigation are the only reasons a server action cannot run in a plain node
// process; the harness answers with a fake Appwrite session so the real assertAdmin() path is used.
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
      "export * from '@/cms/order';\n" +
      "export * from '@/cms/media';\n" +
      "export * from '@/cms/blank';\n" +
      "export * from '@/cms/render';\n" +
      "export * from '@/cms/structure';\n" +
      "export * from '@/server/actions/unit';\n" +
      "export * from '@/server/actions/build';\n" +
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
  CMS_ADMIN_USER_IDS: 'harness-order',
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

const courseId = 'vi_en';
const pad = (order) => `${String(order + 1).padStart(2, '0')}`;
const code = (order) => `u${order + 1}`;

// ---------- pure invariants: what a move may and may not do ----------
const rows = (n) => Array.from({ length: n }, (_, i) => ({ unitId: `r${i}`, order: i }));
const seeded = rows(4);

check(
  'moveWithin không sửa mảng gốc',
  JSON.stringify(cms.moveWithin(seeded, 3, 0)) !== JSON.stringify(seeded) &&
    JSON.stringify(seeded) === JSON.stringify(rows(4)),
);
check(
  'moveWithin(from===to) trả bản sao giống hệt',
  JSON.stringify(cms.moveWithin(seeded, 2, 2)) === JSON.stringify(seeded),
);
for (const [label, args] of [
  ['from -1', [-1, 1]],
  ['to -1', [1, -1]],
  ['from = n', [4, 0]],
  ['to = n', [0, 4]],
]) {
  let threw = false;
  try {
    cms.moveWithin(seeded, ...args);
  } catch (error) {
    threw = error instanceof RangeError;
  }
  check(`moveWithin(${label}) báo RangeError`, threw);
}

let pairs = 0;
const bad = [];
for (let from = 0; from < 4; from += 1) {
  for (let to = 0; to < 4; to += 1) {
    pairs += 1;
    const before = rows(4);
    const moved = cms.moveWithin(before, from, to);
    const changes = cms.orderChanges(before, from, to);
    const after = before.map((row) => {
      const change = changes.find((c) => c.unit.unitId === row.unitId);
      return { ...row, order: change ? change.order : row.order };
    });
    const sortedByNewOrder = [...after].sort((a, b) => a.order - b.order).map((u) => u.unitId);
    const untouched = before.filter((_, i) => i !== from).map((u) => u.unitId);
    const keepOrder = moved.filter((u) => u.unitId !== `r${from}`).map((u) => u.unitId);
    const label = `${from}→${to}`;
    if (JSON.stringify(sortedByNewOrder) !== JSON.stringify(moved.map((u) => u.unitId)))
      bad.push(`${label}: các dòng ghi lại không dựng lại đúng thứ tự mới`);
    if (JSON.stringify(keepOrder) !== JSON.stringify(untouched))
      bad.push(`${label}: đơn vị đi ngang bị đảo thứ tự`);
    if ([...after].sort((a, b) => a.order - b.order).map((u) => u.order).join() !== '0,1,2,3')
      bad.push(`${label}: mã vị trí bị thủng/trùng`);
    const expected = from === to ? 0 : Math.abs(from - to) + 1;
    if (changes.length !== expected) bad.push(`${label}: ghi ${changes.length} dòng, phải là ${expected}`);
  }
}
check(
  `${pairs} cặp (from,to): chỉ ghi lại các unit đi ngang, vị trí luôn kín 0..n-1`,
  bad.length === 0,
  bad.slice(0, 4).join(' | '),
);

// ---------- the real action on a seeded course ----------
const draftFor = (theme) => {
  const draft = cms.blankUnit(theme, 'A1');
  draft.title = `Bài ${theme}`;
  draft.levels = ['L1', 'L2', '', '', ''];
  draft.guide = `Hướng dẫn ${theme}`;
  draft.vocab = [
    { level: 1, en: theme, enAlts: [], vi: `vi ${theme}`, viAlts: [], img: true, forms: [], id: `w_${theme}` },
  ];
  draft.sentences = [{ en: `${theme} one.`, enAlts: [], vi: 'Một.', viAlts: [] }];
  draft.dialogues = [{ line: `${theme} a`, reply: `${theme} b`, replyAlts: [], vi: 'Chào.' }];
  return draft;
};

const themes = ['alpha', 'beta', 'gamma', 'delta', 'echo'];
await store.saveCourse({
  courseId,
  draft: {
    course: {
      courseId,
      title: 'Khóa thử đổi thứ tự',
      sourceLocale: 'vi',
      targetLocale: 'en',
      status: 'DRAFT',
    },
    sections: [
      { sectionId: 's1', title: 'Phần một', units: ['alpha', 'beta', 'gamma'] },
      { sectionId: 's2', title: 'Phần hai', units: ['delta', 'echo'] },
    ],
    version: 'v2',
  },
  actorId: 'harness-order',
  expectedRevision: 0,
});
for (const [index, theme] of themes.entries()) {
  await store.saveUnit({
    courseId,
    unitId: `${pad(index)}-${theme}`,
    order: index,
    draft: draftFor(theme),
    actorId: 'harness-order',
    expectedRevision: 0,
  });
}

const sequence = async () => (await store.listUnits(courseId)).map((u) => u.draft.theme);
const idOf = async (theme) => (await store.listUnits(courseId)).find((u) => u.draft.theme === theme)?.unitId;
const ordersOf = async () => (await store.listUnits(courseId)).map((u) => u.order);
const revisions = async () =>
  Object.fromEntries((await store.listUnits(courseId)).map((u) => [u.draft.theme, u.revision]));
const auditRows = async () => (await store.listAudit(50)).filter((e) => e.operation === 'unit.reorder');

check('5 unit vào kho với thứ tự gốc', (await sequence()).join() === themes.join());

const first = await cms.moveUnitDraft(courseId, await idOf('echo'), 0);
check('echo → đầu danh sách: ok', first.ok === true, first.message ?? '');
check('echo → đầu danh sách: 5 unit phải ghi lại', first.moved === 5, `moved=${first.moved}`);
check(
  'echo → đầu danh sách: app sẽ thấy [echo, alpha, beta, gamma, delta]',
  (await sequence()).join() === ['echo', 'alpha', 'beta', 'gamma', 'delta'].join(),
  (await sequence()).join(),
);
check(
  'echo → đầu danh sách: vị trí vẫn kín 0..4',
  (await ordersOf()).join() === '0,1,2,3,4',
  (await ordersOf()).join(),
);
const firstAudit = (await auditRows()).at(-1);
check('unit.reorder được ghi vào audit', Boolean(firstAudit), '');
check(
  'audit ghi đủ 5 đơn vị trước/sau',
  JSON.parse(firstAudit?.beforeJson ?? '[]').length === 5 &&
    JSON.parse(firstAudit?.afterJson ?? '[]').length === 5,
  firstAudit?.afterJson ?? '',
);
check('audit mang tên người thao tác', firstAudit?.actorId === 'harness-order', firstAudit?.actorId ?? '');

const same = await cms.moveUnitDraft(courseId, await idOf('alpha'), 1);
check('vị trí cũ = không chuyển (moved 0)', same.ok === true && same.moved === 0, JSON.stringify(same));
check('không chuyển thì không ghi audit', (await auditRows()).length === 1, `${(await auditRows()).length} dòng`);

const tooFar = await cms.moveUnitDraft(courseId, await idOf('alpha'), 9);
check('vị trí ngoài danh sách bị từ chối', tooFar.ok === false && /ngoài/.test(tooFar.message ?? ''), tooFar.message ?? '');
check('bị từ chối thì không ghi gì', (await sequence()).join() === ['echo', 'alpha', 'beta', 'gamma', 'delta'].join());

const gone = await cms.moveUnitDraft(courseId, '99-nope', 0);
check('unit không tồn tại bị từ chối', gone.ok === false && /không còn/.test(gone.message ?? ''), gone.message ?? '');

const revBefore = await revisions();
const swap = await cms.moveUnitDraft(courseId, await idOf('beta'), 1);
check('beta tụt một chỗ: chỉ 2 unit ghi lại', swap.ok === true && swap.moved === 2, JSON.stringify(swap));
const revAfter = await revisions();
const touched = themes.filter((t) => revBefore[t] !== revAfter[t]).sort();
check(
  'đúng các unit đi ngang bị ghi lại, phần còn giữ nguyên revision',
  touched.join() === ['alpha', 'beta'].join(),
  `${touched.join()} / ${swap.moved}`,
);
check(
  'beta tụt một chỗ: [echo, beta, alpha, gamma, delta]',
  (await sequence()).join() === ['echo', 'beta', 'alpha', 'gamma', 'delta'].join(),
  (await sequence()).join(),
);

// A half-written move (the store answered mid-loop) leaves two rows on the same position; the next
// move must heal it because it recomputes from the rows, not from the indexes the browser showed.
const healed = await store.listUnits(courseId);
await store.saveUnit({
  courseId,
  unitId: healed[3].unitId,
  order: 0,
  draft: healed[3].draft,
  actorId: 'harness-order',
  expectedRevision: healed[3].revision,
});
check(
  'hỏng một nửa thì có trùng vị trí',
  (await ordersOf()).join() === '0,0,1,2,4',
  (await ordersOf()).join(),
);
const repair = await cms.moveUnitDraft(courseId, healed[4].unitId, 0);
check('lần chuyển kế tiếp tự sửa lại vị trí', repair.ok === true, repair.message ?? '');
check(
  'sau khi sửa: vị trí kín 0..4',
  (await ordersOf()).join() === '0,1,2,3,4',
  (await ordersOf()).join(),
);
const healedSequence = await sequence();

// ---------- export: what the generator and the app actually read ----------
const exported = await cms.exportCourseToRepo(courseId);
check('xuất khóa ra thư mục tạm: ok', exported.ok === true, exported.message ?? '');
check('xuất 5 unit + course.mjs', exported.files.length === 6, exported.files.join(' '));
check('xuất sạch thì không có file bỏ rơi', (exported.stale ?? []).length === 0, (exported.stale ?? []).join());

const unitsDir = path.join(repoRoot, 'content', courseId, 'source', 'v2', 'units');
const onDisk = await readdir(unitsDir);
check(
  'mọi file unit trong thư mục đều có dạng uNN-*.mjs (nên không tên nào lọt bộ lọc)',
  cms.staleUnitFiles(onDisk, []).length === onDisk.length,
  onDisk.filter((f) => !/^u\d{2}-.+\.mjs$/.test(f)).join(),
);

const rendered = await import(pathToFileURL(path.join(repoRoot, 'content', courseId, 'source', 'v2', 'course.mjs')).href);
const built = rendered.unitModules.map((m) => m.default.theme);
check('course.mjs import unit theo đúng thứ tự đã đổi', built.join() === healedSequence.join(), built.join());

// The alias and the folder name are what the generator reads, so both have to carry the new number.
const courseSource = await readFile(
  path.join(repoRoot, 'content', courseId, 'source', 'v2', 'course.mjs'),
  'utf8',
);
const importLines = courseSource
  .split('\n')
  .filter((line) => line.startsWith('import * as'))
  .map((line) => line.match(/as (u\d+) from '\.\/units\/([^']+)'/).slice(1, 3).join(' '));
const padded = (i) => `u${String(i + 1).padStart(2, '0')}`;
check(
  'mỗi dòng import mang số uNN = vị trí mới, cả trong tên file',
  importLines.join(' | ') ===
    healedSequence.map((theme, i) => `${padded(i)} ${padded(i)}-${theme}.mjs`).join(' | '),
  importLines.join(' | '),
);
check(
  'đổi thứ tự không làm mất section (sections khớp theo theme)',
  cms.structureIssues(
    (await store.getCourse(courseId)).draft.sections,
    healedSequence,
  ).length === 0,
  cms
    .structureIssues((await store.getCourse(courseId)).draft.sections, healedSequence)
    .join('; '),
);

// Every asset the draft names is named after the unit's position. Word clips are not named here at all
// — the app derives them from the text on an exercise tile, so only a build knows them (media-report-
// check.mjs proves the panels pick them up from dist/<version>/bundles/ and keep them stable).
const catalog = themes.map((theme) => ({ key: `a.w.w_${theme}`, kind: 'word', text: `nghe ${theme}` }));
const mediaByPosition = healedSequence.map((theme, i) => ({
  theme,
  keys: cms.unitMedia(code(i), draftFor(theme), catalog).map((m) => m.fileId),
}));
check(
  'audio câu + thoại của mỗi unit mang đúng mã uNN theo vị trí mới',
  mediaByPosition.every(
    ({ keys }, i) =>
      keys.includes(`a.${code(i)}.s1.n`) &&
      keys.includes(`a.${code(i)}.s1.s`) &&
      keys.includes(`a.${code(i)}.d1.n`),
  ),
  mediaByPosition.map((m) => m.keys[0]).join(),
);
check(
  'tên ảnh cũng theo vị trí: i.uNN.<wordId>',
  mediaByPosition.every(({ theme, keys }, i) => keys.includes(`i.${code(i)}.w_${theme}`)),
  mediaByPosition.map((m) => m.keys.join(',')).join(' | '),
);
const allCodes = themes.map((_, i) => code(i));
check(
  'mỗi tài nguyên chỉ mang mã uNN của đúng unit đang ở vị trí đó',
  mediaByPosition.every(({ keys }, i) =>
    keys.every(
      (k) =>
        k.includes(`.${code(i)}.`) &&
        allCodes.filter((c) => c !== code(i)).every((c) => !k.includes(`.${c}.`)),
    ),
  ),
  mediaByPosition.map((m) => m.keys.join(',')).join(' | '),
);
check(
  'nháp không tự đặt tên clip từ vựng, nên đổi chỗ cũng không thể làm sai tên chúng',
  mediaByPosition.every(({ keys }) => keys.every((k) => !k.startsWith('a.w.'))),
  mediaByPosition.map((m) => m.keys.filter((k) => k.startsWith('a.w.')).join(',')).join(' | '),
);

// Moving one more time must show the export's abandoned files, or the next import would resurrect them.
const mover = await cms.moveUnitDraft(courseId, await idOf(healedSequence[1]), 0);
const reExport = await cms.exportCourseToRepo(courseId);
const abandoned = reExport.stale ?? [];
const swapped = [healedSequence[0], healedSequence[1]];
check('chuyển 1 bước vẫn ok', mover.ok === true && reExport.ok === true, reExport.message ?? mover.message ?? '');
check('chuyển 1 bước: đúng 2 unit được ghi lại', mover.moved === 2, `moved=${mover.moved}`);
check(
  'xuất lại báo đúng 2 file bỏ rơi',
  abandoned.join() === [`u01-${swapped[0]}.mjs`, `u02-${swapped[1]}.mjs`].sort().join(),
  abandoned.join(),
);
const newCourseSource = await readFile(
  path.join(repoRoot, 'content', courseId, 'source', 'v2', 'course.mjs'),
  'utf8',
);
check(
  'course.mjs mới không tham chiếu file bỏ rơi',
  abandoned.every((f) => !newCourseSource.includes(f)),
  abandoned.join(),
);
check(
  'thư mục units vẫn giữ cả file bỏ rơi nên lần nhập sau sẽ thấy chúng',
  (await readdir(unitsDir)).length === onDisk.length + 2,
  `${(await readdir(unitsDir)).length} file, trước đó ${onDisk.length}`,
);

if (failures.length) {
  console.error(`FAIL — ${failures.length}/${checks.length} checks:\n`);
  for (const f of failures.slice(0, 25)) console.error(`• ${f}\n`);
  await rm(scratch, { recursive: true, force: true });
  process.exit(1);
}
await rm(scratch, { recursive: true, force: true });
console.log(
  `OK — ${checks.length} checks: moveUnitDraft giữ vị trí kín, chỉ ghi lại các unit đi ngang, và thứ tự mới cho ra đúng mã uNN mà build-course + key media dùng.`,
);
