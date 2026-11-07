'use client';

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { foldKey } from '@/cms/search';
import { NAV_GROUPS } from '@/lib/words';
import { field } from '@/lib/ui';
import { cn } from '@/lib/utils';

export interface JumpLesson {
  courseId: string;
  unitId: string;
  order: number;
  title: string;
  theme: string;
}

interface Row {
  key: string;
  primary: string;
  secondary: string;
  kind: 'bài' | 'màn';
  href: string;
  hay: string;
}

const PAGES: Row[] = NAV_GROUPS.flatMap((group) => group.links).map((link) => ({
  key: `page:${link.href}`,
  primary: link.label,
  secondary: link.hint,
  kind: 'màn' as const,
  href: link.href,
  hay: foldKey(`${link.label} ${link.hint}`),
}));

/** A lesson list is 16 rows of near-identical titles, so typing three letters is faster than scanning. */
const LIMIT = 12;

export function QuickJump({
  lessons,
  onNavigate,
  openButton,
}: {
  lessons: JumpLesson[];
  onNavigate?: () => void;
  /** Replaces the default labelled trigger, e.g. the round search button in the top bar. */
  openButton?: (open: () => void) => React.ReactNode;
}) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const [index, setIndex] = useState(0);
  const input = useRef<HTMLInputElement>(null);
  const active = useRef<HTMLButtonElement>(null);

  const rows = useMemo<Row[]>(() => {
    const lessonRows: Row[] = lessons.map((lesson) => ({
      key: `lesson:${lesson.courseId}/${lesson.unitId}`,
      primary: `Bài ${lesson.order + 1} · ${lesson.title || '(chưa đặt tên)'}`,
      secondary: lesson.theme,
      kind: 'bài' as const,
      href: `/courses/${lesson.courseId}/units/${lesson.unitId}`,
      hay: foldKey(`${lesson.title} ${lesson.theme} ${lesson.unitId}`),
    }));
    const all = [...lessonRows, ...PAGES];
    const needle = foldKey(query.trim());
    if (!needle) return all.slice(0, LIMIT);
    const hits = all.filter((row) => row.hay.includes(needle));
    return [...hits.filter((r) => r.kind === 'bài'), ...hits.filter((r) => r.kind === 'màn')].slice(
      0,
      LIMIT,
    );
  }, [lessons, query]);

  const show = useCallback(() => {
    setQuery('');
    setIndex(0);
    setOpen(true);
  }, []);

  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k') {
        event.preventDefault();
        show();
      }
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [show]);

  // The list is rebuilt on open, so the caret starts in the box rather than on a stale row.
  useEffect(() => {
    if (open) input.current?.focus();
  }, [open]);

  useEffect(() => {
    active.current?.scrollIntoView({ block: 'nearest' });
  }, [index]);

  function go(href: string) {
    setOpen(false);
    onNavigate?.();
    router.push(href);
  }

  function onKeyDown(event: React.KeyboardEvent) {
    if (event.key === 'ArrowDown') {
      event.preventDefault();
      setIndex((i) => Math.min(i + 1, rows.length - 1));
    } else if (event.key === 'ArrowUp') {
      event.preventDefault();
      setIndex((i) => Math.max(i - 1, 0));
    } else if (event.key === 'Enter') {
      event.preventDefault();
      const row = rows[index];
      if (row) go(row.href);
    } else if (event.key === 'Escape') {
      event.preventDefault();
      setOpen(false);
    }
  }

  return (
    <>
      {openButton ? (
        openButton(show)
      ) : (
        <button
          type="button"
          aria-haspopup="dialog"
          onClick={show}
          className="flex w-full items-center justify-between gap-2 rounded-lg border border-line bg-input-bg px-3 py-2 text-sm text-fg-4 transition-colors hover:border-line-strong hover:text-fg"
        >
          <span className="flex items-center gap-2">
            <svg viewBox="0 0 20 20" className="size-4 shrink-0" aria-hidden="true">
              <path
                d="M9 3.5a5.5 5.5 0 1 1-3.9 9.4M13.4 13.4 17 17"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.6"
                strokeLinecap="round"
              />
            </svg>
            Đi tới một bài học
          </span>
          <kbd className="rounded border border-line bg-elevated px-1.5 py-0.5 text-[10px] font-medium">
            Ctrl K
          </kbd>
        </button>
      )}

      {open && (
        <div
          className="fixed inset-0 z-50 flex items-start justify-center bg-black/40 px-4 pt-[12vh] backdrop-blur-sm"
          onMouseDown={() => setOpen(false)}
        >
          <div
            role="dialog"
            aria-modal="true"
            aria-label="Đi tới bài học hoặc màn làm khác"
            className="w-full max-w-xl animate-pop overflow-hidden rounded-2xl border border-line-strong bg-card shadow-lift"
            onMouseDown={(event) => event.stopPropagation()}
          >
            <input
              ref={input}
              value={query}
              onChange={(event) => {
                setQuery(event.target.value);
                setIndex(0);
              }}
              onKeyDown={onKeyDown}
              placeholder="Gõ vài chữ trong tên bài, không cần dấu…"
              aria-label="Tìm bài học"
              className={cn(
                field,
                'rounded-none border-0 bg-transparent px-4 py-3 text-base focus:ring-0',
              )}
            />
            <ul className="max-h-[45vh] overflow-y-auto py-1">
              {rows.map((row, i) => (
                <li key={row.key}>
                  <button
                    type="button"
                    ref={i === index ? active : undefined}
                    onMouseEnter={() => setIndex(i)}
                    onClick={() => go(row.href)}
                    className={cn(
                      'flex w-full items-baseline gap-2 px-4 py-2 text-left text-sm transition-colors',
                      i === index ? 'bg-primary-soft text-primary-text' : 'text-fg-2',
                    )}
                  >
                    <span className="min-w-0 flex-1">
                      <span className="block truncate font-medium">{row.primary}</span>
                      {row.secondary && (
                        <span className="block truncate text-xs text-fg-4">{row.secondary}</span>
                      )}
                    </span>
                    <span className="shrink-0 text-[11px] text-fg-4">{row.kind}</span>
                  </button>
                </li>
              ))}
              {rows.length === 0 && (
                <li className="px-4 py-6 text-sm text-fg-3">
                  Không có bài nào khớp “{query}”. Thử ít chữ hơn, hoặc gõ một từ có trong tên bài.
                </li>
              )}
            </ul>
            <div className="border-t border-line px-4 py-2 text-[11px] text-fg-4">
              Gõ để tìm · ↑ ↓ để chọn · Enter để mở · Esc để đóng
            </div>
          </div>
        </div>
      )}
    </>
  );
}
