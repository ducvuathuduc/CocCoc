'use server';

import { courseDraftSchema } from '@/cms/schema';
import { blankUnit } from '@/cms/blank';
import { assignTheme, structureIssues } from '@/cms/structure';
import { slug } from '@/cms/tables';
import type { Cefr, CourseDraft, SectionDraft } from '@/cms/types';
import { getStore } from '../store';
import { ConflictError, StoreUnavailableError } from '../store/port';
import { assertAdmin } from '../session';
import { recordAudit } from '../audit';

export interface CourseMetaInput {
  courseId: string;
  title: string;
  sourceLocale: string;
  targetLocale: string;
  status: CourseDraft['course']['status'];
  version: string;
  expectedRevision: number;
}

export interface ActionReply {
  ok: boolean;
  revision?: number;
  message?: string;
  warning?: string;
}

/** Course meta only. Section membership is managed by `saveCourseStructure` and unit create/delete. */
export async function saveCourseMeta(input: CourseMetaInput): Promise<ActionReply> {
  const actor = await assertAdmin();
  const store = getStore();
  const current = await store.getCourse(input.courseId);
  if (!current)
    return { ok: false, message: 'Khóa này chưa có trong bản soạn. Hãy tạo khóa mới trước.' };

  const draft: CourseDraft = {
    course: {
      courseId: input.courseId,
      title: input.title.trim(),
      sourceLocale: input.sourceLocale.trim(),
      targetLocale: input.targetLocale.trim(),
      status: input.status,
    },
    sections: current.draft.sections,
    version: input.version.trim() || current.draft.version,
  };
  const parsed = courseDraftSchema.safeParse(draft);
  if (!parsed.success) return { ok: false, message: 'Tên khóa hoặc mã ngôn ngữ chưa hợp lệ.' };

  try {
    const record = await store.saveCourse({
      courseId: input.courseId,
      draft,
      actorId: actor.userId,
      expectedRevision: input.expectedRevision,
    });
    const auditWarning = await recordAudit({
      actorId: actor.userId,
      operation: 'course.update',
      targetId: input.courseId,
      beforeJson: JSON.stringify({ revision: current.revision }),
      afterJson: JSON.stringify({ revision: record.revision, status: draft.course.status }),
    });
    return { ok: true, revision: record.revision, warning: auditWarning ?? undefined };
  } catch (error) {
    if (error instanceof ConflictError || error instanceof StoreUnavailableError)
      return { ok: false, message: error.message };
    throw error;
  }
}

// slug() from the repo parser separates with underscores, so ids like `17-cms_smoke_test` are valid.
const UNIT_ID = /^[a-z0-9][a-z0-9_-]{1,39}$/;
// Same charset tools/content/course-target.mjs accepts: these values become folder names under
// content/<course>/source/<version>/, so anything else is refused at the boundary.
const COURSE_ID = /^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$/;
const VERSION_ID = /^[a-z][a-z0-9]*(?:[._-][a-z0-9]+)*$/;

export interface CreateCourseInput {
  courseId: string;
  title: string;
  sourceLocale: string;
  targetLocale: string;
  version: string;
}

/**
 * Starts a course that does not exist in the repo yet. Importing the authored tables stays the way to
 * bring in an existing course; this is the path for a brand-new one, which then gets sections, units
 * and lessons from the normal editing screens.
 */
export async function createCourse(
  input: CreateCourseInput,
): Promise<ActionReply & { courseId?: string }> {
  const actor = await assertAdmin();
  const store = getStore();
  const courseId = input.courseId.trim().toLowerCase();
  const version = input.version.trim() || 'v1';

  if (!COURSE_ID.test(courseId))
    return {
      ok: false,
      message: 'Mã khóa chỉ gồm chữ thường, số và dấu gạch dưới (ví dụ: vi_en, en_kids).',
    };
  if (!VERSION_ID.test(version))
    return { ok: false, message: 'Phiên bản chỉ gồm chữ thường, số và dấu chấm (ví dụ: v1, v2).' };
  if (await store.getCourse(courseId))
    return { ok: false, message: `Đã có khóa “${courseId}” trong bản soạn.` };

  const draft: CourseDraft = {
    course: {
      courseId,
      title: input.title.trim(),
      sourceLocale: input.sourceLocale.trim() || 'vi-VN',
      targetLocale: input.targetLocale.trim() || 'en-US',
      status: 'DRAFT',
    },
    sections: [{ sectionId: 'sec1', title: 'Phần 1', units: [] }],
    version,
  };
  if (!courseDraftSchema.safeParse(draft).success)
    return { ok: false, message: 'Tên khóa hoặc mã ngôn ngữ chưa hợp lệ.' };

  try {
    const record = await store.saveCourse({
      courseId,
      draft,
      actorId: actor.userId,
      expectedRevision: 0,
    });
    const auditWarning = await recordAudit({
      actorId: actor.userId,
      operation: 'course.create',
      targetId: courseId,
      afterJson: JSON.stringify({ version, title: draft.course.title }),
    });
    return { ok: true, courseId, revision: record.revision, warning: auditWarning ?? undefined };
  } catch (error) {
    if (error instanceof ConflictError || error instanceof StoreUnavailableError)
      return { ok: false, message: error.message };
    throw error;
  }
}

