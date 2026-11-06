// Round-trip check: the CMS parser must read the repo's authored tables and the CMS renderer must
// write them back so that the repo's own parser (tools/content/course-lib.mjs) sees the same rows.
// If this passes, an exported unit file is still valid input for build-course.mjs and lint-course.mjs.
import { build } from 'esbuild';
import { mkdtemp, writeFile } from 'node:fs/promises';
import { readdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const appRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const repoRoot = path.resolve(appRoot, '..', '..');

const bundled = await build({
  stdin: {
    contents: "export * from '@/cms/tables'; export * from '@/cms/lint';",
    resolveDir: appRoot,
    loader: 'ts',
  },
  bundle: true,
  format: 'esm',
  platform: 'node',
  write: false,
  alias: { '@': path.join(appRoot, 'src') },
});

const dir = await mkdtemp(path.join(repoRoot, 'node_modules', '.roundtrip-'));
const bundleFile = path.join(dir, 'cms.mjs');
await writeFile(bundleFile, bundled.outputFiles[0].text, 'utf8');

const cms = await import(pathToFileURL(bundleFile).href);
const repo = await import(
  pathToFileURL(path.join(repoRoot, 'tools', 'content', 'course-lib.mjs')).href
);

const unitsDir = path.join(repoRoot, 'content', 'vi_en', 'source', 'v2', 'units');
const files = (await readdir(unitsDir)).filter((f) => /^u\d{2}-.+\.mjs$/.test(f)).sort();

let checks = 0;
const failures = [];

function compare(label, a, b) {
  checks += 1;
  const x = JSON.stringify(a);
  const y = JSON.stringify(b);
  if (x !== y) failures.push(`${label}\n  repo:  ${x.slice(0, 300)}\n  cms:   ${y.slice(0, 300)}`);
}

for (const [index, file] of files.entries()) {
  const unitId = `${String(index + 1).padStart(2, '0')}-${(await import(pathToFileURL(path.join(unitsDir, file)).href)).default.theme}`;
  const { default: unit } = await import(pathToFileURL(path.join(unitsDir, file)).href);

  compare(`${file} vocab`, repo.parseVocab(unitId, unit.vocab), repo.parseVocab(unitId, cms.renderVocab(cms.parseVocab(unit.vocab))));
  compare(`${file} sentences`, repo.parseSentences(unitId, unit.sentences), repo.parseSentences(unitId, cms.renderSentences(cms.parseSentences(unit.sentences))));
  compare(`${file} dialogues`, repo.parseDialogues(unitId, unit.dialogues), repo.parseDialogues(unitId, cms.renderDialogues(cms.parseDialogues(unit.dialogues))));
  compare(`${file} questions`, repo.parseStoryQuestions(unitId, unit.story.questions), repo.parseStoryQuestions(unitId, cms.renderStoryQuestions(cms.parseStoryQuestions(unit.story.questions))));

  const draft = cms.tablesToUnit({
    theme: unit.theme,
    cefr: unit.cefr,
    title: unit.title,
    levels: unit.levels,
    guide: unit.guide,
    vocab: unit.vocab,
    sentences: unit.sentences,
    dialogues: unit.dialogues,
    storyTitle: unit.story.title,
    passage: unit.story.passage,
    questions: unit.story.questions,
  });
  const errors = cms.lintUnit(draft).filter((i) => i.level === 'error');
  compare(`${file} lint errors on authored content`, [], errors);
}

if (failures.length) {
  console.error(`FAIL ${failures.length}/${checks} checks\n`);
  for (const f of failures.slice(0, 8)) console.error(f, '\n');
  process.exit(1);
}
console.log(`OK — ${checks} checks: CMS parse/render round-trip matches the repo parser on ${files.length} units.`);
