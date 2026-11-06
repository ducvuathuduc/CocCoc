'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useRef, useState } from 'react';
import { ThemeToggle } from '@/components/theme';
import { QuickJump, type JumpLesson } from '@/components/quick-jump';
import { ADMIN_NAV, PRIMARY_NAV, type NavLink } from '@/lib/words';
import { button } from '@/lib/ui';
import { cn } from '@/lib/utils';

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

export function Sidebar({
  identity,
  mode,
  lessons,
}: {
  identity: string;
  mode: string;
  lessons: JumpLesson[];
}) {
  const pathname = usePathname();
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [open, setOpen] = useState(false);
  const rail = useRef<HTMLElement>(null);
  const toggle = useRef<HTMLButtonElement>(null);

  async function signOut() {
    setBusy(true);
    await fetch('/api/auth/logout', { method: 'POST' });
    router.replace('/login');
    router.refresh();
  }

  // The drawer closes from the controls that navigate; an effect on `pathname` would re-render
  // the whole rail after every route change just to hide it.
  useEffect(() => {
    if (!open) return;
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setOpen(false);
        toggle.current?.focus();
      }
    };
    document.addEventListener('keydown', onKey);
    const previous = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    rail.current?.focus();
    return () => {
      document.removeEventListener('keydown', onKey);
      document.body.style.overflow = previous;
    };
  }, [open]);

  const activeOf = (href: string): boolean => {
    if (href === '/') return pathname === '/' || pathname.startsWith('/courses/');
    if (href === '/courses') return pathname === '/courses';
    return pathname === href || pathname.startsWith(`${href}/`);
  };

  const navItem = (link: NavLink, small = false) => {
    const active = activeOf(link.href);
    return (
      <Link
        key={link.href}
        href={link.href}
        title={link.hint}
        transitionTypes={['nav-section']}
        aria-current={active ? 'page' : undefined}
        onClick={() => setOpen(false)}
        className={cn(
          'relative flex min-h-9 items-center rounded-lg px-3 py-2 transition-colors',
          small ? 'text-[13px]' : 'text-sm',
          active
            ? 'bg-primary-soft font-medium text-primary-text'
            : 'text-fg-2 hover:bg-elevated hover:text-fg',
        )}
      >
        {active && (
          <span className="absolute top-1/2 -left-4 h-5 w-1 -translate-y-1/2 rounded-r-full bg-primary" />
        )}
        {link.label}
      </Link>
    );
  };

  const nav = (
    <nav aria-label="Điều hướng chính" className="mt-5 flex flex-1 flex-col gap-0.5">
      {PRIMARY_NAV.map((link) => navItem(link))}

      <details className="mt-3 rounded-lg border border-line">
        <summary className="cursor-pointer list-none px-3 py-2 text-xs font-medium text-fg-4 hover:text-fg [&::-webkit-details-marker]:hidden">
          Quản trị
        </summary>
        <div className="flex flex-col gap-0.5 p-1">
          {ADMIN_NAV.map((link) => navItem(link, true))}
          <div
            className="mt-1 flex items-center gap-1.5 border-t border-line px-3 pt-2 pb-1 text-[11px] text-fg-4"
            title={
              mode.includes('Appwrite')
                ? 'Bản soạn lưu trên máy chủ dùng chung'
                : 'Bản soạn chỉ lưu trên máy này'
            }
          >
            <span
              className={cn(
                'size-1.5 rounded-full',
                mode.includes('Appwrite') ? 'bg-ok-fg' : 'bg-warn-fg',
              )}
            />
            {mode.includes('Appwrite') ? 'Máy chủ dùng chung' : 'Chỉ máy này'}
          </div>
        </div>
      </details>
    </nav>
  );

  return (
    <>
      <header className="sticky top-0 z-30 flex h-14 shrink-0 items-center gap-3 border-b border-line bg-surface px-4 lg:hidden">
        <button
          ref={toggle}
          type="button"
          aria-label={open ? 'Đóng menu' : 'Mở menu'}
          aria-expanded={open}
          aria-controls="cms-nav"
          onClick={() => setOpen((value) => !value)}
          className="-ml-1 rounded-lg p-2 text-fg-2 hover:bg-elevated hover:text-fg"
        >
          <MenuIcon open={open} />
        </button>
        <span className="text-sm font-semibold tracking-tight text-primary-text">CocEnglish</span>
        <span className="ml-auto max-w-[45vw] truncate text-xs text-fg-4" title={identity}>
          {identity}
        </span>
      </header>

      {open && (
        <button
          type="button"
          aria-label="Đóng menu"
          tabIndex={-1}
          onClick={() => setOpen(false)}
          className="fixed inset-0 z-40 cursor-default bg-black/40 lg:hidden"
        />
      )}

      <aside
        id="cms-nav"
        ref={rail}
        tabIndex={-1}
        aria-label="Khu điều hướng"
        // The rail is the spatial anchor of the admin: naming it keeps it still
        // while the screen inside it changes.
        style={{ viewTransitionName: 'sidebar' }}
        className={cn(
          'fixed inset-y-0 left-0 z-50 flex w-72 max-w-[85vw] flex-col overflow-y-auto border-r border-line bg-surface p-4 outline-none transition-transform duration-200',
          'lg:sticky lg:top-0 lg:z-auto lg:h-screen lg:w-64 lg:max-w-none lg:translate-x-0 lg:shadow-none',
          open ? 'translate-x-0 shadow-lift' : '-translate-x-full',
        )}
      >
        <div className="flex items-center gap-2 px-2">
          <span className="size-2.5 rounded-full bg-primary shadow-[0_0_0_4px_var(--primary-soft)]" />
          <span className="text-sm font-semibold tracking-tight text-primary-text">CocEnglish</span>
        </div>

        <div className="mt-4">
          <QuickJump lessons={lessons} onNavigate={() => setOpen(false)} />
        </div>

        {nav}

        <div className="mt-6 space-y-2 border-t border-line pt-4 text-xs text-fg-4">
          <div className="hidden truncate text-fg-3 lg:block" title={identity}>
            {identity}
          </div>
          <div className="pt-1">
            <ThemeToggle />
          </div>
          <button type="button" onClick={signOut} disabled={busy} className={cn(button, 'w-full')}>
            {busy ? 'Đang thoát…' : 'Thoát'}
          </button>
        </div>
      </aside>
    </>
  );
}
