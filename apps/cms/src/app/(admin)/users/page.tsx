import Link from 'next/link';
import { PageTransition } from '@/components/page-transition';
import { LEARNERS_UNAVAILABLE, listLearners } from '@/server/ops/learners';
import { config } from '@/server/config';
import type { LearnerSummary } from '@/server/ops/port';
import { requireAdmin } from '@/server/session';
import { cn, formatDateTime, timeAgo } from '@/lib/utils';
import { badge, card, field, hint, primary, row, td, th } from '@/lib/ui';

export const instant = false;

const PAGE_LIMIT = 50;

/** Past a week `timeAgo` already says the date, so printing both would read "2026-10-29 · 2026-10-29 13:11". */
function createdCell(iso: string): string {
  const stamp = formatDateTime(iso);
  const ago = timeAgo(iso);
  return ago === stamp.slice(0, 10) ? stamp : `${ago} · ${stamp}`;
}

export default async function UsersPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string }>;
}) {
  await requireAdmin();
  const { q = '' } = await searchParams;
  const admins = config().admins;

  let accounts: LearnerSummary[] = [];
  let problem = '';
  try {
    accounts = await listLearners(q);
  } catch (error) {
    problem = error instanceof Error ? error.message : LEARNERS_UNAVAILABLE;
  }

  return (
    <PageTransition>
      <div className="rise space-y-6">
        <header>
          <h1 className="text-2xl font-semibold tracking-tight">Người học</h1>
          <p className="mt-1 text-sm text-fg-3">
            Mọi tài khoản của app, mới nhất trước. Bấm vào một người để xem họ đã học tới đâu và
            khóa lại nếu cần.
          </p>
        </header>

        <form action="/users" method="get" className="flex max-w-xl flex-wrap items-center gap-2">
          <input
            type="search"
            name="q"
            defaultValue={q}
            placeholder="Email hoặc mã tài khoản"
            aria-label="Tìm theo email hoặc mã tài khoản"
            className={field}
          />
          <button type="submit" className={cn(primary, 'px-4 py-2 text-sm')}>
            Tìm
          </button>
          {q && (
            <Link href="/users" className={cn(hint, 'shrink-0 text-fg-3 hover:text-primary-text')}>
              Xóa tìm
            </Link>
          )}
        </form>

        {problem ? (
          <div className={cn(card, 'p-6 text-sm text-warn-fg')}>{problem}</div>
        ) : (
          <section className={cn(card, 'overflow-hidden')}>
            <div className="overflow-x-auto">
              <table className="w-full min-w-[36rem] text-sm">
                <thead className="bg-elevated text-xs text-fg-4">
                  <tr>
                    <th className={cn(th, 'w-1/3')}>Người dùng</th>
                    <th className={th}>Trạng thái</th>
                    <th className={th}>Tạo lúc</th>
                  </tr>
                </thead>
                <tbody>
                  {accounts.map((account) => (
                    <tr key={account.userId} className={cn(row, 'border-t border-line')}>
                      <td className={td}>
                        <Link
                          href={`/users/${account.userId}`}
                          transitionTypes={['nav-forward']}
                          className="font-mono text-xs text-primary-text hover:underline"
                        >
                          {account.userId}
                        </Link>
                        <div className="text-xs text-fg-3">
                          {account.anonymous ? 'không có email (chưa đăng ký xong)' : account.email}
                        </div>
                      </td>
                      <td className={td}>
                        <div className="flex flex-wrap gap-1.5">
                          <span
                            className={cn(badge, account.locked && 'bg-danger-bg text-danger-fg')}
                          >
                            {account.locked ? 'Đang khóa' : 'Đang mở'}
                          </span>
                          {admins.has(account.userId) && (
                            <span className={cn(badge, 'bg-elevated text-fg-3')}>quản trị</span>
                          )}
                        </div>
                      </td>
                      <td className={cn(td, 'whitespace-nowrap text-xs text-fg-3')}>
                        {createdCell(account.createdAt)}
                      </td>
                    </tr>
                  ))}
                  {accounts.length === 0 && (
                    <tr>
                      <td colSpan={3} className={cn(td, 'py-6 text-sm text-fg-4')}>
                        {q
                          ? `Không có tài khoản nào khớp với “${q}”.`
                          : 'Chưa có tài khoản nào trong hệ thống.'}
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
            {accounts.length >= PAGE_LIMIT && (
              <p className={cn(hint, 'border-t border-line px-4 py-3')}>
                Danh sách chỉ lấy {PAGE_LIMIT} tài khoản gần nhất. Gõ email vào ô tìm để thấy người
                khác.
              </p>
            )}
          </section>
        )}
      </div>
    </PageTransition>
  );
}
