import Link from 'next/link';
import { LearnerAccessButton } from '@/components/learner-access-button';
import { PageTransition } from '@/components/page-transition';
import { config } from '@/server/config';
import { LEARNERS_UNAVAILABLE, learnerDetail } from '@/server/ops/learners';
import type { LearnerDetail } from '@/server/ops/port';
import { requireAdmin } from '@/server/session';
import { isUserId } from '@/server/ops/port';
import { cn, formatDateTime, timeAgo, truncate } from '@/lib/utils';
import { badge, card, hint } from '@/lib/ui';

export const instant = false;

export default async function LearnerPage({
  params,
}: {
  params: Promise<{ userId: string }>;
}) {
  const { userId } = await params;
  await requireAdmin();

  let detail: LearnerDetail | null = null;
  let problem = '';
  try {
    detail = isUserId(userId) ? await learnerDetail(userId) : null;
  } catch (error) {
    problem = error instanceof Error ? error.message : LEARNERS_UNAVAILABLE;
  }

  return (
    <PageTransition>
      <div className="rise space-y-6">
        <Link
          href="/users"
          transitionTypes={['nav-back']}
          className="inline-block text-sm text-fg-3 hover:text-primary-text"
        >
          ← Người học
        </Link>

        {problem ? (
          <div className={cn(card, 'p-6 text-sm text-warn-fg')}>{problem}</div>
        ) : !detail ? (
          <section className={cn(card, 'p-6')}>
            <h1 className="text-xl font-semibold tracking-tight">Không có tài khoản này</h1>
            <p className={cn(hint, 'mt-2 max-w-xl text-sm')}>
              Mã <code className="font-mono">{truncate(userId, 40)}</code> không nằm trong hệ thống:
              người học có thể đã tự xóa tài khoản, hoặc đường dẫn bị gõ sai.
            </p>
          </section>
        ) : (
          <Learner detail={detail} isSiteAdmin={config().admins.has(detail.userId)} />
        )}
      </div>
    </PageTransition>
  );
}

