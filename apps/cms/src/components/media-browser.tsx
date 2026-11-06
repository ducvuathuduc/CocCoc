'use client';

import { useMemo, useState } from 'react';
import { fold } from '@/cms/search';
import { button, card, compact, hint } from '@/lib/ui';
import { cn } from '@/lib/utils';

/** One thing the app will play or show for this lesson, already resolved to a plain row. */
export interface MediaRow {
  /** Stable identity for the row: the clip's base id or the image's file id. */
  key: string;
  kind: 'audio' | 'image';
  /** What the author calls it: "Câu 7", "Lượt 3", "Ảnh của hello". */
  label: string;
  /** The words inside it, so a search finds the clip without reading a filename. */
  text: string;
  state: 'ready' | 'missing' | 'stale' | 'unreadable' | 'unused' | 'unasked';
  /** Why the state is what it is, in the author's words. */
  note: string;
  /** Whether a slower take belongs to this row at all. */
  slow: boolean | null;
}

/**
 * Each label names the work the file actually needs. A clip that exists but that the build has not
 * registered is not a clip that has to be recorded again, and printing both as "cần thu lại" sent
 * authors to the studio for audio that was already fine.
 */
const STATE_LABEL: Record<MediaRow['state'], string> = {
  ready: 'sẵn sàng',
  missing: 'chưa có file',
  stale: 'cần thu lại',
  unreadable: 'app chưa đọc được',
  unused: 'chưa bài nào dùng',
  unasked: 'chưa câu hỏi nào đố tới',
};

const STATE_CLASS: Record<MediaRow['state'], string> = {
  ready: 'bg-ok-bg text-ok-fg',
  missing: 'bg-danger-bg text-danger-fg',
  stale: 'bg-warn-bg text-warn-fg',
  unreadable: 'bg-warn-bg text-warn-fg',
  unused: 'bg-warn-bg text-warn-fg',
  unasked: 'bg-warn-bg text-warn-fg',
};

const FILTERS = [
  ['all', 'Tất cả'],
  ['missing', 'Chưa có file'],
  ['stale', 'Cần thu lại'],
  ['unreadable', 'App chưa đọc được'],
  ['unused', 'Chưa được dùng'],
  ['ready', 'Sẵn sàng'],
] as const;

type FilterKey = (typeof FILTERS)[number][0];
type KindKey = 'all' | 'audio' | 'image';

const mediaUrl = (courseId: string, fileId: string) =>
  `/api/media?course=${encodeURIComponent(courseId)}&file=${encodeURIComponent(fileId)}`;

/**
 * 86 clips do not fit a page. One line each, filtered down to the handful you are asking about,
 * and the player only appears for the clip you actually chose to hear.
 */
