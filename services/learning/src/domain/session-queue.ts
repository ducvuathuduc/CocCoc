// Lesson item queue (FR-LESSON-004): every original once (attemptOrdinal 0) in authored order,
// then up to two retry passes over the items still wrong (ordinals 1 and 2). Unresolved items go
// to review. Pure and deterministic: derived only from the authored order and the answer log.

export interface AttemptRecord {
  exerciseId: string;
  attemptOrdinal: number;
  correct: boolean;
  assisted: boolean;
}
export interface QueueItem {
  exerciseId: string;
  attemptOrdinal: number;
}
export interface QueueState {
  next: QueueItem | null;
  nextOriginalOrdinal: number;
  retryPass: number;
}

function latest(attempts: readonly AttemptRecord[], exerciseId: string, ordinal: number) {
  return attempts.find((a) => a.exerciseId === exerciseId && a.attemptOrdinal === ordinal);
}

export function queueState(
  order: readonly string[],
  attempts: readonly AttemptRecord[],
): QueueState {
  const originalsDone = order.filter((id) => latest(attempts, id, 0)).length;
  const firstMissing = order.find((id) => !latest(attempts, id, 0));
  if (firstMissing !== undefined) {
    return {
      next: { exerciseId: firstMissing, attemptOrdinal: 0 },
      nextOriginalOrdinal: originalsDone,
      retryPass: 0,
    };
  }
  for (const pass of [1, 2]) {
    const due = order.filter((id) => latest(attempts, id, pass - 1)?.correct === false);
    const pending = due.find((id) => !latest(attempts, id, pass));
    if (pending !== undefined) {
      return {
        next: { exerciseId: pending, attemptOrdinal: pass },
        nextOriginalOrdinal: order.length,
        retryPass: pass,
      };
    }
  }
  const passesUsed = order.some((id) => latest(attempts, id, 2))
    ? 2
    : order.some((id) => latest(attempts, id, 1))
      ? 1
      : 0;
  return { next: null, nextOriginalOrdinal: order.length, retryPass: passesUsed };
}

export interface SessionTally {
  originalCount: number;
  originalCorrect: number;
  assisted: boolean;
  /** Exercises never answered correctly in this session (to review). */
  needsReviewIds: string[];
}

export function tally(order: readonly string[], attempts: readonly AttemptRecord[]): SessionTally {
  let originalCorrect = 0;
  const needsReviewIds: string[] = [];
  for (const id of order) {
    const first = latest(attempts, id, 0);
    if (first?.correct) originalCorrect++;
    const everCorrect = attempts.some((a) => a.exerciseId === id && a.correct);
    if (!everCorrect) needsReviewIds.push(id);
  }
  return {
    originalCount: order.length,
    originalCorrect,
    assisted: attempts.some((a) => a.assisted),
    needsReviewIds: needsReviewIds.slice(0, 20),
  };
}

/** FR-PATH-002: mastery needs at least 80% first-attempt accuracy and no hint. */
export function masteryPassed(t: SessionTally): boolean {
  return t.originalCount > 0 && !t.assisted && t.originalCorrect * 5 >= t.originalCount * 4;
}

/** FR-COURSE-002: placement with at least 8 first-correct answers unlocks unit 2. */
export const PLACEMENT_PASS = 8;
