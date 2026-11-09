import Link from 'next/link';
import { LessonList } from '@/components/lesson-list';
import { CourseTabs } from '@/components/course-tabs';
import { PublishBadge } from '@/components/publish-badge';
import { NewUnitForm } from '@/components/course-tools';
import { PageTransition } from '@/components/page-transition';
import { courseWorkflow, type CourseWorkflow, type StageView } from '@/server/workflow';
import { workspaceData } from '@/server/workspace';
import { STAGE_STATE } from '@/lib/stages';
import { card, hint, primary, warnBox } from '@/lib/ui';
import { cn, timeAgo } from '@/lib/utils';

function Step({
  n,
  stage,
  action,
}: {
  n: number;
  stage: StageView;
  action?: { href: string; label: string };
}) {
  const tone = STAGE_STATE[stage.state];
  return (
    <li
      className={cn(
        'rounded-xl border px-4 py-3',
        tone.box,
        action && 'ring-1 ring-primary/40',
      )}
      aria-current={action ? 'step' : undefined}
    >
      <div className="flex items-center gap-2">
        <span className={cn('size-2 shrink-0 rounded-full', tone.dot)} />
        <span className="text-sm font-medium">
          {n}. {stage.label}
        </span>
        <span className="ml-auto shrink-0 text-[11px] text-fg-4">{tone.mark}</span>
      </div>
      <p className="mt-1.5 text-xs leading-relaxed text-fg-3">{stage.line}</p>
      {action && (
        <>
          <p className="mt-2 text-[10px] uppercase tracking-wide text-fg-4">Việc tiếp theo</p>
          <Link
            href={action.href}
            transitionTypes={['nav-forward']}
            className="mt-0.5 inline-flex text-xs font-medium text-primary-text hover:underline"
          >
            {action.label} →
          </Link>
        </>
      )}
    </li>
  );
}

/** The same stage reading the check-and-publish screen uses, so the two can never disagree. */
function Flow({ workflow }: { workflow: CourseWorkflow }) {
  const { stages, next } = workflow;
  return (
    <ol className="grid gap-2 md:grid-cols-3" aria-label="Tiến trình soạn và xuất bản">
      {stages.map((stage, i) => (
        <Step
          key={stage.key}
          n={i + 1}
          stage={stage}
          action={
            next.stage === stage.key ? { href: next.href, label: next.label } : undefined
          }
        />
      ))}
    </ol>
  );
}

/** One number with a plain-language label: the teacher reads "12 bài" before opening anything. */
function Stat({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex flex-col">
      <span className="text-xl font-semibold tabular-nums tracking-tight">{value}</span>
      <span className="text-xs text-fg-4">{label}</span>
    </div>
  );
}

export async function CourseWorkspace({
  courseId,
  showAllCourses = false,
}: {
  courseId: string;
  showAllCourses?: boolean;
}) {
  const data = await workspaceData(courseId);
  if (!data) return null;
  const workflow = await courseWorkflow(courseId, data);

  const { course, lessons, counts, lastEdited, publish } = data;
  const words = lessons.reduce((sum, lesson) => sum + lesson.vocab, 0);
  const sentences = lessons.reduce((sum, lesson) => sum + lesson.sentences, 0);

  return (
    <PageTransition>
      <div className="space-y-5">
        <header>
          {showAllCourses && (
            <Link
              href="/courses"
              transitionTypes={['nav-back']}
              className="mb-2 inline-block text-sm text-fg-3 hover:text-primary-text"
            >
              ← Tất cả khóa học
            </Link>
          )}
          <div className="flex flex-wrap items-start justify-between gap-x-6 gap-y-2">
            <div className="min-w-0">
              <h1 className="truncate text-2xl font-semibold tracking-tight">{course.title}</h1>
              <p className={cn(hint, 'mt-1 text-sm')}>
                {course.locales} · cập nhật {timeAgo(course.updatedAt)}
                {lastEdited && <> · sửa {timeAgo(lastEdited.updatedAt)}</>}
              </p>
            </div>
            <PublishBadge publish={publish} />
          </div>
        </header>

        <CourseTabs courseId={courseId} />

        <div className={cn(card, 'flex flex-wrap items-center gap-x-8 gap-y-3 px-5 py-4')}>
          <Stat label="Bài học" value={counts.total} />
          <Stat
            label="Sẵn sàng"
            value={
              <span className={cn(counts.total > 0 && counts.ready === counts.total && 'text-ok-fg')}>
                {counts.ready}/{counts.total}
              </span>
            }
          />
          <Stat label="Từ vựng" value={words} />
          <Stat label="Câu" value={sentences} />
          {(counts.errors > 0 || counts.warnings > 0) && (
            <Stat
              label="Cần sửa"
              value={
                <span className="text-warn-fg">
                  {counts.errors > 0 && <>{counts.errors} lỗi</>}
                  {counts.errors > 0 && counts.warnings > 0 && ' · '}
                  {counts.warnings > 0 && <>{counts.warnings} cảnh báo</>}
                </span>
              }
            />
          )}
        </div>

        {!publish.appwriteMode && (
          <div className={warnBox}>
            Bản soạn chỉ lưu trên máy này; người khác không thấy và chưa gửi lên app được.
          </div>
        )}

        {workflow && <Flow workflow={workflow} />}

        <section aria-labelledby="lessons-title">
          <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
            <h2 id="lessons-title" className="text-base font-medium">
              Bài học <span className="ml-1 text-xs font-normal text-fg-4">{counts.total}</span>
            </h2>
            <details className="w-full sm:w-auto">
              <summary
                className={cn(
                  primary,
                  'inline-flex min-h-10 w-full cursor-pointer list-none items-center justify-center [&::-webkit-details-marker]:hidden sm:w-auto',
                )}
              >
                + Thêm bài học
              </summary>
              <div className={cn(card, 'mt-2 p-3')}>
                <NewUnitForm courseId={courseId} />
              </div>
            </details>
          </div>

          {counts.total === 0 ? (
            <div className={cn(card, 'p-6')}>
              <p className="text-sm font-medium">Chưa có bài học nào.</p>
              <p className={cn(hint, 'mt-1')}>
                Bấm “+ Thêm bài học” ở trên để đặt tên cho bài đầu tiên.
              </p>
            </div>
          ) : (
            <LessonList courseId={courseId} lessons={lessons} />
          )}
        </section>
      </div>
    </PageTransition>
  );
}
