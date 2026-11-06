'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { cn } from '@/lib/utils';

const TOOLS = [
  { key: 'structure', label: 'Cấu trúc & thông tin khóa', hint: 'Các phần học, tên khóa' },
  { key: 'media', label: 'Âm thanh & ảnh', hint: 'File chưa có, file chưa dùng được' },
  { key: 'search', label: 'Tìm & thay thế', hint: 'Tìm một từ trong cả khóa' },
  { key: 'readiness', label: 'Điều kiện xuất bản', hint: 'Còn gì chưa xong' },
];

/**
 * The six tabs read like an admin console. The way back to the lessons is the one link an author
 * needs every time; the four inspection tools are still here, one click deeper.
 */
export function CourseTabs({ courseId }: { courseId: string }) {
  const pathname = usePathname();
  const base = `/courses/${courseId}`;

  return (
    <div className="flex flex-wrap items-center gap-2 border-b border-line pb-2">
      <Link
        href={base}
        transitionTypes={['nav-back']}
        className="rounded-lg px-2 py-2 text-sm text-fg-3 hover:bg-elevated hover:text-fg"
      >
        ← Bài học
      </Link>

      <details className="relative">
        <summary className="cursor-pointer list-none rounded-lg border border-line px-3 py-2 text-sm text-fg-2 hover:border-line-strong hover:bg-elevated [&::-webkit-details-marker]:hidden">
          Công cụ khóa
        </summary>
        <div className="absolute left-0 z-30 mt-1 w-72 max-w-[calc(100vw-2rem)] rounded-xl border border-line-strong bg-card p-2 shadow-lift">
          {TOOLS.map((tool) => {
            const active = pathname.startsWith(`${base}/${tool.key}`);
            return (
              <Link
                key={tool.key}
                href={`${base}/${tool.key}`}
                transitionTypes={['nav-forward']}
                aria-current={active ? 'page' : undefined}
                className={cn(
                  'block rounded-lg px-3 py-2 hover:bg-elevated',
                  active && 'bg-primary-soft',
                )}
              >
                <span
                  className={cn(
                    'block text-sm',
                    active ? 'font-medium text-primary-text' : 'text-fg-2',
                  )}
                >
                  {tool.label}
                </span>
                <span className="block text-xs text-fg-4">{tool.hint}</span>
              </Link>
            );
          })}
        </div>
      </details>

      <Link
        href={`/builds?course=${courseId}`}
        transitionTypes={['nav-forward']}
        className="ml-auto text-sm text-fg-3 hover:text-primary-text"
      >
        Xuất bản →
      </Link>
    </div>
  );
}
