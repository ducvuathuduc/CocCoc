import Link from 'next/link';
import type { CourseWorkflow } from '@/server/workflow';
import type { WorkspaceData, WorkspaceLesson } from '@/server/workspace';
import { big, circle, hint, panel, primary } from '@/lib/ui';
import { cn, timeAgo } from '@/lib/utils';

const STATE_PILL: Record<WorkspaceLesson['state'], { label: string; cls: string; dot: string }> = {
  ready: { label: 'Sẵn sàng', cls: 'bg-ok-bg text-ok-fg', dot: 'var(--ok-fg)' },
  warning: { label: 'Cần xem lại', cls: 'bg-warn-bg text-warn-fg', dot: 'var(--warn-fg)' },
  error: { label: 'Có lỗi', cls: 'bg-danger-bg text-danger-fg', dot: 'var(--danger-fg)' },
  empty: { label: 'Chưa có nội dung', cls: 'bg-elevated text-fg-3', dot: 'var(--line-strong)' },
};

function Chevron() {
  return (
    <svg
      viewBox="0 0 20 20"
      className="size-4 shrink-0 text-fg-4"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.6"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="m7.5 5 5 5-5 5" />
    </svg>
  );
}

function StepRow({
  href,
  mark,
  tone,
  title,
  sub,
}: {
  href?: string;
  mark: string;
  tone: string;
  title: string;
  sub?: string;
}) {
  const inner = (
    <>
      <span
        className={cn(
          'flex size-8 shrink-0 items-center justify-center rounded-full text-[11px] font-semibold',
          tone,
        )}
      >
        {mark}
      </span>
      <span className="min-w-0 flex-1">
        <span className="block truncate text-[13px] font-medium">{title}</span>
        {sub && <span className="block truncate text-[11px] text-fg-4">{sub}</span>}
      </span>
      {href && <Chevron />}
    </>
  );
  const cls = 'flex items-center gap-2.5 rounded-xl bg-card p-2.5 shadow-card';
  return href ? (
    <Link href={href} transitionTypes={['nav-forward']} className={cn(cls, 'hover:-translate-y-px hover:shadow-lift')}>
      {inner}
    </Link>
  ) : (
    <div className={cls}>{inner}</div>
  );
}

function Column({ caption, children }: { caption: string; children: React.ReactNode }) {
  return (
    <div className="flex flex-col">
      <div className="flex flex-1 flex-col gap-2 rounded-2xl bg-elevated/70 p-2.5">{children}</div>
      <p className="mt-2 text-center text-xs font-medium text-fg-3">{caption}</p>
    </div>
  );
}

function Donut({
  value,
  total,
  color,
  label,
}: {
  value: number;
  total: number;
  color: string;
  label: string;
}) {
  const radius = 34;
  const around = 2 * Math.PI * radius;
  const filled = total === 0 ? 0 : (value / total) * around;
  return (
    <div className="flex flex-col items-center">
      <div className="relative">
        <svg viewBox="0 0 80 80" className="size-28 -rotate-90">
          <circle cx="40" cy="40" r={radius} fill="none" strokeWidth="13" style={{ stroke: 'var(--elevated)' }} />
          {filled > 0 && (
            <circle
              cx="40"
              cy="40"
              r={radius}
              fill="none"
              strokeWidth="13"
              strokeLinecap="round"
              strokeDasharray={`${filled} ${around}`}
              style={{ stroke: color }}
            />
          )}
        </svg>
        <span className="absolute top-0 left-0 flex size-7 items-center justify-center rounded-full bg-card text-xs font-semibold shadow-card">
          {value}
        </span>
      </div>
      <span className="mt-1.5 text-xs font-medium text-fg-2">{label}</span>
      <span className="text-[11px] text-fg-4">
        {total === 0 ? 'chưa có bài' : `${value}/${total} bài`}
      </span>
    </div>
  );
}

/**
 * The overview screen. Every number on it is read from the draft store or the run
 * history through `workspaceData`/`courseWorkflow`, so the board can only show a
 * state the backend actually holds — the same rule the rest of the CMS follows.
 */
