import { cn } from '@/lib/utils';

/**
 * Technical depth stays available but never competes with the action a non-technical operator needs to
 * take. Plain `<details>` so the block is collapsed in the server HTML and needs no hydration to open.
 */
export function TechDetails({
  title = 'Chi tiết kỹ thuật',
  children,
  className,
}: {
  title?: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <details
      className={cn(
        'group rounded-xl border border-line bg-elevated/50 px-4 py-2.5 transition-colors hover:border-line-strong',
        className,
      )}
    >
      <summary className="cursor-pointer list-none text-xs font-medium text-fg-3 hover:text-primary-text [&::-webkit-details-marker]:hidden">
        <span className="mr-1.5 inline-block transition-transform group-open:rotate-90">›</span>
        {title}
      </summary>
      <div className="mt-2.5 space-y-2 border-t border-line pt-2.5 text-xs leading-relaxed text-fg-3">
        {children}
      </div>
    </details>
  );
}
