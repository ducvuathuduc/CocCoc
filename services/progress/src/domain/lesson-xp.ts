// First-completion lesson XP (docs/product/SRS.md FR-GAME-001 formula):
// XP = 10 + originalFirstCorrectCount (0-10) + 5 if all originals correct without hint (online).
// Placement earns no reward. Replay XP, daily caps and league eligibility are not modelled here
// yet; they belong to the Progress ledger task in docs/agent/IMPLEMENTATION_PLAN.md.

export interface GradedLesson {
  mode: string;
  source: string;
  originalCount: number;
  originalCorrect: number;
  assisted: boolean;
}

export type LessonXpResult =
  | { ok: true; studyXp: number; perfect: boolean }
  | { ok: false; reason: 'MODE_NOT_IMPLEMENTED' | 'INVALID_GRADED_RESULT' };

export const LESSON_ORIGINAL_COUNT = 10;

export function firstCompletionXp(lesson: GradedLesson): LessonXpResult {
  if (lesson.mode !== 'LESSON' && lesson.mode !== 'PLACEMENT') {
    return { ok: false, reason: 'MODE_NOT_IMPLEMENTED' };
  }
  if (
    lesson.originalCount !== LESSON_ORIGINAL_COUNT ||
    !Number.isInteger(lesson.originalCorrect) ||
    lesson.originalCorrect < 0 ||
    lesson.originalCorrect > lesson.originalCount
  ) {
    return { ok: false, reason: 'INVALID_GRADED_RESULT' };
  }
  if (lesson.mode === 'PLACEMENT') return { ok: true, studyXp: 0, perfect: false };
  const perfect =
    lesson.source === 'ONLINE' &&
    lesson.originalCorrect === LESSON_ORIGINAL_COUNT &&
    !lesson.assisted;
  return { ok: true, studyXp: 10 + lesson.originalCorrect + (perfect ? 5 : 0), perfect };
}
