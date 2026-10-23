// Economy and monetization use cases:
// P6-GAME-003 shop/inventory/boosts/streak repair, P10-BILL-001 MOCK billing (SIMULATION
// purchases, mock verifier, family, gifts, referrals), P10-PROMO-001 promo codes and
// P10-ADS-001 mock free-tier ads. Every wallet delta writes a ledger row in the same transaction;
// every entitlement change writes entitlement.changed.v1 to p_outbox atomically. No store SDK,
// no ad network, no real money.
import { createHash, createHmac, randomUUID } from 'node:crypto';
import { ServiceError } from '../../../shared/src/errors.js';
import type { ProgressPersistence, ProgressTx, Row } from '../persistence/port.js';
import {
  AD_PLACEMENTS,
  FAMILY_MAX_MEMBERS,
  PRODUCTS,
  REFERRAL_TRIAL_DAYS,
  SHOP_CATALOG_VERSION,
  SHOP_ITEMS,
  STREAK_REPAIR_GEMS,
  STREAK_REPAIR_WINDOW_DAYS,
  entitlementStatusFor,
  normalizeCode,
  premiumActive,
  type PurchaseState,
} from '../domain/commerce.js';
import { freezeCapacity } from '../domain/streak.js';
import { addDays, daysBetween, leagueWeek, zonedDay } from '../domain/time.js';
import {
  DEFAULT_ZONE,
  editable,
  emptyRewards,
  freeEntitlement,
  ids,
  operationId,
  putOutbox,
  requireProfile,
  rewardsView,
} from './records.js';
import { rowId } from '../persistence/core.js';
import { isBlockedPair } from './social.js';

const DAY_MS = 86_400_000;
let codeSecret = 'cocenglish-dev-only-code-secret';

/** Hosted entry sets COC_PROGRESS_CODE_SECRET; referral/family codes derive from it. */
export function setCodeSecret(secret: string | undefined): void {
  if (secret && secret.length >= 16) codeSecret = secret;
}
export function codeHash(code: string): string {
  return createHash('sha256').update(normalizeCode(code), 'utf8').digest('hex');
}
const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
export function derivedCode(kind: string, id: string): string {
  const digest = createHmac('sha256', codeSecret).update(`${kind}|${id}`).digest();
  let out = '';
  for (let i = 0; i < 8; i++) out += CODE_ALPHABET[(digest[i] as number) % CODE_ALPHABET.length];
  return out;
}

// ---------------------------------------------------------------- shared wallet helpers

async function zoneOf(tx: ProgressTx, userId: string): Promise<string> {
  const profile = await requireProfile(tx, userId);
  return String(profile['learningZone'] ?? DEFAULT_ZONE);
}

/** Apply a gem delta with its ledger row; never below zero. Returns the new balance. */
export async function creditGems(
  tx: ProgressTx,
  userId: string,
  delta: number,
  kind: 'SHOP' | 'STREAK' | 'PURCHASE' | 'REFUND' | 'ADJUST' | 'GIFT' | 'LEAGUE' | 'QUEST',
  completionId: string,
  rewardIdentity: string,
  zone: string = DEFAULT_ZONE,
): Promise<number> {
  const rewardsId = ids.rewards(userId);
  const rewards = editable((await tx.get('p_rewards', rewardsId)) ?? emptyRewards(userId));
  const balance = Number(rewards['gems'] ?? 0);
  const applied = Math.max(delta, -balance);
  if (delta < 0 && applied !== delta && kind !== 'REFUND') {
    throw new ServiceError('INSUFFICIENT_GEMS', { details: { required: -delta } });
  }
  rewards['gems'] = balance + applied;
  tx.put('p_rewards', rewardsId, rewards);
  const ledgerId = ids.ledger(userId, completionId, kind);
  if (await tx.get('p_reward_ledger', ledgerId)) {
    throw new ServiceError('IDEMPOTENCY_CONFLICT', { details: { reason: 'LEDGER_ROW_EXISTS' } });
  }
  tx.put('p_reward_ledger', ledgerId, {
    eventId: operationId('ledger', userId, completionId, kind),
    completionId,
    userId,
    rewardIdentity: rewardIdentity.slice(0, 36),
    kind,
    studyXpDelta: 0,
    leagueXpDelta: 0,
    gemsDelta: applied,
    learningDay: zonedDay(tx.nowIso, zone),
    leagueWeek: leagueWeek(tx.nowIso),
    occurredAt: tx.nowIso,
    capped: false,
  });
  return Number(rewards['gems']);
}

export interface InventoryView {
  itemId: string;
  quantity: number;
  expiresAt: string | null;
}

async function adjustInventory(
  tx: ProgressTx,
  userId: string,
  itemId: string,
  delta: number,
  action: 'BUY' | 'GRANT' | 'CONSUME' | 'ACTIVATE',
  opId: string,
  gemsDelta: number,
  source: string,
): Promise<InventoryView> {
  const id = rowId('p_inventory', userId, itemId);
  const row = await tx.get('p_inventory', id);
  const quantity = Number(row?.['quantity'] ?? 0) + delta;
  if (quantity < 0) throw new ServiceError('ITEM_UNAVAILABLE', { details: { itemId } });
  tx.put('p_inventory', id, {
    ...(row ? editable(row) : {}),
    userId,
    itemId,
    quantity: Math.min(999, quantity),
    expiresAt: (row?.['expiresAt'] as string | null | undefined) ?? null,
  });
  tx.put('p_item_ledger', rowId('p_item_ledger', userId, opId, itemId), {
    userId,
    operationId: opId,
    itemId,
    action,
    quantityDelta: delta,
    gemsDelta,
    source,
    occurredAt: tx.nowIso,
  });
  return { itemId, quantity: Math.min(999, quantity), expiresAt: null };
}

