// P6-GAME-003 (Learning part): energy battery (FR-GAME-005, DATA_MODEL l_energy).
// Course configuration energyMode defaults to UNLIMITED: nothing is spent and no row is needed.
// Under LIMITED a row regenerates lazily (one unit every 24h/capacity from anchorAt); a lesson or
// mastery answer spends one unit inside the answer transaction and starting such a session with
// an empty battery is ENERGY_DEPLETED. Mistakes review (REVIEW) and PLACEMENT are free. A paid
// plan (SUPER/MAX, projected from entitlement.changed.v1) is UNLIMITED; refills arrive only as
// energy.granted.v1 from Progress (shop, ads, promo), applied once through the l_inbox row.
import { ServiceError } from '../../../shared/src/errors.js';
import { ids } from '../persistence/ids.js';
import type { LearningTransaction, Row } from '../persistence/port.js';
import { bumped, created, iso, type LearningDeps } from './deps.js';

export const DEFAULT_CAPACITY = 25;
const DAY_MS = 24 * 60 * 60 * 1000;
export type EnergyMode = 'LIMITED' | 'UNLIMITED';

/** COC_ENERGY_MODE: only the exact value LIMITED turns spending on. */
export function energyModeFrom(value: string | undefined): EnergyMode {
  return value === 'LIMITED' ? 'LIMITED' : 'UNLIMITED';
}

/** Session modes that spend energy (everything else is free). */
export function spendsEnergy(mode: string): boolean {
  return mode === 'LESSON' || mode === 'MASTERY';
}

interface Battery {
  balance: number;
  capacity: number;
  /** Anchor that keeps partial regeneration progress after a write. */
  anchorMs: number;
  unitMs: number;
}

function battery(row: Row | null, nowMs: number): Battery {
  const capacity = Math.max(1, Math.min(100, Number(row?.['capacity'] ?? DEFAULT_CAPACITY)));
  const unitMs = Math.floor(DAY_MS / capacity);
  if (!row) return { balance: capacity, capacity, anchorMs: nowMs, unitMs };
  const anchor = Date.parse(String(row['anchorAt']));
  const stored = Math.max(0, Math.min(capacity, Number(row['balance'] ?? capacity)));
  const gained = Number.isNaN(anchor) ? 0 : Math.max(0, Math.floor((nowMs - anchor) / unitMs));
  const balance = Math.min(capacity, stored + gained);
  // Full battery: regeneration restarts at the next spend; otherwise keep the partial unit.
  const anchorMs = balance >= capacity || Number.isNaN(anchor) ? nowMs : anchor + gained * unitMs;
  return { balance, capacity, anchorMs, unitMs };
}

/** Effective mode: configuration first, then the entitlement projection on the row. */
export function effectiveMode(config: EnergyMode, row: Row | null): EnergyMode {
  if (config === 'UNLIMITED') return 'UNLIMITED';
  return row?.['mode'] === 'UNLIMITED' ? 'UNLIMITED' : 'LIMITED';
}

/**
 * Read model. With `config` the deployment mode applies (getEnergy); without it the row's own
 * mode is shown (a missing row is UNLIMITED), which is what the stored battery alone says.
 */
export function energyView(row: Row | null, nowMs: number, config?: EnergyMode) {
  const b = battery(row, nowMs);
  const mode = config
    ? effectiveMode(config, row)
    : row?.['mode'] === 'LIMITED'
      ? 'LIMITED'
      : 'UNLIMITED';
  if (mode === 'UNLIMITED') {
    return {
      mode: 'UNLIMITED' as const,
      balance: b.capacity,
      capacity: b.capacity,
      nextUnitAt: null,
      fullAt: null,
      revision: Number(row?.['revision'] ?? 0),
      asOf: iso(nowMs),
    };
  }
  const full = b.balance >= b.capacity;
  const nextUnitMs = b.anchorMs + b.unitMs;
  return {
    mode: 'LIMITED' as const,
    balance: b.balance,
    capacity: b.capacity,
    nextUnitAt: full ? null : iso(nextUnitMs),
    fullAt: full ? null : iso(nextUnitMs + (b.capacity - b.balance - 1) * b.unitMs),
    revision: Number(row?.['revision'] ?? 0),
    asOf: iso(nowMs),
  };
}

export async function getEnergy(deps: LearningDeps, userId: string) {
  return energyView(
    await deps.persistence.read('l_energy', ids.energy(userId)),
    deps.nowMs(),
    deps.energyMode ?? 'UNLIMITED',
  );
}

