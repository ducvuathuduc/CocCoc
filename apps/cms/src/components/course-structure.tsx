'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { toast } from 'sonner';
import { saveCourseStructure } from '@/server/actions/course';
import { dropSection, moveTheme, newSection, sectionOf, structureIssues } from '@/cms/structure';
import type { SectionDraft } from '@/cms/types';
import type { UnitStat } from '@/server/queries';
import { button, card, compact, field, ghost, primary } from '@/lib/ui';
import { cn } from '@/lib/utils';

/**
 * Sections are the course map the app walks, and membership is keyed by theme: build-course.mjs
 * crashes on a unit that no section lists, so this panel is what keeps an export from failing.
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
  units: UnitStat[];
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
      <div className="rise space-y-2">
        {rows.map((section, index) => (
          <div key={index} className="flex flex-wrap items-center gap-2">
            <input
              aria-label="Mã phần học"
              className={cn(compact, 'w-24 font-mono text-xs')}
              value={section.sectionId}
              onChange={(e) => patch(index, { sectionId: e.target.value })}
            />
            <input
              aria-label="Tên phần học"
              className={cn(field, 'w-80')}
              placeholder="Tên phần, ví dụ Làm quen"
              value={section.title}
              onChange={(e) => patch(index, { title: e.target.value })}
            />
            <span className="rounded-full bg-elevated px-2 py-0.5 text-xs tabular-nums text-fg-3">
              {section.units.length} bài
            </span>
            <button
              type="button"
              className={ghost}
              disabled={section.units.length > 0}
              title={
                section.units.length > 0
                  ? 'Chuyển hết bài sang phần khác trước khi xóa.'
                  : 'Xóa phần học trống'
              }
              onClick={() => setRows(dropSection(rows, section.sectionId))}
            >
              Xóa
            </button>
          </div>
        ))}
        <button
          type="button"
          className={button}
          onClick={() => setRows([...rows, newSection(rows)])}
        >
          + Thêm phần học
        </button>
      </div>

      <div className={cn(card, 'divide-y divide-line overflow-hidden')}>
        {units.length === 0 ? (
          <div className="px-4 py-6 text-sm text-fg-3">
            Khóa chưa có bài nào để xếp vào phần học.
          </div>
        ) : (
          units.map((unit) => (
            <div
              key={unit.unitId}
              className="flex items-center justify-between gap-4 px-4 py-2 transition-colors hover:bg-elevated"
            >
              <div className="min-w-0">
                <p className="truncate text-sm">{unit.title || '(chưa đặt tên)'}</p>
                <p className="font-mono text-xs text-fg-4">{unit.theme}</p>
              </div>
              <select
                aria-label={`Bài “${unit.title || unit.theme}” thuộc phần học nào`}
                className={cn(compact, 'w-52 shrink-0')}
                value={sectionOf(rows, unit.theme)}
                onChange={(e) => setRows(moveTheme(rows, unit.theme, e.target.value))}
              >
                {sectionOf(rows, unit.theme) === '' && <option value="">— chưa xếp —</option>}
                {rows.map((section, index) => (
                  <option key={index} value={section.sectionId}>
                    {section.title || '(chưa đặt tên)'}
                  </option>
                ))}
              </select>
            </div>
          ))
        )}
      </div>

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