function energyGrant(
  tx: ProgressTx,
  userId: string,
  opId: string,
  reason: 'SHOP' | 'AD' | 'PROMO',
  amount: number | null,
): void {
  putOutbox(
    tx,
    'energy.granted.v1',
    userId,
    { operationId: opId, userId, amount, refillToCapacity: amount === null, reason },
    randomUUID(),
  );
}

// ---------------------------------------------------------------- shop (P6-GAME-003)

export async function listShop(tx: ProgressTx, userId: string) {
  await requireProfile(tx, userId);
  const rewards = (await tx.get('p_rewards', ids.rewards(userId))) ?? emptyRewards(userId);
  const inventory = (await tx.list('p_inventory', { where: { userId }, limit: 50 })).map(
    ({ row }) => ({
      itemId: String(row['itemId']),
      quantity: Number(row['quantity']),
      expiresAt: (row['expiresAt'] as string | null) ?? null,
    }),
  );
  const slots = Number(rewards['freezeSlots'] ?? 0);
  const capacity = freezeCapacity(Number(rewards['currentStreak'] ?? 0));
  return {
    catalogVersion: SHOP_CATALOG_VERSION,
    gems: Number(rewards['gems'] ?? 0),
    freezeSlots: slots,
    items: SHOP_ITEMS.map((item) => {
      const owned =
        item.kind === 'FREEZE'
          ? slots
          : (inventory.find((entry) => entry.itemId === item.itemId)?.quantity ?? 0);
      const maxOwned = item.kind === 'FREEZE' ? capacity : item.maxOwned;
      return {
        itemId: item.itemId,
        kind: item.kind,
        priceGems: item.priceGems,
        maxOwned,
        owned,
        durationMinutes: item.durationMinutes,
        available:
          item.available &&
          (item.kind === 'ENERGY_REFILL' || owned < maxOwned) &&
          Number(rewards['gems'] ?? 0) >= item.priceGems,
      };
    }),
    inventory,
    asOf: tx.nowIso,
  };
}

export async function buyItem(
  tx: ProgressTx,
  userId: string,
  request: { itemId: string; quantity: number; catalogVersion: string },
  key: string,
) {
  const zone = await zoneOf(tx, userId);
  const item = SHOP_ITEMS.find((entry) => entry.itemId === request.itemId);
  if (request.catalogVersion !== SHOP_CATALOG_VERSION || !item || !item.available) {
    throw new ServiceError('ITEM_UNAVAILABLE', {
      details: { itemId: request.itemId, catalogVersion: SHOP_CATALOG_VERSION },
    });
  }
  const opId = operationId('shop-buy', userId, key);
  const rewardsRow = (await tx.get('p_rewards', ids.rewards(userId))) ?? emptyRewards(userId);
  const cost = item.priceGems * request.quantity;
  let inventory: InventoryView | null = null;
  let freezeSlots = Number(rewardsRow['freezeSlots'] ?? 0);
  if (item.kind === 'FREEZE') {
    if (freezeSlots + request.quantity > freezeCapacity(Number(rewardsRow['currentStreak'] ?? 0))) {
      throw new ServiceError('FREEZE_CAPACITY', { details: { freezeSlots } });
    }
  } else if (item.kind === 'ENERGY_REFILL') {
    if (request.quantity !== 1) {
      throw new ServiceError('ITEM_UNAVAILABLE', {
        details: { reason: 'ONE_REFILL_PER_PURCHASE' },
      });
    }
  } else {
    const held = await tx.get('p_inventory', rowId('p_inventory', userId, item.itemId));
    if (Number(held?.['quantity'] ?? 0) + request.quantity > item.maxOwned) {
      throw new ServiceError('ITEM_UNAVAILABLE', {
        details: { reason: 'MAX_OWNED', itemId: item.itemId },
      });
    }
  }
  if (Number(rewardsRow['gems'] ?? 0) < cost) {
    throw new ServiceError('INSUFFICIENT_GEMS', { details: { required: cost } });
  }
  const gems = await creditGems(tx, userId, -cost, 'SHOP', opId, item.itemId, zone);
  if (item.kind === 'FREEZE') {
    const rewards = editable((await tx.get('p_rewards', ids.rewards(userId))) as Row);
    freezeSlots += request.quantity;
    rewards['freezeSlots'] = freezeSlots;
    tx.put('p_rewards', ids.rewards(userId), rewards);
    tx.put('p_freeze_ledger', ids.freeze(userId, opId), {
      userId,
      operationId: opId,
      action: 'BUY',
      day: null,
      gemsDelta: -cost,
      slotDelta: request.quantity,
    });
  } else if (item.kind === 'ENERGY_REFILL') {
    tx.put('p_item_ledger', rowId('p_item_ledger', userId, opId, item.itemId), {
      userId,
      operationId: opId,
      itemId: item.itemId,
      action: 'BUY',
      quantityDelta: 0,
      gemsDelta: -cost,
      source: 'shop',
      occurredAt: tx.nowIso,
    });
    energyGrant(tx, userId, opId, 'SHOP', null);
  } else {
    inventory = await adjustInventory(
      tx,
      userId,
      item.itemId,
      request.quantity,
      'BUY',
      opId,
      -cost,
      'shop',
    );
  }
  return {
    operationId: opId,
    itemId: item.itemId,
    quantity: request.quantity,
    gemsSpent: cost,
    gems,
    freezeSlots,
    inventory,
    energyGrantPending: item.kind === 'ENERGY_REFILL',
    asOf: tx.nowIso,
  };
}

