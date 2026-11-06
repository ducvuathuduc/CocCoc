import type { CourseDraft, UnitDraft } from './types';
import {
  renderDialogues,
  renderSentences,
  renderStoryQuestions,
  renderVocab,
  slug,
} from './tables';

/** Template literal body: only backslash, backtick and `${` need escaping in authored text. */
function literal(text: string): string {
  return text
    .replace(/\\/g, '\\\\')
    .replace(/`/g, '\\`')
    .replace(/\$\{/g, '\\${');
}

const jsonString = (text: string): string => JSON.stringify(text);

export function unitFileStem(index: number, unit: UnitDraft): string {
  return `u${String(index + 1).padStart(2, '0')}-${slug(unit.theme)}`;
}

const UNIT_FILE = /^u\d{2}-.+\.mjs$/;

/**
 * Unit files in the source folder that the export no longer writes. Export never deletes: a file
 * matching this shape but absent from `written` is the previous name of a moved or renamed unit, and
 * the next import from the folder would re-create it as a second unit.
 */
export function staleUnitFiles(found: string[], written: string[]): string[] {
  const kept = new Set(written);
  return found.filter((file) => UNIT_FILE.test(file) && !kept.has(file)).sort();
}

export interface UnitFile {
  fileName: string;
  source: string;
}

const CMS_NOTE = '// Edited in apps/cms; the tables below are what the export action wrote.';

export function renderUnitFile(index: number, unit: UnitDraft, header?: string[]): UnitFile {
  const lines: string[] = [
    ...(header?.length ? header : [`// Unit ${index + 1} — ${unit.title} (${unit.cefr}). Format: see tools/content/course-lib.mjs.`, CMS_NOTE]),
    'export default {',
    `  theme: ${jsonString(unit.theme)},`,
    `  cefr: ${jsonString(unit.cefr)},`,
    `  title: ${jsonString(unit.title)},`,
    `  levels: [${unit.levels.map(jsonString).join(', ')}],`,
    '  guide: `',
    literal(unit.guide.trim()),
    '`,',
    '  vocab: `',
    literal(renderVocab(unit.vocab)),
    '`,',
    '  sentences: `',
    literal(renderSentences(unit.sentences)),
    '`,',
    '  dialogues: `',
    literal(renderDialogues(unit.dialogues)),
    '`,',
    '  story: {',
    `    title: ${jsonString(unit.story.title)},`,
    // The passage reaches the app bundle as-is (build-course only trims it for the manifest), so it
    // opens right after the backtick and closes right after the last character, like the authored files.
    `    passage: \`${literal(unit.story.passage.trim())}\`,`,
    '    questions: `',
    literal(renderStoryQuestions(unit.story.questions)),
    '`,',
    '  },',
    '};',
    '',
  ];
  return { fileName: `${unitFileStem(index, unit)}.mjs`, source: lines.join('\n') };
}

export function renderCourseFile(
  draft: CourseDraft,
  units: UnitDraft[],
  headerComment: string[],
): string {
  const imports = units
    .map((u, i) => `import * as u${String(i + 1).padStart(2, '0')} from './units/${unitFileStem(i, u)}.mjs';`)
    .join('\n');
  const moduleList = units.map((_u, i) => `  u${String(i + 1).padStart(2, '0')},`).join('\n');
  const sections = draft.sections
    .map(
      (s) =>
        `  {\n    sectionId: ${jsonString(s.sectionId)},\n    title: ${jsonString(s.title)},\n` +
        `    units: [${s.units.map(jsonString).join(', ')}],\n  },`,
    )
    .join('\n');
  return [
    ...headerComment,
    imports,
    '',
    'export const course = {',
    `  courseId: ${jsonString(draft.course.courseId)},`,
    `  title: ${jsonString(draft.course.title)},`,
    `  sourceLocale: ${jsonString(draft.course.sourceLocale)},`,
    `  targetLocale: ${jsonString(draft.course.targetLocale)},`,
    '};',
    '',
    'export const sections = [',
    sections,
    '];',
    '',
    'export const unitModules = [',
    moduleList,
    '];',
    '',
  ].join('\n');
}
