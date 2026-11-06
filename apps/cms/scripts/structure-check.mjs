// Structure proof: render every CMS draft exactly the way exportCourseToRepo does, write the result to
// a scratch tree, then replay the two repo rules that decide whether the next build survives:
// build-course.mjs maps each unit through sections.find(s => s.units.includes(theme)).sectionId, and
// lint-course.mjs refuses a course with fewer than two sections. Nothing in the repo is touched.
import { build } from 'esbuild';
import { mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const appRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const repoRoot = path.resolve(appRoot, '..', '..');
const storeFile = path.join(appRoot, '.cms-data', 'cms-data.json');

const bundled = await build({
  stdin: {
    contents: "export * from '@/cms/render'; export * from '@/cms/structure';",
    resolveDir: appRoot,
    loader: 'ts',
  },
  bundle: true,
  format: 'esm',
  platform: 'node',
  write: false,
  alias: { '@': path.join(appRoot, 'src') },
});

const scratch = await mkdtemp(path.join(repoRoot, 'node_modules', '.structure-'));
const bundleFile = path.join(scratch, 'cms.mjs');
await writeFile(bundleFile, bundled.outputFiles[0].text, 'utf8');
const cms = await import(pathToFileURL(bundleFile).href);

const checks = [];
const failures = [];
const check = (label, ok, detail = '') => {
  checks.push(label);
  if (!ok) failures.push(`${label}${detail ? ` — ${detail}` : ''}`);
};

const db = JSON.parse(await readFile(storeFile, 'utf8'));
for (const course of db.courses) {
  const units = db.units
    .filter((u) => u.courseId === course.courseId)
    .sort((a, b) => a.order - b.order);
  const themes = units.map((u) => u.draft.theme);

  // course.mjs imports './units/<stem>.mjs', so the scratch tree mirrors content/<courseId>/source/<version>/.
  const dir = path.join(scratch, course.courseId);
  const unitsDir = path.join(dir, 'units');
  await mkdir(unitsDir, { recursive: true });
  for (const [index, unit] of units.entries()) {
    const file = cms.renderUnitFile(index, unit.draft, ['// structure proof']);
    await writeFile(path.join(unitsDir, file.fileName), file.source, 'utf8');
  }

  const courseFile = path.join(dir, 'course.mjs');
  await writeFile(
    courseFile,
    cms.renderCourseFile(course.draft, units.map((u) => u.draft), ['// structure proof']),
    'utf8',
  );
  const rendered = await import(pathToFileURL(courseFile).href);
  const listed = rendered.sections.flatMap((s) => s.units);

  check(
    `${course.courseId}: đủ 2 section cho lint-course`,
    rendered.sections.length >= 2,
    `${rendered.sections.length} section`,
  );

  // build-course.mjs:46 — the exact lookup, one unit at a time, with no optional chaining to save it.
  for (const [index, theme] of themes.entries()) {
    const found = rendered.sections.find((s) => s.units.includes(theme));
    check(
      `${course.courseId} unit ${index + 1} "${theme}" có sectionId`,
      Boolean(found?.sectionId),
      'build-course sẽ crash',
    );
  }

  check(
    `${course.courseId}: không theme nào ở hai section`,
    new Set(listed).size === listed.length,
    listed.join(', '),
  );
  for (const theme of listed)
    check(`${course.courseId}: section "${theme}" còn unit`, themes.includes(theme), 'unit đã bị xóa');

  // The panel offers exactly the problems the repo would refuse, so a green panel means a green build.
  const issues = cms.structureIssues(course.draft.sections, themes);
  check(`${course.courseId}: CMS thấy cùng vấn đề`, issues.length === 0, issues.join('; '));
}

await rm(scratch, { recursive: true, force: true });

if (failures.length) {
  console.error(`FAIL — ${failures.length}/${checks.length} checks:\n`);
  for (const f of failures.slice(0, 20)) console.error(`• ${f}\n`);
  process.exit(1);
}
console.log(
  `OK — ${checks.length} checks: course.mjs xuất từ bản nháp CMS không làm build-course crash và đủ section cho lint-course.`,
);