/** Consume one held boost item and open its window (stacked after an active same-kind boost). */
export async function activateBoost(tx: ProgressTx, userId: string, itemId: string, key: string) {
  await requireProfile(tx, userId);
  const item = SHOP_ITEMS.find((entry) => entry.itemId === itemId);
  if (!item || (item.kind !== 'XP_BOOST' && item.kind !== 'TIMER_BOOST') || !item.durationMinutes) {
    throw new ServiceError('ITEM_UNAVAILABLE', { details: { itemId } });
  }
  const opId = operationId('boost', userId, key);
  const inventory = await adjustInventory(tx, userId, itemId, -1, 'ACTIVATE', opId, 0, 'boost');
  const active = await tx.list('p_boosts', {
    where: { userId, kind: item.kind },
    gte: { endsAt: tx.nowIso },
    orderBy: [['endsAt', 'desc']],
    limit: 1,
  });
  const startsAt = active[0] ? String(active[0].row['endsAt']) : tx.nowIso;
  const endsAt = new Date(Date.parse(startsAt) + item.durationMinutes * 60_000).toISOString();
  tx.put('p_boosts', rowId('p_boosts', userId, opId), {
    userId,
    boostId: opId,
    kind: item.kind,
    multiplier: item.multiplier ?? 1,
    startsAt,
    endsAt,
    sourceOperationId: opId,
  });
  return {
    boostId: opId,
    kind: item.kind,
    multiplier: item.multiplier ?? 1,
    startsAt,
    endsAt,
    inventory,
  };
}

/** Restore the lost streak inside the offer window, paid with gems or a held repair item. */
export async function repairStreak(
  tx: ProgressTx,
  userId: string,
  request: { lostStreakDay: string; payWith: 'GEMS' | 'ITEM' },
  key: string,
) {
  const zone = await zoneOf(tx, userId);
  const rewardsId = ids.rewards(userId);
  const stored = (await tx.get('p_rewards', rewardsId)) ?? emptyRewards(userId);
  const lost = Number(stored['lostStreak'] ?? 0);
  const today = zonedDay(tx.nowIso, zone);
  if (
    lost <= 0 ||
    stored['lostStreakDay'] !== request.lostStreakDay ||
    daysBetween(request.lostStreakDay, today) > STREAK_REPAIR_WINDOW_DAYS
  ) {
    throw new ServiceError('STREAK_REPAIR_EXPIRED');
  }
  const opId = operationId('streak-repair', userId, key);
  if (request.payWith === 'GEMS') {
    await creditGems(tx, userId, -STREAK_REPAIR_GEMS, 'STREAK', opId, 'streak_repair', zone);
  } else {
    await adjustInventory(tx, userId, 'streak_repair', -1, 'CONSUME', opId, 0, 'streak-repair');
  }
  const rewards = editable((await tx.get('p_rewards', rewardsId)) ?? stored);
  const last = (rewards['lastQualifiedDay'] as string | null) ?? null;
  const continuing = last !== null && last >= request.lostStreakDay;
  const restored = lost + (continuing ? Number(rewards['currentStreak'] ?? 0) : 0);
  const end = continuing ? (last as string) : addDays(request.lostStreakDay, -1);
  rewards['currentStreak'] = restored;
  rewards['streakStartDay'] = addDays(end, -(restored - 1));
  rewards['lastQualifiedDay'] = continuing ? last : end;
  rewards['bestStreak'] = Math.max(Number(rewards['bestStreak'] ?? 0), restored);
  rewards['lostStreak'] = 0;
  rewards['lostStreakDay'] = null;
  tx.put('p_rewards', rewardsId, rewards);
  return rewardsView(
    { ...rewards, revision: Number(stored['revision'] ?? -1) + 1 },
    zone,
    tx.nowIso,
  );
}

// ---------------------------------------------------------------- entitlements (P10-BILL-001)

export function entitlementView(row: Readonly<Row>, nowIso: string) {
  const plan = String(row['plan'] ?? 'FREE');
  const status = String(row['status'] ?? 'ACTIVE');
  const expiresAt = (row['expiresAt'] as string | null) ?? null;
  const active = premiumActive(plan, status, expiresAt, nowIso);
  const lapsed = plan !== 'FREE' && !active && expiresAt !== null && expiresAt <= nowIso;
  return {
    plan: (lapsed ? 'FREE' : plan) as 'FREE' | 'SUPER' | 'MAX',
    source: String(row['source'] ?? 'NONE') as 'NONE',
    status: (lapsed ? 'EXPIRED' : status) as 'ACTIVE',
    expiresAt,
    autoRenew: lapsed ? false : Boolean(row['autoRenew']),
    familyGroupId: (row['familyGroupId'] as string | null) ?? null,
    unlimitedEnergy: active,
    adFree: active,
    conversations: active && plan === 'MAX',
    revision: Number(row['revision'] ?? 0),
    asOf: nowIso,
  };
}

export async function getEntitlement(tx: ProgressTx, userId: string) {
  await requireProfile(tx, userId);
  const row = (await tx.get('p_entitlements', ids.entitlement(userId))) ?? freeEntitlement(userId);
  return entitlementView(row, tx.nowIso);
}

/** Write an entitlement change and its entitlement.changed.v1 event atomically. */
export async function changeEntitlement(tx: ProgressTx, userId: string, patch: Row) {
  const id = ids.entitlement(userId);
  const current = await tx.get('p_entitlements', id);
  const next: Row = {
    ...(current ? editable(current) : freeEntitlement(userId)),
    ...patch,
    userId,
  };
  tx.put('p_entitlements', id, next);
  const revision = current ? Number(current['revision'] ?? 0) + 1 : 0;
  putOutbox(
    tx,
    'entitlement.changed.v1',
    userId,
    {
      userId,
      plan: next['plan'],
      status: next['status'],
      expiresAt: next['expiresAt'] ?? null,
      entitlementRevision: revision,
    },
    randomUUID(),
  );
  return entitlementView({ ...next, revision }, tx.nowIso);
}

