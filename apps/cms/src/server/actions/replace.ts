'use server';

import { replaceRequestSchema } from '@/cms/schema';
import type { ReplaceRequest } from '@/cms/replace';
import { checkReplace } from '../content-replace';
import { recordAudit } from '../audit';
import { getStore } from '../store';
import { ConflictError, StoreUnavailableError } from '../store/port';
import { assertAdmin } from '../session';

export interface ReplaceResult {
  ok: boolean;
  message?: string;
  warning?: string;
  /** Cells rewritten, units touched, occurrences replaced — the numbers the admin previewed. */
  rows?: number;
  units?: number;
  matches?: number;
  /** Why nothing was written: a row changed under the preview, or the result would not save. */
  drift?: { unitId: string; field: string; expected: string; found: string }[];
  lint?: { unitId: string; message: string }[];
}

/**
 * Applies a course-wide find/replace. Nothing is written unless the whole batch is clean, and each unit is
 * saved through the same path the editor uses — `assertAdmin`, the live revision as an optimistic lock, and
 * the lint gate — so a bulk edit cannot bypass a single edit's checks.
 */
export async function applyCourseReplace(
  courseId: string,
  request: ReplaceRequest,
): Promise<ReplaceResult> {
  const actor = await assertAdmin();
  const parsed = replaceRequestSchema.safeParse(request);
  if (!parsed.success)
    return { ok: false, message: 'Cần nội dung cần tìm và danh sách cột được chọn.' };
  const store = getStore();
  const check = await checkReplace(courseId, parsed.data);
  if (!check) return { ok: false, message: 'Khóa này chưa có unit nào.' };

  if (!check.plan.edits.length)
    return {
      ok: false,
      message: check.plan.skipped.length
        ? `Không có dòng nào trong cột được phép sửa khớp "${parsed.data.find}" — ${check.plan.skipped
            .map((s) => `${s.field}: ${s.reason}`)
            .join(' ')}`
        : `Không dòng nào khớp "${parsed.data.find}" trong ${check.plan.scanned} chuỗi đã soi.`,
    };
  if (check.drift.length)
    return {
      ok: false,
      message: `Chưa sửa gì: ${check.drift.length} dòng đã đổi ở cửa sổ khác sau khi xem trước. Tải lại để xem bản hiện tại.`,
      drift: check.drift,
    };
  if (check.lint.length)
    return {
      ok: false,
      message: `Chưa sửa gì: kết quả sẽ không lưu được ở ${check.lint.length} unit.`,
      lint: check.lint.flatMap((l) => l.issues.map((i) => ({ unitId: l.unitId, message: i.message }))),
    };

  const written: { unitId: string; before: number; after: number; rows: number }[] = [];
  try {
    for (const draft of check.drafts) {
      const record = await store.saveUnit({
        courseId,
        unitId: draft.unitId,
        order: draft.order,
        draft: draft.draft,
        actorId: actor.userId,
        expectedRevision: draft.revision,
      });
      written.push({
        unitId: draft.unitId,
        before: draft.revision,
        after: record.revision,
        rows: draft.rows,
      });
    }
  } catch (error) {
    if (error instanceof ConflictError || error instanceof StoreUnavailableError)
      return {
        ok: false,
        message: `Đã sửa ${written.length}/${check.drafts.length} unit rồi dừng (${error.message}). Tải lại trang để xem phần đã áp dụng.`,
      };
    throw error;
  }

  const warnings: string[] = [];
  for (const entry of written) {
    const warning = await recordAudit({
      actorId: actor.userId,
      operation: 'unit.replace',
      targetId: `${courseId}/${entry.unitId}`,
      beforeJson: JSON.stringify({ revision: entry.before, find: parsed.data.find }),
      afterJson: JSON.stringify({ revision: entry.after, rows: entry.rows, to: parsed.data.to }),
    });
    if (warning) warnings.push(warning);
  }
  return {
    ok: true,
    message: `Đã sửa ${check.plan.rows} dòng ở ${check.plan.unitIds.length} unit (${check.plan.matches} lần khớp).`,
    rows: check.plan.rows,
    units: check.plan.unitIds.length,
    matches: check.plan.matches,
    warning: warnings[0],
  };
}
