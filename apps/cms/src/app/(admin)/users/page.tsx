import Link from 'next/link';
import { PageTransition } from '@/components/page-transition';
import { LEARNERS_UNAVAILABLE } from '@/server/ops/learners';
import { accountTotal, listLearnerRows, type LearnerListRow } from '@/server/ops/overview';
import { config } from '@/server/config';
import { requireAdmin } from '@/server/session';
import { isPaidActive, planBadge, planLabel, statusLabel } from '@/lib/billing';
import { cn, formatDateTime, timeAgo, truncate } from '@/lib/utils';
import { badge, card, field, hint, primary, row, td, th } from '@/lib/ui';

export const instant = false;

const PAGE_LIMIT = 50;

/** Past a week `timeAgo` already says the date, so printing both would read "2026-10-29 · 2026-10-29 13:11". */
function createdCell(iso: string): string {
  const stamp = formatDateTime(iso);
  const ago = timeAgo(iso);
  return ago === stamp.slice(0, 10) ? stamp : `${ago} · ${stamp}`;
}

const FILTERS = [
  { key: 'all', label: 'Tất cả' },
  { key: 'paid', label: 'Gói trả phí' },
  { key: 'free', label: 'Miễn phí' },
] as const;

type FilterKey = (typeof FILTERS)[number]['key'];

function filterHref(key: FilterKey, q: string): string {
  const params = new URLSearchParams();
  if (key !== 'all') params.set('plan', key);
  if (q) params.set('q', q);
  const query = params.toString();
  return query ? `/users?${query}` : '/users';
}