async function applyPurchaseState(
  tx: ProgressTx,
  purchase: Row,
  state: PurchaseState,
): Promise<{ gems: number | null }> {
  const userId = String(purchase['userId']);
  const product = PRODUCTS.find((p) => p.productId === purchase['productId']);
  const purchaseId = String(purchase['purchaseId']);
  if (!product) return { gems: null };
  if (product.kind === 'GEMS') {
    const credited = await tx.get('p_reward_ledger', ids.ledger(userId, purchaseId, 'PURCHASE'));
    const refunded = await tx.get('p_reward_ledger', ids.ledger(userId, purchaseId, 'REFUND'));
    if ((state === 'ACTIVE' || state === 'GRACE') && !credited) {
      return {
        gems: await creditGems(
          tx,
          userId,
          product.gems ?? 0,
          'PURCHASE',
          purchaseId,
          product.productId,
        ),
      };
    }
    if ((state === 'REFUNDED' || state === 'REVOKED') && credited && !refunded) {
      return {
        gems: await creditGems(
          tx,
          userId,
          -(product.gems ?? 0),
          'REFUND',
          purchaseId,
          product.productId,
        ),
      };
    }
    return { gems: null };
  }
  const status = entitlementStatusFor(state);
  if (!status) return { gems: null };
  const current = await tx.get('p_entitlements', ids.entitlement(userId));
  // Only the purchase that owns the entitlement (or a fresh grant) may change it.
  if (
    current &&
    current['purchaseId'] &&
    current['purchaseId'] !== purchaseId &&
    premiumActive(
      String(current['plan']),
      String(current['status']),
      (current['expiresAt'] as string | null) ?? null,
      tx.nowIso,
    ) &&
    status !== 'ACTIVE' &&
    status !== 'GRACE'
  ) {
    return { gems: null };
  }
  const expiresAt =
    status === 'ACTIVE' || status === 'GRACE'
      ? ((current?.['purchaseId'] === purchaseId ? current?.['expiresAt'] : null) ??
        new Date(tx.nowMs + (product.days ?? 30) * DAY_MS).toISOString())
      : (((current?.['purchaseId'] === purchaseId ? current?.['expiresAt'] : null) as
          string | null) ?? tx.nowIso);
  await changeEntitlement(tx, userId, {
    plan: product.plan,
    source: 'PURCHASE',
    status,
    expiresAt: status === 'CANCELED' ? (current?.['expiresAt'] ?? expiresAt) : expiresAt,
    autoRenew: status === 'ACTIVE' || status === 'GRACE',
    purchaseId,
    giftId: null,
  });
  return { gems: null };
}

function purchaseView(
  row: Readonly<Row>,
  gems: number | null,
  entitlement: ReturnType<typeof entitlementView>,
) {
  return {
    purchaseId: String(row['purchaseId']),
    productId: String(row['productId']),
    kind: String(row['kind']) as 'SUBSCRIPTION',
    platform: 'SIMULATION' as const,
    state: String(row['state']) as PurchaseState,
    verifiedAt: (row['verifiedAt'] as string | null) ?? null,
    gems,
    entitlement,
  };
}

/** Mock verifier: SIMULATION purchase moves to the fixture outcome; no store is contacted. */
export async function verifyPurchase(
  tx: ProgressTx,
  userId: string,
  request: { productId: string; kind: 'SUBSCRIPTION' | 'GEMS'; simulationOutcome: PurchaseState },
  key: string,
) {
  await requireProfile(tx, userId);
  const product = PRODUCTS.find(
    (p) => p.productId === request.productId && p.kind === request.kind,
  );
  if (!product) throw new ServiceError('NOT_FOUND', { details: { productId: request.productId } });
  const purchaseId = operationId('purchase', userId, key);
  const token = `sim:${purchaseId}`;
  const row: Row = {
    purchaseId,
    userId,
    platform: 'SIMULATION',
    productId: product.productId,
    kind: product.kind,
    purchaseToken: token,
    purchaseTokenHash: createHash('sha256').update(token).digest('hex'),
    state: request.simulationOutcome,
    vendorStateJson: JSON.stringify({ simulation: true, lastOccurredAt: tx.nowIso }),
    verifiedAt: request.simulationOutcome === 'PENDING' ? null : tx.nowIso,
    lastNotificationId: null,
  };
  tx.put('p_purchases', rowId('p_purchases', purchaseId), row);
  const { gems } = await applyPurchaseState(tx, row, request.simulationOutcome);
  const ent = (await tx.get('p_entitlements', ids.entitlement(userId))) ?? freeEntitlement(userId);
  return purchaseView(row, gems, entitlementView(ent, tx.nowIso));
}

/** Simulated store notification (maintainer-signed): dedupe by id, ignore older states. */
export async function applyBillingNotification(
  store: ProgressPersistence,
  notification: {
    notificationId: string;
    purchaseId: string;
    state: PurchaseState;
    occurredAt: string;
  },
  bodyHash: string,
) {
  const eventId = operationId('billing-notification', notification.notificationId);
  return store.applyInboxEvent({ eventId, type: 'billing.notification', bodyHash }, async (tx) => {
    const id = rowId('p_purchases', notification.purchaseId);
    const purchase = await tx.get('p_purchases', id);
    if (!purchase) throw new ServiceError('NOT_FOUND');
    // Terminal receipts cannot be reactivated by a late or repeated hint.
    if (['REFUNDED', 'REVOKED', 'EXPIRED'].includes(String(purchase['state']))) return;
    const vendor = JSON.parse(String(purchase['vendorStateJson'] ?? '{}')) as {
      lastOccurredAt?: string;
    };
    if (
      vendor.lastOccurredAt &&
      Date.parse(notification.occurredAt) <= Date.parse(vendor.lastOccurredAt)
    )
      return;
    if (purchase['state'] === notification.state) return;
    const next = {
      ...editable(purchase),
      state: notification.state,
      verifiedAt: notification.state === 'PENDING' ? purchase['verifiedAt'] : tx.nowIso,
      lastNotificationId: notification.notificationId,
      vendorStateJson: JSON.stringify({ ...vendor, lastOccurredAt: notification.occurredAt }),
    };
    tx.put('p_purchases', id, next);
    await applyPurchaseState(tx, next, notification.state);
  });
}

/** Owner-only receipt projection; raw simulated tokens never leave Progress. */
export async function getPurchase(tx: ProgressTx, userId: string, purchaseId: string) {
  await requireProfile(tx, userId);
  const row = await tx.get('p_purchases', rowId('p_purchases', purchaseId));
  if (!row || row['userId'] !== userId) throw new ServiceError('NOT_FOUND');
  return purchaseView(row, null, await getEntitlement(tx, userId));
}

