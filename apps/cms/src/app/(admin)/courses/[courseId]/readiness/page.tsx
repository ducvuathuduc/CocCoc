import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { CourseTabs } from '@/components/course-tabs';
import { PageTransition } from '@/components/page-transition';
import { card, link, tile } from '@/lib/ui';
import { cn } from '@/lib/utils';
import type { ReadinessItem } from '@/server/readiness';
import { courseReadiness } from '@/server/readiness';
import { requireAdmin } from '@/server/session';

export const instant = false;

export function generateMetadata(): Metadata {
  return {
    title: 'Điều kiện xuất bản',
    description: 'Những gì còn thiếu trước khi bản nội dung tới điện thoại.',
  };
}

export default async function ReadinessPage({ params }: { params: Promise<{ courseId: string }> }) {
  const { courseId } = await params;
  await requireAdmin();
  const report = await courseReadiness(courseId);
  if (!report) notFound();

  const pending = report.items.filter((i) => i.state !== 'ok');

  return (
    <PageTransition>
      <div className="space-y-5">
        <header>
          <CourseTabs courseId={courseId} />
          <h1 className="mt-4 text-2xl font-semibold tracking-tight">Điều kiện xuất bản</h1>
          <p className="mt-1 max-w-3xl text-sm text-fg-3">
            Danh sách này dùng lại đúng các con số của từng màn hình (audio và ảnh, bài đã soạn, từ
            trùng nhau), nên không có số nào ở đây khác với số bạn thấy khi mở từng phần. Nút{' '}
            <b>xuất bản</b> ở tab{' '}
            <Link href={`/builds?course=${courseId}`} className={link}>
              Kiểm tra &amp; Xuất bản
            </Link>{' '}
            cũng chặn theo đúng danh sách này.
          </p>
        </header>

        <section className="rise grid grid-cols-3 gap-4">
          <Tile label="Chưa xuất bản được vì" value={report.blocked} tone="text-danger-fg" />
          <Tile label="Nên xem thêm" value={report.warned} tone="text-warn-fg" />
          <Tile label="Bài đã có bản soạn" value={report.unitCount} />
        </section>

        <div
          className={cn(
            card,
            'p-4 text-sm',
            report.publishable
              ? 'border-ok-bd bg-ok-bg text-ok-fg'
              : 'border-warn-bd bg-warn-bg text-warn-fg',
          )}
        >
          {report.publishable ? (
            <>
              Cấu trúc khóa gọn, bản mới nhất đã qua bước kiểm tra, {report.unitCount} bài học —{' '}
              <b>đã sẵn sàng cho app nhận bản</b>.
            </>
          ) : (
            <>
              Chưa cho app nhận bản được: {report.publishBlocking}{' '}
              <span className="text-xs text-fg-3">
                (đó là lý do <em>đầu tiên</em> — danh sách bên dưới liệt kê cùng lúc mọi việc còn
                chờ)
              </span>
            </>
          )}
        </div>

        {pending.length > 0 ? (
          <section className={cn(card, 'animate-pop divide-y divide-line overflow-hidden')}>
            <h2 className="px-4 py-3 text-sm font-medium">
              Còn {pending.length} việc — {report.blocked} chặn xuất bản, {report.warned} nên xem
            </h2>
            {pending.map((row) => (
              <Row key={row.id} row={row} />
            ))}
          </section>
        ) : (
          <div className={cn(card, 'animate-pop border-ok-bd bg-ok-bg p-6 text-sm text-ok-fg')}>
            Không còn việc nào trong {report.items.length} mục: nội dung, bản dựng và media đều khớp
            nhau.
          </div>
        )}

        <section className={cn(card, 'divide-y divide-line overflow-hidden')}>
          <h2 className="px-4 py-3 text-sm font-medium text-fg-3">Đã kiểm tra xong</h2>
          {report.items
            .filter((row) => row.state === 'ok')
            .map((row) => (
              <Row key={row.id} row={row} />
            ))}
        </section>
      </div>
    </PageTransition>
  );
}

const TONE = {
  block: 'border-l-danger-fg text-danger-fg',
  warn: 'border-l-warn-fg text-warn-fg',
  ok: 'border-l-ok-bd text-ok-fg',
} as const;

function Row({ row }: { row: ReadinessItem }) {
  return (
    <div className="flex items-start gap-3 border-l-2 px-4 py-3 text-sm transition-colors hover:bg-elevated/40">
      <span
        className={cn('w-16 shrink-0 pt-0.5 text-lg font-semibold tabular-nums', TONE[row.state])}
      >
        {row.count}
      </span>
      <span className="min-w-0 flex-1">
        <span className="font-medium">{row.label}</span>
        {row.detail && <span className="mt-0.5 block text-xs text-fg-3">{row.detail}</span>}
      </span>
      {row.href && (
        <Link
          href={row.href}
          transitionTypes={['nav-forward']}
          className={cn(link, 'shrink-0 text-xs no-underline hover:underline')}
        >
          {row.state === 'ok' ? 'xem →' : 'sửa →'}
        </Link>
      )}
    </div>
  );
}

function Tile({ label, value, tone }: { label: string; value: number; tone?: string }) {
  return (
    <div className={tile}>
      <div className="text-xs text-fg-4">{label}</div>
      <div
        className={cn('mt-1 text-xl font-semibold tabular-nums tracking-tight', tone ?? 'text-fg')}
      >
        {value}
      </div>
    </div>
  );
}
