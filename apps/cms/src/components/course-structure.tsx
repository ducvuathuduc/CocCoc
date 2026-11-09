'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { toast } from 'sonner';
import { saveCourseStructure } from '@/server/actions/course';
import { dropSection, moveTheme, newSection, sectionOf, structureIssues } from '@/cms/structure';
import type { SectionDraft } from '@/cms/types';
import type { UnitIndexEntry } from '@/server/store/port';
import { button, card, compact, field, ghost, hint, primary } from '@/lib/ui';
import { cn } from '@/lib/utils';

/**
 * Sections are the course map the app walks, and membership is keyed by theme: build-course.mjs
 * crashes on a unit that no section lists, so this panel is what keeps an export from failing.
 * The author only ever names a part and drops lessons into it; the machine ids stay out of sight
 * unless they switch on "Tùy chọn nâng cao".
 */
export function CourseStructure({
  courseId,
  revision,
  sections,
  units,
}: {
  courseId: string;
  revision: number;
  sections: SectionDraft[];
  units: UnitIndexEntry[];
}) {
  const router = useRouter();
  const [rows, setRows] = useState<SectionDraft[]>(sections);
  const [busy, setBusy] = useState(false);

  const issues = structureIssues(
    rows,
    units.map((u) => u.theme),
  );
  const dirty = JSON.stringify(rows) !== JSON.stringify(sections);
  const patch = (index: number, value: Partial<SectionDraft>) =>
    setRows(rows.map((s, i) => (i === index ? { ...s, ...value } : s)));

  // A lesson belongs to the section that lists its theme; the leftover list is everything still
  // unplaced, which is the only thing the author must act on by hand.
  const unplaced = units.filter((u) => sectionOf(rows, u.theme) === '');

  async function submit() {
    setBusy(true);
    try {
      const result = await saveCourseStructure({
        courseId,
        sections: rows,
        expectedRevision: revision,
      });
      if (!result.ok) {
        toast.error(result.message ?? 'Không lưu được cấu trúc khóa.');
        return;
      }
      toast.success('Đã lưu các phần học.');
      if (result.warning) toast.warning(result.warning);
      router.refresh();
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'Không lưu được cấu trúc khóa.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <p className={cn(hint, 'max-w-prose')}>
          App dạy theo thứ tự: phần học → bài học. Mỗi bài nằm trong đúng một phần. Kéo bài vào đúng
          phần, rồi bấm Lưu — thay đổi không làm mất nội dung bài.
        </p>
      </div>

      <div className="rise space-y-3">
        {rows.map((section, index) => {
          const members = section.units
            .map((theme) => units.find((u) => u.theme === theme))
            .filter((u): u is UnitIndexEntry => Boolean(u));
          return (
            <section key={section.sectionId || index} className={cn(card, 'p-4')}>
              <div className="flex flex-wrap items-center gap-2">
                <input
                  aria-label="Tên phần học"
                  className={cn(field, 'min-w-0 flex-1')}
                  placeholder="Tên phần, ví dụ Làm quen"
                  value={section.title}
                  onChange={(e) => patch(index, { title: e.target.value })}
                />
                <span className="rounded-full bg-elevated px-2 py-0.5 text-xs tabular-nums text-fg-3">
                  {members.length} bài
                </span>
                <button
                  type="button"
                  className={ghost}
                  disabled={members.length > 0}
                  title={
                    members.length > 0
                      ? 'Chuyển hết bài sang phần khác trước khi xóa.'
                      : 'Xóa phần học trống'
                  }
                  onClick={() => setRows(dropSection(rows, section.sectionId))}
                >
                  Xóa phần
                </button>
              </div>

              {members.length === 0 ? (
                <p className={cn(hint, 'mt-3')}>
                  Phần này chưa có bài nào. Thêm bài ở màn soạn, rồi chọn phần bên dưới.
                </p>
              ) : (
                <ul className="mt-3 divide-y divide-line border-t border-line">
                  {members.map((unit) => (
                    <li
                      key={unit.unitId}
                      className="flex items-center justify-between gap-3 py-2"
                    >
                      <div className="min-w-0">
                        <p className="truncate text-sm">{unit.title || '(chưa đặt tên)'}</p>
                      </div>
                      <select
                        aria-label={`Bài “${unit.title || unit.theme}” thuộc phần học nào`}
                        className={cn(compact, 'w-44 shrink-0')}
                        value={section.sectionId}
                        onChange={(e) => setRows(moveTheme(rows, unit.theme, e.target.value))}
                      >
                        <option value="">— bỏ khỏi phần —</option>
                        {rows.map((s, i) => (
                          <option key={s.sectionId || i} value={s.sectionId}>
                            {s.title || '(chưa đặt tên)'}
                          </option>
                        ))}
                      </select>
                    </li>
                  ))}
                </ul>
              )}
            </section>
          );
        })}
        <button
          type="button"
          className={button}
          onClick={() => setRows([...rows, newSection(rows)])}
        >
          + Thêm phần học
        </button>
      </div>

      {unplaced.length > 0 && (
        <section className={cn(card, 'p-4')}>
          <h3 className="text-sm font-medium">
            Bài chưa xếp vào phần nào ({unplaced.length})
          </h3>
          <p className={cn(hint, 'mb-3 mt-1')}>
            Những bài này chưa thuộc phần học nào — app sẽ không phát được đến chúng cho đến khi bạn
            chọn một phần.
          </p>
          <ul className="divide-y divide-line border-t border-line">
            {unplaced.map((unit) => (
              <li key={unit.unitId} className="flex items-center justify-between gap-3 py-2">
                <div className="min-w-0">
                  <p className="truncate text-sm">{unit.title || '(chưa đặt tên)'}</p>
                </div>
                <select
                  aria-label={`Gán bài “${unit.title || unit.theme}” vào phần học`}
                  className={cn(compact, 'w-44 shrink-0')}
                  value=""
                  onChange={(e) => setRows(moveTheme(rows, unit.theme, e.target.value))}
                >
                  <option value="">— chọn phần —</option>
                  {rows.map((s, i) => (
                    <option key={s.sectionId || i} value={s.sectionId}>
                      {s.title || '(chưa đặt tên)'}
                    </option>
                  ))}
                </select>
              </li>
            ))}
          </ul>
        </section>
      )}

      {issues.length > 0 && (
        <ul className="animate-fade-in space-y-1 rounded-lg border border-warn-bd bg-warn-bg p-3 text-xs text-warn-fg">
          {issues.map((issue) => (
            <li key={issue} className="flex gap-2">
              <span aria-hidden>•</span>
              <span>{issue}</span>
            </li>
          ))}
        </ul>
      )}

      <div className="flex items-center gap-2">
        {dirty && (
          <span className="flex items-center gap-1.5 text-xs text-warn-fg">
            <span className="size-1.5 animate-pulse rounded-full bg-warn-fg" /> chưa lưu
          </span>
        )}
        <button
          type="button"
          className={primary}
          onClick={submit}
          disabled={busy || !dirty || issues.length > 0}
        >
          {busy ? 'Đang lưu…' : 'Lưu các phần học'}
        </button>
        <button type="button" className={ghost} onClick={() => setRows(sections)} disabled={!dirty}>
          Hủy thay đổi
        </button>
      </div>

    </div>
  );
}