export async function cancelSubscription(tx: ProgressTx, userId: string) {
  const entitlement = await getEntitlement(tx, userId);
  const current = await tx.get('p_entitlements', ids.entitlement(userId));
  if (!current?.['purchaseId'] || !entitlement.unlimitedEnergy) return entitlement;
  const id = rowId('p_purchases', String(current['purchaseId']));
  const purchase = await tx.get('p_purchases', id);
  if (!purchase || purchase['userId'] !== userId || purchase['platform'] !== 'SIMULATION') {
    throw new ServiceError('NOT_FOUND');
  }
  if (purchase['state'] === 'CANCELED') return entitlement;
  tx.put('p_purchases', id, {
    ...editable(purchase),
    state: 'CANCELED',
    vendorStateJson: JSON.stringify({ simulation: true, lastOccurredAt: tx.nowIso }),
  });
  return changeEntitlement(tx, userId, { status: 'CANCELED', autoRenew: false });
}

// ---------------------------------------------------------------- promo codes (P10-PROMO-001)

export interface PromoDefinition {
  code: string;
  rewardType: 'SUPER_DAYS' | 'GEMS' | 'ITEM';
  superDays?: number;
  gems?: number;
  itemId?: string;
  itemQuantity?: number;
  maxRedemptions?: number | null;
  startsAt: string;
  endsAt?: string | null;
  note?: string | null;
}

/** Maintainer-only creation (CLI/test); the plaintext code is never stored. */
export async function createPromoCode(store: ProgressPersistence, def: PromoDefinition) {
  const hash = codeHash(def.code);
  const promoId = operationId('promo', hash);
  await store.transact(async (tx) => {
    if (await tx.get('p_promo_codes', rowId('p_promo_codes', promoId))) return;
    tx.put('p_promo_codes', rowId('p_promo_codes', promoId), {
      promoId,
      codeHash: hash,
      rewardType: def.rewardType,
      superDays: def.rewardType === 'SUPER_DAYS' ? (def.superDays ?? 0) : 0,
      gems: def.rewardType === 'GEMS' ? (def.gems ?? 0) : 0,
      itemId: def.rewardType === 'ITEM' ? (def.itemId ?? null) : null,
      itemQuantity: def.rewardType === 'ITEM' ? (def.itemQuantity ?? 1) : 0,
      maxRedemptions: def.maxRedemptions ?? null,
      redeemedCount: 0,
      startsAt: def.startsAt,
      endsAt: def.endsAt ?? null,
      status: 'ACTIVE',
      note: def.note ?? null,
    });
  });
  return promoId;
}

export async function redeemPromoCode(tx: ProgressTx, userId: string, code: string, key: string) {
  const zone = await zoneOf(tx, userId);
  const hash = codeHash(code);
  const promoRowId = rowId('p_promo_codes', operationId('promo', hash));
  const promo = await tx.get('p_promo_codes', promoRowId);
  const exhausted =
    promo?.['maxRedemptions'] !== null &&
    promo?.['maxRedemptions'] !== undefined &&
    Number(promo['redeemedCount']) >= Number(promo['maxRedemptions']);
  // A user who already redeemed this code hears so even after the last slot went to them.
  if (promo && promo['codeHash'] === hash) {
    const own = rowId('p_promo_redemptions', userId, String(promo['promoId']));
    if (await tx.get('p_promo_redemptions', own)) throw new ServiceError('PROMO_ALREADY_REDEEMED');
  }
  if (
    !promo ||
    promo['codeHash'] !== hash ||
    promo['status'] !== 'ACTIVE' ||
    String(promo['startsAt']) > tx.nowIso ||
    (promo['endsAt'] && String(promo['endsAt']) <= tx.nowIso) ||
    exhausted
  ) {
    throw new ServiceError('NOT_FOUND'); // unknown, expired and exhausted look identical
  }
  const promoId = String(promo['promoId']);
  const redemptionRowId = rowId('p_promo_redemptions', userId, promoId);
  if (await tx.get('p_promo_redemptions', redemptionRowId)) {
    throw new ServiceError('PROMO_ALREADY_REDEEMED');
  }
  const rewardOperationId = operationId('promo-reward', userId, promoId);
  const rewardType = String(promo['rewardType']) as 'SUPER_DAYS' | 'GEMS' | 'ITEM';
  tx.put('p_promo_codes', promoRowId, {
    ...editable(promo),
    redeemedCount: Number(promo['redeemedCount']) + 1,
  });
  tx.put('p_promo_redemptions', redemptionRowId, {
    redemptionId: operationId('promo-redemption', userId, promoId),
    userId,
    promoId,
    rewardType,
    rewardOperationId,
    redeemedAt: tx.nowIso,
  });
  let entitlement = null;
  if (rewardType === 'SUPER_DAYS') {
    const current =
      (await tx.get('p_entitlements', ids.entitlement(userId))) ?? freeEntitlement(userId);
    const active = premiumActive(
      String(current['plan']),
      String(current['status']),
      (current['expiresAt'] as string | null) ?? null,
      tx.nowIso,
    );
    const base =
      active && current['expiresAt'] ? Date.parse(String(current['expiresAt'])) : tx.nowMs;
    entitlement = await changeEntitlement(tx, userId, {
      plan: active && current['plan'] === 'MAX' ? 'MAX' : 'SUPER',
      source: active ? current['source'] : 'PROMO',
      status: 'ACTIVE',
      expiresAt: new Date(base + Number(promo['superDays']) * DAY_MS).toISOString(),
    });
  } else if (rewardType === 'GEMS') {
    await creditGems(tx, userId, Number(promo['gems']), 'ADJUST', rewardOperationId, 'promo', zone);
  } else {
    await adjustInventory(
      tx,
      userId,
      String(promo['itemId']),
      Number(promo['itemQuantity']),
      'GRANT',
      rewardOperationId,
      0,
      'promo',
    );
  }
  void key;
  return {
    redemptionId: operationId('promo-redemption', userId, promoId),
    promoId,
    rewardType,
    superDays: rewardType === 'SUPER_DAYS' ? Number(promo['superDays']) : null,
    gems: rewardType === 'GEMS' ? Number(promo['gems']) : null,
    itemId: rewardType === 'ITEM' ? String(promo['itemId']) : null,
    itemQuantity: rewardType === 'ITEM' ? Number(promo['itemQuantity']) : null,
    entitlement,
    redeemedAt: tx.nowIso,
  };
}

