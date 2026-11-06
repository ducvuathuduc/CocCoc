'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { toast } from 'sonner';
import { exportCourseToRepo, runContentGates } from '@/server/actions/build';
import { publishCourseVersion } from '@/server/actions/publish';
import { TechDetails } from '@/components/tech-details';
import type { CourseWorkflow } from '@/server/workflow';
import { STAGE_STATE } from '@/lib/stages';
import { button, card, hint, link, primary, warnBox } from '@/lib/ui';
import { cn, timeAgo } from '@/lib/utils';

/**
 * The three stages an author actually moves through, and exactly one action for the stage they are
 * standing in. Import, source-folder writes, raw logs and the server switch that gates publication
 * live in the advanced area underneath instead — the same gates still run, they are just not the
 * first thing a content editor is asked to press.
 */
export function WorkflowPanel({ workflow }: { workflow: CourseWorkflow }) {
  const router = useRouter();
  const [busy, setBusy] = useState<null | 'check' | 'publish'>(null);
  const [armed, setArmed] = useState(false);
  const [stale, setStale] = useState<string[]>([]);
  const { next, stages, gate, published } = workflow;
  const checked = stages.find((stage) => stage.key === 'checking')?.state === 'done';
  const needsSave =
    next.kind === 'save-check' || (next.kind === 'review' && workflow.awaitingValidation > 0);
  const canDryRun = !busy && checked && workflow.appwriteMode;

  async function runCheck() {
    setBusy('check');
    try {
      if (needsSave) {
        const saved = await exportCourseToRepo(workflow.courseId);
        if (!saved.ok) {
          toast.error(saved.message ?? 'Chưa lưu được bản nội dung.');
          return;
        }
        const leftover = saved.stale ?? [];
        if (leftover.length > 0) {
          setStale(leftover);
          toast.warning(
            `${leftover.length} tệp bài cũ trong thư mục nội dung không còn bài nào dùng tới.`,
          );
        } else setStale([]);
      }
      const run = await runContentGates(workflow.courseId);
      if (run.status === 'SUCCEEDED') toast.success(run.message);
      else toast.error(run.message);
      if (run.warning) toast.warning(run.warning);
      router.refresh();
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'Không gọi được máy chủ.');
    } finally {
      setBusy(null);
    }
  }

  async function publish(live: boolean) {
    setBusy('publish');
    setArmed(false);
    try {
      const result = await publishCourseVersion(workflow.courseId, live);
      if (result.ok)
        toast.success(live ? 'Đã xuất bản. Người học sẽ nhận bản này.' : 'Chạy thử xong, chưa xuất bản.');
      else toast.error(result.message ?? 'Chưa xuất bản được.');
      if (result.warning) toast.warning(result.warning);
      router.refresh();
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'Không gọi được máy chủ.');
    } finally {
      setBusy(null);
    }
  }

  return (
    <section className={cn(card, 'overflow-hidden')} aria-label="Quy trình soạn, kiểm tra, xuất bản">
      <ol className="grid gap-px bg-line md:grid-cols-3">
        {stages.map((stage, i) => {
          const tone = STAGE_STATE[stage.state];
          return (
            <li key={stage.key} className={cn('px-4 py-3', tone.box)}>
              <div className="flex items-center gap-2">
                <span className={cn('size-2 shrink-0 rounded-full', tone.dot)} />
                <span className="text-sm font-medium">
                  {i + 1}. {stage.label}
                </span>
                <span className="ml-auto text-[11px] text-fg-4">{tone.mark}</span>
              </div>
              <p className="mt-1 text-xs leading-relaxed text-fg-3">{stage.line}</p>
            </li>
          );
        })}
      </ol>

      <div className="border-t border-line px-4 py-4">
        <p className="text-xs uppercase tracking-wide text-fg-4">Việc tiếp theo</p>
        <div className="mt-2 flex flex-wrap items-center gap-2">
          <h2 className="text-base font-semibold">{next.label}</h2>
          {gate && (
            <span className={cn(hint, 'tabular-nums')}>
              {gate.ok ? 'Kiểm tra gần nhất đã qua' : 'Kiểm tra gần nhất chưa qua'} ·{' '}
              {timeAgo(gate.at)}
            </span>
          )}
        </div>
        <p className="mt-1 max-w-2xl text-sm text-fg-3">{next.note}</p>

        <div className="mt-4 flex flex-wrap items-center gap-2">
          {(next.kind === 'edit' || next.kind === 'structure' || next.kind === 'review') && (
            <Link
              href={next.href}
              transitionTypes={['nav-forward']}
              className={cn(primary, 'py-2')}
            >
              {next.label}
            </Link>
          )}

          {(next.kind === 'save-check' || next.kind === 'review') && (
            <button
              type="button"
              disabled={busy !== null}
              onClick={runCheck}
              className={cn(next.kind === 'save-check' ? primary : button, 'py-2')}
            >
              {busy === 'check'
                ? 'Đang chạy…'
                : next.kind === 'review'
                  ? needsSave
                    ? 'Lưu và kiểm tra lại'
                    : 'Kiểm tra lại'
                  : next.label}
            </button>
          )}

          {next.kind === 'publish' && !armed && (
            <button
              type="button"
              disabled={busy !== null}
              onClick={() => setArmed(true)}
              className={cn(primary, 'py-2')}
            >
              {next.label}
            </button>
          )}

          {next.kind === 'publish' && armed && (
            <div className="w-full animate-fade-up rounded-xl border border-danger-bd bg-danger-bg px-4 py-3">
              <p className="text-sm font-medium text-danger-fg">
                Bản này sẽ được đưa đến người học đang dùng app.
              </p>
              <p className="mt-1 text-sm text-danger-fg">
                App sẽ dùng {workflow.unitCount} bài học của bản này cho tới lần xuất bản sau. Bản cũ
                không bị xóa.
              </p>
              <div className="mt-3 flex flex-wrap gap-2">
                <button
                  type="button"
                  disabled={busy !== null}
                  onClick={() => publish(true)}
                  className={cn(primary, 'py-1.5')}
                >
                  {busy === 'publish' ? 'Đang xuất bản…' : 'Xuất bản ngay'}
                </button>
                <button
                  type="button"
                  onClick={() => setArmed(false)}
                  className={cn(button, 'py-1.5')}
                >
                  Quay lại
                </button>
              </div>
            </div>
          )}

          {(next.kind === 'publish' || next.kind === 'publish-locked') && canDryRun && !armed && (
            <button
              type="button"
              disabled={busy !== null}
              onClick={() => publish(false)}
              className={cn(button, 'py-2')}
            >
              {busy === 'publish' ? 'Đang chạy…' : 'Chạy thử trước (không ghi gì)'}
            </button>
          )}

          {next.kind === 'publish-locked' && (
            <p className={cn(hint, 'w-full')}>
              Cần người quản trị bật công tắc cho phép xuất bản ở máy chủ. Không có nội dung nào được
              gửi đi cho tới lúc đó.
            </p>
          )}
        </div>

        <p className="mt-3 text-xs">
          <Link href={`/courses/${workflow.courseId}/readiness`} className={link}>
            Xem mọi điều kiện xuất bản của khóa
          </Link>
        </p>

        {stale.length > 0 && (
          <div className={cn(warnBox, 'mt-3 text-left')}>
            <p className="font-medium">
              {stale.length} tệp bài trong thư mục nội dung không còn bài nào dùng tới
            </p>
            <p className="mt-1 text-xs">
              Bản dựng bỏ qua những tệp này, nhưng “Nhập từ thư mục nội dung gốc” thì không: nó sẽ
              dựng lại bài dưới tên cũ. Nhờ người quản lý nội dung xóa chúng trước khi nhập lại.
            </p>
            <TechDetails title="Tên tệp">
              <ul className="list-inside list-disc">
                {stale.map((file) => (
                  <li key={file}>{file}</li>
                ))}
              </ul>
            </TechDetails>
          </div>
        )}

        {workflow.checkAfterPublish && published && (
          <p className={cn(hint, 'mt-2')}>
            Bản kiểm tra gần nhất mới hơn bản app đang dùng ({timeAgo(published.at)}).
          </p>
        )}
      </div>
    </section>
  );
}
