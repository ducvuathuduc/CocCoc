'use server';

import path from 'node:path';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import type { CourseDraft, SectionDraft, UnitDraft } from '@/cms/types';
import { tablesToUnit, type ParsedUnit } from '@/cms/tables';
import { config } from '../config';
import { getStore } from '../store';
import { assertAdmin } from '../session';
import { recordAudit } from '../audit';

const run = promisify(execFile);

interface AuthoredUnit {
  theme: string;
  cefr: string;
  title: string;
  levels: string[];
  guide: string;
  vocab: string;
  sentences: string;
  dialogues: string;
  story: { title: string; passage: string; questions: string };
}

interface AuthoredCourse {
  courseId: string;
  title: string;
  sourceLocale: string;
  targetLocale: string;
}

interface ReaderOutput {
  course: AuthoredCourse;
  sections: SectionDraft[];
  units: { fileName: string; index: number; unit: AuthoredUnit }[];
}

function toDraft(unit: AuthoredUnit): UnitDraft {
  const parsed: ParsedUnit = {
    theme: unit.theme,
    cefr: unit.cefr as UnitDraft['cefr'],
    title: unit.title,
    levels: unit.levels,
    guide: unit.guide,
    vocab: unit.vocab,
    sentences: unit.sentences,
    dialogues: unit.dialogues,
    storyTitle: unit.story.title,
    passage: unit.story.passage,
    questions: unit.story.questions,
  };
  return tablesToUnit(parsed);
}

export interface ImportResult {
  ok: boolean;
  units?: number;
  message?: string;
  warning?: string;
}

/**
 * Pulls the checked-in authoring tables into the CMS draft store so editing starts from real
 * content. The repo files stay the published source until the export action writes them back.
 *
 * Failures come back as `ok:false` rather than as a throw: Next replaces the message of a thrown
 * server-action error with a digest, so the operator would read "a server-side exception" instead of
 * the one sentence that tells them which folder is missing.
 */
export async function importCourseFromRepo(courseId: string): Promise<ImportResult> {
  const actor = await assertAdmin();
  const c = config();
  const script = path.join(c.repoRoot, 'apps', 'cms', 'scripts', 'read-authored.mjs');
  let stdout: string;
  try {
    ({ stdout } = await run(process.execPath, [script, courseId, 'v2'], {
      cwd: c.repoRoot,
      maxBuffer: 32 * 1024 * 1024,
    }));
  } catch (error) {
    // The reader dies with a module-not-found stack when the course has no authored tables; that trace
    // belongs in the server log, not in a toast.
    console.error(`[cms] read-authored.mjs failed for ${courseId}`, error);
    return {
      ok: false,
      message: `Không đọc được bảng tác giả của khóa “${courseId}”. Kiểm tra content/${courseId}/source/v2/course.mjs có tồn tại và đúng mã khóa không.`,
    };
  }
  const authored = JSON.parse(stdout) as ReaderOutput;
  if (authored.course.courseId !== courseId) {
    return {
      ok: false,
      message: `Khóa trong repo là ${authored.course.courseId}, không phải ${courseId}.`,
    };
  }

  const draft: CourseDraft = {
    course: { ...authored.course, status: 'ACTIVE' },
    sections: authored.sections,
    version: 'v2',
  };

  const store = getStore();
  const current = await store.getCourse(courseId);
  await store.saveCourse({
    courseId,
    draft,
    actorId: actor.userId,
    expectedRevision: current?.revision ?? 0,
  });

  let saved = 0;
  for (const { index, unit } of authored.units) {
    const unitId = `${String(index + 1).padStart(2, '0')}-${unit.theme}`;
    const existing = await store.getUnit(courseId, unitId);
    await store.saveUnit({
      courseId,
      unitId,
      order: index,
      draft: toDraft(unit),
      actorId: actor.userId,
      expectedRevision: existing?.revision ?? 0,
    });
    saved += 1;
  }

  const auditWarning = await recordAudit({
    actorId: actor.userId,
    operation: 'course.import',
    targetId: courseId,
    afterJson: JSON.stringify({ units: saved }),
  });
  return { ok: true, units: saved, warning: auditWarning ?? undefined };
}
