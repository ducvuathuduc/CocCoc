// Export proof: render each CMS draft exactly the way `exportCourseToRepo` does, write the result to a
// scratch tree, then let the repo parser read both the authored file and the exported one.
// Byte output differs (formatting), but the generator must see the same unit. Nothing in the repo is touched.
import { build } from 'esbuild';
import { mkdir, mkdtemp, readFile, readdir, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const appRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const repoRoot = path.resolve(appRoot, '..', '..');
const courseId = process.argv[2] ?? 'vi_en';
const storeFile = path.join(appRoot, '.cms-data', 'cms-data.json');

const bundled = await build({
  stdin: {
    contents: "export * from '@/cms/render'; export * from '@/cms/tables';",
    resolveDir: appRoot,
    loader: 'ts',
  },
  bundle: true,
  format: 'esm',
  platform: 'node',
  write: false,
  alias: { '@': path.join(appRoot, 'src') },
});

const scratch = await mkdtemp(path.join(repoRoot, 'node_modules', '.export-diff-'));
const bundleFile = path.join(scratch, 'cms.mjs');
await writeFile(bundleFile, bundled.outputFiles[0].text, 'utf8');
const cms = await import(pathToFileURL(bundleFile).href);
const repo = await import(pathToFileURL(path.join(repoRoot, 'tools', 'content', 'course-lib.mjs')).href);

const db = JSON.parse(await readFile(storeFile, 'utf8'));
const course = db.courses.find((c) => c.courseId === courseId);
if (!course) throw new Error(`CMS chưa có khóa ${courseId}. Chạy "Nhập từ repo" trước.`);
const units = db.units.filter((u) => u.courseId === courseId).sort((a, b) => a.order - b.order);

const sourceDir = path.join(repoRoot, 'content', courseId, 'source', course.draft.version);
const authoredDir = path.join(sourceDir, 'units');
const exportedDir = path.join(scratch, 'units');
await mkdir(exportedDir, { recursive: true });

// Same rule as the export action: keep the hand-written comment block that opens each file.
function leadingComments(text) {
  const out = [];
  for (const line of text.split('\n')) {
    if (line.startsWith('//')) out.push(line);
    else if (out.length === 0) return undefined;
    else break;
  }
  return out.length ? out : undefined;
}

const checks = [];
const failures = [];

async function check(label, authored, exported) {
  checks.push(label);
  const a = JSON.stringify(authored);
  const b = JSON.stringify(exported);
  if (a === b) return;
  let i = 0;
  while (i < a.length && i < b.length && a[i] === b[i]) i += 1;
  const around = (s) => JSON.stringify(s.slice(Math.max(0, i - 30), i + 60));
  failures.push(`${label} (khác từ ký tự ${i} của JSON)\n  authored: ${around(a)}\n  exported: ${around(b)}`);
}

for (const [index, record] of units.entries()) {
  const draft = record.draft;
  const stem = cms.unitFileStem(index, draft);
  const authoredFile = path.join(authoredDir, `${stem}.mjs`);
  let original;
  try {
    original = await readFile(authoredFile, 'utf8');
  } catch {
    failures.push(`${stem}.mjs: export sẽ tạo mới file này (repo chưa có).`);
    continue;
  }
  const rendered = cms.renderUnitFile(index, draft, leadingComments(original));
  const exportedFile = path.join(exportedDir, rendered.fileName);
  await writeFile(exportedFile, rendered.source, 'utf8');

  const unitId = `${String(index + 1).padStart(2, '0')}-${draft.theme}`;
  const { default: a } = await import(pathToFileURL(authoredFile).href);
  const { default: e } = await import(pathToFileURL(exportedFile).href);

  await check(`${stem} header kept`, leadingComments(original), leadingComments(rendered.source));
  await check(`${stem} meta`, { theme: a.theme, cefr: a.cefr, title: a.title, levels: a.levels, guide: a.guide, storyTitle: a.story.title, passage: a.story.passage },
    { theme: e.theme, cefr: e.cefr, title: e.title, levels: e.levels, guide: e.guide, storyTitle: e.story.title, passage: e.story.passage });
  await check(`${stem} vocab`, repo.parseVocab(unitId, a.vocab), repo.parseVocab(unitId, e.vocab));
  await check(`${stem} sentences`, repo.parseSentences(unitId, a.sentences), repo.parseSentences(unitId, e.sentences));
  await check(`${stem} dialogues`, repo.parseDialogues(unitId, a.dialogues), repo.parseDialogues(unitId, e.dialogues));
  await check(`${stem} questions`, repo.parseStoryQuestions(unitId, a.story.questions), repo.parseStoryQuestions(unitId, e.story.questions));
}

const authoredCourseFile = path.join(sourceDir, 'course.mjs');
const authoredCourse = await readFile(authoredCourseFile, 'utf8');
const courseSource = cms.renderCourseFile(
  course.draft,
  units.map((u) => u.draft),
  leadingComments(authoredCourse) ?? ['// header missing in repo'],
);
const courseExportFile = path.join(scratch, 'course.mjs');
await writeFile(courseExportFile, courseSource, 'utf8');

const a = await import(pathToFileURL(authoredCourseFile).href);
const e = await import(pathToFileURL(courseExportFile).href);
await check('course.mjs header kept', leadingComments(authoredCourse), leadingComments(courseSource));
await check('course.mjs course', a.course, e.course);
await check('course.mjs sections', a.sections, e.sections);
await check('course.mjs unit count', a.unitModules.length, e.unitModules.length);

const stems = (await readdir(exportedDir)).filter((f) => f.endsWith('.mjs') && f !== 'cms.mjs').sort();
await check('unit files exported', units.length, stems.length);

await rm(scratch, { recursive: true, force: true });

if (failures.length) {
  console.error(`FAIL — ${failures.length}/${checks.length} checks khác nhau:\n`);
  for (const f of failures.slice(0, 10)) console.error(f, '\n');
  process.exit(1);
}
console.log(
  `OK — ${checks.length} checks: xuất ${units.length} unit + course.mjs từ bản nháp CMS cho ra đúng nội dung mà bộ dựng của repo đang đọc.`,
);