// ---------------------------------------------------------------- mock ads (P10-ADS-001)

export async function recordAdEvent(
  tx: ProgressTx,
  userId: string,
  request: { adEventId: string; placement: string; kind: 'IMPRESSION' | 'REWARDED_COMPLETION' },
) {
  const zone = await zoneOf(tx, userId);
  const config = AD_PLACEMENTS[request.placement];
  if (!config) throw new ServiceError('VALIDATION_ERROR', { details: { field: 'placement' } });
  const id = rowId('p_ad_events', request.adEventId);
  const rewardsId = ids.rewards(userId);
  const existing = await tx.get('p_ad_events', id);
  const rewards = editable((await tx.get('p_rewards', rewardsId)) ?? emptyRewards(userId));
  const cap = request.kind === 'IMPRESSION' ? config.impressionCap : config.rewardCap;
  if (existing) {
    if (
      existing['userId'] !== userId ||
      existing['placement'] !== request.placement ||
      existing['kind'] !== request.kind
    ) {
      throw new ServiceError('IDEMPOTENCY_CONFLICT', { details: { field: 'adEventId' } });
    }
    return adView(existing, cap, Number(rewards['gems']), false);
  }
  const ent = (await tx.get('p_entitlements', ids.entitlement(userId))) ?? freeEntitlement(userId);
  if (
    premiumActive(
      String(ent['plan']),
      String(ent['status']),
      (ent['expiresAt'] as string | null) ?? null,
      tx.nowIso,
    )
  ) {
    throw new ServiceError('AD_NOT_ELIGIBLE');
  }
  if (request.kind === 'REWARDED_COMPLETION' && cap === 0) {
    throw new ServiceError('AD_NOT_ELIGIBLE', { details: { reason: 'PLACEMENT_HAS_NO_REWARD' } });
  }
  const learningDay = zonedDay(tx.nowIso, zone);
  const today = await tx.list('p_ad_events', {
    where: { userId, learningDay, placement: request.placement, kind: request.kind },
    limit: 50,
  });
  const dailyIndex = today.length + 1;
  if (dailyIndex > cap) throw new ServiceError('AD_DAILY_CAP', { details: { cap } });
  const rewarded = request.kind === 'REWARDED_COMPLETION';
  const rewardOperationId = rewarded ? operationId('ad-reward', userId, request.adEventId) : null;
  // Rewriting the aggregate serializes concurrent ad events (dailyIndex slot + wallet).
  tx.put('p_rewards', rewardsId, rewards);
  let gems = Number(rewards['gems']);
  if (rewarded && config.rewardGems > 0) {
    gems = await creditGems(
      tx,
      userId,
      config.rewardGems,
      'ADJUST',
      rewardOperationId as string,
      'ad',
      zone,
    );
  }
  if (rewarded && config.rewardEnergy > 0) {
    energyGrant(tx, userId, rewardOperationId as string, 'AD', config.rewardEnergy);
  }
  const row: Row = {
    adEventId: request.adEventId,
    userId,
    placement: request.placement,
    kind: request.kind,
    learningDay,
    dailyIndex,
    rewardGems: rewarded ? config.rewardGems : 0,
    rewardEnergy: rewarded ? config.rewardEnergy : 0,
    rewardOperationId,
    occurredAt: tx.nowIso,
  };
  tx.put('p_ad_events', id, row);
  return adView(row, cap, gems, rewarded && config.rewardEnergy > 0);
}

function adView(row: Readonly<Row>, cap: number, gems: number, energyGrantPending: boolean) {
  return {
    adEventId: String(row['adEventId']),
    placement: String(row['placement']) as 'REWARDED_GEMS',
    kind: String(row['kind']) as 'IMPRESSION',
    learningDay: String(row['learningDay']),
    dailyIndex: Number(row['dailyIndex']),
    remainingToday: Math.max(0, cap - Number(row['dailyIndex'])),
    rewardGems: Number(row['rewardGems']),
    rewardEnergy: Number(row['rewardEnergy']),
    gems,
    energyGrantPending,
  };
}

// ---------------------------------------------------------------- gifts, family, referrals

function giftView(row: Readonly<Row>) {
  return {
    giftId: String(row['giftId']),
    senderId: String(row['senderId']),
    recipientId: String(row['recipientId']),
    plan: String(row['plan']) as 'SUPER' | 'MAX',
    durationDays: Number(row['durationDays']),
    note: (row['note'] as string | null) ?? null,
    status: String(row['status']) as 'PENDING',
    deliveredAt: (row['deliveredAt'] as string | null) ?? null,
  };
}

