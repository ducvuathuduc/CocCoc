'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useRef, useState } from 'react';
import { Icon } from '@/components/icons';
import { QuickJump } from '@/components/quick-jump';
import { ThemeToggle } from '@/components/theme';
import { NAV_GROUPS, type NavLink } from '@/lib/words';
import { button, circle } from '@/lib/ui';
import { cn } from '@/lib/utils';

/**
 * A small logo mark plus the wordmark: the operator reads "CocEnglish" by the coloured tile, not by
 * scanning a row of text. Kept at module scope so its identity is stable across shell re-renders.
 */
function BrandMark({ size = 17 }: { size?: number }) {
  return (
    <Link
      href="/"
      transitionTypes={['nav-back']}
      aria-label="CocEnglish CMS — về tổng quan"
      className="flex items-center gap-2"
    >
      <span className="grid size-7 shrink-0 place-items-center rounded-lg bg-primary text-primary-fg shadow-card">
        <Icon name="courses" className="size-4" />
      </span>
      <span className={cn('font-semibold tracking-tight', size === 15 && 'text-[15px]')}>
        CocEnglish <span className="font-normal text-fg-4">CMS</span>
      </span>
    </Link>
  );
}

/**
 * The chrome is a fixed left rail, not a top bar: nine destinations in one horizontal strip read as a
 * toolbar, while a grouped column reads as a table of contents. Every item is a word plus a shape, so
 * the operator can find "Người học" by position or by icon without reading the whole list.
 */