function writeBattery(
  tx: LearningTransaction,
  userId: string,
  previous: Row | null,
  next: { mode?: EnergyMode; balance: number; anchorMs: number; entitlementRevision?: number },
  nowMs: number,
): void {
  const capacity = Math.max(1, Math.min(100, Number(previous?.['capacity'] ?? DEFAULT_CAPACITY)));
  tx.put('l_energy', ids.energy(userId), {
    userId,
    mode: next.mode ?? (previous?.['mode'] === 'UNLIMITED' ? 'UNLIMITED' : 'LIMITED'),
    balance: Math.max(0, Math.min(capacity, next.balance)),
    capacity,
    anchorAt: iso(next.anchorMs),
    entitlementRevision: next.entitlementRevision ?? Number(previous?.['entitlementRevision'] ?? 0),
    ...(previous
      ? { createdAt: previous['createdAt'], ...bumped(previous, nowMs) }
      : created(nowMs)),
  });
}

function depleted(row: Row | null, nowMs: number): never {
  const view = energyView(row, nowMs, 'LIMITED');
  throw new ServiceError('ENERGY_DEPLETED', {
    details: { balance: view.balance, nextUnitAt: view.nextUnitAt },
  });
}

/** Session start gate (inside the start transaction): an empty LIMITED battery is refused. */
export async function assertEnergyForStart(
  deps: LearningDeps,
  tx: LearningTransaction,
  userId: string,
  mode: string,
): Promise<void> {
  if (!spendsEnergy(mode)) return;
  const row = await tx.get('l_energy', ids.energy(userId));
  if (effectiveMode(deps.energyMode ?? 'UNLIMITED', row) === 'UNLIMITED') return;
  if (battery(row, deps.nowMs()).balance < 1) depleted(row, deps.nowMs());
}

/** Spend one unit for an answer (inside the answer transaction). Returns units spent. */
export async function spendEnergy(
  deps: LearningDeps,
  tx: LearningTransaction,
  userId: string,
  mode: string,
): Promise<number> {
  if (!spendsEnergy(mode)) return 0;
  const row = await tx.get('l_energy', ids.energy(userId));
  if (effectiveMode(deps.energyMode ?? 'UNLIMITED', row) === 'UNLIMITED') return 0;
  const now = deps.nowMs();
  const b = battery(row, now);
  if (b.balance < 1) depleted(row, now);
  writeBattery(tx, userId, row, { balance: b.balance - 1, anchorMs: b.anchorMs }, now);
  return 1;
}

export interface EnergyGrant {
  operationId: string;
  userId: string;
  amount: number | null;
  refillToCapacity: boolean;
  reason: string;
}

/** energy.granted.v1 effect (the l_inbox row makes it apply once per eventId). */
export async function applyEnergyGrant(
  deps: LearningDeps,
  tx: LearningTransaction,
  grant: EnergyGrant,
): Promise<void> {
  const row = await tx.get('l_energy', ids.energy(grant.userId));
  const now = deps.nowMs();
  const b = battery(row, now);
  const balance = grant.refillToCapacity ? b.capacity : b.balance + (grant.amount ?? 0);
  writeBattery(
    tx,
    grant.userId,
    row,
    { balance, anchorMs: balance >= b.capacity ? now : b.anchorMs },
    now,
  );
}

export interface EntitlementProjection {
  userId: string;
  plan: string;
  status: string;
  expiresAt: string | null;
  entitlementRevision: number;
}

/** entitlement.changed.v1 effect: keep only the newest revision; paid plans are UNLIMITED. */
export async function applyEntitlement(
  deps: LearningDeps,
  tx: LearningTransaction,
  change: EntitlementProjection,
): Promise<void> {
  const row = await tx.get('l_energy', ids.energy(change.userId));
  if (row && Number(row['entitlementRevision'] ?? 0) > change.entitlementRevision) return;
  const now = deps.nowMs();
  const paid =
    (change.plan === 'SUPER' || change.plan === 'MAX') &&
    (change.status === 'ACTIVE' || change.status === 'GRACE') &&
    (change.expiresAt === null || Date.parse(change.expiresAt) > now);
  const b = battery(row, now);
  writeBattery(
    tx,
    change.userId,
    row,
    {
      mode: paid ? 'UNLIMITED' : 'LIMITED',
      balance: b.balance,
      anchorMs: b.anchorMs,
      entitlementRevision: change.entitlementRevision,
    },
    now,
  );
}
