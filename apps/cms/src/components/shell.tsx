'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useRef, useState } from 'react';
import { QuickJump, type JumpLesson } from '@/components/quick-jump';
import { ThemeToggle } from '@/components/theme';
import { ADMIN_NAV, PRIMARY_NAV, type NavLink } from '@/lib/words';
import { button, circle } from '@/lib/ui';
import { cn } from '@/lib/utils';

/* One stroke vocabulary for the whole chrome: 20x20, round caps, 1.6 weight, so a
   rail icon and a top-bar icon read as the same hand. */
const PATHS: Record<string, React.ReactNode> = {
  '/': <path d="M4 4h5v5H4zM11 4h5v5h-5zM4 11h5v5H4zM11 11h5v5h-5z" />,
  '/lessons': <path d="M5 4.5h8.5A1.5 1.5 0 0 1 15 6v9.5H6.5A1.5 1.5 0 0 1 5 14zM5 14a2 2 0 0 1 2-2h8M8 7.5h4" />,
  '/builds': <path d="M10 13V4M6.5 7.5 10 4l3.5 3.5M4 15.5h12" />,
  '/users': (
    <>
      <circle cx="8" cy="7.5" r="2.5" />
      <path d="M3.5 15.5c.6-2.7 2.4-4 4.5-4s3.9 1.3 4.5 4M13 5.4a2.5 2.5 0 0 1 0 4.9M14.3 11.6c1.5.5 2.4 1.8 2.8 3.9" />
    </>
  ),
  '/courses': <path d="M10 3.5 16 7l-6 3.5L4 7zM4 10.5l6 3.5 6-3.5M4 13.5 10 17l6-3.5" />,
  '/ops/inbox': (
    <>
      <rect x="3.5" y="5" width="13" height="10" rx="2" />
      <path d="m4.5 7.5 5.5 4 5.5-4" />
    </>
  ),
  '/ops/audit': (
    <>
      <circle cx="10" cy="10" r="6.5" />
      <path d="M10 6.5V10l2.5 2" />
    </>
  ),
  '/ops/access': <path d="M10 3.5 15 5.5v4.2c0 3.3-2.1 5.7-5 6.8-2.9-1.1-5-3.5-5-6.8V5.5z" />,
  search: <path d="M9 3.5a5.5 5.5 0 1 1-3.9 9.4M13.4 13.4 17 17" />,
};

function Icon({ name, className }: { name: string; className?: string }) {
  return (
    <svg
      viewBox="0 0 20 20"
      className={className ?? 'size-5'}
      fill="none"
      stroke="currentColor"
      strokeWidth="1.6"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {PATHS[name] ?? PATHS['/']}
    </svg>
  );
}

function MenuIcon({ open }: { open: boolean }) {
  return (
    <svg
      viewBox="0 0 20 20"
      aria-hidden
      className="size-5"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.6"
      strokeLinecap="round"
    >
      {open ? <path d="M5 5l10 10M15 5L5 15" /> : <path d="M3.5 6h13M3.5 10h13M3.5 14h13" />}
    </svg>
  );
}

