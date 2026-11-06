'use client';

import Link from 'next/link';
import { useMemo, useState } from 'react';
import { DeleteUnitButton, UnitMoveButtons } from '@/components/course-tools';
import { foldKey } from '@/cms/search';
import type { LessonState, WorkspaceLesson } from '@/server/workspace';
import { button, field } from '@/lib/ui';
import { cn, timeAgo } from '@/lib/utils';

const STATE: Record<LessonState, { label: string; chip: string }> = {
  error: { label: 'Cần sửa', chip: 'bg-danger-bg text-danger-fg ring-danger-bd' },
  empty: { label: 'Còn trống', chip: 'bg-warn-bg text-warn-fg ring-warn-bd' },
  warning: { label: 'Nên xem lại', chip: 'bg-warn-bg text-warn-fg ring-warn-bd' },
  ready: { label: 'Nội dung ổn', chip: 'bg-ok-bg text-ok-fg ring-ok-bd' },
};

function summary(lesson: WorkspaceLesson): string {
  if (lesson.vocab === 0 && lesson.sentences === 0) return 'Chưa có từ vựng hay câu nào';
  const parts = [`${lesson.vocab} từ`, `${lesson.sentences} câu`];
  if (lesson.dialogues > 0) parts.push(`${lesson.dialogues} hội thoại`);
  if (lesson.questions > 0) parts.push(`${lesson.questions} câu hỏi`);
  return parts.join(' · ');
}

function statusDetail(lesson: WorkspaceLesson): string | null {
  if (lesson.state === 'error') return `${lesson.errors} lỗi cần sửa`;
  if (lesson.state === 'warning') return `${lesson.warnings} điều nên xem lại`;
  if (lesson.state === 'empty') return 'Thêm từ vựng để bắt đầu';
  return null;
}

/**
 * The lesson list is the home screen, so search sits above the rows and the status of a lesson is
 * visible without opening it. Reordering and deleting stay behind one menu per row: they are rare,
 * and each rewrites how the app numbers the lessons.
 */
