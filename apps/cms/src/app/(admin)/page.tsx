import { redirect } from 'next/navigation';
import { Overview } from '@/components/overview';
import { PageTransition } from '@/components/page-transition';
import { learnerOverview, openQueue } from '@/server/ops/overview';
import { listCourseSummaries } from '@/server/queries';
import { requireAdmin } from '@/server/session';
import { courseWorkflow } from '@/server/workflow';
import { workspaceData } from '@/server/workspace';

export const instant = false;

export const metadata = { title: 'Tổng quan' };

/**
 * The landing screen answers two questions — "how is the product doing?" and "what do I do now?" — from
 * two independent reads: the draft store (content) and Appwrite (learners). With more than one course
 * there is no single journey to show, so the course list decides first.
 */
export default async function HomePage() {
  await requireAdmin();
  const courses = await listCourseSummaries();
  if (courses.length !== 1) redirect('/courses');
  const courseId = courses[0].courseId;
  const data = await workspaceData(courseId);
  if (!data) redirect('/courses');
  const [workflow, stats, queue] = await Promise.all([
    courseWorkflow(courseId, data),
    learnerOverview(),
    openQueue(),
  ]);
  if (!workflow) redirect('/courses');
  return (
    <PageTransition>
      <Overview data={data} workflow={workflow} stats={stats} queue={queue} />
    </PageTransition>
  );
}
