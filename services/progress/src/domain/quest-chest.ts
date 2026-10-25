import { randomBytes } from 'node:crypto';

export type ChestTier = 'COMMON' | 'RARE' | 'EPIC' | 'MEGA';
export interface QuestChestReceipt {
  receiptId: string;
  tiers: ChestTier[];
  gems: number;
}

// CocEnglish chest policy v1 (not Duolingo's undisclosed probabilities).
// Persist the opaque random operation identity in the existing quest claim row.
// Its version prefix freezes the outcome policy across retries and restarts.
export function newChestOperation(): string {
  return `ch1_${randomBytes(12).toString('hex')}`;
}

export function questChestReceipt(operation: string, baseGems: number): QuestChestReceipt | null {
  if (!/^ch1_[0-9a-f]{24}$/.test(operation) || baseGems <= 0) return null;
  const rolls = Buffer.from(operation.slice(4), 'hex');
  const ranks: ChestTier[] = ['COMMON', 'RARE', 'EPIC', 'MEGA'];
  let rank = 0;
  const tiers: ChestTier[] = ['COMMON'];
  for (let i = 0; i < 3; i++) {
    if (rolls[i]! < 64) rank = Math.min(3, rank + 1);
    tiers.push(ranks[rank]!);
  }
  return { receiptId: operation, tiers, gems: baseGems * 2 ** rank };
}