export function ShellNav({
  identity,
  mode,
  inbox,
}: {
  identity: string;
  mode: string;
  /** The unread-count badge, streamed in separately so the chrome never waits on learner data. */
  inbox: React.ReactNode;
}) {
  const pathname = usePathname();
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [sheet, setSheet] = useState(false);
  const [menu, setMenu] = useState(false);
  // One menu, two places it can be anchored: the mobile bar and the desktop rail footer.
  const menuTop = useRef<HTMLDivElement>(null);
  const menuBottom = useRef<HTMLDivElement>(null);
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
      const target = event.target as Node;
      if (!menuTop.current?.contains(target) && !menuBottom.current?.contains(target)) setMenu(false);
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
    // `/courses` is the course list; a course workspace lives below it and belongs to "Bài học".
    if (href === '/courses') return pathname === '/courses';
    if (href === '/lessons') return pathname === '/lessons' || pathname.startsWith('/courses/');
    return pathname === href || pathname.startsWith(`${href}/`);
  };

  const row = (link: NavLink, inMenu = false) => {
    const active = activeOf(link.href);
    return (
      <Link
        key={link.href}
        href={link.href}
        title={link.hint}
        transitionTypes={['nav-section']}
        aria-current={active ? 'page' : undefined}
        role={inMenu ? 'menuitem' : undefined}
        onClick={() => {
          setSheet(false);
          setMenu(false);
        }}
        className={cn(
          'group flex min-h-10 items-center gap-2.5 rounded-lg px-2.5 py-2 text-sm transition-colors',
          active
            ? 'bg-primary-soft font-medium text-primary-text'
            : 'text-fg-2 hover:bg-elevated hover:text-fg',
        )}
      >
        <Icon
          name={link.icon}
          className={cn('size-[18px] shrink-0', active ? 'text-primary-text' : 'text-fg-4')}
        />
        <span className="truncate">{link.label}</span>
      </Link>
    );
  };

  const groups = (inMenu = false) =>
    NAV_GROUPS.map((group) => (
      <div key={group.title} className="space-y-0.5">
        <p className="px-2.5 pt-3 pb-1 text-[10px] font-semibold tracking-[0.08em] text-fg-4 uppercase">
          {group.title}
        </p>
        {group.links.map((link) => row(link, inMenu))}
      </div>
    ));

  const shared = mode.includes('Appwrite');
  const initials = identity.replace(/@.*/, '').slice(0, 2).toUpperCase() || '•';

  const account = (placement: 'top' | 'bottom') => (
    <div ref={placement === 'top' ? menuTop : menuBottom} className="relative">
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
          className={cn(
            'absolute z-50 w-60 rounded-2xl bg-card p-2 shadow-lift',
            placement === 'top' ? 'right-0 top-12' : 'bottom-12 left-0',
          )}
        >
          <div className="px-3 pt-2 pb-1">
            <div className="truncate text-sm font-medium" title={identity}>
              {identity}
            </div>
            <div
              className="mt-1 flex items-center gap-1.5 text-[11px] text-fg-4"
              title={shared ? 'Bản soạn lưu trên máy chủ dùng chung' : 'Bản soạn chỉ lưu trên máy này'}
            >
              <span className={cn('size-1.5 rounded-full', shared ? 'bg-ok-fg' : 'bg-warn-fg')} />
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
  );

  return (
    <>
      <header className="fixed inset-x-0 top-0 z-40 flex h-14 items-center gap-2 border-b border-line/70 bg-surface/95 px-3 backdrop-blur lg:hidden">
        <button
          ref={toggle}
          type="button"
          aria-label={sheet ? 'Đóng menu' : 'Mở menu'}
          aria-expanded={sheet}
          aria-controls="cms-sheet"
          onClick={() => setSheet((value) => !value)}
          className={cn(button, 'min-h-10 px-3')}
        >
          Menu
        </button>

        <div className="pr-1 text-[15px] font-semibold tracking-tight">
          <BrandMark size={15} />
        </div>

        <div className="ml-auto flex items-center gap-1.5">
          <Link
            href="/ops/inbox"
            transitionTypes={['nav-section']}
            title="Thư của người học — góp ý và báo cáo còn đang mở"
            className={cn(
              'flex min-h-10 items-center rounded-lg border border-line-strong px-3 text-sm shadow-card transition-colors',
              activeOf('/ops/inbox')
                ? 'bg-fg font-medium text-card'
                : 'bg-card text-fg-2 hover:bg-primary-soft hover:text-primary-text',
            )}
          >
            Thư
            {inbox}
          </Link>
          {account('top')}
        </div>
      </header>

      <aside className="fixed inset-y-0 left-0 z-40 hidden w-64 flex-col border-r border-line bg-surface lg:flex">
        <div className="px-5 pt-6 pb-4">
          <BrandMark />
          <p className="mt-0.5 text-xs text-fg-4">Quản lý bài học và người học</p>
        </div>

        <div className="px-3 pb-2">
          <QuickJump
            openButton={(open) => (
              <button
                type="button"
                onClick={open}
                aria-haspopup="dialog"
                aria-label="Tìm bài học hoặc màn làm việc (Ctrl K)"
                title="Tìm bài học hoặc màn làm việc (Ctrl K)"
                className={cn(
                  button,
                  'flex w-full min-h-10 items-center gap-2 px-3 text-fg-3',
                )}
              >
                <Icon name="search" />
                <span>Tìm bài học…</span>
                <kbd className="ml-auto rounded border border-line bg-elevated px-1.5 py-0.5 text-[10px] font-medium text-fg-4">
                  Ctrl K
                </kbd>
              </button>
            )}
          />
        </div>

        <nav
          aria-label="Điều hướng chính"
          className="flex-1 space-y-1 overflow-y-auto px-3 pt-1 pb-4"
        >
          {groups()}
        </nav>

        <div className="border-t border-line p-3">
          <div className="flex items-center gap-2.5">
            {account('bottom')}
            <div className="min-w-0 flex-1">
              <div className="truncate text-xs font-medium" title={identity}>
                {identity}
              </div>
              <div
                className="flex items-center gap-1.5 text-[11px] text-fg-4"
                title={shared ? 'Bản soạn lưu trên máy chủ dùng chung' : 'Bản soạn chỉ lưu trên máy này'}
              >
                <span className={cn('size-1.5 rounded-full', shared ? 'bg-ok-fg' : 'bg-warn-fg')} />
                {shared ? 'Máy chủ dùng chung' : 'Chỉ máy này'}
              </div>
            </div>
          </div>
          <Link
            href="/ops/inbox"
            transitionTypes={['nav-section']}
            className="mt-2 flex min-h-9 items-center gap-2 rounded-lg px-2 text-xs text-fg-3 hover:bg-elevated hover:text-fg"
          >
            <Icon name="inbox" className="size-4 shrink-0 text-fg-4" />
            Thư chờ xử lý
            {inbox}
          </Link>
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
          'fixed inset-y-0 left-0 z-50 flex w-72 max-w-[85vw] flex-col overflow-y-auto border-r border-line bg-surface p-3 outline-none transition-transform duration-200 lg:hidden',
          sheet ? 'translate-x-0 shadow-lift' : '-translate-x-full',
        )}
      >
        <div className="px-2 pt-2 pb-3 text-sm font-semibold tracking-tight">
          <BrandMark size={15} />
        </div>
        <nav aria-label="Điều hướng chính" className="flex flex-col">
          {groups(true)}
        </nav>
        <div className="mt-auto space-y-2 border-t border-line pt-3">
          <div className="flex items-center gap-2 px-1 text-xs text-fg-4">
            <span className={cn('size-1.5 rounded-full', shared ? 'bg-ok-fg' : 'bg-warn-fg')} />
            {identity}
          </div>
          <ThemeToggle />
          <button type="button" onClick={signOut} disabled={busy} className={cn(button, 'w-full')}>
            {busy ? 'Đang thoát…' : 'Thoát'}
          </button>
        </div>
      </div>
    </>
  );
}
