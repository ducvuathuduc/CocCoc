import { redirect } from 'next/navigation';
import { CourseWorkspace } from '@/components/course-workspace';
import { listCourseSummaries } from '@/server/queries';
import { requireAdmin } from '@/server/session';

export const instant = false;

export const metadata = { title: 'Bài học' };

/**
 * One course means one workspace: a teacher lands on the lesson list instead of a screen that
 * asks which course to open. More than one course still goes through the course list.
 */
export default async function LessonsPage() {
  await requireAdmin();
  const courses = await listCourseSummaries();
  if (courses.length !== 1) redirect('/courses');
  return <CourseWorkspace courseId={courses[0].courseId} />;
}
