import Link from 'next/link';
import { PageTransition } from '@/components/page-transition';
import { auditLog } from '@/server/queries';
import { isUserId } from '@/server/ops/port';
import { requireAdmin } from '@/server/session';
import { operationLabel } from '@/lib/activity';
import { cn, formatDateTime, truncate } from '@/lib/utils';
import { badge, card, code } from '@/lib/ui';

export const instant = false;

export default async function AuditPage() {
  await requireAdmin();
  const entries = await auditLog(200);

  return (
    <PageTransition>
      <div className="space-y-6">
        <header>
          <h1 className="text-2xl font-semibold tracking-tight">Lịch sử hoạt động</h1>
          <p className="mt-1 text-sm text-fg-3">
            Ai đã làm gì, lúc nào và với đối tượng nào: một bài, một file media hay một tài khoản.
            200 hoạt động gần nhất.
          </p>
        </header>

        <section className={cn(card, 'overflow-hidden')}>
          {entries.length === 0 ? (
            <div className="px-4 py-8 text-sm text-fg-3">Chưa có thao tác nào.</div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[40rem] text-sm">
                <thead className="bg-elevated text-left text-xs text-fg-4">
                  <tr>
                    <th className="px-4 py-2 font-medium">Thời gian</th>
                    <th className="px-4 py-2 font-medium">Ai làm</th>
                    <th className="px-4 py-2 font-medium">Việc đã làm</th>
                    <th className="px-4 py-2 font-medium">Đối tượng</th>
                    <th className="px-4 py-2 font-medium">Bản ghi chi tiết</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-line">
                  {entries.map((entry) => (
                    <tr key={entry.entryId} className="transition-colors hover:bg-elevated">
                      <td className="px-4 py-2 text-xs tabular-nums text-fg-3">
                        {formatDateTime(entry.createdAt)}
                      </td>
                      <td className="px-4 py-2 text-xs text-fg-3">{entry.actorId}</td>
                      <td className="px-4 py-2">
                        <span className={badge}>{operationLabel(entry.operation)}</span>
                      </td>
                      <td className="px-4 py-2 font-mono text-xs text-fg-2">
                        {entry.operation.startsWith('user.') && isUserId(entry.targetId) ? (
                          <Link
                            href={`/users/${entry.targetId}`}
                            className="text-primary-text hover:underline"
                          >
                            {entry.targetId}
                          </Link>
                        ) : (
                          entry.targetId
                        )}
                      </td>
                      <td className="px-4 py-2 text-xs text-fg-4">
                        <details>
                          <summary className="cursor-pointer hover:text-fg-3">xem chi tiết</summary>
                          <code className={cn(code, 'mt-1 block max-w-[28rem] break-all')}>
                            {truncate(entry.afterJson, 240)}
                          </code>
                        </details>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      </div>
    </PageTransition>
  );
}
