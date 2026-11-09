import { Suspense } from 'react';
import { ShellNav } from './shell';
import { learnerQueue } from '@/server/ops/learners';
import { requireAdmin } from '@/server/session';
import { storeLabel } from '@/server/audit';

/**
 * The badge counts what is still unanswered. It streams in behind its own Suspense boundary so the
 * chrome never waits on learner data; a learner-data outage must not take the chrome down with it,
 * so a failed read is simply "no badge".
 */
async function InboxBadge() {
  let count = 0;
  try {
    const queue = await learnerQueue();
    count = queue.feedback.length + queue.userReports.length + queue.contentReports.length;
  } catch {
    count = 0;
  }
  if (count === 0) return null;
  return (
    <span className="ml-1.5 flex min-w-4.5 items-center justify-center rounded-full bg-danger-fg px-1 py-0.5 text-[9px] font-semibold text-white">
      {count > 9 ? '9+' : count}
      <span className="sr-only"> thư chưa xử lý</span>
    </span>
  );
}

/** The chrome only needs the session: everything else loads when a screen or palette asks for it. */
export async function SidebarNav() {
  const identity = await requireAdmin();
  return (
    <ShellNav
      identity={identity.email || identity.userId}
      mode={storeLabel()}
      inbox={
        <Suspense fallback={null}>
          <InboxBadge />
        </Suspense>
      }
    />
  );
}