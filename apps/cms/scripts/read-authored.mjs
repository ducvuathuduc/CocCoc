// Reads the authored v2 tables straight from the repository and prints them as JSON.
// The CMS runs this as a child process: the unit files change on disk, so a bundler cannot
// statically resolve them, and running them through the repo's own ESM loader keeps the
// generator and the CMS reading exactly the same bytes.
import { readdir } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const repoRoot = path.resolve(import.meta.dirname, '..', '..', '..');
const courseId = process.argv[2] ?? 'vi_en';
const version = process.argv[3] ?? 'v2';
const sourceDir = path.join(repoRoot, 'content', courseId, 'source', version);

const courseModule = await import(pathToFileURL(path.join(sourceDir, 'course.mjs')).href);

const unitsDir = path.join(sourceDir, 'units');
const names = (await readdir(unitsDir)).filter((f) => /^u\d{2}-.+\.mjs$/.test(f)).sort();
const units = [];
for (const [index, fileName] of names.entries()) {
  const { default: unit } = await import(pathToFileURL(path.join(unitsDir, fileName)).href);
  units.push({
    fileName,
    index,
    unit: {
      theme: unit.theme,
      cefr: unit.cefr,
      title: unit.title,
      levels: unit.levels,
      guide: unit.guide,
      vocab: unit.vocab,
      sentences: unit.sentences,
      dialogues: unit.dialogues,
      story: {
        title: unit.story.title,
        passage: unit.story.passage,
        questions: unit.story.questions,
      },
    },
  });
}

process.stdout.write(
  JSON.stringify({
    course: courseModule.course,
    sections: courseModule.sections,
    units,
  }),
);