export function ShellNav({
  identity,
  mode,
  lessons,
  inboxCount,
}: {
  identity: string;
  mode: string;
  lessons: JumpLesson[];
  inboxCount: number;
}) {
  const pathname = usePathname();
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [sheet, setSheet] = useState(false);
  const [menu, setMenu] = useState(false);
  const menuBox = useRef<HTMLDivElement>(null);
  const sheetPanel = useRef<HTMLDivElement>(null);
  const toggle = useRef<HTMLButtonElement>(null);

  async function signOut() {
    setBusy(true);
    await fetch('/api/auth/logout', { method: 'POST' });
    router.replace('/login');
    router.refresh();
  }

  useEffect(() => {
    if (!menu) return;
    const onDown = (event: MouseEvent) => {
      if (!menuBox.current?.contains(event.target as Node)) setMenu(false);
    };
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setMenu(false);
    };
    document.addEventListener('mousedown', onDown);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onDown);
      document.removeEventListener('keydown', onKey);
    };
  }, [menu]);

  // The sheet owns the scroll lock and closes from the controls that navigate;
  // an effect on `pathname` would re-render the whole chrome per route change.
  useEffect(() => {
    if (!sheet) return;
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setSheet(false);
        toggle.current?.focus();
      }
    };
    document.addEventListener('keydown', onKey);
    const previous = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    sheetPanel.current?.focus();
    return () => {
      document.removeEventListener('keydown', onKey);
      document.body.style.overflow = previous;
    };
  }, [sheet]);

  const activeOf = (href: string): boolean => {
    if (href === '/') return pathname === '/';
    // The lesson workspace lives under /courses/<id>, so "Bài học" owns those paths.
    if (href === '/lessons') return pathname === '/lessons' || pathname.startsWith('/courses/');
    if (href === '/courses') return pathname === '/courses';
    return pathname === href || pathname.startsWith(`${href}/`);
  };

  const pill = (link: NavLink) => {
    const active = activeOf(link.href);
    return (
      <Link
        key={link.href}
        href={link.href}
        title={link.hint}
        transitionTypes={['nav-section']}
        aria-current={active ? 'page' : undefined}
        onClick={() => setSheet(false)}
        className={cn(
          'rounded-full px-4 py-2 text-sm transition-colors',
          active
            ? 'bg-fg font-medium text-card shadow-card'
            : 'text-fg-2 hover:bg-elevated hover:text-fg',
        )}
      >
        {link.label}
      </Link>
    );
  };

  const row = (link: NavLink) => {
    const active = activeOf(link.href);
    return (
      <Link
        key={link.href}
        href={link.href}
        title={link.hint}
        transitionTypes={['nav-section']}
        aria-current={active ? 'page' : undefined}
        onClick={() => setSheet(false)}
        className={cn(
          'flex min-h-10 items-center gap-2.5 rounded-xl px-3 py-2 text-sm transition-colors',
          active ? 'bg-fg font-medium text-card' : 'text-fg-2 hover:bg-elevated hover:text-fg',
        )}
      >
        <Icon name={link.href} className="size-4.5 shrink-0" />
        {link.label}
      </Link>
    );
  };

  const shared = mode.includes('Appwrite');
  const initials = identity.replace(/@.*/, '').slice(0, 2).toUpperCase() || '•';

  return (
    <>
      <header className="fixed inset-x-0 top-0 z-40 flex h-16 items-center gap-2 border-b border-line/70 bg-surface/90 px-3 backdrop-blur sm:px-5">
        <button
          ref={toggle}
          type="button"
          aria-label={sheet ? 'Đóng menu' : 'Mở menu'}
          aria-expanded={sheet}
          aria-controls="cms-sheet"
          onClick={() => setSheet((value) => !value)}
          className={cn(circle, 'lg:hidden')}
        >
          <MenuIcon open={sheet} />
        </button>

        <Link
          href="/"
          transitionTypes={['nav-back']}
          aria-label="CocEnglish CMS — về tổng quan"
          className="flex items-center gap-2.5 pr-1"
        >
          <span className="flex size-9 items-center justify-center rounded-2xl bg-fg text-card shadow-card">
            <Icon name="/courses" className="size-4.5" />
          </span>
          <span className="hidden text-[15px] font-semibold tracking-tight md:block">
            CocEnglish <span className="font-normal text-fg-4">CMS</span>
          </span>
        </Link>

        <nav aria-label="Điều hướng chính" className="mx-auto hidden items-center gap-1 lg:flex">
          {PRIMARY_NAV.map(pill)}
        </nav>

        <div className="ml-auto flex items-center gap-2">
          <QuickJump
            lessons={lessons}
            openButton={(open) => (
              <button
                type="button"
                onClick={open}
                aria-haspopup="dialog"
                aria-label="Tìm bài học hoặc màn làm việc (Ctrl K)"
                title="Tìm bài học hoặc màn làm việc (Ctrl K)"
                className={circle}
              >
                <Icon name="search" className="size-4.5" />
              </button>
            )}
          />

          <Link
            href="/ops/inbox"
            transitionTypes={['nav-section']}
            title="Thư của người học — góp ý và báo cáo còn đang mở"
            aria-label={`Thư của người học${inboxCount > 0 ? `, ${inboxCount} thư chưa xử lý` : ''}`}
            className={cn(circle, activeOf('/ops/inbox') && 'bg-fg text-card')}
          >
            <Icon name="/ops/inbox" className="size-4.5" />
            {inboxCount > 0 && (
              <span className="absolute -top-1 -right-1 flex size-4.5 items-center justify-center rounded-full bg-danger-fg text-[9px] font-semibold text-white">
                {inboxCount > 9 ? '9+' : inboxCount}
              </span>
            )}
          </Link>

          <div ref={menuBox} className="relative">
            <button
              type="button"
              aria-haspopup="menu"
              aria-expanded={menu}
              aria-label={`Tài khoản ${identity}`}
              onClick={() => setMenu((value) => !value)}
              className={cn(
                circle,
                'bg-fg text-xs font-semibold text-card hover:text-card',
                menu && 'shadow-lift',
              )}
            >
              {initials}
            </button>
            {menu && (
              <div
                role="menu"
                aria-label="Tài khoản"
                className="absolute right-0 top-12 w-60 rounded-2xl bg-card p-2 shadow-lift"
              >
                <div className="px-3 pt-2 pb-1">
                  <div className="truncate text-sm font-medium" title={identity}>
                    {identity}
                  </div>
                  <div
                    className="mt-1 flex items-center gap-1.5 text-[11px] text-fg-4"
                    title={shared ? 'Bản soạn lưu trên máy chủ dùng chung' : 'Bản soạn chỉ lưu trên máy này'}
                  >
                    <span
                      className={cn('size-1.5 rounded-full', shared ? 'bg-ok-fg' : 'bg-warn-fg')}
                    />
                    {shared ? 'Máy chủ dùng chung' : 'Chỉ máy này'}
                  </div>
                </div>
                <div className="my-1 border-t border-line" />
                <div className="px-1">
                  <ThemeToggle />
                </div>
                <button
                  type="button"
                  role="menuitem"
                  onClick={signOut}
                  disabled={busy}
                  className={cn(button, 'mt-1 w-full')}
                >
                  {busy ? 'Đang thoát…' : 'Thoát'}
                </button>
              </div>
            )}
          </div>
        </div>
      </header>

      <aside
        aria-label="Quản trị"
        // The rail is the spatial anchor of the admin: naming it keeps it still
        // while the screen inside it changes.
        style={{ viewTransitionName: 'sidebar' }}
        className="fixed bottom-0 left-0 top-16 z-30 hidden w-14 flex-col items-center gap-1.5 border-r border-line/70 bg-surface pt-4 pb-16 lg:flex"
      >
        {ADMIN_NAV.map((link) => {
          const active = activeOf(link.href);
          return (
            <Link
              key={link.href}
              href={link.href}
              title={`${link.label} — ${link.hint}`}
              transitionTypes={['nav-section']}
              aria-current={active ? 'page' : undefined}
              className={cn(
                'flex size-10 items-center justify-center rounded-full transition-colors',
                active ? 'bg-fg text-card shadow-card' : 'text-fg-3 hover:bg-elevated hover:text-fg',
              )}
            >
              <Icon name={link.href} className="size-4.5" />
            </Link>
          );
        })}
        <div className="mt-auto">
          <ThemeToggle
            showLabel={false}
            className={cn(circle, 'bg-surface text-fg-3 shadow-none hover:bg-elevated')}
          />
        </div>
      </aside>

      {sheet && (
        <button
          type="button"
          aria-label="Đóng menu"
          tabIndex={-1}
          onClick={() => setSheet(false)}
          className="fixed inset-0 z-40 cursor-default bg-black/40 lg:hidden"
        />
      )}

      <div
        id="cms-sheet"
        ref={sheetPanel}
        tabIndex={-1}
        aria-label="Khu điều hướng"
        aria-hidden={!sheet}
        className={cn(
          'fixed inset-y-0 left-0 z-50 flex w-72 max-w-[85vw] flex-col overflow-y-auto border-r border-line bg-surface p-4 outline-none transition-transform duration-200 lg:hidden',
          sheet ? 'translate-x-0 shadow-lift' : '-translate-x-full',
        )}
      >
        <div className="flex items-center gap-2 px-1">
          <span className="flex size-8 items-center justify-center rounded-xl bg-fg text-card">
            <Icon name="/courses" className="size-4" />
          </span>
          <span className="text-sm font-semibold tracking-tight">
            CocEnglish <span className="font-normal text-fg-4">CMS</span>
          </span>
        </div>
        <nav aria-label="Điều hướng chính" className="mt-4 flex flex-col gap-0.5">
          {PRIMARY_NAV.map(row)}
        </nav>
        <div className="mt-4 flex flex-col gap-0.5 border-t border-line pt-3">
          {ADMIN_NAV.map(row)}
        </div>
        <div className="mt-auto space-y-2 border-t border-line pt-4">
          <ThemeToggle />
          <button type="button" onClick={signOut} disabled={busy} className={cn(button, 'w-full')}>
            {busy ? 'Đang thoát…' : 'Thoát'}
          </button>
        </div>
      </div>
    </>
  );
}
