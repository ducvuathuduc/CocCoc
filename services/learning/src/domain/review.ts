// Review heuristic (SRS "Review heuristic", FR-PRACTICE-002). Transparent spaced repetition:
// intervals 1/3/7/14/30 calendar days; a correct unassisted review schedules the current interval
// and advances the stage (cap 4); wrong or assisted resets to stage 0, due tomorrow. Within-session
// retries never advance the long-term stage: only first attempts count.

export const INTERVAL_DAYS = [1, 3, 7, 14, 30] as const;
export const MAX_STAGE = 4;
export const EVIDENCE_WINDOW = 20;
export const MASTERY_MIN_ATTEMPTS = 5;
const DAY_MS = 24 * 60 * 60 * 1000;

export interface ReviewState {
  stage: number;
  dueAt: string;
  window: boolean[];
  correctCount: number;
  incorrectCount: number;
  halfLifeHours: number;
  lastReviewedAt: string;
  firstSeenAt: string;
}

export interface Evidence {
  /** First attempt(s) for this vocabulary in the session were all correct. */
  correct: boolean;
  assisted: boolean;
}

/**
 * Apply one session's evidence for a vocabulary item. `advance` is true for REVIEW/MASTERY
 * sessions; a LESSON exposure seeds new items and resets on mistakes but does not push an
 * existing item further out (the learner has not been asked to recall it from memory yet).
 */
export function applyEvidence(
  previous: ReviewState | null,
  evidence: Evidence,
  nowMs: number,
  advance: boolean,
): ReviewState {
  const now = new Date(nowMs).toISOString();
  const good = evidence.correct && !evidence.assisted;
  const window = [...(previous?.window ?? []), evidence.correct].slice(-EVIDENCE_WINDOW);
  const base = {
    window,
    correctCount: (previous?.correctCount ?? 0) + (evidence.correct ? 1 : 0),
    incorrectCount: (previous?.incorrectCount ?? 0) + (evidence.correct ? 0 : 1),
    lastReviewedAt: now,
    firstSeenAt: previous?.firstSeenAt ?? now,
  };
  if (!good) {
    return { ...base, stage: 0, dueAt: new Date(nowMs + DAY_MS).toISOString(), halfLifeHours: 24 };
  }
  if (previous && !advance) {
    return {
      ...base,
      stage: previous.stage,
      dueAt: previous.dueAt,
      halfLifeHours: previous.halfLifeHours,
    };
  }
  const stage = previous?.stage ?? 0;
  const days = INTERVAL_DAYS[stage] ?? 30;
  return {
    ...base,
    stage: Math.min(stage + 1, MAX_STAGE),
    dueAt: new Date(nowMs + days * DAY_MS).toISOString(),
    halfLifeHours: days * 24,
  };
}

/** Rolling fraction over the last 20 first attempts; null until 5 attempts exist. */
export function masteryOf(window: readonly boolean[]): number | null {
  if (window.length < MASTERY_MIN_ATTEMPTS) return null;
  return Math.round((window.filter(Boolean).length / window.length) * 1000) / 1000;
}

export interface DueCandidate {
  vocabularyId: string;
  skillId: string;
  dueAt: string;
  lastMistakeAt: string | null;
}

/**
 * Due selection: dueAt ascending, then most recent mistake, then stable vocabularyId; then
 * interleave so at most two consecutive items share a skill, keeping the order otherwise stable.
 */
export function orderDue<T extends DueCandidate>(items: readonly T[], max: number): T[] {
  const sorted = [...items].sort(
    (a, b) =>
      a.dueAt.localeCompare(b.dueAt) ||
      (b.lastMistakeAt ?? '').localeCompare(a.lastMistakeAt ?? '') ||
      (a.vocabularyId < b.vocabularyId ? -1 : a.vocabularyId > b.vocabularyId ? 1 : 0),
  );
  const result: T[] = [];
  const pool = [...sorted];
  while (pool.length && result.length < max) {
    const last = result.at(-1);
    const prev = result.at(-2);
    const blocked = last && prev && last.skillId === prev.skillId ? last.skillId : null;
    const index = blocked ? pool.findIndex((item) => item.skillId !== blocked) : 0;
    const [picked] = pool.splice(index < 0 ? 0 : index, 1);
    if (picked) result.push(picked);
  }
  return result;
}