function Learner({ detail, isSiteAdmin }: { detail: LearnerDetail; isSiteAdmin: boolean }) {
  const { account, profile, entitlement, enrollment, days } = detail;
  const title = profile?.nickname || account.name || account.email || account.userId;

  return (
    <>
      <header className="space-y-2">
        <div className="flex flex-wrap items-center gap-3">
          <h1 className="text-2xl font-semibold tracking-tight">{title}</h1>
          <span className={cn(badge, account.locked && 'bg-danger-bg text-danger-fg')}>
            {account.locked ? 'Đang khóa' : 'Đang mở'}
          </span>
          {entitlement && (
            <span className={cn(badge, 'bg-elevated text-fg-2')}>
              gói {entitlement.plan.toLowerCase()} · {entitlement.status.toLowerCase()}
            </span>
          )}
        </div>
        <p className="font-mono text-xs text-fg-4">{account.userId}</p>
      </header>

      <section className={cn(card, 'p-4')}>
        <h2 className="text-sm font-medium">Quyền truy cập</h2>
        <div className="mt-3">
          <LearnerAccessButton
            userId={account.userId}
            locked={account.locked}
            isSiteAdmin={isSiteAdmin}
          />
        </div>
      </section>

      <div className="grid gap-4 md:grid-cols-3">
        <Facts
          title="Hồ sơ"
          rows={
            profile
              ? [
                  ['Tên hiển thị', profile.nickname],
                  ['Mã người dùng', profile.username],
                  ['Nhóm tuổi', profile.ageBand],
                  ['Mục tiêu mỗi ngày', `${profile.dailyGoal} XP`],
                  [
                    'Vào học',
                    `${formatDateTime(profile.joinedAt)} · ${timeAgo(profile.joinedAt)}`,
                  ],
                  ['Trạng thái hồ sơ', profile.deleted ? 'đã đánh dấu xóa' : 'đang dùng'],
                ]
              : []
          }
          empty="App chưa lưu hồ sơ nào cho tài khoản này — có lẽ người học chưa đi qua màn hình chào."
        />
        <Facts
          title="Gói đang dùng"
          rows={
            entitlement
              ? [
                  ['Gói', entitlement.plan],
                  ['Từ', entitlement.source],
                  ['Trạng thái', entitlement.status],
                  [
                    'Hạn dùng',
                    entitlement.expiresAt ? formatDateTime(entitlement.expiresAt) : 'không hạn',
                  ],
                ]
              : []
          }
          empty="Chưa có dòng gói nào: người học đang dùng bản miễn phí mà app chưa ghi lại."
        />
        <Facts
          title="Khóa đang học"
          rows={
            enrollment
              ? [
                  ['Khóa', enrollment.courseId],
                  ['Bản nội dung', enrollment.courseVersion],
                  ['Bài đã xong', String(enrollment.lessonsDone)],
                  ['Đang ở vị trí', String(enrollment.frontier)],
                  ['Trình độ', String(enrollment.proficiency)],
                ]
              : []
          }
          empty="Chưa có tiến độ nào trong bảng đăng ký."
        />
      </div>

      <section className={cn(card, 'overflow-hidden')}>
        <h2 className="px-4 pt-4 text-sm font-medium">14 ngày gần nhất</h2>
        {days.length === 0 ? (
          <p className={cn(hint, 'px-4 py-3 text-sm')}>
            Chưa có ngày nào được ghi. Màn hình này chỉ hiện những gì app đã lưu.
          </p>
        ) : (
          <>
            <ul className="mt-3 space-y-1 px-4">
              {days.map((day) => (
                <DayRow key={day.day} day={day} max={Math.max(...days.map((d) => d.xp), 1)} />
              ))}
            </ul>
            <p className={cn(hint, 'px-4 py-3')}>
              XP cộng cả học lại bài cũ. Số bài là những bài người học hoàn thành trong ngày đó.
            </p>
          </>
        )}
      </section>

      <section className={cn(card, 'p-4')}>
        <h2 className="text-sm font-medium">Góp ý còn mở của người này</h2>
        {detail.feedback.length === 0 ? (
          <p className={cn(hint, 'mt-2 text-sm')}>Không còn góp ý nào đang chờ.</p>
        ) : (
          <ul className="mt-2 space-y-2">
            {detail.feedback.map((note) => (
              <li key={note.noteId} className="text-sm">
                <div className="text-xs text-fg-4">
                  {note.topic} · {note.platform} · {timeAgo(note.createdAt)}
                </div>
                <div className="text-fg-2">{note.message}</div>
              </li>
            ))}
          </ul>
        )}
        <p className={cn(hint, 'mt-3')}>
          Trả lời góp ý vẫn là việc trong app; ở đây chỉ nhìn thấy những gì người học gửi lên.
        </p>
      </section>
    </>
  );
}

function Facts({
  title,
  rows,
  empty,
}: {
  title: string;
  rows: [string, string][];
  empty: string;
}) {
  return (
    <section className={cn(card, 'p-4')}>
      <h2 className="text-sm font-medium">{title}</h2>
      {rows.length === 0 ? (
        <p className={cn(hint, 'mt-2 text-sm')}>{empty}</p>
      ) : (
        <dl className="mt-2 space-y-1.5 text-sm">
          {rows.map(([label, value]) => (
            <div key={label} className="flex gap-2">
              <dt className="w-36 shrink-0 text-fg-4">{label}</dt>
              <dd className="min-w-0 break-words text-fg">{value}</dd>
            </div>
          ))}
        </dl>
      )}
    </section>
  );
}

function DayRow({ day, max }: { day: { day: string; xp: number; lessons: number }; max: number }) {
  return (
    <li className="grid grid-cols-[9rem_1fr_5rem] items-center gap-3 text-xs">
      <span className="font-mono text-fg-3">{day.day}</span>
      <span className="h-2 overflow-hidden rounded-full bg-elevated">
        <span
          className="block h-full rounded-full bg-primary/70"
          style={{ width: `${Math.round((day.xp / max) * 100)}%` }}
        />
      </span>
      <span className="text-right tabular-nums text-fg-2">
        {day.xp} XP · {day.lessons} bài
      </span>
    </li>
  );
}