export function LessonList({
  courseId,
  lessons,
}: {
  courseId: string;
  lessons: WorkspaceLesson[];
}) {
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<'all' | LessonState>('all');

  const counts = useMemo(
    () => ({
      all: lessons.length,
      error: lessons.filter((lesson) => lesson.state === 'error').length,
      empty: lessons.filter((lesson) => lesson.state === 'empty').length,
      warning: lessons.filter((lesson) => lesson.state === 'warning').length,
      ready: lessons.filter((lesson) => lesson.state === 'ready').length,
    }),
    [lessons],
  );

  const rows = useMemo(() => {
    const needle = foldKey(query.trim());
    return lessons.filter(
      (lesson) =>
        (filter === 'all' || lesson.state === filter) &&
        (!needle || foldKey(lesson.title).includes(needle)),
    );
  }, [lessons, query, filter]);

  const filters: { key: 'all' | LessonState; label: string }[] = [
    { key: 'all', label: 'Tất cả' },
    { key: 'error', label: STATE.error.label },
    { key: 'empty', label: STATE.empty.label },
    { key: 'warning', label: STATE.warning.label },
    { key: 'ready', label: STATE.ready.label },
  ];

  return (
    <div className="space-y-3">
      <div className="flex flex-col gap-2 sm:flex-row sm:items-center">
        <div className="relative min-w-0 flex-1">
          <svg
            viewBox="0 0 20 20"
            aria-hidden
            className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-fg-4"
          >
            <path
              d="M9 3.5a5.5 5.5 0 1 1-3.9 9.4M13.4 13.4 17 17"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.6"
              strokeLinecap="round"
            />
          </svg>
          <input
            className={cn(field, 'pl-9')}
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Tìm bài theo tên…"
            aria-label="Tìm bài học"
            type="search"
          />
        </div>
        <div className="flex gap-1 overflow-x-auto pb-0.5 sm:flex-wrap sm:justify-end">
          {filters.map((item) => {
            const count = counts[item.key];
            if (item.key !== 'all' && count === 0) return null;
            return (
              <button
                key={item.key}
                type="button"
                aria-pressed={filter === item.key}
                onClick={() => setFilter(item.key)}
                className={cn(
                  'min-h-9 shrink-0 rounded-full border px-3 text-xs transition-colors',
                  filter === item.key
                    ? 'border-primary bg-primary-soft font-medium text-primary-text'
                    : 'border-line text-fg-3 hover:border-line-strong hover:text-fg',
                )}
              >
                {item.label}
                <span className="ml-1 tabular-nums text-fg-4">{count}</span>
              </button>
            );
          })}
        </div>
      </div>

      <div className="rounded-xl border border-line bg-card shadow-card">
        {rows.length === 0 ? (
          <div className="px-4 py-8 text-center">
            <p className="text-sm text-fg-2">
              {query.trim() ? `Không có bài nào tên chứa “${query.trim()}”.` : 'Không có bài nào ở mục này.'}
            </p>
            {query.trim() && (
              <button
                type="button"
                onClick={() => setQuery('')}
                className="mt-1 text-xs font-medium text-primary-text hover:underline"
              >
                Xóa tìm kiếm
              </button>
            )}
          </div>
        ) : (
          <ul className="divide-y divide-line">
            {rows.map((lesson) => {
              const state = STATE[lesson.state];
              const detail = statusDetail(lesson);
              const title = lesson.title || 'Bài chưa đặt tên';
              const editHref = `/courses/${courseId}/units/${lesson.unitId}`;
              return (
                <li
                  key={lesson.unitId}
                  className="flex items-start gap-2 px-3 py-3 transition-colors first:rounded-t-xl last:rounded-b-xl hover:bg-elevated sm:gap-3 sm:px-4"
                >
                  <span
                    className="w-6 shrink-0 pt-1 text-right text-xs tabular-nums text-fg-4"
                    aria-hidden
                  >
                    {lesson.order + 1}
                  </span>
                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-x-2 gap-y-1">
                      <Link
                        href={editHref}
                        transitionTypes={['nav-forward']}
                        className="min-w-0 max-w-full truncate text-sm font-medium text-fg underline-offset-4 hover:text-primary-text hover:underline"
                      >
                        {title}
                      </Link>
                      <span
                        className={cn(
                          'rounded-full px-2 py-0.5 text-[11px] font-medium ring-1',
                          state.chip,
                        )}
                      >
                        {state.label}
                        {lesson.state === 'error' && lesson.errors > 0
                          ? ` ${lesson.errors}`
                          : lesson.state === 'warning' && lesson.warnings > 0
                            ? ` ${lesson.warnings}`
                            : ''}
                      </span>
                    </div>
                    <p className="mt-0.5 text-xs text-fg-4">
                      {summary(lesson)}
                      {detail && <span className="text-fg-3"> — {detail}</span>}
                      <span className="hidden md:inline"> · sửa {timeAgo(lesson.updatedAt)}</span>
                    </p>
                  </div>

                  <div className="flex shrink-0 items-center gap-1">
                    <Link
                      href={`${editHref}?tab=preview`}
                      className={cn(button, 'hidden min-h-9 px-3 py-1.5 sm:inline-flex')}
                    >
                      Xem trước
                    </Link>
                    <Link href={editHref} className={cn(button, 'min-h-9 px-3 py-1.5')}>
                      Sửa
                    </Link>
                    <details className="relative">
                      <summary
                        className="grid size-9 cursor-pointer list-none place-items-center rounded-md text-fg-3 hover:bg-primary-soft hover:text-primary-text [&::-webkit-details-marker]:hidden"
                        aria-label={`Thêm lựa chọn cho ${title}`}
                      >
                        <svg viewBox="0 0 20 20" aria-hidden className="size-4">
                          <circle cx="4" cy="10" r="1.4" fill="currentColor" />
                          <circle cx="10" cy="10" r="1.4" fill="currentColor" />
                          <circle cx="16" cy="10" r="1.4" fill="currentColor" />
                        </svg>
                      </summary>
                      <div className="absolute right-0 z-20 mt-1 w-48 rounded-lg border border-line-strong bg-card p-2 shadow-lift">
                        <Link
                          href={`${editHref}?tab=preview`}
                          className="flex min-h-9 items-center rounded-md px-2 text-sm text-fg-2 hover:bg-elevated sm:hidden"
                        >
                          Xem trước
                        </Link>
                        <p className="border-t border-line px-2 pt-2 pb-1 text-[11px] text-fg-4">
                          Đổi thứ tự trong khóa
                        </p>
                        <UnitMoveButtons
                          courseId={courseId}
                          unitId={lesson.unitId}
                          title={lesson.title}
                          position={lesson.order}
                          total={lessons.length}
                        />
                        <div className="mt-1 border-t border-line pt-1">
                          <DeleteUnitButton
                            courseId={courseId}
                            unitId={lesson.unitId}
                            title={lesson.title}
                          />
                        </div>
                      </div>
                    </details>
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </div>
    </div>
  );
}
