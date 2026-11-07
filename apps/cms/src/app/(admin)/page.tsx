import { redirect } from 'next/navigation';
import { Dashboard } from '@/components/dashboard';
import { PageTransition } from '@/components/page-transition';
import { listCourseSummaries } from '@/server/queries';
import { requireAdmin } from '@/server/session';
import { courseWorkflow } from '@/server/workflow';
import { workspaceData } from '@/server/workspace';

export const instant = false;

export const metadata = { title: 'Tổng quan' };

/**
 * The landing screen answers one question — "what do I do now?" — from the real
 * draft store, then hands over to the lesson workspace at /lessons. With more than
 * one course there is no single journey to show, so the course list decides first.
 */
export default async function HomePage() {
  await requireAdmin();
  const courses = await listCourseSummaries();
  if (courses.length !== 1) redirect('/courses');
  const courseId = courses[0].courseId;
  const data = await workspaceData(courseId);
  const workflow = data ? await courseWorkflow(courseId, data) : null;
  if (!data || !workflow) redirect('/courses');
  return (
    <PageTransition>
      <Dashboard data={data} workflow={workflow} />
    </PageTransition>
  );
}
