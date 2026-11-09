import Link from 'next/link';
import { PageTransition } from '@/components/page-transition';
import { learnerOverview, planRows, type PlanRow } from '@/server/ops/overview';
import { requireAdmin } from '@/server/session';
import { planBadge, planLabel, sourceLabel, statusLabel } from '@/lib/billing';
import { cn, formatDateTime, timeAgo } from '@/lib/utils';
import { badge, card, hint, row, td, th } from '@/lib/ui';

export const instant = false;

export const metadata = { title: 'Gói và thanh toán' };

/** The order the schema declares, so an empty status still gets a labelled tile. */
const STATUS_ORDER = ['ACTIVE', 'GRACE', 'HOLD', 'CANCELED', 'EXPIRED', 'REVOKED'] as const;

export default async function BillingPage() {
  await requireAdmin();
  const stats = await learnerOverview();

  let rows: PlanRow[] = [];
  let problem = '';
  try {
    rows = await planRows(200);
  } catch (error) {
    problem = error instanceof Error ? error.message : 'Chưa đọc được gói của người học.';
  }

  const counts = new Map(stats.statuses.map((entry) => [entry.status, entry.count]));
  const statusTiles = STATUS_ORDER.map((status) => ({
    status,
    count: counts.get(status) ?? 0,
  }));

  return (
    <PageTransition>
      <div className="rise space-y-5">
        <header>
          <h1 className="text-2xl font-semibold tracking-tight">Gói &amp; thanh toán</h1>
          <p className={cn(hint, 'mt-1 max-w-2xl text-sm')}>
            Ai đang dùng gói trả phí, gói nào, và còn hạn tới bao giờ. Mọi con số đếm từ bảng gói của
            app.
          </p>
        </header>

        <div className={cn(card, 'border-line bg-elevated p-4 text-sm text-fg-2')}>
          <p className="font-medium">Trang này chưa hiển thị doanh thu.</p>
          <p className={cn(hint, 'mt-1 leading-relaxed')}>
            Thanh toán trong app hiện là bản mô phỏng, và bảng mua hàng không lưu số tiền của từng đơn
            — nên một con số tiền ở đây sẽ là số bịa. Khi có thanh toán thật và giá được lưu cùng đơn,
            doanh thu sẽ được thêm vào đúng trang này.
          </p>
        </div>

        {!stats.connected ? (
          <div className={cn(card, 'p-6 text-sm text-warn-fg')}>
            Chưa đọc được dữ liệu người học: máy này chưa nối (hoặc đang không gọi được) Appwrite.
          </div>
        ) : (
          <>
            <section className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4" aria-label="Tài khoản theo gói">
              <Tile label="Tổng tài khoản" value={stats.accounts} note="mọi tài khoản trong app" />
              <Tile label="Gói trả phí" value={stats.paying} note="Super và Max đang hiệu lực" tone="ok" />
              <Tile
                label="Gói Super"
                value={stats.plans.find((slice) => slice.plan === 'SUPER')?.count ?? 0}
                note="đang hiệu lực"
              />
              <Tile
                label="Gói Max"
                value={stats.plans.find((slice) => slice.plan === 'MAX')?.count ?? 0}
                note="đang hiệu lực"
              />
            </section>

            <section className={cn(card, 'p-4 sm:p-5')} aria-label="Trạng thái gói">
              <h2 className="text-base font-semibold">Trạng thái gói</h2>
              <p className={cn(hint, 'mt-1')}>
                Mỗi tài khoản chỉ có một dòng gói. “Đang dùng” là còn hiệu lực; các trạng thái khác
                nghĩa là quyền lợi đã dừng hoặc đang chờ.
              </p>
              <dl className="mt-3 grid grid-cols-2 gap-2 sm:grid-cols-3 lg:grid-cols-6">
                {statusTiles.map((tile) => (
                  <div key={tile.status} className="rounded-xl bg-elevated px-3 py-2.5">
                    <dt className="text-[11px] text-fg-4">{statusLabel(tile.status)}</dt>
                    <dd
                      className={cn(
                        'mt-0.5 text-xl font-semibold tabular-nums',
                        tile.status === 'ACTIVE' ? 'text-ok-fg' : 'text-fg-2',
                        tile.count === 0 && 'text-fg-4',
                      )}
                    >
                      {tile.count.toLocaleString('vi-VN')}
                    </dd>
                  </div>
                ))}
              </dl>
            </section>

            <section className={cn(card, 'overflow-hidden')} aria-label="Tài khoản đang dùng gói">
              <div className="flex flex-wrap items-center gap-2 px-4 pt-4 pb-2">
                <h2 className="text-base font-semibold">
                  Tài khoản đang dùng gói trả phí
                </h2>
                <span className="text-xs text-fg-4">{rows.length}</span>
                <Link href="/users?plan=paid" className="ml-auto text-xs text-fg-3 hover:text-primary-text">
                  Xem trong danh sách người học →
                </Link>
              </div>

              {problem ? (
                <p className={cn(hint, 'px-4 pb-4 text-warn-fg')}>{problem}</p>
              ) : rows.length === 0 ? (
                <p className={cn(hint, 'px-4 pb-4')}>
                  Chưa có ai dùng gói trả phí. Người học vẫn dùng bản miễn phí bình thường.
                </p>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full min-w-[36rem] text-sm">
                    <thead className="bg-elevated text-xs text-fg-4">
                      <tr>
                        <th className={th}>Người học</th>
                        <th className={th}>Gói</th>
                        <th className={th}>Từ đâu</th>
                        <th className={th}>Hạn dùng</th>
                        <th className={th} />
                      </tr>
                    </thead>
                    <tbody>
                      {rows.map((planRow) => (
                        <tr key={planRow.userId} className={cn(row, 'border-t border-line')}>
                          <td className={td}>
                            <Link
                              href={`/users/${planRow.userId}`}
                              transitionTypes={['nav-forward']}
                              className="block py-1 font-medium hover:text-primary-text"
                            >
                              {planRow.name}
                            </Link>
                          </td>
                          <td className={cn(td, 'py-1')}>
                            <span className={cn(badge, planBadge(planRow.plan))}>
                              {planLabel(planRow.plan)}
                            </span>
                          </td>
                          <td className={cn(td, 'py-1 text-xs text-fg-3')}>
                            {sourceLabel(planRow.source)}
                          </td>
                          <td className={cn(td, 'py-1 text-xs text-fg-3')}>
                            {planRow.expiresAt ? (
                              <>
                                {formatDateTime(planRow.expiresAt)}
                                <span className="ml-1 text-fg-4">· {timeAgo(planRow.expiresAt)}</span>
                              </>
                            ) : (
                              'không hạn'
                            )}
                          </td>
                          <td className={cn(td, 'py-1 text-right text-fg-4')} aria-hidden="true">
                            →
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
              <p className={cn(hint, 'border-t border-line px-4 py-3')}>
                Danh sách chỉ lấy 200 dòng gần nhất mà máy chủ trả về, không sắp xếp theo ngày. Con số
                phía trên vẫn là tổng thật.
              </p>
            </section>
          </>
        )}
      </div>
    </PageTransition>
  );
}

function Tile({
  label,
  value,
  note,
  tone = 'plain',
}: {
  label: string;
  value: number;
  note: string;
  tone?: 'plain' | 'ok';
}) {
  return (
    <div className={cn(card, 'p-4')}>
      <div className="text-xs text-fg-4">{label}</div>
      <div
        className={cn(
          'mt-2 text-3xl font-semibold tabular-nums tracking-tight',
          tone === 'ok' ? 'text-ok-fg' : 'text-fg',
        )}
      >
        {value.toLocaleString('vi-VN')}
      </div>
      <div className="mt-1 text-xs text-fg-4">{note}</div>
    </div>
  );
}