export async function sendGift(
  tx: ProgressTx,
  userId: string,
  request: {
    recipientUserId: string;
    plan: 'SUPER' | 'MAX';
    durationDays: number;
    note: string | null;
    simulationOutcome: PurchaseState;
  },
  key: string,
) {
  await requireProfile(tx, userId);
  const recipient = await tx.get('p_profiles', ids.profile(request.recipientUserId));
  if (!recipient || recipient['deletedAt'] || request.recipientUserId === userId) {
    throw new ServiceError('PROFILE_UNAVAILABLE');
  }
  if (await isBlockedPair(tx, userId, request.recipientUserId))
    throw new ServiceError('USER_BLOCKED');
  if (request.simulationOutcome === 'PENDING') throw new ServiceError('PURCHASE_PENDING');
  const giftId = operationId('gift', userId, key);
  const purchaseId = operationId('gift-purchase', userId, key);
  const token = `sim:${purchaseId}`;
  const paid = request.simulationOutcome === 'ACTIVE' || request.simulationOutcome === 'GRACE';
  tx.put('p_purchases', rowId('p_purchases', purchaseId), {
    purchaseId,
    userId,
    platform: 'SIMULATION',
    productId: `gift_${request.plan.toLowerCase()}`,
    kind: 'GIFT',
    purchaseToken: token,
    purchaseTokenHash: createHash('sha256').update(token).digest('hex'),
    state: request.simulationOutcome,
    vendorStateJson: JSON.stringify({ simulation: true, lastOccurredAt: tx.nowIso }),
    verifiedAt: tx.nowIso,
    lastNotificationId: null,
  });
  const row: Row = {
    giftId,
    senderId: userId,
    recipientId: request.recipientUserId,
    plan: request.plan,
    durationDays: request.durationDays,
    note: request.note,
    status: paid ? 'DELIVERED' : 'REFUNDED',
    purchaseId,
    deliveredAt: paid ? tx.nowIso : null,
  };
  tx.put('p_gifts', rowId('p_gifts', giftId), row);
  return giftView(row);
}

export async function redeemGift(tx: ProgressTx, userId: string, giftId: string) {
  await requireProfile(tx, userId);
  const id = rowId('p_gifts', giftId);
  const gift = await tx.get('p_gifts', id);
  if (!gift || gift['recipientId'] !== userId) throw new ServiceError('NOT_FOUND');
  const ent = (await tx.get('p_entitlements', ids.entitlement(userId))) ?? freeEntitlement(userId);
  if (gift['status'] === 'REDEEMED') return entitlementView(ent, tx.nowIso);
  if (gift['status'] !== 'DELIVERED') throw new ServiceError('NOT_FOUND');
  tx.put('p_gifts', id, { ...editable(gift), status: 'REDEEMED' });
  const active = premiumActive(
    String(ent['plan']),
    String(ent['status']),
    (ent['expiresAt'] as string | null) ?? null,
    tx.nowIso,
  );
  const base = active && ent['expiresAt'] ? Date.parse(String(ent['expiresAt'])) : tx.nowMs;
  return changeEntitlement(tx, userId, {
    plan: active && ent['plan'] === 'MAX' ? 'MAX' : gift['plan'],
    source: active ? ent['source'] : 'GIFT',
    status: 'ACTIVE',
    expiresAt: new Date(base + Number(gift['durationDays']) * DAY_MS).toISOString(),
    giftId,
  });
}

/** memberIdsJson holds [userId, joinedAt] pairs (fits the 512-char column for 6 members). */
function familyMembers(row: Readonly<Row>): Array<[string, string]> {
  return JSON.parse(String(row['memberIdsJson'] ?? '[]')) as Array<[string, string]>;
}

function familyView(row: Readonly<Row>, viewerId: string, nicknames: Record<string, string>) {
  const members = familyMembers(row);
  return {
    groupId: String(row['groupId']),
    ownerUserId: String(row['ownerUserId']),
    plan: String(row['plan']) as 'SUPER' | 'MAX',
    status: String(row['status']) as 'ACTIVE' | 'ENDED',
    members: members.map(([memberId, joinedAt]) => ({
      userId: memberId,
      nickname: nicknames[memberId] ?? 'Learner',
      role: memberId === row['ownerUserId'] ? 'MANAGER' : 'MEMBER',
      joinedAt,
    })),
    inviteCode:
      viewerId === row['ownerUserId'] && row['status'] === 'ACTIVE'
        ? derivedCode('family', String(row['groupId']))
        : null,
    revision: Number(row['revision'] ?? 0),
  };
}

async function nicknamesOf(tx: ProgressTx, userIds: string[]) {
  const out: Record<string, string> = {};
  for (const id of userIds) {
    out[id] = String(
      (await tx.get('p_profiles', ids.profile(id)))?.['nickname'] ?? 'Learner',
    ).slice(0, 40);
  }
  return out;
}

export async function createFamily(
  tx: ProgressTx,
  userId: string,
  plan: 'SUPER' | 'MAX',
  key: string,
) {
  await requireProfile(tx, userId);
  const ent = (await tx.get('p_entitlements', ids.entitlement(userId))) ?? freeEntitlement(userId);
  const active = premiumActive(
    String(ent['plan']),
    String(ent['status']),
    (ent['expiresAt'] as string | null) ?? null,
    tx.nowIso,
  );
  if (!active || ent['source'] !== 'PURCHASE' || (plan === 'MAX' && ent['plan'] !== 'MAX')) {
    throw new ServiceError('ENTITLEMENT_REQUIRED');
  }
  if (ent['familyGroupId'])
    throw new ServiceError('REVISION_CONFLICT', { details: { reason: 'ALREADY_IN_FAMILY' } });
  const groupId = operationId('family', userId, key);
  const row: Row = {
    groupId,
    ownerUserId: userId,
    plan,
    memberIdsJson: JSON.stringify([[userId, tx.nowIso]]),
    inviteCodeHash: codeHash(derivedCode('family', groupId)),
    status: 'ACTIVE',
  };
  tx.put('p_family_groups', rowId('p_family_groups', groupId), row);
  await changeEntitlement(tx, userId, { familyGroupId: groupId });
  return familyView({ ...row, revision: 0 }, userId, await nicknamesOf(tx, [userId]));
}

