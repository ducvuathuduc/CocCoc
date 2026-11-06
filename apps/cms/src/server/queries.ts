import type { AuditEntry, BuildRun, CourseRecord, UnitRecord } from '@/cms/types';
import { lintUnit, type ContentIssue } from '@/cms/lint';
import { getStore } from './store';

export interface CourseSummary {
  courseId: string;
  title: string;
  version: string;
  status: string;
  locales: string;
  updatedAt: string;
  updatedBy: string;
}

export function toSummary(course: CourseRecord): CourseSummary {
  return {
    courseId: course.courseId,
    title: course.draft.course.title,
    version: course.draft.version,
    status: course.draft.course.status,
    locales: `${course.draft.course.sourceLocale} → ${course.draft.course.targetLocale}`,
    updatedAt: course.updatedAt,
    updatedBy: course.updatedBy,
  };
}

export async function listCourseSummaries(): Promise<CourseSummary[]> {
  const courses = await getStore().listCourses();
  return courses.map(toSummary);
}

export async function courseUnits(courseId: string): Promise<UnitRecord[]> {
  return getStore().listUnits(courseId);
}

export interface UnitStat {
  unitId: string;
  theme: string;
  title: string;
  cefr: string;
  order: number;
  revision: number;
  updatedAt: string;
  vocab: number;
  sentences: number;
  dialogues: number;
  questions: number;
}

export function toUnitStat(unit: UnitRecord): UnitStat {
  return {
    unitId: unit.unitId,
    theme: unit.draft.theme,
    title: unit.draft.title,
    cefr: unit.draft.cefr,
    order: unit.order,
    revision: unit.revision,
    updatedAt: unit.updatedAt,
    vocab: unit.draft.vocab.length,
    sentences: unit.draft.sentences.length,
    dialogues: unit.draft.dialogues.length,
    questions: unit.draft.story.questions.length,
  };
}

export async function courseUnitStats(courseId: string): Promise<UnitStat[]> {
  const units = await courseUnits(courseId);
  return units.map(toUnitStat);
}

export function getCourseRecord(courseId: string): Promise<CourseRecord | null> {
  return getStore().getCourse(courseId);
}

export function getUnitRecord(courseId: string, unitId: string): Promise<UnitRecord | null> {
  return getStore().getUnit(courseId, unitId);
}

export function buildRuns(courseId: string): Promise<BuildRun[]> {
  return getStore().listBuildRuns(courseId);
}

/**
 * The publisher writes the command line it ran as the first log line, so a run that carried
 * `--dry-run` proved the content but wrote nothing to the shared project.
 */
export function isDryRunPublish(run: BuildRun): boolean {
  return run.kind === 'PUBLISH' && (run.log[0] ?? '').includes('--dry-run');
}

/** The most recent run that actually reached learners. */
export function lastLivePublish(runs: BuildRun[]): BuildRun | null {
  return (
    runs.find((run) => run.kind === 'PUBLISH' && run.status === 'SUCCEEDED' && !isDryRunPublish(run)) ??
    null
  );
}

export function auditLog(limit = 100): Promise<AuditEntry[]> {
  return getStore().listAudit(limit);
}

export interface UnitReport {
  courseId: string;
  unitId: string;
  title: string;
  errors: ContentIssue[];
  warnings: ContentIssue[];
}

/** Runs the CMS-side lint over every draft: the same questions the repo gates will ask. */
export async function contentReport(): Promise<UnitReport[]> {
  const courses = await getStore().listCourses();
  const reports: UnitReport[] = [];
  for (const course of courses) {
    for (const unit of await getStore().listUnits(course.courseId)) {
      const issues = lintUnit(unit.draft);
      reports.push({
        courseId: course.courseId,
        unitId: unit.unitId,
        title: unit.draft.title,
        errors: issues.filter((i) => i.level === 'error'),
        warnings: issues.filter((i) => i.level === 'warning'),
      });
    }
  }
  return reports;
}
