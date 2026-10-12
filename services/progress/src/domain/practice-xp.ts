// AI practice reward rules (docs/product/SRS.md "Deterministic learning and reward rules",
// ai.practice.completed.v1 in docs/api/EVENTS_ERRORS.md). Pure functions: no I/O, no clock.
// - A completed Roleplay / Video Call conversation credits the producer's server-computed xp
//   (0-100 by schema; AI awards 5 + 5 per star) once per conversationId, times the active boost.
// - At most 100 PRACTICE XP per learning day, inside the shared 1,200 study XP/day cap; the excess
//   stays practiced (active day, streak, quests) with award 0 and capped=true.
// - League XP equals the credited study XP (online, server-scored practice).
import { DAILY_STUDY_XP_CAP } from './lesson-xp.js';

export const PRACTICE_DAILY_CAP = 100;
export const PRACTICE_MAX_EVENT_XP = 100;
export const PRACTICE_KINDS = ['ROLEPLAY', 'VIDEO_CALL'] as const;

export interface PracticeContext {
  /** Credited study XP already on this learning day (all sources). */
  dayStudyXp: number;
  /** PRACTICE XP already credited on this learning day. */
  dayPracticeXp: number;
  /** Active XP boost multiplier at the event time (1 = none). */
  boostMultiplier?: number;
}

export interface PracticeAward {
  rawXp: number;
  studyXp: number;
  leagueXp: number;
  capped: boolean;
}

export function computePracticeAward(xp: number, context: PracticeContext): PracticeAward {
  if (!Number.isInteger(xp) || xp < 0 || xp > PRACTICE_MAX_EVENT_XP) {
    throw new RangeError('PRACTICE_XP_OUT_OF_RANGE');
  }
  const boost = Math.max(1, Math.min(3, Math.floor(context.boostMultiplier ?? 1)));
  const rawXp = xp * boost;
  const practiceRoom = Math.max(0, PRACTICE_DAILY_CAP - context.dayPracticeXp);
  const dayRoom = Math.max(0, DAILY_STUDY_XP_CAP - context.dayStudyXp);
  const studyXp = Math.min(rawXp, practiceRoom, dayRoom);
  return { rawXp, studyXp, leagueXp: studyXp, capped: studyXp < rawXp };
}
