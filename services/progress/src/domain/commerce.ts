// Versioned economy config: shop catalog (P6-GAME-003), mock billing products (P10-BILL-001,
// SIMULATION only), mock ad caps and rewards (P10-ADS-001). Pure data and pure helpers.

export type ShopKind =
  'FREEZE' | 'STREAK_REPAIR' | 'TIMER_BOOST' | 'XP_BOOST' | 'WEEKEND_AMULET' | 'ENERGY_REFILL';

export interface ShopItemConfig {
  itemId: string;
  kind: ShopKind;
  priceGems: number;
  /** Max held at once (FREEZE uses the freeze capacity instead). */
  maxOwned: number;
  durationMinutes: number | null;
  multiplier?: number;
  /** False when the effect is not implemented server-side yet (never sold). */
  available: boolean;
}

export const SHOP_CATALOG_VERSION = 'shop-v1';
export const SHOP_ITEMS: readonly ShopItemConfig[] = [
  {
    itemId: 'streak_freeze',
    kind: 'FREEZE',
    priceGems: 20,
    maxOwned: 5,
    durationMinutes: null,
    available: true,
  },
  {
    itemId: 'streak_repair',
    kind: 'STREAK_REPAIR',
    priceGems: 100,
    maxOwned: 1,
    durationMinutes: null,
    available: true,
  },
  {
    itemId: 'xp_boost_15',
    kind: 'XP_BOOST',
    priceGems: 100,
    maxOwned: 3,
    durationMinutes: 15,
    multiplier: 2,
    available: true,
  },
  {
    itemId: 'timer_boost',
    kind: 'TIMER_BOOST',
    priceGems: 50,
    maxOwned: 5,
    durationMinutes: 5,
    multiplier: 1,
    available: true,
  },
  {
    itemId: 'energy_refill',
    kind: 'ENERGY_REFILL',
    priceGems: 50,
    maxOwned: 0,
    durationMinutes: null,
    available: true,
  },
  // Weekend protection is not modelled by the streak worker yet: listed, never sold.
  {
    itemId: 'weekend_amulet',
    kind: 'WEEKEND_AMULET',
    priceGems: 150,
    maxOwned: 1,
    durationMinutes: null,
    available: false,
  },
];
export const STREAK_REPAIR_GEMS = 100;
export const STREAK_REPAIR_WINDOW_DAYS = 2;

export interface ProductConfig {
  productId: string;
  kind: 'SUBSCRIPTION' | 'GEMS';
  plan?: 'SUPER' | 'MAX';
  days?: number;
  gems?: number;
}
export const PRODUCTS: readonly ProductConfig[] = [
  { productId: 'super_family', kind: 'SUBSCRIPTION', plan: 'SUPER', days: 365 },
  { productId: 'max_family', kind: 'SUBSCRIPTION', plan: 'MAX', days: 365 },
  { productId: 'super_monthly', kind: 'SUBSCRIPTION', plan: 'SUPER', days: 30 },
  { productId: 'super_annual', kind: 'SUBSCRIPTION', plan: 'SUPER', days: 365 },
  { productId: 'max_monthly', kind: 'SUBSCRIPTION', plan: 'MAX', days: 30 },
  { productId: 'max_annual', kind: 'SUBSCRIPTION', plan: 'MAX', days: 365 },
  { productId: 'gems_500', kind: 'GEMS', gems: 500 },
  { productId: 'gems_1200', kind: 'GEMS', gems: 1200 },
];

export type PurchaseState =
  'PENDING' | 'ACTIVE' | 'GRACE' | 'HOLD' | 'CANCELED' | 'EXPIRED' | 'REVOKED' | 'REFUNDED';
export type EntitlementStatus = 'ACTIVE' | 'GRACE' | 'HOLD' | 'CANCELED' | 'EXPIRED' | 'REVOKED';

/** MONETIZATION state table: purchase state -> entitlement status (null = no change). */
export function entitlementStatusFor(state: PurchaseState): EntitlementStatus | null {
  switch (state) {
    case 'PENDING':
      return null;
    case 'REFUNDED':
      return 'REVOKED';
    default:
      return state;
  }
}

/** Premium access is on only while verified active/grace, or canceled before paid expiry. */
export function premiumActive(
  plan: string,
  status: string,
  expiresAt: string | null,
  nowIso: string,
): boolean {
  if (plan !== 'SUPER' && plan !== 'MAX') return false;
  if (!['ACTIVE', 'GRACE', 'CANCELED'].includes(status)) return false;
  return expiresAt === null || expiresAt > nowIso;
}

export const FAMILY_MAX_MEMBERS = 6;
export const REFERRAL_TRIAL_DAYS = 7;

export interface AdPlacementConfig {
  impressionCap: number;
  rewardCap: number;
  rewardGems: number;
  rewardEnergy: number;
}
export const AD_PLACEMENTS: Readonly<Record<string, AdPlacementConfig>> = {
  LESSON_END_INTERSTITIAL: { impressionCap: 20, rewardCap: 0, rewardGems: 0, rewardEnergy: 0 },
  REWARDED_GEMS: { impressionCap: 20, rewardCap: 5, rewardGems: 5, rewardEnergy: 0 },
  REWARDED_ENERGY_REFILL: { impressionCap: 20, rewardCap: 5, rewardGems: 0, rewardEnergy: 25 },
};

/** Promo/referral/family/classroom codes are compared by hash of the normalized code. */
export function normalizeCode(code: string): string {
  return code
    .normalize('NFKC')
    .toUpperCase()
    .replace(/[\s-]+/g, '');
}

export const INTERACTION_GIFT_BOOST_GEMS = 50;
export const INTERACTION_MESSAGE_KEYS: Readonly<Record<string, readonly string[]>> = {
  NUDGE: ['nudge.keep_going', 'nudge.miss_you', 'nudge.streak_risk'],
  HIGH_FIVE: ['high_five.nice', 'high_five.great_job'],
  KUDOS: ['kudos.milestone', 'kudos.league', 'kudos.streak'],
  GIFT_BOOST: ['gift_boost.enjoy'],
  CONGRATS: ['congrats.streak', 'congrats.league', 'congrats.achievement'],
};
export const FRIEND_STREAK_LIMIT = 5;
