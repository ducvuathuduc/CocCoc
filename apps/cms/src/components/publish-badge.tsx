import type { WorkspacePublish } from '@/server/workspace';
import { cn } from '@/lib/utils';

/**
 * Whether a course can ship, in one word. It reads the same gates the readiness screen reads, so the
 * course list, the workspace and the publish check can never tell three different stories.
 */
export function PublishBadge({
  publish,
  className,
}: {
  publish: Pick<WorkspacePublish, 'publishAllowed' | 'gatesOk' | 'blocking'>;
  className?: string;
}) {
  const base =
    'inline-flex shrink-0 items-center gap-1.5 rounded-full border px-2.5 py-1 text-xs font-medium';
  if (!publish.publishAllowed) {
    return (
      <span className={cn(base, 'border-line bg-elevated text-fg-3', className)}>
        <span className="size-1.5 rounded-full bg-fg-4" />
        Chưa bật xuất bản
      </span>
    );
  }
  if (publish.gatesOk) {
    return (
      <span className={cn(base, 'border-ok-bd bg-ok-bg text-ok-fg', className)}>
        <span className="size-1.5 rounded-full bg-ok-fg" />
        Sẵn sàng xuất bản
      </span>
    );
  }
  return (
    <span
      className={cn(base, 'border-warn-bd bg-warn-bg text-warn-fg', className)}
      title={publish.blocking}
    >
      <span className="size-1.5 rounded-full bg-warn-fg" />
      Chưa đủ điều kiện
    </span>
  );
}
