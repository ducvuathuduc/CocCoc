import Link from 'next/link';
import { CreateCourse } from '@/components/create-course';
import { ImportCourseButton } from '@/components/import-course-button';
import { PageTransition } from '@/components/page-transition';
import { PublishBadge } from '@/components/publish-badge';
import { listCourseSummaries } from '@/server/queries';
import { repoCourseSources } from '@/server/repo-courses';
import { workspaceData } from '@/server/workspace';
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
  // One read per course: the landing shows the same numbers the workspace will, so a tile never
  // promises "12 bài" and then opens a course with a different count.
  const cards = await Promise.all(
    courses.map(async (course) => {
      const data = await workspaceData(course.courseId);
      return {
        course,
        units: data?.counts.total ?? 0,
        ready: data?.counts.ready ?? 0,
        words: data ? data.lessons.reduce((sum, lesson) => sum + lesson.vocab, 0) : 0,
        publish: data?.publish ?? null,
      };
    }),
  );
  // Authoring tables that exist in the repo but have no draft here yet — the import targets, read
  // from the folders instead of naming one course in the markup.
  const drafted = new Set(courses.map((course) => course.courseId));
  const importable = repoCourseSources().filter((source) => !drafted.has(source.courseId));

  return (
    <PageTransition>
      <div className="space-y-5">
        <header className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <p className="text-[11px] font-semibold tracking-[0.08em] text-fg-4 uppercase">
              Nội dung
            </p>
            <h1 className="mt-1 text-2xl font-semibold tracking-tight">Khóa học</h1>
            <p className={cn(hint, 'mt-1 text-sm')}>
              Mở một khóa để soạn bài, kiểm tra âm thanh và xuất bản cho app.
            </p>
          </div>
          {courses.length > 0 && <CreateCourse />}
        </header>

        {courses.length === 0 ? (
          <div className="space-y-4">
            <CreateCourse defaultOpen />
            {importable.length > 0 && (
              <div className={cn(card, 'animate-fade-in space-y-3 p-6')}>
                <div>
                  <h2 className="text-sm font-medium">Hoặc lấy khóa đã viết sẵn</h2>
                  <p className={cn(hint, 'mt-1 max-w-xl')}>
                    Những khóa dưới đây đã có bài viết trong thư mục nội dung gốc. Lấy lên để sửa
                    từng bài trên máy tính.
                  </p>
                </div>
                <div className="flex flex-wrap gap-4">
                  {importable.map((source) => (
                    <ImportCourseButton
                      key={`${source.courseId}/${source.version}`}
                      courseId={source.courseId}
                      version={source.version}
                      variant="quiet"
                    />
                  ))}
                </div>
              </div>
            )}
          </div>
        ) : (
          <div className="rise grid gap-3 sm:grid-cols-2">
            {cards.map(({ course, units, ready, words, publish }) => (
              <div key={course.courseId} className={cn(tile, 'flex flex-col gap-4 p-5')}>
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <h2 className="truncate text-base font-medium">{course.title}</h2>
                    <p className={cn(hint, 'mt-1')}>
                      {STATUS[course.status] ?? course.status} · {course.locales} · sửa lần cuối{' '}
                      {formatDateTime(course.updatedAt)}
                    </p>
                  </div>
                  {publish && <PublishBadge publish={publish} />}
                </div>

                <dl className="grid grid-cols-3 gap-2 border-t border-line pt-3">
                  <div>
                    <dt className="text-xs text-fg-4">Bài học</dt>
                    <dd className="text-lg font-semibold tabular-nums">{units}</dd>
                  </div>
                  <div>
                    <dt className="text-xs text-fg-4">Sẵn sàng</dt>
                    <dd
                      className={cn(
                        'text-lg font-semibold tabular-nums',
                        units > 0 && ready === units && 'text-ok-fg',
                      )}
                    >
                      {ready}/{units}
                    </dd>
                  </div>
                  <div>
                    <dt className="text-xs text-fg-4">Từ vựng</dt>
                    <dd className="text-lg font-semibold tabular-nums">{words}</dd>
                  </div>
                </dl>

                <div className="mt-auto flex flex-wrap gap-2">
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

        {courses.length > 0 && importable.length > 0 && (
          <div className={cn(card, 'space-y-3 p-5')}>
            <div>
              <h2 className="text-sm font-medium">Khóa còn trong thư mục nội dung gốc</h2>
              <p className={cn(hint, 'mt-1 max-w-xl')}>
                Chưa có bản soạn ở đây. Lấy lên nếu bạn muốn sửa bằng giao diện này.
              </p>
            </div>
            <div className="flex flex-wrap gap-4">
              {importable.map((source) => (
                <ImportCourseButton
                  key={`${source.courseId}/${source.version}`}
                  courseId={source.courseId}
                  version={source.version}
                  variant="quiet"
                />
              ))}
            </div>
          </div>
        )}
      </div>
    </PageTransition>
  );
}

export async function generateMetadata() {
  return { title: 'Danh sách khóa học' };
}
