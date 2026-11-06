import Link from 'next/link';
import { CourseWorkspace } from '@/components/course-workspace';
import { ImportCourseButton } from '@/components/import-course-button';
import { PageTransition } from '@/components/page-transition';
import { getCourseRecord } from '@/server/queries';
import { requireAdmin } from '@/server/session';
import { card, hint } from '@/lib/ui';
import { cn } from '@/lib/utils';

export const instant = false;

export default async function CoursePage({ params }: { params: Promise<{ courseId: string }> }) {
  const { courseId } = await params;
  await requireAdmin();
  const course = await getCourseRecord(courseId);

  if (!course) {
    return (
      <PageTransition>
        <div className="space-y-5">
          <Link
            href="/courses"
            transitionTypes={['nav-back']}
            className="inline-block text-sm text-fg-3 hover:text-primary-text"
          >
            ← Tất cả khóa học
          </Link>
          <div className={cn(card, 'p-6')}>
            <h1 className="text-xl font-semibold tracking-tight">Khóa {courseId}</h1>
            <p className={cn(hint, 'mt-2 max-w-xl text-sm')}>
              Khóa này chưa có nội dung trong CMS. Lấy các bài đã soạn sẵn trong thư mục nội dung gốc
              để bắt đầu sửa.
            </p>
            <div className="mt-5">
              <ImportCourseButton courseId={courseId} />
            </div>
          </div>
        </div>
      </PageTransition>
    );
  }

  return <CourseWorkspace courseId={courseId} showAllCourses />;
}

export async function generateMetadata({ params }: { params: Promise<{ courseId: string }> }) {
  const { courseId } = await params;
  const course = await getCourseRecord(courseId);
  const name = course?.draft.course.title.trim();
  return { title: name ? `Khóa ${name}` : `Khóa ${courseId}` };
}
