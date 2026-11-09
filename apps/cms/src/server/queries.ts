import { cache } from 'react';
import type { AuditEntry, BuildRun, CourseRecord, UnitRecord } from '@/cms/types';
import { lintUnit, type ContentIssue } from '@/cms/lint';
import { getStore } from './store';
import type { UnitIndexEntry } from './store/port';

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

/* One render asks the same question from the layout, the page and the readiness panel. React's
   cache dedupes the in-flight promise per request, so each Appwrite read happens once. */
export const listCourseSummaries = cache(async (): Promise<CourseSummary[]> => {
  const courses = await getStore().listCourses();
  return courses.map(toSummary);
});

export const courseUnits = cache((courseId: string): Promise<UnitRecord[]> => {
  return getStore().listUnits(courseId);
});

/** Four columns, no draft payloads: what navigation and structure lists actually read. */
export const unitIndex = cache((courseId: string): Promise<UnitIndexEntry[]> => {
  return getStore().listUnitIndex(courseId);
});

export const getCourseRecord = cache((courseId: string): Promise<CourseRecord | null> => {
  return getStore().getCourse(courseId);
});

export function getUnitRecord(courseId: string, unitId: string): Promise<UnitRecord | null> {
  return getStore().getUnit(courseId, unitId);
}

export const buildRuns = cache((courseId: string): Promise<BuildRun[]> => {
  return getStore().listBuildRuns(courseId);
});

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

export const auditLog = cache((limit = 100): Promise<AuditEntry[]> => {
  return getStore().listAudit(limit);
});

export interface UnitReport {
  courseId: string;
  unitId: string;
  title: string;
  errors: ContentIssue[];
  warnings: ContentIssue[];
}

/** Runs the CMS-side lint over every draft: the same questions the repo gates will ask. */
export const contentReport = cache(async (): Promise<UnitReport[]> => {
  const courses = await getStore().listCourses();
  const reports: UnitReport[] = [];
  for (const course of courses) {
    for (const unit of await courseUnits(course.courseId)) {
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
});