export function MediaBrowser({
  courseId,
  rows,
}: {
  courseId: string;
  rows: MediaRow[];
}) {
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<FilterKey>('all');
  const [kind, setKind] = useState<KindKey>('all');
  const [playing, setPlaying] = useState<string | null>(null);

  const shown = useMemo(() => {
    const needle = fold(query).keys.trim();
    return rows.filter((row) => {
      if (kind !== 'all' && row.kind !== kind) return false;
      if (filter === 'missing' && row.state !== 'missing') return false;
      if (filter === 'stale' && row.state !== 'stale') return false;
      if (filter === 'unreadable' && row.state !== 'unreadable') return false;
      if (filter === 'ready' && row.state !== 'ready') return false;
      if (filter === 'unused' && row.state !== 'unused' && row.state !== 'unasked') return false;
      if (needle === '') return true;
      return (
        fold(row.label).keys.includes(needle) ||
        fold(row.text).keys.includes(needle) ||
        fold(STATE_LABEL[row.state]).keys.includes(needle)
      );
    });
  }, [rows, query, filter, kind]);

  const counts = useMemo(() => {
    const of = (test: (row: MediaRow) => boolean) => rows.filter(test).length;
    return {
      missing: of((r) => r.state === 'missing'),
      stale: of((r) => r.state === 'stale'),
      unreadable: of((r) => r.state === 'unreadable'),
      unused: of((r) => r.state === 'unused' || r.state === 'unasked'),
      ready: of((r) => r.state === 'ready'),
    };
  }, [rows]);

  return (
    <section className={cn(card, 'overflow-hidden')} aria-label="Ảnh và âm thanh của bài học">
      <div className="flex flex-wrap items-center gap-2 border-b border-line px-3 py-2">
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Tìm theo lời thoại hoặc tên…"
          aria-label="Tìm trong ảnh và âm thanh"
          className={cn(compact, 'w-44 sm:w-64')}
        />
        <select
          value={kind}
          onChange={(e) => setKind(e.target.value as KindKey)}
          aria-label="Lọc theo loại tài nguyên"
          className={cn(compact, 'w-auto')}
        >
          <option value="all">Mọi loại</option>
          <option value="audio">Chỉ âm thanh</option>
          <option value="image">Chỉ ảnh</option>
        </select>
        <div className="flex flex-wrap items-center gap-1">
          {FILTERS.map(([key, label]) => (
            <button
              key={key}
              type="button"
              onClick={() => setFilter(key)}
              aria-pressed={filter === key}
              className={cn(
                'rounded-full px-2.5 py-1 text-xs transition-colors',
                filter === key
                  ? 'bg-primary text-white'
                  : 'bg-elevated text-fg-3 hover:text-fg',
              )}
            >
              {label}
              {key !== 'all' && counts[key] > 0 && ` ${counts[key]}`}
            </button>
          ))}
        </div>
        <span className={cn(hint, 'ml-auto tabular-nums')}>
          {shown.length}/{rows.length}
        </span>
      </div>

      {counts.missing + counts.stale + counts.unreadable + counts.unused === 0 ? (
        <p className="border-b border-line bg-ok-bg px-3 py-1.5 text-xs text-ok-fg">
          Mọi file bài này cần đều đã có và app đã đọc được.
        </p>
      ) : (
        <ul className="flex flex-wrap gap-x-4 gap-y-1 border-b border-line px-3 py-1.5 text-xs">
          {counts.missing > 0 && (
            <li className="text-danger-fg">
              {counts.missing} file chưa có trên máy — cần nạp thêm.
            </li>
          )}
          {counts.stale > 0 && (
            <li className="text-warn-fg">
              {counts.stale} clip đang nói lời cũ — cần thu âm lại.
            </li>
          )}
          {counts.unreadable > 0 && (
            <li className="text-warn-fg">
              {counts.unreadable} clip đã có file nhưng app chưa phát được — không cần thu âm lại,
              bản dựng kế tiếp sẽ ghi chúng vào danh mục.
            </li>
          )}
          {counts.unused > 0 && (
            <li className="text-warn-fg">
              {counts.unused} ảnh đã có file nhưng chưa dùng trong câu hỏi — không cần nạp gì thêm.
            </li>
          )}
        </ul>
      )}

      <ul className="divide-y divide-line/60">

        {shown.map((row) => (
          <li key={row.key} className="flex items-start gap-3 px-3 py-1.5">
            {row.kind === 'image' && (
              <span className="mt-0.5 shrink-0">
                {row.state === 'missing' ? (
                  <span className="flex h-9 w-9 items-center justify-center rounded-md border border-dashed border-warn-bd bg-warn-bg text-[10px] text-warn-fg">
                    trống
                  </span>
                ) : (
                  // eslint-disable-next-line @next/next/no-img-element -- repo file served through the admin route, not a remote host
                  <img
                    src={mediaUrl(courseId, row.key)}
                    alt={row.label}
                    width={36}
                    height={36}
                    loading="lazy"
                    className="h-9 w-9 rounded-md border border-line bg-elevated object-contain"
                  />
                )}
              </span>
            )}
            <div className="min-w-0 flex-1">
              <p className="text-sm font-medium text-fg">{row.label}</p>
              <p className="truncate text-xs text-fg-3">
                {row.text || <span className="text-fg-4 italic">Chưa có lời</span>}
            </p>
            {playing === row.key && row.state !== 'missing' && (
              <div className="mt-1 space-y-1">
                <audio controls autoPlay src={mediaUrl(courseId, `${row.key}.n`)} className="h-8 w-full max-w-sm" />
                {row.slow === true && (
                  <audio controls src={mediaUrl(courseId, `${row.key}.s`)} className="block h-8 w-full max-w-sm" />
                )}
              </div>
            )}
              {playing !== row.key && row.slow === false && row.state !== 'missing' && (
                <p className="text-[11px] text-warn-fg">bản chậm chưa có file</p>
              )}
            </div>
            <span
              className={cn(
                'shrink-0 rounded-full px-2 py-0.5 text-[11px] font-medium',
                STATE_CLASS[row.state],
              )}
              title={row.note}
            >
              {STATE_LABEL[row.state]}
            </span>
            {row.kind === 'audio' && row.state !== 'missing' && (
              <button
                type="button"
                className={cn(button, 'shrink-0')}
                aria-expanded={playing === row.key}
                onClick={() => setPlaying(playing === row.key ? null : row.key)}
              >
                {playing === row.key ? 'Ẩn' : 'Nghe'}
              </button>
            )}
          </li>
        ))}
        {shown.length === 0 && (
          <li className="px-3 py-6 text-center text-sm text-fg-3">
            {rows.length === 0
              ? 'Bài này chưa cần file âm thanh hay ảnh nào.'
              : 'Không có tài nguyên nào khớp với bộ lọc đang chọn.'}
          </li>
        )}
      </ul>
    </section>
  );
}
