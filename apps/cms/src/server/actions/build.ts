'use server';

import { execFile } from 'node:child_process';
import { mkdir, readFile, readdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { promisify } from 'node:util';
import type { BuildRun } from '@/cms/types';
import { structureIssues } from '@/cms/structure';
import { renderCourseFile, renderUnitFile, staleUnitFiles, unitFileStem } from '@/cms/render';
import { config } from '../config';
import { getStore } from '../store';
import { assertAdmin } from '../session';
import { recordAudit } from '../audit';
import { explainGateFailure, type GateLabel } from '../plain-errors';

const run = promisify(execFile);

const HEADER = [
  '// Course tables edited in apps/cms — export writes this file, the generator reads it.',
  '// Format spec: docs/content/EXERCISE_FORMATS.md. Generator: tools/content/build-course.mjs.',
];

/**
 * The authored files open with hand-written notes (the recurring cast, editing rules). Export
 * keeps that comment block and only replaces the tables, so exporting never deletes documentation.
 */
async function leadingComments(file: string): Promise<string[] | undefined> {
  try {
    const text = await readFile(file, 'utf8');
    const out: string[] = [];
    for (const line of text.split('\n')) {
      if (line.startsWith('//')) out.push(line);
      else if (out.length === 0) return undefined;
      else break;
    }
    return out.length ? out : undefined;
  } catch {
    return undefined;
  }
}

export interface ExportResult {
  ok: boolean;
  files: string[];
  message?: string;
  /**
   * `uNN-*.mjs` files still in the source folder that course.mjs no longer imports. Export writes one
   * file per position and never deletes, so a reorder leaves the previous name of each moved unit
   * behind, and the next "import from repo" — which globs the folder — would re-create those units.
   */
  stale?: string[];
  /** Set when the files were written but the audit row could not be. */
  warning?: string;
}

/**
 * Writes the CMS drafts back into the repository authoring tables. Those tables remain the input
 * the frozen generator and lint consume, so the CMS can never publish a shape the app cannot render.
 */
export async function exportCourseToRepo(courseId: string): Promise<ExportResult> {
  const actor = await assertAdmin();
  const c = config();
  const store = getStore();
  const course = await store.getCourse(courseId);
  if (!course)
    return { ok: false, files: [], message: 'Khóa này chưa có bài nào được soạn ở đây.' };
  const units = await store.listUnits(courseId);
  if (!units.length)
    return { ok: false, files: [], message: 'Khóa này chưa có bài nào để ghi ra.' };
  // Writing course.mjs with an unassigned theme hands build-course a course it cannot map.
  const issues = structureIssues(
    course.draft.sections,
    units.map((u) => u.draft.theme),
  );
  if (issues.length)
    return { ok: false, files: [], message: `Cấu trúc khóa chưa sẵn sàng: ${issues.join(' ')}` };

  const sourceDir = path.join(c.repoRoot, 'content', courseId, 'source', course.draft.version);
  const unitsDir = path.join(sourceDir, 'units');
  await mkdir(unitsDir, { recursive: true });

  const files: string[] = [];
  const stems: string[] = [];
  for (const [index, unit] of units.entries()) {
    const stem = unitFileStem(index, unit.draft);
    const target = path.join(unitsDir, `${stem}.mjs`);
    const file = renderUnitFile(index, unit.draft, await leadingComments(target));
    await writeFile(target, file.source, 'utf8');
    stems.push(file.fileName);
    files.push(`units/${file.fileName}`);
  }
  const courseFile = path.join(sourceDir, 'course.mjs');
  const courseSource = renderCourseFile(
    course.draft,
    units.map((u) => u.draft),
    (await leadingComments(courseFile)) ?? [
      ...HEADER,
      `// Course ${courseId} ${course.draft.version}`,
    ],
  );
  await writeFile(courseFile, courseSource, 'utf8');
  files.push('course.mjs');

  // Telling the admin which files are now unreferenced is the safe half of a cleanup: deleting an
  // authored table nobody imported yet would destroy content, so this only reports.
  const stale = staleUnitFiles(await readdir(unitsDir), stems);

  const auditWarning = await recordAudit({
    actorId: actor.userId,
    operation: 'content.export',
    targetId: courseId,
    afterJson: JSON.stringify({ files: files.length, stale: stale.length }),
  });
  return { ok: true, files, stale, warning: auditWarning ?? undefined };
}

interface GateCommand {
  label: GateLabel;
  args: string[];
}

/**
 * Every gate is scoped to the course being built. check-content verifies media for each course it
 * visits, so an unscoped run would let an unfinished course fail another course's build.
 */
const gatesFor = (courseId: string, versionId: string): GateCommand[] => {
  const scope = ['--course', courseId, '--version', versionId];
  return [
    { label: 'build-course', args: ['tools/content/build-course.mjs', ...scope] },
    { label: 'lint-course', args: ['tools/content/lint-course.mjs', ...scope] },
    { label: 'check-content', args: ['content/tools/check-content.mjs', ...scope] },
  ];
};

/** Runs the repository's own content gates and records the outcome as a build run. */
export async function runContentGates(courseId: string): Promise<BuildRun & { warning?: string }> {
  const actor = await assertAdmin();
  const c = config();
  const store = getStore();
  const runId = crypto.randomUUID();
  const log: string[] = [];
  let status: BuildRun['status'] = 'SUCCEEDED';
  let message = 'Nội dung của khóa đã qua hết các bước kiểm tra.';
  const versionId = (await store.getCourse(courseId))?.draft.version ?? 'v2';

  const record: BuildRun = {
    runId,
    courseId,
    versionId,
    kind: 'GATES',
    status: 'RUNNING',
    message: 'Đang kiểm tra nội dung…',
    log: [],
    actorId: actor.userId,
    createdAt: new Date().toISOString(),
  };
  await store.saveBuildRun(record);

  for (const gate of gatesFor(courseId, versionId)) {
    log.push(`$ node ${gate.args.join(' ')}`);
    try {
      const { stdout, stderr } = await run(process.execPath, gate.args, {
        cwd: c.repoRoot,
        maxBuffer: 8 * 1024 * 1024,
        timeout: 300_000,
      });
      log.push(...tail(stdout), ...tail(stderr));
      log.push(`✓ ${gate.label}`);
    } catch (error) {
      const failure = error as { stdout?: string; stderr?: string; message?: string };
      const raw = [failure.stderr, failure.stdout, failure.message].filter(Boolean).join('\n');
      status = 'FAILED';
      // The author reads one sentence; the raw output stays in the run record and the server log.
      message = explainGateFailure(gate.label, raw);
      console.error(`[content gate ${gate.label}] ${courseId}\n${raw.slice(-2000)}`);
      log.push(...tail(failure.stdout ?? ''), ...tail(failure.stderr ?? failure.message ?? ''));
      log.push(`✗ ${gate.label}`);
      break;
    }
  }

  const finished: BuildRun = { ...record, status, message, log };
  await store.saveBuildRun(finished);
  const auditWarning = await recordAudit({
    actorId: actor.userId,
    operation: 'content.gates',
    targetId: courseId,
    afterJson: JSON.stringify({ status, message }),
  });
  return { ...finished, warning: auditWarning ?? undefined };
}

const tail = (text: string, lines = 40): string[] =>
  text
    .split('\n')
    .map((l) => l.trimEnd())
    .filter(Boolean)
    .slice(-lines);

