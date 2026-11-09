'use server';

import type { JumpLesson } from '@/components/quick-jump';
import { listCourseSummaries, unitIndex } from '@/server/queries';
import { assertAdmin } from '@/server/session';

/**
 * The jump palette loads its index on first open, not with every page: the chrome must not wait on
 * a list nobody asked for. Only the four navigation columns are read — never the draft payloads.
 */
export async function jumpIndex(): Promise<JumpLesson[]> {
  await assertAdmin();
  const courses = await listCourseSummaries();
  const lists = await Promise.all(courses.map((course) => unitIndex(course.courseId)));
  return courses.flatMap((course, i) =>
    lists[i].map((unit) => ({
      courseId: course.courseId,
      unitId: unit.unitId,
      order: unit.order,
      title: unit.title,
      theme: unit.theme,
    })),
  );
}