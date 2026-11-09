'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Icon, type IconName } from '@/components/icons';
import { cn } from '@/lib/utils';

/**
 * One navigation for the whole course, shown on the course home and every sub-page (cấu trúc, media,
 * tìm kiếm, sẵn sàng). A teacher never has to remember which tools live where: the current screen is
 * always highlighted, and Xuất bản stays one tap away on the right as the one action that ships.
 */
const ITEMS: { key: string; href: string; label: string; icon: IconName }[] = [
  { key: 'home', href: '', label: 'Bài học', icon: 'lessons' },
  { key: 'structure', href: '/structure', label: 'Cấu trúc & thông tin', icon: 'courses' },
  { key: 'media', href: '/media', label: 'Âm thanh & ảnh', icon: 'media' },
  { key: 'search', href: '/search', label: 'Tìm kiếm', icon: 'search' },
  { key: 'readiness', href: '/readiness', label: 'Sẵn sàng', icon: 'audit' },
];

export function CourseTabs({
  courseId,
  showPublish = true,
}: {
  courseId: string;
  showPublish?: boolean;
}) {
  const pathname = usePathname();
  const base = `/courses/${courseId}`;
  // The lesson editor lives below /units, so "Bài học" stays lit while a teacher is inside one.
  const isActive = (href: string) =>
    href === ''
      ? pathname === base || pathname.startsWith(`${base}/units`)
      : pathname.startsWith(`${base}${href}`);

  return (
    <nav
      aria-label="Màn hình khóa học"
      className="flex flex-wrap items-center gap-1 border-b border-line pb-2"
    >
      {ITEMS.map((item) => {
        const active = isActive(item.href);
        return (
          <Link
            key={item.key}
            href={`${base}${item.href}`}
            transitionTypes={['nav-forward']}
            aria-current={active ? 'page' : undefined}
            className={cn(
              'flex items-center gap-1.5 rounded-lg px-3 py-2 text-sm transition-colors',
              active
                ? 'bg-primary-soft font-medium text-primary-text'
                : 'text-fg-3 hover:bg-elevated hover:text-fg',
            )}
          >
            <Icon name={item.icon} className="size-4 shrink-0" />
            <span>{item.label}</span>
          </Link>
        );
      })}
      {showPublish && (
        <Link
          href={`/builds?course=${courseId}`}
          transitionTypes={['nav-forward']}
          className="ml-auto flex items-center gap-1.5 rounded-lg bg-primary px-3 py-2 text-sm font-medium text-primary-fg shadow-card hover:bg-primary-hover hover:shadow-lift"
        >
          <Icon name="publish" className="size-4 shrink-0" />
          Xuất bản
        </Link>
      )}
    </nav>
  );
}
