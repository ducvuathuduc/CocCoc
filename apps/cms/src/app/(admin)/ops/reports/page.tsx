import Link from 'next/link';
import { PageTransition } from '@/components/page-transition';
import { contentReport } from '@/server/queries';
import { requireAdmin } from '@/server/session';
import { cn } from '@/lib/utils';
import { card, link, tile } from '@/lib/ui';
import { whereIs } from '@/lib/words';

export const instant = false;

export default async function ReportsPage() {
  await requireAdmin();
  const reports = await contentReport();
  const broken = reports.filter((r) => r.errors.length > 0);
  const soft = reports.filter((r) => r.errors.length === 0 && r.warnings.length > 0);

  return (
    <PageTransition>
      <div className="space-y-6">
        <header>
          <h1 className="text-2xl font-semibold tracking-tight">Cần xử lý</h1>
          <p className="mt-1 text-sm text-fg-3">
            Cùng bộ kiểm tra với trình soạn bài, chạy trên mọi bài đã soạn. Sửa xong thì bài tự biến
            mất khỏi đây.
          </p>
        </header>

        <section className="rise grid grid-cols-3 gap-4">
          <Tile label="Bài đã soạn" value={reports.length} tone="text-fg" />
          <Tile label="Bài chưa lưu được" value={broken.length} tone="text-danger-fg" />
          <Tile label="Bài nên làm thêm" value={soft.length} tone="text-warn-fg" />
        </section>

        {reports.length === 0 && (
          <div className={cn(card, 'p-6 text-sm text-fg-3')}>
            Chưa có bài nào được soạn, nên chưa có gì để kiểm tra.
          </div>
        )}

        {reports.length > 0 && broken.length + soft.length === 0 && (
          <div className={cn(card, 'animate-pop border-ok-bd bg-ok-bg p-6 text-sm text-ok-fg')}>
            {reports.length} bài đều sạch: không có gì chặn lưu, không có gì nên làm thêm.
          </div>
        )}

        <div className="space-y-4">
          {[...broken, ...soft].map((report) => {
            const fatal = report.errors.length > 0;
            return (
              <section
                key={`${report.courseId}/${report.unitId}`}
                className={cn(
                  card,
                  'border-l-2 p-4 transition-shadow hover:shadow-lift',
                  fatal ? 'border-l-danger-fg' : 'border-l-warn-fg',
                )}
              >
                <div className="flex items-center justify-between gap-3">
                  <Link
                    href={`/courses/${report.courseId}/units/${report.unitId}`}
                    transitionTypes={['nav-forward']}
                    className={cn(link, 'text-sm font-medium')}
                  >
                    {report.title || report.unitId}
                  </Link>
                  <span className="text-xs text-fg-4">{report.courseId}</span>
                </div>
                <ul className="mt-2 space-y-1 text-xs">
                  {report.errors.map((issue, i) => (
                    <li key={`e${i}`} className="flex gap-2">
                      <span className="shrink-0 text-danger-fg">{whereIs(issue.path)}</span>
                      <span className="text-fg-2">{issue.message}</span>
                    </li>
                  ))}
                  {report.warnings.map((issue, i) => (
                    <li key={`w${i}`} className="flex gap-2">
                      <span className="shrink-0 text-warn-fg">{whereIs(issue.path)}</span>
                      <span className="text-fg-2">{issue.message}</span>
                    </li>
                  ))}
                </ul>
              </section>
            );
          })}
        </div>
      </div>
    </PageTransition>
  );
}

function Tile({ label, value, tone }: { label: string; value: number; tone: string }) {
  return (
    <div className={tile}>
      <div className="text-xs text-fg-4">{label}</div>
      <div className={cn('mt-1 text-xl font-semibold tabular-nums tracking-tight', tone)}>
        {value}
      </div>
    </div>
  );
}
