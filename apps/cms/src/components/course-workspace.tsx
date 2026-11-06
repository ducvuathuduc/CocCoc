import Link from 'next/link';
import { LessonList } from '@/components/lesson-list';
import { NewUnitForm } from '@/components/course-tools';
import { PageTransition } from '@/components/page-transition';
import { TechDetails } from '@/components/tech-details';
import { courseWorkflow, type CourseWorkflow, type StageView } from '@/server/workflow';
import { workspaceData } from '@/server/workspace';
import { STAGE_STATE } from '@/lib/stages';
import { card, hint, primary, warnBox } from '@/lib/ui';
import { cn, timeAgo } from '@/lib/utils';

const TOOLS = [
  {
    href: 'structure',
    label: 'Cấu trúc & thông tin khóa',
    hint: 'Các phần học, tên khóa, thứ tự bài',
  },
  { href: 'media', label: 'Âm thanh & ảnh', hint: 'File chưa có, file chưa dùng được' },
  { href: 'search', label: 'Tìm & thay thế', hint: 'Tìm một từ trong cả khóa' },
  { href: 'readiness', label: 'Điều kiện xuất bản', hint: 'Còn gì chưa xong' },
];

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
          <div className="flex flex-wrap items-end justify-between gap-x-6 gap-y-2">
            <div className="min-w-0">
              <h1 className="truncate text-2xl font-semibold tracking-tight">{course.title}</h1>
              <p className={cn(hint, 'mt-1 text-sm')}>
                {counts.total} bài học · {words} từ · {sentences} câu
                {lastEdited && <> · sửa {timeAgo(lastEdited.updatedAt)}</>}
              </p>
            </div>
            <Link
              href={`/builds?course=${courseId}`}
              transitionTypes={['nav-forward']}
              className="text-sm text-fg-3 hover:text-primary-text"
            >
              Xuất bản →
            </Link>
          </div>
        </header>

        {!publish.appwriteMode && (
          <div className={warnBox}>
            Bản soạn chỉ lưu trên máy này; người khác không thấy và chưa gửi lên app được.
            <TechDetails title="Dành cho người quản trị máy chủ">
              Dữ liệu nằm trong <code className="rounded bg-elevated px-1 py-0.5">.cms-data/</code>.
              Bản dùng chung cần <code>APPWRITE_ENDPOINT</code>, <code>APPWRITE_PROJECT_ID</code>,{' '}
              <code>APPWRITE_API_KEY</code>.
            </TechDetails>
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

        <details className={cn(card, 'px-4 py-3')}>
          <summary className="cursor-pointer text-sm font-medium text-fg-2 hover:text-fg">
            Công cụ khóa
          </summary>
          <p className={cn(hint, 'mt-1')}>
            Dùng khi cần sửa cấu trúc, kiểm tra âm thanh hoặc xem điều kiện xuất bản.
          </p>
          <div className="mt-3 grid gap-2 sm:grid-cols-2">
            {TOOLS.map((tool) => (
              <Link
                key={tool.href}
                href={`/courses/${courseId}/${tool.href}`}
                transitionTypes={['nav-forward']}
                className="rounded-lg border border-line px-3 py-2 transition-colors hover:border-line-strong hover:bg-elevated"
              >
                <span className="block text-sm font-medium">{tool.label}</span>
                <span className="block text-xs text-fg-4">{tool.hint}</span>
              </Link>
            ))}
          </div>
        </details>
      </div>
    </PageTransition>
  );
}