export default async function UsersPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; plan?: string }>;
}) {
  await requireAdmin();
  const { q = '', plan: rawPlan = 'all' } = await searchParams;
  const plan: FilterKey = FILTERS.some((f) => f.key === rawPlan) ? (rawPlan as FilterKey) : 'all';
  const admins = config().admins;

  let rows: LearnerListRow[] = [];
  let problem = '';
  try {
    rows = await listLearnerRows(q);
  } catch (error) {
    problem = error instanceof Error ? error.message : LEARNERS_UNAVAILABLE;
  }
  const total = await accountTotal();

  const visible =
    plan === 'paid'
      ? rows.filter((account) => isPaidActive(account.plan, account.planStatus))
      : plan === 'free'
        ? rows.filter((account) => !isPaidActive(account.plan, account.planStatus))
        : rows;

  return (
    <PageTransition>
      <div className="rise space-y-5">
        <header className="flex flex-wrap items-end gap-3">
          <div className="min-w-0">
            <h1 className="text-2xl font-semibold tracking-tight">Người học</h1>
            <p className={cn(hint, 'mt-1 max-w-2xl text-sm')}>
              Mọi tài khoản của app, mới nhất trước.
              {total !== null && <> Tổng cộng {total.toLocaleString('vi-VN')} tài khoản.</>}{' '}
              Bấm vào một người để xem tiến độ và khóa tài khoản nếu cần.
            </p>
          </div>
          <Link
            href="/billing"
            transitionTypes={['nav-forward']}
            className="ml-auto text-sm text-fg-3 hover:text-primary-text"
          >
            Gói &amp; thanh toán →
          </Link>
        </header>

        <div className="flex flex-wrap items-center gap-2">
          <form
            action="/users"
            method="get"
            className="flex min-w-0 flex-1 items-center gap-2 sm:max-w-xl"
          >
            {plan !== 'all' && <input type="hidden" name="plan" value={plan} />}
            <input
              type="search"
              name="q"
              defaultValue={q}
              placeholder="Tìm theo email, tên hoặc mã tài khoản"
              aria-label="Tìm người học theo email, tên hoặc mã tài khoản"
              className={cn(field, 'min-w-0 flex-1')}
            />
            <button type="submit" className={cn(primary, 'shrink-0 px-4 py-2 text-sm')}>
              Tìm
            </button>
            {q && (
              <Link href={filterHref(plan, '')} className={cn(hint, 'shrink-0 hover:text-primary-text')}>
                Xóa tìm
              </Link>
            )}
          </form>

          <div className="flex flex-wrap items-center gap-1.5">
            {FILTERS.map((filter) => (
              <Link
                key={filter.key}
                href={filterHref(filter.key, q)}
                aria-current={filter.key === plan ? 'page' : undefined}
                className={cn(
                  'rounded-full border px-3 py-1.5 text-xs transition-colors',
                  filter.key === plan
                    ? 'border-fg bg-fg font-medium text-card'
                    : 'border-line bg-card text-fg-3 hover:border-line-strong hover:text-fg',
                )}
              >
                {filter.label}
              </Link>
            ))}
          </div>
        </div>

        {problem ? (
          <div className={cn(card, 'p-6 text-sm text-warn-fg')}>{problem}</div>
        ) : (
          <section className={cn(card, 'overflow-hidden')}>
            <div className="overflow-x-auto">
              <table className="w-full min-w-[40rem] text-sm">
                <thead className="bg-elevated text-xs text-fg-4">
                  <tr>
                    <th className={cn(th, 'w-[45%]')}>Người học</th>
                    <th className={th}>Gói</th>
                    <th className={th}>Trạng thái</th>
                    <th className={th}>Tham gia</th>
                    <th className={th} />
                  </tr>
                </thead>
                <tbody>
                  {visible.map((account) => (
                    <tr key={account.userId} className={cn(row, 'border-t border-line')}>
                      <td className={td}>
                        <div className="flex items-center gap-2.5 py-1">
                          <span className="flex size-8 shrink-0 items-center justify-center rounded-full bg-elevated text-[11px] font-semibold text-fg-3">
                            {account.displayName.slice(0, 1).toUpperCase()}
                          </span>
                          <div className="min-w-0">
                            <Link
                              href={`/users/${account.userId}`}
                              transitionTypes={['nav-forward']}
                              className="block truncate font-medium hover:text-primary-text"
                              title={account.userId}
                            >
                              {truncate(account.displayName, 42)}
                            </Link>
                            <div className="truncate text-xs text-fg-3">
                              {account.email || 'không có email (chưa đăng ký xong)'}
                            </div>
                          </div>
                        </div>
                      </td>
                      <td className={td}>
                        <span className={cn(badge, 'whitespace-nowrap', planBadge(account.plan))}>
                          {planLabel(account.plan)}
                        </span>
                        {account.planStatus && account.planStatus !== 'ACTIVE' && (
                          <div className="mt-0.5 text-[11px] text-fg-4">
                            {statusLabel(account.planStatus)}
                          </div>
                        )}
                      </td>
                      <td className={td}>
                        <div className="flex flex-wrap gap-1.5 py-1">
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
                      <td className={cn(td, 'whitespace-nowrap py-1 text-xs text-fg-3')}>
                        {createdCell(account.createdAt)}
                      </td>
                      <td className={cn(td, 'py-1 text-right text-fg-4')} aria-hidden="true">
                        →
                      </td>
                    </tr>
                  ))}
                  {visible.length === 0 && (
                    <tr>
                      <td colSpan={5} className={cn(td, 'py-6 text-sm text-fg-4')}>
                        {q
                          ? `Không có tài khoản nào khớp với “${q}”.`
                          : plan === 'paid'
                            ? 'Chưa có ai dùng gói trả phí.'
                            : 'Chưa có tài khoản nào trong hệ thống.'}
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
            {rows.length >= PAGE_LIMIT && (
              <p className={cn(hint, 'border-t border-line px-4 py-3')}>
                Danh sách chỉ lấy {PAGE_LIMIT} tài khoản gần nhất. Gõ email vào ô tìm để thấy người
                khác.
                {plan !== 'all' && ' Bộ lọc chỉ áp dụng trên danh sách này.'}
              </p>
            )}
          </section>
        )}
      </div>
    </PageTransition>
  );
}
