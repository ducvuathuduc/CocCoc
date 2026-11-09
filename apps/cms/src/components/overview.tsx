import Link from 'next/link';
import { Icon, type IconName } from '@/components/icons';
import type { CourseWorkflow } from '@/server/workflow';
import type { WorkspaceData } from '@/server/workspace';
import type { LearnerOverview } from '@/server/ops/overview';
import type { OpenCounts } from '@/server/ops/port';
import { big, card, hint, panel, primary } from '@/lib/ui';
import { cn, formatDateTime, timeAgo } from '@/lib/utils';

/**
 * The landing screen answers "how is the product doing, and what do I do now?".
 *
 * Content state comes from the draft store, learner state from Appwrite. The two are separate reads on
 * purpose: a learner-data outage must still leave the teacher able to publish, so the numbers degrade to
 * "chưa nối" instead of blanking the page.
 */
export function Overview({
  data,
  workflow,
  stats,
  queue,
}: {
  data: WorkspaceData;
  workflow: CourseWorkflow;
  stats: LearnerOverview;
  queue: OpenCounts | null;
}) {
  const openNotes = queue ? queue.feedback + queue.userReports + queue.contentReports : 0;
  const problems = data.lessons.filter((lesson) => lesson.state !== 'ready');

  return (
    <div className="rise space-y-5">
      <header className="flex flex-wrap items-end gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-semibold tracking-tight">Tổng quan</h1>
          <p className={cn(hint, 'mt-1 text-sm')}>
            Cập nhật {formatDateTime(new Date().toISOString())} · mọi con số đọc từ dữ liệu thật của
            app, không có số ước đoán.
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

      {!stats.connected && (
        <div className={cn(card, 'border-warn-bd bg-warn-bg p-4 text-sm text-warn-fg')}>
          <p className="font-medium">Chưa đọc được dữ liệu người học.</p>
          <p className="mt-1 leading-relaxed">
            Máy này chưa nối Appwrite, nên không có số tài khoản hay gói. Phần nội dung bên dưới vẫn
            dùng được bình thường.
          </p>
        </div>
      )}

      <section className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4" aria-label="Số liệu chính">
        <Kpi
          icon="learners"
          label="Người học"
          value={stats.connected ? stats.accounts.toLocaleString('vi-VN') : '—'}
          note={stats.connected ? `${stats.free.toLocaleString('vi-VN')} tài khoản miễn phí` : 'chưa nối'}
          href="/users"
        />
        <Kpi
          icon="billing"
          label="Gói trả phí"
          value={stats.connected ? stats.paying.toLocaleString('vi-VN') : '—'}
          note={
            stats.connected
              ? stats.plans.map((slice) => `${slice.plan} ${slice.count}`).join(' · ')
              : 'chưa nối'
          }
          href="/billing"
        />
        <Kpi
          icon="inbox"
          label="Thư chờ xử lý"
          value={queue ? openNotes.toLocaleString('vi-VN') : '—'}
          note={queue ? `${queue.feedback} góp ý · ${queue.contentReports} báo lỗi bài` : 'chưa nối'}
          href="/ops/inbox"
          tone={openNotes > 0 ? 'warn' : 'plain'}
        />
        <Kpi
          icon="lessons"
          label="Bài học"
          value={data.counts.total.toLocaleString('vi-VN')}
          note={
            problems.length === 0
              ? 'tất cả đã sẵn sàng'
              : `${problems.length} bài cần xem lại`
          }
          href="/lessons"
          tone={problems.length > 0 ? 'warn' : 'plain'}
        />
      </section>

      <div className="grid gap-4 lg:grid-cols-[1.25fr_1fr]">
        <section className={cn(panel, 'p-4 sm:p-5')} aria-label="Việc cần làm hôm nay">
          <div className="flex items-center gap-2">
            <h2 className="text-base font-semibold">Việc cần làm hôm nay</h2>
            <Link href="/builds" className="ml-auto text-xs text-fg-3 hover:text-primary-text">
              Xuất bản →
            </Link>
          </div>

          <Link
            href={workflow.next.href}
            transitionTypes={['nav-forward']}
            className="mt-3 flex items-start gap-3 rounded-2xl bg-fg p-4 text-card shadow-card hover:-translate-y-px hover:shadow-lift"
          >
            <span className="mt-0.5 flex size-7 shrink-0 items-center justify-center rounded-full bg-card/15 text-xs font-semibold">
              1
            </span>
            <span className="min-w-0">
              <span className="block text-sm font-semibold">{workflow.next.label}</span>
              <span className="mt-1 block text-xs leading-relaxed text-card/75">
                {workflow.next.note}
              </span>
            </span>
          </Link>

          <ul className="mt-3 space-y-1.5">
            {problems.slice(0, 4).map((lesson) => (
              <li key={lesson.unitId}>
                <Link
                  href={`/courses/${workflow.courseId}/units/${lesson.unitId}`}
                  transitionTypes={['nav-forward']}
                  className="flex items-center gap-3 rounded-xl px-2 py-2 hover:bg-elevated"
                >
                  <span
                    className={cn(
                      'size-2 shrink-0 rounded-full',
                      lesson.state === 'error' ? 'bg-danger-fg' : 'bg-warn-fg',
                    )}
                  />
                  <span className="min-w-0 flex-1 truncate text-sm">
                    Bài {lesson.order + 1} · {lesson.title || '(chưa đặt tên)'}
                  </span>
                  <span className="shrink-0 text-xs text-fg-4">
                    {lesson.state === 'error' ? `${lesson.errors} lỗi` : `${lesson.warnings} điểm`}
                  </span>
                </Link>
              </li>
            ))}
            {problems.length === 0 && (
              <li className="flex items-center gap-2 rounded-xl px-2 py-2 text-sm text-ok-fg">
                <span className="size-2 rounded-full bg-ok-fg" />
                Cả {data.counts.total} bài đã sạch, không còn gì phải sửa.
              </li>
            )}
            {problems.length > 4 && (
              <li>
                <Link href="/lessons" className="px-2 text-xs text-fg-4 hover:text-primary-text">
                  và {problems.length - 4} bài khác…
                </Link>
              </li>
            )}
          </ul>
        </section>

        <section className={cn(panel, 'p-4 sm:p-5')} aria-label="Người học theo gói">
          <div className="flex items-center gap-2">
            <h2 className="text-base font-semibold">Người học theo gói</h2>
            <Link href="/billing" className="ml-auto text-xs text-fg-3 hover:text-primary-text">
              Chi tiết →
            </Link>
          </div>

          {stats.connected ? (
            <>
              <PlanBar
                label="Miễn phí"
                count={stats.free}
                total={stats.accounts}
                color="bg-line-strong"
              />
              {stats.plans.map((slice) => (
                <PlanBar
                  key={slice.plan}
                  label={slice.plan}
                  count={slice.count}
                  total={stats.accounts}
                  color={slice.plan === 'SUPER' ? 'bg-primary' : 'bg-ok-fg'}
                />
              ))}
              <p className={cn(hint, 'mt-3 border-t border-line pt-3')}>
                {stats.paying === 0
                  ? 'Chưa có ai dùng gói trả phí. Người học vẫn dùng bản miễn phí bình thường.'
                  : `${stats.paying} trên ${stats.accounts} tài khoản đang dùng gói trả phí.`}
                {stats.sampled && ' Con số theo gói là mức tối thiểu vì danh sách đã bị giới hạn.'}
              </p>
            </>
          ) : (
            <p className={cn(hint, 'mt-3')}>
              Cần nối Appwrite để đọc gói của người học.
            </p>
          )}
        </section>
      </div>

      <div className="grid gap-4 lg:grid-cols-[1fr_1fr]">
        <section className={cn(panel, 'overflow-hidden')} aria-label="Tài khoản mới nhất">
          <div className="flex items-center gap-2 px-4 pt-4 pb-2 sm:px-5">
            <h2 className="text-base font-semibold">Tài khoản mới nhất</h2>
            <Link href="/users" className="ml-auto text-xs text-fg-3 hover:text-primary-text">
              Tất cả →
            </Link>
          </div>
          {stats.newest.length === 0 ? (
            <p className={cn(hint, 'px-4 pb-4 sm:px-5')}>
              {stats.connected ? 'Chưa có tài khoản nào.' : 'Chưa nối Appwrite.'}
            </p>
          ) : (
            <ul className="divide-y divide-line">
              {stats.newest.map((account) => (
                <li key={account.userId}>
                  <Link
                    href={`/users/${account.userId}`}
                    transitionTypes={['nav-forward']}
                    className="flex items-center gap-3 px-4 py-2.5 hover:bg-elevated sm:px-5"
                  >
                    <span className="flex size-8 shrink-0 items-center justify-center rounded-full bg-elevated text-[11px] font-semibold text-fg-3">
                      {(account.name || account.email || '?').slice(0, 1).toUpperCase()}
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-sm">
                        {account.name || account.email || 'Chưa đặt tên'}
                      </span>
                      <span className="block truncate text-xs text-fg-4">
                        {account.email || 'không có email'}
                      </span>
                    </span>
                    <span className="shrink-0 text-xs text-fg-4">
                      {timeAgo(account.createdAt)}
                    </span>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </section>

        <section className={cn(panel, 'p-4 sm:p-5')} aria-label="Nội dung đang phát hành">
          <h2 className="text-base font-semibold">Nội dung đang phát hành</h2>
          <dl className="mt-3 space-y-2 text-sm">
            <Row label="Khóa học" value={workflow.title} />
            <Row label="Bài học" value={`${data.counts.total} bài`} />
            <Row
              label="Bản app đang dùng"
              value={workflow.published ? workflow.published.version : 'chưa xuất bản lần nào'}
            />
            <Row
              label="Lần kiểm tra gần nhất"
              value={
                workflow.gate
                  ? `${workflow.gate.ok ? 'đạt' : 'chưa đạt'} · ${timeAgo(workflow.gate.at)}`
                  : 'chưa kiểm tra'
              }
            />
          </dl>
          <Link
            href="/builds"
            transitionTypes={['nav-forward']}
            className="mt-4 inline-flex text-xs font-medium text-primary-text hover:underline"
          >
            Mở trang xuất bản →
          </Link>
        </section>
      </div>
    </div>
  );
}

function Kpi({
  icon,
  label,
  value,
  note,
  href,
  tone = 'plain',
}: {
  icon: IconName;
  label: string;
  value: string;
  note: string;
  href: string;
  tone?: 'plain' | 'warn';
}) {
  return (
    <Link
      href={href}
      transitionTypes={['nav-forward']}
      className={cn(
        card,
        'block p-4 hover:-translate-y-px hover:shadow-lift',
        tone === 'warn' && 'border-warn-bd',
      )}
    >
      <div className="flex items-center gap-2 text-xs text-fg-4">
        <Icon name={icon} className="size-4 shrink-0" />
        {label}
      </div>
      <div
        className={cn(
          'mt-2 text-3xl font-semibold tabular-nums tracking-tight',
          tone === 'warn' ? 'text-warn-fg' : 'text-fg',
        )}
      >
        {value}
      </div>
      <div className="mt-1 truncate text-xs text-fg-4" title={note}>
        {note}
      </div>
    </Link>
  );
}

function PlanBar({
  label,
  count,
  total,
  color,
}: {
  label: string;
  count: number;
  total: number;
  color: string;
}) {
  const share = total === 0 ? 0 : Math.round((count / total) * 100);
  return (
    <div className="mt-3">
      <div className="flex items-baseline justify-between text-xs">
        <span className="font-medium text-fg-2">{label}</span>
        <span className="tabular-nums text-fg-3">
          {count.toLocaleString('vi-VN')}
          <span className="ml-1 text-fg-4">({share}%)</span>
        </span>
      </div>
      <div className="mt-1 h-2 overflow-hidden rounded-full bg-elevated">
        <div
          className={cn('h-full rounded-full', color)}
          style={{ width: `${Math.max(share, count > 0 ? 2 : 0)}%` }}
        />
      </div>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between gap-3 border-b border-line pb-2 last:border-0">
      <dt className="shrink-0 text-fg-4">{label}</dt>
      <dd className="min-w-0 truncate text-right font-medium text-fg-2" title={value}>
        {value}
      </dd>
    </div>
  );
}