/** Creates an empty unit draft at the end of the course so an admin can start typing. */
export async function createUnitDraft(
  courseId: string,
  name: string,
  cefr: Cefr = 'A1',
): Promise<ActionReply & { unitId?: string }> {
  const actor = await assertAdmin();
  const theme = slug(name);
  if (!theme) return { ok: false, message: 'Tên unit phải có chữ cái để làm theme.' };

  const store = getStore();
  const units = await store.listUnits(courseId);
  if (units.some((u) => u.draft.theme === theme))
    return { ok: false, message: `Đã có unit dùng theme “${theme}”.` };

  const taken = new Set(units.map((u) => u.order));
  let order = units.length;
  while (taken.has(order)) order += 1;
  const unitId = `${String(order + 1).padStart(2, '0')}-${theme}`;
  if (!UNIT_ID.test(unitId)) return { ok: false, message: 'Không sinh được mã unit.' };

  const course = await store.getCourse(courseId);
  if (!course)
    return { ok: false, message: 'Khóa này chưa có trong bản soạn. Hãy tạo khóa mới trước.' };
  // Section membership is written before the unit exists: build-course throws on a unit that no
  // section lists, while a theme whose unit was never created is simply skipped by the builder.
  await store.saveCourse({
    courseId,
    draft: { ...course.draft, sections: assignTheme(course.draft.sections, theme) },
    actorId: actor.userId,
    expectedRevision: course.revision,
  });

  const record = await store.saveUnit({
    courseId,
    unitId,
    order,
    draft: blankUnit(theme, cefr),
    actorId: actor.userId,
    expectedRevision: 0,
  });
  const auditWarning = await recordAudit({
    actorId: actor.userId,
    operation: 'unit.create',
    targetId: `${courseId}/${unitId}`,
    afterJson: JSON.stringify({ revision: record.revision }),
  });
  return { ok: true, unitId, warning: auditWarning ?? undefined };
}

export interface CourseStructureInput {
  courseId: string;
  sections: SectionDraft[];
  expectedRevision: number;
}

/**
 * Rewrites section membership. Refuses what the repo gates would reject, so an export never produces
 * a course.mjs that build-course.mjs crashes on.
 */
export async function saveCourseStructure(input: CourseStructureInput): Promise<ActionReply> {
  const actor = await assertAdmin();
  const store = getStore();
  const current = await store.getCourse(input.courseId);
  if (!current)
    return { ok: false, message: 'Khóa này chưa có trong bản soạn. Hãy tạo khóa mới trước.' };

  const sections = input.sections.map((s) => ({
    sectionId: s.sectionId.trim(),
    title: s.title.trim(),
    units: [...new Set(s.units.map((t) => t.trim()).filter(Boolean))],
  }));
  const themes = (await store.listUnits(input.courseId)).map((u) => u.draft.theme);
  const issues = structureIssues(sections, themes);
  if (issues.length) return { ok: false, message: issues.join(' ') };

  const draft: CourseDraft = { ...current.draft, sections };
  if (!courseDraftSchema.safeParse(draft).success)
    return { ok: false, message: 'Tên hoặc mã section quá dài.' };

  try {
    const record = await store.saveCourse({
      courseId: input.courseId,
      draft,
      actorId: actor.userId,
      expectedRevision: input.expectedRevision,
    });
    const auditWarning = await recordAudit({
      actorId: actor.userId,
      operation: 'course.structure',
      targetId: input.courseId,
      beforeJson: JSON.stringify(current.draft.sections),
      afterJson: JSON.stringify(sections),
    });
    return { ok: true, revision: record.revision, warning: auditWarning ?? undefined };
  } catch (error) {
    if (error instanceof ConflictError || error instanceof StoreUnavailableError)
      return { ok: false, message: error.message };
    throw error;
  }
}
