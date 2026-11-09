import { cache } from 'react';
import { lintUnit } from '@/cms/lint';
import { structureIssues } from '@/cms/structure';
import { config } from './config';
import {
  buildRuns,
  courseUnits,
  getCourseRecord,
  lastLivePublish,
  toSummary,
  type CourseSummary,
} from './queries';
import { publishReadiness } from './publish-state';

export type LessonState = 'empty' | 'error' | 'warning' | 'ready';

export interface WorkspaceLesson {
  unitId: string;
  order: number;
  title: string;
  cefr: string;
  revision: number;
  updatedAt: string;
  vocab: number;
  sentences: number;
  dialogues: number;
  questions: number;
  state: LessonState;
  errors: number;
  warnings: number;
}

export interface WorkspaceCounts {
  total: number;
  ready: number;
  empty: number;
  errors: number;
  warnings: number;
}

export interface WorkspacePublish {
  gatesOk: boolean;
  gateAt?: string;
  awaitingValidation: number;
  lastPublishedAt?: string;
  lastPublishedVersion?: string;
  blocking?: string;
  publishAllowed: boolean;
  appwriteMode: boolean;
}

export interface WorkspaceData {
  course: CourseSummary;
  lessons: WorkspaceLesson[];
  counts: WorkspaceCounts;
  structureIssues: string[];
  publish: WorkspacePublish;
  lastEdited: WorkspaceLesson | null;
  /** The first lesson a teacher should open when starting the day. */
  firstProblem: WorkspaceLesson | null;
}

/**
 * The lesson workspace reads one course, its units and the build history once. A lesson's status is
 * the same lint the editor runs, so the list and the editor cannot disagree about what is broken.
 * The reads are independent, so they fly together; the shared query cache dedupes what readiness
 * asks again.
 */
export const workspaceData = cache(async (courseId: string): Promise<WorkspaceData | null> => {
  const [course, units, runs, readiness] = await Promise.all([
    getCourseRecord(courseId),
    courseUnits(courseId),
    buildRuns(courseId),
    publishReadiness(courseId),
  ]);
  if (!course) return null;

  const lessons: WorkspaceLesson[] = units.map((unit) => {
    const issues = lintUnit(unit.draft);
    const errors = issues.filter((issue) => issue.level === 'error').length;
    const warnings = issues.filter((issue) => issue.level === 'warning').length;
    const empty = unit.draft.vocab.length === 0 && unit.draft.sentences.length === 0;
    const state: LessonState = empty
      ? 'empty'
      : errors > 0
        ? 'error'
        : warnings > 0
          ? 'warning'
          : 'ready';
    return {
      unitId: unit.unitId,
      order: unit.order,
      title: unit.draft.title,
      cefr: unit.draft.cefr,
      revision: unit.revision,
      updatedAt: unit.updatedAt,
      vocab: unit.draft.vocab.length,
      sentences: unit.draft.sentences.length,
      dialogues: unit.draft.dialogues.length,
      questions: unit.draft.story.questions.length,
      state,
      errors,
      warnings,
    };
  });

  const counts: WorkspaceCounts = {
    total: lessons.length,
    ready: lessons.filter((lesson) => lesson.state === 'ready').length,
    empty: lessons.filter((lesson) => lesson.state === 'empty').length,
    errors: lessons.filter((lesson) => lesson.state === 'error').length,
    warnings: lessons.filter((lesson) => lesson.state === 'warning').length,
  };

  const structural = structureIssues(
    course.draft.sections,
    units.map((unit) => unit.draft.theme),
  );
  // A dry run proved the content but reached no learner, so it cannot be reported as published.
  const lastPublish = lastLivePublish(runs);
  const gateAt = readiness?.gateRunAt;
  const gateTime = gateAt ? Date.parse(gateAt) : null;
  const awaitingValidation = lessons.filter(
    (lesson) => gateTime === null || Date.parse(lesson.updatedAt) > gateTime,
  ).length;

  const blocking = readiness?.gatesOk
    ? undefined
    : lessons.length === 0
      ? 'Chưa có bài học nào.'
      : structural.length > 0
        ? 'Cấu trúc khóa cần sửa trước khi kiểm tra.'
        : !gateAt
          ? 'Chưa kiểm tra lần nào.'
          : awaitingValidation > 0
            ? `${awaitingValidation} bài đã sửa sau lần kiểm tra gần nhất.`
            : 'Cần kiểm tra lại trước khi xuất bản.';

  const lastEdited = [...lessons].sort(
    (a, b) => Date.parse(b.updatedAt) - Date.parse(a.updatedAt),
  )[0];

  return {
    course: toSummary(course),
    lessons,
    counts,
    structureIssues: structural,
    publish: {
      gatesOk: readiness?.gatesOk ?? false,
      gateAt,
      awaitingValidation,
      lastPublishedAt: lastPublish?.createdAt,
      lastPublishedVersion: lastPublish?.versionId,
      blocking,
      publishAllowed: config().publishAllowed,
      appwriteMode: config().mode === 'appwrite',
    },
    lastEdited: lastEdited ?? null,
    firstProblem:
      lessons.find((lesson) => lesson.state === 'error') ??
      lessons.find((lesson) => lesson.state === 'empty') ??
      lessons.find((lesson) => lesson.state === 'warning') ??
      lessons[0] ??
      null,
  };
});
