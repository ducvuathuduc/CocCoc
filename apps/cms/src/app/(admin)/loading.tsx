import { card } from '@/lib/ui';
import { cn } from '@/lib/utils';

const Bar = ({ className }: { className?: string }) => (
  <span className={cn('skeleton block rounded-md', className)} aria-hidden />
);

export default function WorkspaceLoading() {
  return (
    <div className="space-y-5" aria-busy role="status">
      <span className="sr-only">Đang tải bài học…</span>
      <div className="space-y-2">
        <Bar className="h-8 w-56" />
        <Bar className="h-4 w-72 max-w-full" />
      </div>
      <div className="grid gap-2 md:grid-cols-3">
        {Array.from({ length: 3 }, (_, index) => (
          <div key={index} className={cn(card, 'space-y-2 px-4 py-3')}>
            <Bar className="h-5 w-28" />
            <Bar className="h-3 w-40 max-w-full" />
          </div>
        ))}
      </div>
      <div className="flex gap-2">
        <Bar className="h-10 flex-1 rounded-lg" />
        <Bar className="hidden h-9 w-48 sm:block" />
      </div>
      <div className={cn(card, 'overflow-hidden')}>
        {Array.from({ length: 8 }, (_, index) => (
          <div key={index} className="flex items-center gap-3 border-b border-line px-4 py-3 last:border-0">
            <Bar className="size-6 rounded-full" />
            <div className="flex-1 space-y-1.5">
              <Bar className="h-4 w-48 max-w-full" />
              <Bar className="h-3 w-64 max-w-full" />
            </div>
            <Bar className="h-9 w-16 rounded-lg" />
          </div>
        ))}
      </div>
    </div>
  );
}
