import { Sidebar } from './sidebar';
import { courseUnitStats, listCourseSummaries } from '@/server/queries';
import { requireAdmin } from '@/server/session';
import { storeLabel } from '@/server/audit';

export async function SidebarNav() {
  const identity = await requireAdmin();
  const courses = await listCourseSummaries();
  const stats = await Promise.all(
    courses.map(async (course) => ({ course, units: await courseUnitStats(course.courseId) })),
  );
  const lessons = stats.flatMap(({ course, units }) =>
    units.map((unit) => ({
      courseId: course.courseId,
      unitId: unit.unitId,
      order: unit.order,
      title: unit.title,
      theme: unit.theme,
    })),
  );
  return <Sidebar identity={identity.email || identity.userId} mode={storeLabel()} lessons={lessons} />;
}
