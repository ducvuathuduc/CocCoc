import { ShellNav } from './shell';
import { courseUnitStats, listCourseSummaries } from '@/server/queries';
import { learnerQueue } from '@/server/ops/learners';
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

  // The bell counts what is still unanswered. A learner-data outage must not take
  // the chrome down with it, so a failed read is simply "no badge".
  let inboxCount = 0;
  try {
    const queue = await learnerQueue();
    inboxCount = queue.feedback.length + queue.userReports.length + queue.contentReports.length;
  } catch {
    inboxCount = 0;
  }

  return (
    <ShellNav
      identity={identity.email || identity.userId}
      mode={storeLabel()}
      lessons={lessons}
      inboxCount={inboxCount}
    />
  );
}
