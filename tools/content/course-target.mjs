// Shared `--course <id> --version <v>` parser for the content CLIs (build-course, lint-course).
//
// Both segments become path components (`content/<course>/source/<version>/…`), so they are validated
// against a strict charset rather than merely checked for `..`: a leading letter, then lowercase
// letters/digits and single `_ - .` separators. That rejects absolute paths, `/`, `\`, `.`, `..`,
// whitespace and anything that could resolve outside the course folder.
//
// The defaults are the only published course today, so every existing command keeps its behaviour.

export const DEFAULT_COURSE = 'vi_en';
export const DEFAULT_VERSION = 'v2';

const COURSE_ID = /^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$/;
const VERSION_ID = /^[a-z][a-z0-9]*(?:[._-][a-z0-9]+)*$/;

function readFlag(argv, name) {
  const at = argv.indexOf(name);
  if (at === -1) return null;
  const value = argv[at + 1];
  if (!value || value.startsWith('--')) throw new Error(`${name} cần một giá trị`);
  return value;
}

/** Returns `{ courseId, version }`, defaulting to vi_en / v2. Throws on an unsafe segment. */
export function parseCourseTarget(argv = process.argv.slice(2)) {
  const courseId = readFlag(argv, '--course') ?? DEFAULT_COURSE;
  const version = readFlag(argv, '--version') ?? DEFAULT_VERSION;
  if (!COURSE_ID.test(courseId))
    throw new Error(
      `--course "${courseId}" không hợp lệ (chữ thường, số, dấu _ giữa các từ; ví dụ vi_en)`,
    );
  if (!VERSION_ID.test(version)) throw new Error(`--version "${version}" không hợp lệ (ví dụ v2)`);
  return { courseId, version };
}
