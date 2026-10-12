// League rules (SRS FR-SOCIAL-002): weekly cohort <= 30, 10 tiers (0 Bronze .. 9 Diamond),
// rank by eligible XP desc, then earliest lastXpAt, then stable userId. Full cohorts (>= 10)
// promote the top 5 and demote the bottom 5; smaller cohorts never change tier.

export const COHORT_SIZE = 30;
export const MIN_COHORT_FOR_MOVES = 10;
export const PROMOTE_COUNT = 5;
export const DEMOTE_COUNT = 5;
export const MAX_TIER = 9;

export interface LeagueEntry {
  userId: string;
  eligibleXp: number;
  lastXpAt: string | null;
}

export function rankMembers<T extends LeagueEntry>(
  members: readonly T[],
): Array<T & { rank: number }> {
  return [...members]
    .sort((a, b) => {
      if (a.eligibleXp !== b.eligibleXp) return b.eligibleXp - a.eligibleXp;
      if (a.lastXpAt !== b.lastXpAt) {
        if (a.lastXpAt === null) return 1;
        if (b.lastXpAt === null) return -1;
        return a.lastXpAt < b.lastXpAt ? -1 : 1;
      }
      return a.userId < b.userId ? -1 : a.userId > b.userId ? 1 : 0;
    })
    .map((member, index) => ({ ...member, rank: index + 1 }));
}

export type Movement = 'PROMOTE' | 'STAY' | 'DEMOTE';

export function movementFor(rank: number, cohortSize: number, tier: number): Movement {
  if (cohortSize < MIN_COHORT_FOR_MOVES) return 'STAY';
  if (rank <= PROMOTE_COUNT && tier < MAX_TIER) return 'PROMOTE';
  if (rank > cohortSize - DEMOTE_COUNT && tier > 0) return 'DEMOTE';
  return 'STAY';
}

export function nextTier(tier: number, movement: Movement): number {
  if (movement === 'PROMOTE') return Math.min(MAX_TIER, tier + 1);
  if (movement === 'DEMOTE') return Math.max(0, tier - 1);
  return tier;
}
