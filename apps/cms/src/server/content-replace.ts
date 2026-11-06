import { applyReplace, planReplace, replaceChoices, type ReplaceChoiceGroup, type ReplacePlan, type ReplaceRequest } from '@/cms/replace';
import { lintUnit, type ContentIssue } from '@/cms/lint';
import type { UnitDraft } from '@/cms/types';
import { getStore } from './store';

export interface ReplacePreview {
  courseId: string;
  request: ReplaceRequest;
  plan: ReplacePlan;
  /** The columns the form offers, with the ones this module refuses to rewrite marked and explained. */
  choices: ReplaceChoiceGroup[];
  unitCount: number;
}

/** What a find/replace would do, computed from the drafts and written nowhere — the preview the admin confirms. */
export async function previewReplace(
  courseId: string,
  request: ReplaceRequest,
): Promise<ReplacePreview | null> {
  const units = await getStore().listUnits(courseId);
  if (units.length === 0) return null;
  return {
    courseId,
    request,
    plan: planReplace(units, request),
    choices: replaceChoices(),
    unitCount: units.length,
  };
}

export interface ReplaceDraft {
  unitId: string;
  order: number;
  revision: number;
  draft: UnitDraft;
  rows: number;
}

export interface ReplaceCheck {
  plan: ReplacePlan;
  /** New drafts, in unit order, each with the revision it was written against. */
  drafts: ReplaceDraft[];
  /** Units whose live text no longer matches the preview — the batch must not run. */
  drift: { unitId: string; field: string; expected: string; found: string }[];
  lint: { unitId: string; issues: ContentIssue[] }[];
  ok: boolean;
}

/**
 * The whole point of a bulk edit is that it is checked before one byte is written: every affected unit is
 * rebuilt in memory, replayed against the draft that is live right now, and linted. Anything that fails —
 * a row someone else changed a second ago, a replacement that empties a required field, two headwords that
 * become the same word — aborts the entire batch, because a half-applied replace across sixteen units is
 * much harder to notice than one that did not happen.
 */
export async function checkReplace(courseId: string, request: ReplaceRequest): Promise<ReplaceCheck | null> {
  const units = await getStore().listUnits(courseId);
  if (units.length === 0) return null;
  const plan = planReplace(units, request);
  const drafts: ReplaceDraft[] = [];
  const drift: ReplaceCheck['drift'] = [];
  const lint: ReplaceCheck['lint'] = [];

  for (const unitId of plan.unitIds) {
    const unit = units.find((u) => u.unitId === unitId);
    if (!unit) continue;
    const edits = plan.edits.filter((e) => e.unitId === unitId);
    const result = applyReplace(unit.draft, edits);
    for (const d of result.drift)
      drift.push({ unitId, field: `${d.list} · ${d.field}`, expected: d.expected, found: d.found });
    const issues = lintUnit(result.draft).filter((i) => i.level === 'error');
    if (issues.length) lint.push({ unitId, issues });
    else if (!result.drift.length)
      drafts.push({ unitId, order: unit.order, revision: unit.revision, draft: result.draft, rows: edits.length });
  }
  return { plan, drafts, drift, lint, ok: plan.edits.length > 0 && !drift.length && !lint.length };
}
