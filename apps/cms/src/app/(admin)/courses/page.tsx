import Link from 'next/link';
import { ImportCourseButton } from '@/components/import-course-button';
import { PageTransition } from '@/components/page-transition';
import { listCourseSummaries, toUnitStat } from '@/server/queries';
import { requireAdmin } from '@/server/session';
import { cn, formatDateTime } from '@/lib/utils';
import { big, card, hint, primary, quiet, tile } from '@/lib/ui';

export const instant = false;

const STATUS: Record<string, string> = {
  DRAFT: 'Bản nháp',
  // The repo table flags this course as the one the generator builds; it says nothing about what the
  // app has actually been given, so the label cannot claim the app is using it.
  ACTIVE: 'Bản soạn đang hoạt động',
  RETIRED: 'Đã ngừng dùng',
};

export default async function CoursesPage() {
  await requireAdmin();
  const courses = await listCourseSummaries();

  return (
    <PageTransition>
      <div className="space-y-5">
        <header>
          <h1 className="text-2xl font-semibold tracking-tight">Tất cả khóa học</h1>
          <p className={cn(hint, 'mt-1 text-sm')}>Mở một khóa để xem danh sách bài học.</p>
        </header>

        {courses.length === 0 ? (
          <div className={cn(card, 'animate-fade-in p-6')}>
            <h2 className="text-sm font-medium">Chưa có bài nào ở đây</h2>
            <p className="mt-2 max-w-xl text-sm text-fg-3">
              Bộ bài tiếng Anh cho người Việt đã được viết sẵn trong repo. Lấy nó lên để sửa từng
              bài trên máy tính.
            </p>
            <div className="mt-5">
              <ImportCourseButton courseId="vi_en" />
            </div>
          </div>
        ) : (
          <div className="rise grid gap-3 sm:grid-cols-2">
            {courses.map((course) => (
              <div key={course.courseId} className={cn(tile, 'flex flex-col gap-3 p-5')}>
                <div className="min-w-0">
                  <h2 className="truncate text-base font-medium">{course.title}</h2>
                  <p className={cn(hint, 'mt-1')}>
                    {STATUS[course.status] ?? course.status} · sửa lần cuối{' '}
                    {formatDateTime(course.updatedAt)}
                  </p>
                </div>
                <div className="flex flex-wrap gap-2">
                  <Link
                    href={`/courses/${course.courseId}`}
                    transitionTypes={['nav-forward']}
                    className={cn(primary, big)}
                  >
                    Soạn bài
                  </Link>
                  <Link
                    href={`/courses/${course.courseId}/readiness`}
                    transitionTypes={['nav-forward']}
                    className={quiet}
                  >
                    Việc còn chờ
                  </Link>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </PageTransition>
  );
}

export async function generateMetadata() {
  return { title: 'Danh sách khóa học' };
}

export { toUnitStat };
