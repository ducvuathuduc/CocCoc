'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { toast } from 'sonner';
import { applyCourseReplace } from '@/server/actions/replace';
import type { ReplacePreview } from '@/server/content-replace';
import type { ReplaceEdit } from '@/cms/replace';
import type { SearchList } from '@/cms/search';
import { card, compact, field, link, primary, td, th } from '@/lib/ui';
import { cn } from '@/lib/utils';

/** Rows the preview lists before pointing at the total instead of scrolling forever. */
const EDIT_LIMIT = 60;

const key = (list: SearchList, field: string): string => `${list}.${field}`;

export function ReplacePanel({ preview }: { preview: ReplacePreview }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [find, setFind] = useState(preview.request.find);
  const [to, setTo] = useState(preview.request.to);
  const [picked, setPicked] = useState<Set<string>>(
    () => new Set(preview.request.targets.map((t) => key(t.list, t.field))),
  );
  const { courseId, plan, choices, unitCount } = preview;

  function go(nextFind = find, nextTo = to, nextPicked = picked) {
    const params = new URLSearchParams();
    params.set('find', nextFind);
    params.set('to', nextTo);
    params.set('cols', [...nextPicked].join(','));
    router.push(`/courses/${courseId}/search?${params.toString()}`);
  }

  async function apply() {
    if (
      !window.confirm(
        `Thay “${find}” bằng “${to}” trên ${plan.rows} dòng ở ${plan.unitIds.length} bài học của khóa này?\n\n` +
          'Bản app đang chạy chưa đổi gì cả. Sau khi thay, lưu bản nội dung rồi chạy kiểm tra tự động.',
      )
    )
      return;
    setBusy(true);
    try {
      const targets = [...picked].map((id) => {
        const dot = id.indexOf('.');
        return { list: id.slice(0, dot) as SearchList, field: id.slice(dot + 1) };
      });
      const result = await applyCourseReplace(courseId, { find, to, targets });
      if (result.ok) toast.success(result.message ?? 'Đã thay thế.');
      else toast.error(result.message ?? 'Không thay thế được.');
      if (result.warning) toast.warning(result.warning);
      router.refresh();
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'Không gọi được bộ thay thế.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className={cn(card, 'p-4')}>
      <div className="flex flex-wrap items-baseline gap-2">
        <h2 className="text-sm font-medium">Thay thế trong toàn khóa</h2>
        <span className="text-xs text-fg-4">
          {plan.scanned} dòng chữ ở {unitCount} bài · {plan.rows} dòng sẽ đổi · {plan.matches} lần
          khớp
        </span>
      </div>

      <div className="mt-3 grid gap-3 md:grid-cols-[1fr_1fr_auto]">
        <label className="text-xs text-fg-3">
          Tìm
          <input
            value={find}
            onChange={(e) => setFind(e.target.value)}
            className={cn(field, 'mt-1')}
            placeholder="Hello, xin chào…"
          />
        </label>
        <label className="text-xs text-fg-3">
          Thay bằng (để trống là xóa)
          <input value={to} onChange={(e) => setTo(e.target.value)} className={cn(field, 'mt-1')} />
        </label>
        <button
          type="button"
          className={cn(compact, 'self-end px-3 py-2 text-sm')}
          disabled={!find.trim()}
          onClick={() => go()}
        >
          Xem lại
        </button>
      </div>

      <div className="mt-3 space-y-2">
        {choices.map((group) => (
          <div key={group.list} className="flex flex-wrap items-center gap-2 text-xs">
            <span className="w-20 shrink-0 font-medium text-fg-3">{group.listLabel}</span>
            {group.fields.map((column) => {
              const id = key(group.list, column.field);
              return (
                <label
                  key={id}
                  title={column.why}
                  className={cn(
                    'cursor-pointer rounded-full px-2 py-1 ring-1 transition-colors',
                    !column.editable
                      ? 'cursor-not-allowed bg-elevated text-fg-4 line-through'
                      : picked.has(id)
                        ? 'bg-primary-soft text-primary-text ring-primary/40'
                        : 'ring-line text-fg-3 hover:text-fg',
                  )}
                >
                  <input
                    type="checkbox"
                    className="sr-only"
                    disabled={!column.editable}
                    checked={column.editable && picked.has(id)}
                    onChange={(event) => {
                      const next = new Set(picked);
                      if (event.target.checked) next.add(id);
                      else next.delete(id);
                      setPicked(next);
                      go(find, to, next);
                    }}
                  />
                  {column.field}
                </label>
              );
            })}
          </div>
        ))}
      </div>

      {plan.skipped.length > 0 && (
        <ul className="mt-3 space-y-1 text-xs text-fg-3">
          {plan.skipped.map((skip) => (
            <li key={key(skip.list, skip.field)}>
              <span className="font-medium">{skip.field}</span>: {skip.cells} dòng khớp nhưng không
              nằm trong phạm vi sửa — {skip.reason}
            </li>
          ))}
        </ul>
      )}

      {plan.edits.length === 0 ? (
        <p className="mt-3 text-sm text-fg-3">
          {find.trim()
            ? `Không dòng nào trong các cột đã chọn khớp “${find}”. ${plan.scanned} chuỗi đã soi — tìm không phân biệt hoa thường và dấu thanh, nên “chao hoi” vẫn thấy “Chào hỏi”.`
            : 'Gõ nội dung cần tìm để xem trước những dòng sẽ đổi.'}
        </p>
      ) : (
        <>
          <div className="mt-3 overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr>
                  <th className={th}>Unit</th>
                  <th className={th}>Ở đâu</th>
                  <th className={th}>Hiện là</th>
                  <th className={th}>Thành</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {plan.edits.slice(0, EDIT_LIMIT).map((edit) => (
                  <tr
                    key={`${edit.unitId}-${edit.list}-${edit.row}-${edit.alt}-${edit.field}`}
                    className="align-top"
                  >
                    <td className={cn(td, 'whitespace-nowrap')}>
                      <Link
                        href={`/courses/${courseId}/units/${edit.unitId}?tab=${edit.tab}${
                          edit.row === null ? '' : `&row=${edit.row}`
                        }`}
                        transitionTypes={['nav-forward']}
                        className={cn(link, 'text-sm font-medium')}
                      >
                        Bài {edit.order + 1}: {edit.unitTitle || edit.unitId}
                      </Link>
                    </td>
                    <td className={cn(td, 'whitespace-nowrap text-xs text-fg-3')}>
                      {edit.listLabel} · {where(edit)} · {edit.field}
                    </td>
                    <td className={cn(td, 'break-words text-fg-2')}>{edit.before}</td>
                    <td className={cn(td, 'break-words')}>
                      <span className="text-ok-fg">{edit.after || '(xóa)'}</span>
                      {edit.count > 1 && (
                        <span className="ml-1 text-xs text-fg-4">{edit.count} lần</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {plan.edits.length > EDIT_LIMIT && (
              <p className="mt-2 text-xs text-fg-4">
                … còn {plan.edits.length - EDIT_LIMIT} dòng nữa chưa liệt kê; nút dưới vẫn sửa đủ{' '}
                {plan.rows} dòng.
              </p>
            )}
          </div>

          <div className="mt-3 flex flex-wrap items-center gap-2">
            <button type="button" className={cn(primary, 'py-1.5')} disabled={busy} onClick={apply}>
              {busy ? 'Đang sửa…' : `Sửa ${plan.rows} dòng ở ${plan.unitIds.length} bài`}
            </button>
            <span className="text-xs text-fg-4">
              Mỗi bài đi qua đúng nút Lưu của màn soạn bài: bài thiếu vẫn bị chặn, không ghi đè lên
              người đang sửa cùng bài, và lịch sử ghi lại đã thay gì.
            </span>
          </div>
        </>
      )}
    </section>
  );
}

/** How to point a human at the cell, in the words the editor itself uses. */
function where(edit: ReplaceEdit): string {
  if (edit.row === null) return edit.alt === null ? 'thông tin chung' : `mức ${edit.alt + 1}`;
  const row = `dòng ${edit.row + 1}`;
  return edit.alt === null ? row : `${row} · mục ${edit.alt + 1}`;
}
