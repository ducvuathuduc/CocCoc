import Link from 'next/link';
import { ViewTransition } from 'react';
import { ContentActions } from '@/components/content-actions';
import { VersionHistorySection } from '@/components/version-history-section';
import { PageTransition } from '@/components/page-transition';
import { WorkflowPanel } from '@/components/workflow-panel';
import { buildRuns, isDryRunPublish, listCourseSummaries } from '@/server/queries';
import type { BuildRun } from '@/cms/types';
import { requireAdmin } from '@/server/session';
import { courseWorkflow } from '@/server/workflow';
import { cn, formatDateTime } from '@/lib/utils';
import { card, hint, link } from '@/lib/ui';

export const metadata = { title: 'Kiểm tra và xuất bản' };

const STATUS: Record<string, string> = {
  SUCCEEDED: 'bg-ok-bg text-ok-fg ring-ok-bd',
  FAILED: 'bg-danger-bg text-danger-fg ring-danger-bd',
  RUNNING: 'bg-warn-bg text-warn-fg ring-warn-bd',
};

const KIND: Record<string, string> = {
  GATES: 'Kiểm tra tự động',
  PUBLISH: 'Xuất bản cho app',
};

const OUTCOME: Record<string, string> = {
  SUCCEEDED: 'Thành công',
  FAILED: 'Chưa qua',
  RUNNING: 'Đang chạy…',
};

/** A dry run proved the content but reached no learner, so it must not read like a release. */
function runLabel(run: BuildRun): string {
  const outcome = OUTCOME[run.status] ?? run.status;
  if (isDryRunPublish(run)) return `Chạy thử xuất bản · ${outcome}`;
  return `${KIND[run.kind] ?? run.kind} · ${outcome}`;
}

export const instant = false;

export default async function BuildsPage({
  searchParams,
}: {
  searchParams: Promise<{ course?: string }>;
}) {
  await requireAdmin();
  const { course } = await searchParams;
  const courses = await listCourseSummaries();
  const courseId = courses.some((c) => c.courseId === course)
    ? (course as string)
    : courses[0]?.courseId;
  const runs = courseId ? await buildRuns(courseId) : [];
  const workflow = courseId ? await courseWorkflow(courseId) : null;

  return (
    <PageTransition>
      <div className="space-y-5">
        <header>
          <h1 className="text-2xl font-semibold tracking-tight">
            {workflow ? `${workflow.title}: kiểm tra và xuất bản` : 'Kiểm tra và xuất bản'}
          </h1>
          <p className="mt-1 text-sm text-fg-3">
            Ba bước theo thứ tự: soạn bài, kiểm tra, rồi cho app nhận bản. Trang này chỉ gợi ý một
            việc tiếp theo, không phải tám nút cùng lúc.
          </p>
        </header>

        {courses.length === 0 ? (
          <div className={cn(card, 'animate-fade-in p-6 text-sm text-fg-3')}>
            Chưa có khóa học nào ở đây. Vào{' '}
            <Link href="/courses" className={link}>
              danh sách khóa học
            </Link>{' '}
            để nhập nội dung có sẵn.
          </div>
        ) : (
          <>
            {courses.length > 1 && (
              <div className="flex flex-wrap items-center gap-2">
                {courses.map((c) => (
                  <Link
                    key={c.courseId}
                    href={`/builds?course=${c.courseId}`}
                    aria-current={c.courseId === courseId ? 'page' : undefined}
                    className={cn(
                      'rounded-lg px-3 py-1.5 text-sm active:scale-[0.98]',
                      c.courseId === courseId
                        ? 'bg-primary-soft font-medium text-primary-text'
                        : 'text-fg-3 hover:bg-elevated hover:text-fg',
                    )}
                  >
                    {c.title}
                  </Link>
                ))}
              </div>
            )}

            {/* Same route, another course: crossfade, because the location did
                not change — only the content inside it. */}
            <ViewTransition
              key={courseId}
              name="build-course"
              share="auto"
              enter="auto"
              default="none"
            >
              {workflow && courseId && <WorkflowPanel workflow={workflow} />}
            </ViewTransition>

            {courseId && (
              <>
                <section className={cn(card, 'space-y-3 p-4')}>
                  <h2 className="text-sm font-medium">Các bản đã đưa lên app</h2>
                  <p className={hint}>
                    Mỗi lần cho app nhận là một bản. Bản cũ không bao giờ bị xóa: gỡ bản đang chạy
                    làm khóa biến mất khỏi app, ngừng dùng hẳn thì bản đó không bao giờ chạy lại,
                    còn quay lại là chọn một bản cũ làm bản đang chạy.
                  </p>
                  <VersionHistorySection courseId={courseId} />
                </section>

                <ContentActions courseId={courseId} />

                <section className={cn(card, 'space-y-2 p-4')}>
                  <h2 className="text-sm font-medium">
                    Những lần kiểm tra và xuất bản trước ({runs.length})
                  </h2>
                  {runs.length === 0 ? (
                    <p className="text-xs text-fg-4">
                      Khóa này chưa được kiểm tra lần nào. Bấm việc tiếp theo ở trên.
                    </p>
                  ) : (
                    <ul className="rise divide-y divide-line">
                      {runs.map((run) => (
                        <li key={run.runId} className="py-2">
                          <div className="flex flex-wrap items-center justify-between gap-2 text-sm">
                            <span
                              className={cn(
                                'rounded-full px-2 py-0.5 text-xs font-medium ring-1',
                                STATUS[run.status] ??
                                  'bg-primary-soft text-primary-text ring-transparent',
                              )}
                            >
                              {runLabel(run)}
                            </span>
                            <span className="text-xs tabular-nums text-fg-4">
                              {formatDateTime(run.createdAt)}
                            </span>
                          </div>
                          <p className="mt-1 text-sm text-fg-2">{run.message}</p>
                        </li>
                      ))}
                    </ul>
                  )}
                </section>
              </>
            )}
          </>
        )}
      </div>
    </PageTransition>
  );
}
