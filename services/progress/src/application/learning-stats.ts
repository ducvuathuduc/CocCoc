import type { ProgressTx } from '../persistence/port.js';
import { addDays, zonedDay } from '../domain/time.js';
import { requireProfile, zoneAt } from './records.js';

/** Bounded private read. Past day keys are never reinterpreted on zone changes. */
export async function getLearningStats(tx: ProgressTx, userId: string) {
  await requireProfile(tx, userId);
  const learningZone = await zoneAt(tx, userId, tx.nowIso);
  let end = zonedDay(tx.nowIso, learningZone);
  const latest = await tx.list('p_day_activity', {
    where: { userId },
    orderBy: [['day', 'desc']],
    limit: 1,
  });
  const lastDay = latest[0]?.row['day'];
  if (typeof lastDay === 'string' && lastDay > end) end = lastDay;
  const start = addDays(end, -27);
  const rows = await tx.list('p_day_activity', {
    where: { userId },
    gte: { day: start },
    lt: { day: addDays(end, 1) },
    orderBy: [['day', 'asc']],
    limit: 28,
  });
  const byDay = new Map(rows.map(({ row }) => [String(row['day']), row]));
  return {
    asOf: tx.nowIso,
    learningZone,
    days: Array.from({ length: 28 }, (_, i) => {
      const day = addDays(start, i);
      const row = byDay.get(day);
      return {
        day,
        studyXp: Number(row?.['studyXp'] ?? 0),
        completedLessons: Number(row?.['completedLessons'] ?? 0),
        reviewSessions: Number(row?.['reviewSessions'] ?? 0),
        originalCorrect: Number(row?.['originalCorrect'] ?? 0),
        active: Boolean(row?.['active']),
        trackedOriginalCount: Number(row?.['trackedOriginalCount'] ?? 0),
        trackedOriginalCorrect: Number(row?.['trackedOriginalCorrect'] ?? 0),
      };
    }),
  };
}
