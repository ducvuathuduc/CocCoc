// Lesson reward rules (docs/product/SRS.md FR-GAME-001 and "Deterministic learning and reward
// rules"). Pure functions: no I/O, no clock.
// - First online completion: XP = 10 + originalFirstCorrectCount (0-10) + 5 if all originals
//   correct without hint. Offline first completion omits the perfect bonus and league XP.
//   Published lessons carry 5-20 originals (vi_en v2 authors 10-15), so the 0-10 term is the
//   first-correct share scaled to 10: round(10 * originalCorrect / originalCount); a 10-original
//   lesson is unchanged.
// - Repeated lesson, REVIEW and MASTERY sessions: 5 study XP, at most 30 replay XP per server
//   learning day, zero league XP for REVIEW/MASTERY.
// - At most 1,200 credited study XP per learning day; the excess stays practiced with award 0.
// - PLACEMENT earns no XP, activity or quest credit.

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

/** Normal lesson length in the SRS; the first-correct XP term is scaled to it. */
export const LESSON_ORIGINAL_COUNT = 10;
export const MIN_ORIGINAL_COUNT = 5;
export const MAX_ORIGINAL_COUNT = 20;
export const REPLAY_XP = 5;
export const REPLAY_DAILY_CAP = 30;
export const DAILY_STUDY_XP_CAP = 1200;
const SESSION_MODES = new Set(['LESSON', 'PLACEMENT', 'REVIEW', 'MASTERY']);

export function validateGraded(lesson: GradedLesson): LessonXpResult | null {
  if (!SESSION_MODES.has(lesson.mode)) return { ok: false, reason: 'MODE_NOT_IMPLEMENTED' };
  if (lesson.source !== 'ONLINE' && lesson.source !== 'OFFLINE') {
    return { ok: false, reason: 'INVALID_GRADED_RESULT' };
  }
  const countOk =
    Number.isInteger(lesson.originalCount) &&
    lesson.originalCount >= MIN_ORIGINAL_COUNT &&
    lesson.originalCount <= MAX_ORIGINAL_COUNT;
  if (
    !countOk ||
    !Number.isInteger(lesson.originalCorrect) ||
    lesson.originalCorrect < 0 ||
    lesson.originalCorrect > lesson.originalCount ||
    typeof lesson.assisted !== 'boolean'
  ) {
    return { ok: false, reason: 'INVALID_GRADED_RESULT' };
  }
  return null;
}

/** First-completion XP for LESSON (and the zero-XP PLACEMENT case). */
export function firstCompletionXp(lesson: GradedLesson): LessonXpResult {
  if (lesson.mode !== 'LESSON' && lesson.mode !== 'PLACEMENT') {
    return { ok: false, reason: 'MODE_NOT_IMPLEMENTED' };
  }
  const invalid = validateGraded(lesson);
  if (invalid) return invalid;
  if (lesson.mode === 'PLACEMENT') return { ok: true, studyXp: 0, perfect: false };
  const perfect =
    lesson.source === 'ONLINE' &&
    lesson.originalCorrect === lesson.originalCount &&
    !lesson.assisted;
  const firstCorrect = Math.round(
    (LESSON_ORIGINAL_COUNT * lesson.originalCorrect) / lesson.originalCount,
  );
  return { ok: true, studyXp: 10 + firstCorrect + (perfect ? 5 : 0), perfect };
}

export interface AwardContext {
  /** No p_first_rewards marker exists yet for (userId, rewardIdentity). */
  firstCompletion: boolean;
  /** Credited study XP already on this learning day. */
  dayStudyXp: number;
  /** Replay XP already credited on this learning day. */
  dayReplayXp: number;
  /** Active XP boost multiplier at the server-accepted completion time (1 = none). */
  boostMultiplier?: number;
}

export interface Award {
  /** Ledger kind; null for PLACEMENT (no ledger row, no activity). */
  kind: 'FIRST' | 'REPLAY' | null;
  /** XP before caps. */
  rawXp: number;
  studyXp: number;
  replayXp: number;
  leagueXp: number;
  capped: boolean;
  perfect: boolean;
}

export function computeAward(lesson: GradedLesson, context: AwardContext): Award | LessonXpResult {
  const invalid = validateGraded(lesson);
  if (invalid) return invalid;
  if (lesson.mode === 'PLACEMENT') {
    return {
      kind: null,
      rawXp: 0,
      studyXp: 0,
      replayXp: 0,
      leagueXp: 0,
      capped: false,
      perfect: false,
    };
  }
  const boost = Math.max(1, Math.min(3, Math.floor(context.boostMultiplier ?? 1)));
  let kind: 'FIRST' | 'REPLAY';
  let rawXp: number;
  let perfect = false;
  let replayXp = 0;
  let capped = false;
  if (lesson.mode === 'LESSON' && context.firstCompletion) {
    const first = firstCompletionXp(lesson);
    if (!first.ok) return first;
    kind = 'FIRST';
    rawXp = first.studyXp * boost;
    perfect = first.perfect;
  } else {
    kind = 'REPLAY';
    rawXp = REPLAY_XP * boost;
    const replayRoom = Math.max(0, REPLAY_DAILY_CAP - context.dayReplayXp);
    replayXp = Math.min(rawXp, replayRoom);
    capped = replayXp < rawXp;
  }
  const preCap = kind === 'REPLAY' ? replayXp : rawXp;
  const room = Math.max(0, DAILY_STUDY_XP_CAP - context.dayStudyXp);
  const studyXp = Math.min(preCap, room);
  if (studyXp < preCap) capped = true;
  if (kind === 'REPLAY') replayXp = studyXp;
  const leagueEligible = lesson.mode === 'LESSON' && lesson.source === 'ONLINE';
  return {
    kind,
    rawXp,
    studyXp,
    replayXp,
    leagueXp: leagueEligible ? studyXp : 0,
    capped,
    perfect,
  };
}

export function isAward(value: Award | LessonXpResult): value is Award {
  return 'kind' in value;
}