export async function joinFamily(
  tx: ProgressTx,
  userId: string,
  groupId: string,
  inviteCode: string,
) {
  await requireProfile(tx, userId);
  const id = rowId('p_family_groups', groupId);
  const group = await tx.get('p_family_groups', id);
  if (!group || group['status'] !== 'ACTIVE' || group['inviteCodeHash'] !== codeHash(inviteCode)) {
    throw new ServiceError('NOT_FOUND');
  }
  const members = familyMembers(group);
  if (!members.some(([id]) => id === userId)) {
    if (members.length >= FAMILY_MAX_MEMBERS) {
      throw new ServiceError('REVISION_CONFLICT', { details: { reason: 'FAMILY_FULL' } });
    }
    const ent = await tx.get('p_entitlements', ids.entitlement(userId));
    if (ent?.['familyGroupId'] && ent['familyGroupId'] !== groupId) {
      throw new ServiceError('REVISION_CONFLICT', { details: { reason: 'ALREADY_IN_FAMILY' } });
    }
    members.push([userId, tx.nowIso]);
    tx.put('p_family_groups', id, { ...editable(group), memberIdsJson: JSON.stringify(members) });
    const owner = await tx.get('p_entitlements', ids.entitlement(String(group['ownerUserId'])));
    await changeEntitlement(tx, userId, {
      plan: group['plan'],
      source: 'FAMILY',
      status: 'ACTIVE',
      expiresAt: owner?.['expiresAt'] ?? null,
      autoRenew: false,
      familyGroupId: groupId,
      purchaseId: null,
    });
  }
  const updated = (await tx.get('p_family_groups', id)) as Row;
  return familyView(
    { ...updated, revision: Number(group['revision'] ?? 0) + 1 },
    userId,
    await nicknamesOf(
      tx,
      members.map(([memberId]) => memberId),
    ),
  );
}

export async function removeFamilyMember(
  tx: ProgressTx,
  userId: string,
  groupId: string,
  memberId: string,
) {
  await requireProfile(tx, userId);
  const id = rowId('p_family_groups', groupId);
  const group = await tx.get('p_family_groups', id);
  if (!group || group['status'] !== 'ACTIVE') throw new ServiceError('NOT_FOUND');
  const owner = String(group['ownerUserId']);
  if (userId !== owner && userId !== memberId) throw new ServiceError('FORBIDDEN');
  if (memberId === owner)
    throw new ServiceError('VALIDATION_ERROR', { details: { reason: 'MANAGER_CANNOT_LEAVE' } });
  const members = familyMembers(group);
  if (members.some(([id]) => id === memberId)) {
    const remaining = members.filter(([id]) => id !== memberId);
    tx.put('p_family_groups', id, { ...editable(group), memberIdsJson: JSON.stringify(remaining) });
    await changeEntitlement(tx, memberId, { ...freeEntitlement(memberId), status: 'REVOKED' });
    return familyView(
      {
        ...group,
        memberIdsJson: JSON.stringify(remaining),
        revision: Number(group['revision'] ?? 0) + 1,
      },
      userId,
      await nicknamesOf(
        tx,
        remaining.map(([id]) => id),
      ),
    );
  }
  return familyView(
    group,
    userId,
    await nicknamesOf(
      tx,
      members.map(([id]) => id),
    ),
  );
}

export async function getReferral(tx: ProgressTx, userId: string) {
  await requireProfile(tx, userId);
  const code = derivedCode('referral', userId);
  await ensureReferralIssued(tx, userId);
  const rows = await tx.list('p_referrals', { where: { inviterId: userId }, limit: 500 });
  const count = (statuses: string[]) =>
    rows.filter(({ row }) => statuses.includes(String(row['status']))).length;
  return {
    code,
    accepted: count(['ACCEPTED', 'QUALIFIED', 'REWARDED']),
    qualified: count(['QUALIFIED', 'REWARDED']),
    rewarded: count(['REWARDED']),
    asOf: tx.nowIso,
  };
}

/** Invitee accepts once; the trial reward is granted immediately (qualification = acceptance). */
export async function redeemReferral(tx: ProgressTx, userId: string, code: string) {
  await requireProfile(tx, userId);
  // Codes resolve through the inviter's ISSUED row (created by getReferral), looked up by hash.
  const hash = codeHash(code);
  const existing = await tx.list('p_referrals', { where: { inviteeId: userId }, limit: 1 });
  if (existing.length) return 'replayed' as const;
  const index = await tx.list('p_referrals', {
    where: { codeHash: hash, status: 'ISSUED' },
    limit: 1,
  });
  const issued = index[0];
  if (!issued || issued.row['inviterId'] === userId) throw new ServiceError('NOT_FOUND');
  const inviterId = String(issued.row['inviterId']);
  const rewardOperationId = operationId('referral', inviterId, userId);
  tx.put('p_referrals', rowId('p_referrals', hash, userId), {
    inviterId,
    inviteeId: userId,
    codeHash: createHash('sha256').update(`${hash}|${userId}`).digest('hex'),
    status: 'REWARDED',
    rewardOperationId,
  });
  for (const member of [inviterId, userId]) {
    const ent =
      (await tx.get('p_entitlements', ids.entitlement(member))) ?? freeEntitlement(member);
    const active = premiumActive(
      String(ent['plan']),
      String(ent['status']),
      (ent['expiresAt'] as string | null) ?? null,
      tx.nowIso,
    );
    if (active) continue; // paid/ongoing plans are never shortened or replaced
    await changeEntitlement(tx, member, {
      plan: 'SUPER',
      source: 'REFERRAL',
      status: 'ACTIVE',
      expiresAt: new Date(tx.nowMs + REFERRAL_TRIAL_DAYS * DAY_MS).toISOString(),
      autoRenew: false,
    });
  }
  return 'completed' as const;
}

/** Issue (idempotently) the inviter's ISSUED referral row so codes resolve by hash. */
export async function ensureReferralIssued(tx: ProgressTx, userId: string): Promise<void> {
  const hash = codeHash(derivedCode('referral', userId));
  const id = rowId('p_referrals', hash);
  if (await tx.get('p_referrals', id)) return;
  tx.put('p_referrals', id, {
    inviterId: userId,
    inviteeId: null,
    codeHash: hash,
    status: 'ISSUED',
    rewardOperationId: null,
  });
}
