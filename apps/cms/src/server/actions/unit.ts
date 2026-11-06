'use server';

import { lintUnit, type ContentIssue } from '@/cms/lint';
import { orderChanges } from '@/cms/order';
import { unitDraftSchema } from '@/cms/schema';
import { unassignTheme } from '@/cms/structure';
import { slug } from '@/cms/tables';
import type { UnitDraft } from '@/cms/types';
import { getStore } from '../store';
import { ConflictError, StoreUnavailableError } from '../store/port';
import { assertAdmin } from '../session';
import { recordAudit } from '../audit';

export interface UnitSaveResult {
  ok: boolean;
  revision?: number;
  message?: string;
  warning?: string;
  issues?: ContentIssue[];
}

export interface UnitInput {
  courseId: string;
  unitId: string;
  order: number;
  expectedRevision: number;
  draft: UnitDraft;
}

export async function saveUnitDraft(input: UnitInput): Promise<UnitSaveResult> {
  const actor = await assertAdmin();
  const parsed = unitDraftSchema.safeParse(input.draft);
  if (!parsed.success) {
    return { ok: false, message: 'Bài này có ô chưa hợp lệ nên hệ thống chưa nhận. Xem danh sách cần sửa bên trên.' };
  }
  const draft = parsed.data as UnitDraft;
  // An empty id column means "derive it from the headword", the same rule the repo parser uses.
  draft.vocab = draft.vocab.map((v) => ({ ...v, id: v.id || slug(v.en) }));
  const issues = lintUnit(draft);
  if (issues.some((i) => i.level === 'error')) return { ok: false, issues };

  try {
    const store = getStore();
    const before = await store.getUnit(input.courseId, input.unitId);
    const record = await store.saveUnit({
      courseId: input.courseId,
      unitId: input.unitId,
      order: input.order,
      draft,
      actorId: actor.userId,
      expectedRevision: input.expectedRevision,
    });
    const auditWarning = await recordAudit({
      actorId: actor.userId,
      operation: before ? 'unit.update' : 'unit.create',
      targetId: `${input.courseId}/${input.unitId}`,
      beforeJson: before ? JSON.stringify({ revision: before.revision }) : '',
      afterJson: JSON.stringify({ revision: record.revision, vocab: draft.vocab.length }),
    });
    return {
      ok: true,
      revision: record.revision,
      warning: auditWarning ?? undefined,
      issues: issues.filter((i) => i.level === 'warning'),
    };
  } catch (error) {
    if (error instanceof ConflictError || error instanceof StoreUnavailableError)
      return { ok: false, message: error.message };
    throw error;
  }
}

export async function deleteUnitDraft(
  courseId: string,
  unitId: string,
): Promise<{ ok: boolean; message?: string; warning?: string }> {
  const actor = await assertAdmin();
  const store = getStore();
  const unit = await store.getUnit(courseId, unitId);
  if (!unit) return { ok: false, message: 'Unit không còn tồn tại (có thể đã bị xóa ở cửa sổ khác).' };
  try {
    await store.deleteUnit(courseId, unitId, actor.userId);
    // A section that still lists the deleted theme survives into course.mjs, and structureIssues
    // would then refuse the export, so membership is dropped in the same action.
    const course = await store.getCourse(courseId);
    if (course) {
      const sections = unassignTheme(course.draft.sections, unit.draft.theme);
      if (JSON.stringify(sections) !== JSON.stringify(course.draft.sections))
        await store.saveCourse({
          courseId,
          draft: { ...course.draft, sections },
          actorId: actor.userId,
          expectedRevision: course.revision,
        });
    }
    const auditWarning = await recordAudit({
      actorId: actor.userId,
      operation: 'unit.delete',
      targetId: `${courseId}/${unitId}`,
      beforeJson: JSON.stringify({ theme: unit.draft.theme, revision: unit.revision }),
    });
    return { ok: true, warning: auditWarning ?? undefined };
  } catch (error) {
    return { ok: false, message: error instanceof Error ? error.message : 'Không xóa được unit.' };
  }
}

export interface MoveResult {
  ok: boolean;
  moved?: number;
  message?: string;
  warning?: string;
}

/**
 * Repositions a unit inside the course. Positions are dense because `build-course.mjs` turns them into
 * the `uNN` codes the app stores learner progress against, so writing the whole tail is unavoidable —
 * every row whose number changed is saved in one call, each with its own revision check.
 */
export async function moveUnitDraft(
  courseId: string,
  unitId: string,
  toIndex: number,
): Promise<MoveResult> {
  const actor = await assertAdmin();
  const store = getStore();
  const units = await store.listUnits(courseId);
  const from = units.findIndex((u) => u.unitId === unitId);
  if (from < 0)
    return { ok: false, message: 'Unit không còn tồn tại (có thể đã bị xóa ở cửa sổ khác).' };
  if (toIndex < 0 || toIndex >= units.length)
    return { ok: false, message: 'Vị trí này vượt ra ngoài danh sách unit.' };
  if (toIndex === from) return { ok: true, moved: 0 };

  const changes = orderChanges(units, from, toIndex);
  const before = changes.map(({ unit }) => ({ unitId: unit.unitId, order: unit.order }));
  let done = 0;
  try {
    for (const { unit, order } of changes) {
      await store.saveUnit({
        courseId,
        unitId: unit.unitId,
        order,
        draft: unit.draft,
        actorId: actor.userId,
        expectedRevision: unit.revision,
      });
      done += 1;
    }
  } catch (error) {
    if (error instanceof ConflictError || error instanceof StoreUnavailableError)
      return {
        ok: false,
        message: `Chỉ chuyển được ${done}/${changes.length} unit (${error.message}). Tải lại trang để xem thứ tự hiện tại rồi thử lại.`,
      };
    throw error;
  }

  const auditWarning = await recordAudit({
    actorId: actor.userId,
    operation: 'unit.reorder',
    targetId: `${courseId}/${unitId}`,
    beforeJson: JSON.stringify(before),
    afterJson: JSON.stringify(changes.map(({ unit, order }) => ({ unitId: unit.unitId, order }))),
  });
  return { ok: true, moved: changes.length, warning: auditWarning ?? undefined };
}
