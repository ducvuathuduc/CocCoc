// Streak rules (SRS "Streak derives from day_activity rows with active=true or protected=true";
// IMPLEMENTATION_PLAN P6-GAME-002). Pure functions over day keys.
// The streak count is uncapped: it is recomputed from the activity window (last 365 days) and
// anchored by p_rewards.streakStartDay when the run reaches past the window.
import { addDays, daysBetween } from './time.js';

export const STREAK_WINDOW_DAYS = 365;
export const PURCHASABLE_FREEZES = 2;
export const STREAK_SOCIETY_DAYS = 365;
export const STREAK_SOCIETY_FREEZES = 3;
export const MAX_FREEZE_SLOTS = 5;
export const FREEZE_PRICE_GEMS = 20;
export const MISSED_DAY_CATCH_UP = 7;

export interface StreakState {
  currentStreak: number;
  streakStartDay: string | null;
  lastQualifiedDay: string | null;
}

/**
 * Recompute the run ending at the latest qualified day.
 * @param qualified day keys (active or protected) inside the window ending at `latest`
 * @param latest the most recent qualified day
 * @param windowStart first day covered by `qualified`
 * @param anchor stored streakStartDay (used when the run reaches the window start)
 */
export function recomputeStreak(
  qualified: ReadonlySet<string>,
  latest: string,
  windowStart: string,
  anchor: string | null,
): StreakState {
  let day = latest;
  let length = 0;
  while (qualified.has(day)) {
    length++;
    if (day === windowStart) {
      // The run reaches past the bounded window: continue from the stored anchor.
      if (anchor && anchor < windowStart) {
        return {
          currentStreak: daysBetween(anchor, latest) + 1,
          streakStartDay: anchor,
          lastQualifiedDay: latest,
        };
      }
      break;
    }
    day = addDays(day, -1);
  }
  return {
    currentStreak: length,
    streakStartDay: length ? addDays(latest, -(length - 1)) : null,
    lastQualifiedDay: length ? latest : null,
  };
}

/** Freeze capacity: 2 purchasable, plus 3 Streak Society slots at a 365+ day streak (max 5). */
export function freezeCapacity(currentStreak: number): number {
  return Math.min(
    MAX_FREEZE_SLOTS,
    PURCHASABLE_FREEZES + (currentStreak >= STREAK_SOCIETY_DAYS ? STREAK_SOCIETY_FREEZES : 0),
  );
}

/**
 * Displayed streak: the run ending today or yesterday; a longer gap shows 0 unless enough
 * equipped freezes remain for the missed-day worker to protect every missed day.
 */
export function displayStreak(state: StreakState, today: string, freezeSlots: number): number {
  if (!state.lastQualifiedDay) return 0;
  const gap = daysBetween(state.lastQualifiedDay, today);
  if (gap <= 1) return state.currentStreak;
  return gap - 1 <= Math.min(freezeSlots, MISSED_DAY_CATCH_UP) ? state.currentStreak : 0;
}
