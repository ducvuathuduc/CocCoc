// P6-GAME-003 (Learning part): energy read model (FR-GAME-005). Default configuration is UNLIMITED
// (no row needed). A LIMITED row regenerates lazily: one unit every 24h/capacity from anchorAt.
// Spending (ENERGY_DEPLETED) and energy.granted.v1 consumption are not wired yet: the error code is
// not in services/shared/src/errors.ts and the event is not in Learning's inbox allowlist.
import { ids } from '../persistence/ids.js';
import type { Row } from '../persistence/port.js';
import { iso, type LearningDeps } from './deps.js';

export const DEFAULT_CAPACITY = 25;
const DAY_MS = 24 * 60 * 60 * 1000;

export function energyView(row: Row | null, nowMs: number) {
  if (!row || row['mode'] !== 'LIMITED') {
    return {
      mode: 'UNLIMITED' as const,
      balance: Number(row?.['capacity'] ?? DEFAULT_CAPACITY),
      capacity: Number(row?.['capacity'] ?? DEFAULT_CAPACITY),
      nextUnitAt: null,
      fullAt: null,
      revision: Number(row?.['revision'] ?? 0),
      asOf: iso(nowMs),
    };
  }
  const capacity = Math.max(1, Number(row['capacity']));
  const unitMs = Math.floor(DAY_MS / capacity);
  const anchor = Date.parse(String(row['anchorAt']));
  const stored = Math.max(0, Math.min(capacity, Number(row['balance'])));
  const gained = Number.isNaN(anchor) ? 0 : Math.max(0, Math.floor((nowMs - anchor) / unitMs));
  const balance = Math.min(capacity, stored + gained);
  const full = balance >= capacity;
  const nextUnitMs = anchor + (gained + 1) * unitMs;
  return {
    mode: 'LIMITED' as const,
    balance,
    capacity,
    nextUnitAt: full ? null : iso(nextUnitMs),
    fullAt: full ? null : iso(nextUnitMs + (capacity - balance - 1) * unitMs),
    revision: Number(row['revision']),
    asOf: iso(nowMs),
  };
}

export async function getEnergy(deps: LearningDeps, userId: string) {
  return energyView(await deps.persistence.read('l_energy', ids.energy(userId)), deps.nowMs());
}
