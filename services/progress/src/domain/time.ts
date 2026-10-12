// Server-time calendar helpers (docs/product/SRS.md "Deterministic learning and reward rules").
// Learning days use the profile zone selected from immutable history at event server time;
// league weeks are Monday 00:00 UTC to the next Monday 00:00 UTC, independent of the zone.

const DAY_MS = 86_400_000;
const formatters = new Map<string, Intl.DateTimeFormat>();

export function isValidZone(zone: unknown): zone is string {
  if (typeof zone !== 'string' || zone.length < 1 || zone.length > 64) return false;
  try {
    new Intl.DateTimeFormat('en-CA', { timeZone: zone });
    return true;
  } catch {
    return false;
  }
}

/** Calendar day (YYYY-MM-DD) of an instant in an IANA zone. */
export function zonedDay(instant: string | number, zone: string): string {
  let formatter = formatters.get(zone);
  if (!formatter) {
    formatter = new Intl.DateTimeFormat('en-CA', {
      timeZone: zone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    });
    formatters.set(zone, formatter);
  }
  const parts = formatter.formatToParts(new Date(instant));
  const get = (type: string) => parts.find((part) => part.type === type)?.value ?? '';
  return `${get('year')}-${get('month')}-${get('day')}`;
}

function dayMs(day: string): number {
  return Date.parse(`${day}T00:00:00.000Z`);
}

export function addDays(day: string, delta: number): string {
  return new Date(dayMs(day) + delta * DAY_MS).toISOString().slice(0, 10);
}

/** Whole days from a to b (b - a). */
export function daysBetween(a: string, b: string): number {
  return Math.round((dayMs(b) - dayMs(a)) / DAY_MS);
}

/** League week ID: the Monday (UTC) starting the week containing the instant. */
export function leagueWeek(instant: string | number): string {
  const date = new Date(instant);
  const weekday = (date.getUTCDay() + 6) % 7; // Monday = 0
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate() - weekday))
    .toISOString()
    .slice(0, 10);
}

/** Exclusive end of a league week (next Monday 00:00 UTC) as ISO-8601. */
export function leagueWeekEnd(weekId: string): string {
  return new Date(dayMs(weekId) + 7 * DAY_MS).toISOString();
}

/** 00:00:00Z of the UTC date immediately after the instant (timezone change effectiveAt). */
export function nextUtcMidnight(instantMs: number): string {
  const date = new Date(instantMs);
  return new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate() + 1),
  ).toISOString();
}

export function monthKey(day: string): string {
  return day.slice(0, 7);
}
