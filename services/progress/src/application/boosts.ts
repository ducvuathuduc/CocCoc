// XP boost lookup at the server-accepted completion time (DATA_MODEL p_boosts: "reward consume
// applies a boost whose window covers the server-accepted completion time"). Boosts are written
// by shop activation (P6-GAME-003) once its OpenAPI operation exists; until then none exist.
import type { ProgressTx } from '../persistence/port.js';

export async function activeBoostMultiplier(
  tx: ProgressTx,
  userId: string,
  instant: string,
): Promise<number> {
  const boosts = await tx.list('p_boosts', {
    where: { userId },
    gte: { endsAt: instant },
    orderBy: [['endsAt', 'asc']],
    limit: 20,
  });
  let multiplier = 1;
  for (const { row } of boosts) {
    const kind = row['kind'];
    if (kind !== 'XP_BOOST' && kind !== 'HAPPY_HOUR') continue;
    if (String(row['startsAt']) <= instant && instant < String(row['endsAt'])) {
      multiplier = Math.max(multiplier, Number(row['multiplier'] ?? 1));
    }
  }
  return multiplier;
}
