import Link from 'next/link';
import { PageTransition } from '@/components/page-transition';
import { LEARNERS_UNAVAILABLE, learnerQueue } from '@/server/ops/learners';
import type { LearnerQueue } from '@/server/ops/port';
import { requireAdmin } from '@/server/session';
import { cn, timeAgo, truncate } from '@/lib/utils';
import { card, hint, link } from '@/lib/ui';

export const instant = false;

type InboxItem = {
  key: string;
  meta: string;
  body: string;
  linkTo: string;
  linkLabel: string;
  /** The identifier an answer needs in order to be useful: who reported, or which question. */
  trail?: string;
};

export default async function LearnerInboxPage() {
  await requireAdmin();

  let queue: LearnerQueue;
  try {
    queue = await learnerQueue();
  } catch (error) {
    return (
      <PageTransition>
        <div className={cn(card, 'rise p-6 text-sm text-warn-fg')}>
          {error instanceof Error ? error.message : LEARNERS_UNAVAILABLE}
        </div>
      </PageTransition>
    );
  }

  const { feedback, userReports, contentReports } = queue;

  return (
    <PageTransition>
      <div className="rise space-y-6">
        <header>
          <h1 className="text-2xl font-semibold tracking-tight">Thư của người học</h1>
          <p className="mt-1 text-sm text-fg-3">
            Những gì người học gửi lên và chưa có phản hồi. Trang này chỉ đọc: trả lời họ vẫn diễn ra
            trong app.
          </p>
        </header>

        <Group
          title="Góp ý về app"
          empty="Không có góp ý nào đang chờ."
          items={feedback.map((note) => ({
            key: note.noteId,
            meta: `${note.topic} · ${note.platform} · ${timeAgo(note.createdAt)}`,
            body: note.message,
            linkTo: note.userId,
            linkLabel: 'xem người này',
          }))}
        />

        <Group
          title="Báo cáo về một người"
          empty="Chưa có báo cáo nào về hành vi của người học."
          items={userReports.map((report) => ({
            key: report.reportId,
            meta: `lý do: ${report.reason} · ${timeAgo(report.createdAt)}`,
            body: report.note || 'Người báo không ghi gì thêm.',
            linkTo: report.targetUserId,
            linkLabel: 'người bị báo cáo',
            trail: `người báo: ${report.reporterId}`,
          }))}
        />

        <Group
          title="Báo lỗi bài học"
          empty="Chưa có báo lỗi nào về câu hỏi hay đáp án."
          items={contentReports.map((report) => ({
            key: report.reportId,
            meta: `${report.category} · bài ${report.lessonVersion} · ${timeAgo(report.createdAt)}`,
            body: report.note || 'Người học chỉ bấm báo, không ghi thêm.',
            linkTo: report.userId,
            linkLabel: 'người báo',
            trail: `câu hỏi: ${report.exerciseId}`,
          }))}
        />
      </div>
    </PageTransition>
  );
}

function Group({ title, empty, items }: { title: string; empty: string; items: InboxItem[] }) {
  return (
    <section className={cn(card, 'p-4')}>
      <div className="flex items-baseline justify-between gap-3">
        <h2 className="text-sm font-medium">{title}</h2>
        <span className="text-xs tabular-nums text-fg-4">{items.length}</span>
      </div>
      {items.length === 0 ? (
        <p className={cn(hint, 'mt-2 text-sm')}>{empty}</p>
      ) : (
        <ul className="mt-2 divide-y divide-line">
          {items.map((item) => (
            <li key={item.key} className="space-y-1 py-2.5 first:pt-0 last:pb-0">
              <div className="text-xs text-fg-4">{item.meta}</div>
              <div className="text-sm text-fg-2">{truncate(item.body, 300)}</div>
              <div className="flex flex-wrap items-center gap-3 text-xs">
                <Link
                  href={`/users/${item.linkTo}`}
                  transitionTypes={['nav-forward']}
                  className={cn(link, 'text-xs')}
                >
                  {item.linkLabel}
                </Link>
                {item.trail && <span className="font-mono text-fg-4">{item.trail}</span>}
              </div>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