export function Dashboard({
  data,
  workflow,
}: {
  data: WorkspaceData;
  workflow: CourseWorkflow;
}) {
  const problems = data.lessons.filter((lesson) => lesson.state !== 'ready');
  const recent = [...data.lessons]
    .sort((a, b) => Date.parse(b.updatedAt) - Date.parse(a.updatedAt))
    .slice(0, 6);
  const cluster = data.lessons.slice(0, 8);
  const gate = workflow.gate;
  const published = workflow.published;

  return (
    <div className="rise space-y-5">
      <header className="flex flex-wrap items-end gap-3">
        <div className="min-w-0">
          <h1 className="text-3xl font-semibold tracking-tight">Bảng điều khiển</h1>
          <p className={cn(hint, 'mt-1 max-w-2xl text-sm')}>
            Khóa “{workflow.title}” đang ở đâu trong Soạn bài → Kiểm tra → Xuất bản, và việc cần làm
            hôm nay. Mọi con số đếm từ bản soạn thật, không có số ước đoán.
          </p>
        </div>
        <Link
          href={workflow.next.href}
          transitionTypes={['nav-forward']}
          className={cn(primary, big, 'ml-auto')}
        >
          {workflow.next.label} →
        </Link>
      </header>

      <section className={cn(panel, 'p-4 sm:p-6')} aria-label="Hành trình của khóa">
        <div className="flex flex-wrap items-center gap-3">
          <h2 className="text-base font-semibold">Hành trình xuất bản</h2>
          <div className="mx-auto hidden items-center -space-x-2 md:flex" aria-hidden="true">
            {cluster.map((lesson) => (
              <span
                key={lesson.unitId}
                title={`Bài ${lesson.order + 1} · ${lesson.title}`}
                className="flex size-9 items-center justify-center rounded-full border-2 border-card text-[11px] font-semibold text-white"
                style={{ background: STATE_PILL[lesson.state].dot }}
              >
                {lesson.order + 1}
              </span>
            ))}
            {data.lessons.length > cluster.length && (
              <span className="flex size-9 items-center justify-center rounded-full border-2 border-card bg-elevated text-[11px] font-semibold text-fg-3">
                +{data.lessons.length - cluster.length}
              </span>
            )}
          </div>
          <div className="ml-auto flex gap-2 md:ml-0">
            <Link href="/lessons" title="Mở danh sách bài học" className={circle}>
              <svg viewBox="0 0 20 20" className="size-4.5" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                <path d="M5 4.5h8.5A1.5 1.5 0 0 1 15 6v9.5H6.5A1.5 1.5 0 0 1 5 14zM5 14a2 2 0 0 1 2-2h8" />
              </svg>
            </Link>
            <Link href="/builds" title="Kiểm tra và xuất bản" className={circle}>
              <svg viewBox="0 0 20 20" className="size-4.5" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                <path d="M10 13V4M6.5 7.5 10 4l3.5 3.5M4 15.5h12" />
              </svg>
            </Link>
          </div>
        </div>

        <div className="relative mt-5">
          <div
            className="pointer-events-none absolute inset-x-8 top-[40%] hidden border-t-2 border-dashed border-line-strong/50 xl:block"
            aria-hidden="true"
          />
          <div className="relative grid gap-3 md:grid-cols-2 xl:grid-cols-4">
            <Column caption="Soạn bài">
              {problems.length === 0 ? (
                <StepRow
                  mark="✓"
                  tone="bg-ok-bg text-ok-fg"
                  title={`Cả ${data.counts.total} bài đã soạn`}
                  sub="Không còn lỗi nào trong bộ kiểm tra của CMS"
                />
              ) : (
                problems.slice(0, 4).map((lesson) => (
                  <StepRow
                    key={lesson.unitId}
                    href={`/courses/${workflow.courseId}/units/${lesson.unitId}`}
                    mark={lesson.state === 'empty' ? '+' : lesson.order + 1 > 9 ? '!' : String(lesson.order + 1)}
                    tone={
                      lesson.state === 'error'
                        ? 'bg-danger-bg text-danger-fg'
                        : lesson.state === 'empty'
                          ? 'bg-elevated text-fg-3'
                          : 'bg-warn-bg text-warn-fg'
                    }
                    title={`Bài ${lesson.order + 1} · ${lesson.title || '(chưa đặt tên)'}`}
                    sub={
                      lesson.state === 'error'
                        ? `${lesson.errors} lỗi cần sửa`
                        : lesson.state === 'empty'
                          ? 'Chưa có từ vựng và câu'
                          : `${lesson.warnings} điểm cần xem lại`
                    }
                  />
                ))
              )}
              {problems.length > 4 && (
                <Link href="/lessons" className="px-1 text-[11px] text-fg-4 hover:text-primary-text hover:underline">
                  và {problems.length - 4} bài khác…
                </Link>
              )}
            </Column>

            <Column caption="Kiểm tra">
              <StepRow
                href="/builds"
                mark={gate ? (gate.ok ? '✓' : '!') : '•'}
                tone={
                  gate ? (gate.ok ? 'bg-ok-bg text-ok-fg' : 'bg-danger-bg text-danger-fg') : 'bg-elevated text-fg-3'
                }
                title={gate ? (gate.ok ? 'Lần kiểm tra gần nhất đã đạt' : 'Lần kiểm tra gần nhất chưa đạt') : 'Chưa kiểm tra lần nào'}
                sub={gate ? timeAgo(gate.at) : 'Bước kiểm tra đọc lại toàn bộ bài đã lưu'}
              />
              <StepRow
                href="/lessons"
                mark={workflow.awaitingValidation > 0 ? '!' : '✓'}
                tone={workflow.awaitingValidation > 0 ? 'bg-warn-bg text-warn-fg' : 'bg-ok-bg text-ok-fg'}
                title={
                  workflow.awaitingValidation > 0
                    ? `${workflow.awaitingValidation} bài sửa sau lần kiểm tra`
                    : 'Bản đã kiểm tra khớp bản đã lưu'
                }
                sub={workflow.awaitingValidation > 0 ? 'Cần lưu và kiểm tra lại' : 'Không có gì chờ xác nhận'}
              />
            </Column>

            <Column caption="Xuất bản">
              <StepRow
                href="/builds"
                mark={published ? '✓' : '•'}
                tone={published ? 'bg-ok-bg text-ok-fg' : 'bg-elevated text-fg-3'}
                title={published ? `App đang dùng bản ${published.version}` : 'Chưa xuất bản lần nào'}
                sub={published ? timeAgo(published.at) : workflow.appwriteMode ? 'Bản đạt kiểm tra sẽ gửi được cho app' : 'Máy này chưa nối kho dùng chung'}
              />
              {workflow.checkAfterPublish && (
                <StepRow
                  href="/builds"
                  mark="↑"
                  tone="bg-warn-bg text-warn-fg"
                  title="Bản vừa kiểm tra mới hơn bản trên app"
                  sub="Xuất bản để người học nhận bản mới"
                />
              )}
            </Column>

            <Column caption="Việc cần làm">
              <div className="grid flex-1 grid-cols-2 gap-2">
                <Link
                  href={workflow.next.href}
                  transitionTypes={['nav-forward']}
                  className="col-span-2 flex min-h-24 flex-col justify-between rounded-2xl bg-fg p-3 text-card shadow-card hover:-translate-y-px hover:shadow-lift"
                >
                  <span className="text-[10px] font-medium tracking-wide uppercase text-card/70">
                    Việc tiếp theo
                  </span>
                  <span className="text-sm font-semibold">{workflow.next.label}</span>
                  <span className="line-clamp-2 text-[11px] leading-relaxed text-card/75">
                    {workflow.next.note}
                  </span>
                </Link>
                {[
                  { href: '/lessons', label: 'Danh sách bài học' },
                  { href: '/users', label: 'Người học' },
                  { href: '/ops/inbox', label: 'Thư người học' },
                  { href: `/courses/${workflow.courseId}/media`, label: 'Âm thanh & ảnh' },
                ].map((tile) => (
                  <Link
                    key={tile.href}
                    href={tile.href}
                    transitionTypes={['nav-forward']}
                    className="flex min-h-14 items-center rounded-2xl bg-card px-3 py-2 text-[12px] font-medium text-fg-2 shadow-card hover:-translate-y-px hover:shadow-lift"
                  >
                    {tile.label}
                  </Link>
                ))}
              </div>
            </Column>
          </div>
        </div>
      </section>

      <div className="grid gap-4 lg:grid-cols-[1.4fr_1fr]">
        <section className={cn(panel, 'p-4 sm:p-5')} aria-label="Bài học gần đây">
          <div className="flex items-center gap-2">
            <h2 className="text-base font-semibold">Bài học gần đây</h2>
            <Link href="/lessons" title="Mở danh sách bài học" className={cn(circle, 'ml-auto size-9')}>
              <Chevron />
            </Link>
          </div>
          <table className="mt-3 w-full border-separate border-spacing-0 text-sm">
            <thead>
              <tr className="text-left text-xs text-fg-4">
                <th className="px-2 py-1.5 font-medium">Bài học</th>
                <th className="px-2 py-1.5 font-medium">Trạng thái</th>
                <th className="hidden px-2 py-1.5 font-medium sm:table-cell">Nội dung</th>
                <th className="hidden px-2 py-1.5 font-medium md:table-cell">Lần lưu</th>
                <th className="px-2 py-1.5" />
              </tr>
            </thead>
            <tbody>
              {recent.map((lesson) => (
                <tr key={lesson.unitId}>
                  <td className="max-w-0 min-w-52 px-2 py-2">
                    <Link
                      href={`/courses/${workflow.courseId}/units/${lesson.unitId}`}
                      transitionTypes={['nav-forward']}
                      className="block truncate font-medium hover:text-primary-text"
                      title={`Bài ${lesson.order + 1} · ${lesson.title}`}
                    >
                      Bài {lesson.order + 1} · {lesson.title || '(chưa đặt tên)'}
                    </Link>
                  </td>
                  <td className="px-2 py-2">
                    <span className={cn('rounded-full px-2 py-0.5 text-[11px] font-medium whitespace-nowrap', STATE_PILL[lesson.state].cls)}>
                      {STATE_PILL[lesson.state].label}
                    </span>
                  </td>
                  <td className="hidden px-2 py-2 text-xs whitespace-nowrap text-fg-3 sm:table-cell">
                    {lesson.vocab} từ · {lesson.sentences} câu
                  </td>
                  <td className="hidden px-2 py-2 text-xs whitespace-nowrap text-fg-4 md:table-cell">
                    {timeAgo(lesson.updatedAt)}
                  </td>
                  <td className="px-2 py-2">
                    <Chevron />
                  </td>
                </tr>
              ))}
              {recent.length === 0 && (
                <tr>
                  <td colSpan={5} className="px-2 py-6 text-sm text-fg-3">
                    Chưa có bài học nào. Bắt đầu bằng “{workflow.next.label}”.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </section>

        <section className={cn(panel, 'p-4 sm:p-5')} aria-label="Tình trạng khóa">
          <h2 className="text-base font-semibold">Tình trạng khóa</h2>
          <div className="mt-4 flex justify-around gap-2">
            <Donut value={data.counts.ready} total={data.counts.total} color="var(--ok-fg)" label="Sẵn sàng" />
            <Donut
              value={workflow.awaitingValidation}
              total={data.counts.total}
              color="var(--warn-fg)"
              label="Chờ kiểm tra lại"
            />
          </div>
          <dl className="mt-4 space-y-1.5 border-t border-line pt-3 text-xs text-fg-3">
            <div className="flex justify-between gap-3">
              <dt>Bài có lỗi / chưa có nội dung</dt>
              <dd className="font-medium text-fg-2">
                {data.counts.errors} / {data.counts.empty}
              </dd>
            </div>
            <div className="flex justify-between gap-3">
              <dt>Kiểm tra gần nhất</dt>
              <dd className="font-medium text-fg-2">
                {gate ? `${gate.ok ? 'đạt' : 'chưa đạt'} · ${timeAgo(gate.at)}` : 'chưa có'}
              </dd>
            </div>
            <div className="flex justify-between gap-3">
              <dt>Bản trên app</dt>
              <dd className="font-medium text-fg-2">
                {published ? `${published.version} · ${timeAgo(published.at)}` : 'chưa xuất bản'}
              </dd>
            </div>
          </dl>
        </section>
      </div>
    </div>
  );
}
