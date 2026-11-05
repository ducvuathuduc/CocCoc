import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { initUser, lessonEvent, setup, validate } from './harness.mjs';
import { kit, repoRoot } from './kit.mjs';

const ok = (r, schema) => {
  assert.ok(r.status >= 200 && r.status < 300, JSON.stringify(r.body));
  return schema ? validate(schema, r.body) : r.body;
};
const code = (r) => r.body?.error?.code;

test('every OpenAPI progress operation is routed', () => {
  const api = JSON.parse(fs.readFileSync(path.join(repoRoot, 'docs/api/openapi.yaml'), 'utf8'));
  const h = setup();
  const routes = kit
    .progressWiring(h.store, {}, { allowSimulatedCommerce: true })
    .routes.map((r) => `${r.method} ${r.path}`);
  const missing = [];
  for (const [p, item] of Object.entries(api.paths)) {
    for (const [method, op] of Object.entries(item)) {
      if (!op?.tags?.includes('progress') || p === '/internal/events') continue;
      if (!routes.includes(`${method.toUpperCase()} ${p}`)) missing.push(`${method} ${p}`);
    }
  }
  assert.deepEqual(missing, []);
});

test('preferences CAS and feedback receipt', async () => {
  const h = setup();
  await initUser(h, 'alice');
  const p = ok(await h.call('GET', '/v1/me/preferences', { user: 'alice' }), 'Preferences');
  const up = ok(
    await h.call('PATCH', '/v1/me/preferences', {
      user: 'alice',
      body: { soundEffects: false, notificationsOff: ['streak'], expectedRevision: p.revision },
    }),
    'Preferences',
  );
  assert.deepEqual([up.soundEffects, up.notificationsOff, up.revision], [false, ['streak'], 1]);
  assert.equal(
    code(
      await h.call('PATCH', '/v1/me/preferences', {
        user: 'alice',
        body: { haptics: false, expectedRevision: 0 },
      }),
    ),
    'REVISION_CONFLICT',
  );
  ok(
    await h.call('POST', '/v1/feedback', {
      user: 'alice',
      body: { topic: 'bug', message: 'hi', appVersion: '1.0.0', platform: 'ANDROID' },
    }),
    'Receipt',
  );
  assert.equal(h.store.dump('p_feedback').length, 1);
});

test('shop: buy freeze/boost/refill, caps and funds; boost activation applies XP multiplier at completion time', async () => {
  const h = setup();
  await initUser(h, 'alice');
  const shop = ok(await h.call('GET', '/v1/shop', { user: 'alice' }), 'Shop');
  assert.equal(shop.gems, 20);
  const buy = (itemId, quantity = 1, k) =>
    h.call('POST', '/v1/shop/purchases', {
      user: 'alice',
      key: k,
      body: { itemId, quantity, catalogVersion: shop.catalogVersion },
    });
  assert.equal(
    code(
      await h.call('POST', '/v1/shop/purchases', {
        user: 'alice',
        body: { itemId: 'xp_boost_15', quantity: 1, catalogVersion: 'old' },
      }),
    ),
    'ITEM_UNAVAILABLE',
  );
  assert.equal(code(await buy('weekend_amulet')), 'ITEM_UNAVAILABLE');
  assert.equal(code(await buy('xp_boost_15')), 'INSUFFICIENT_GEMS');
  // Mock gem pack purchase (SIMULATION) funds the wallet.
  const pack = ok(
    await h.call('POST', '/v1/billing/purchases', {
      user: 'alice',
      body: {
        productId: 'gems_500',
        kind: 'GEMS',
        platform: 'SIMULATION',
        simulationOutcome: 'ACTIVE',
      },
    }),
    'Purchase',
  );
  assert.equal(pack.gems, 520);
  const k = randomUUID();
  const b1 = ok(await buy('xp_boost_15', 1, k), 'ShopPurchase');
  assert.deepEqual(ok(await buy('xp_boost_15', 1, k)), b1);
  assert.deepEqual([b1.gems, b1.inventory.quantity], [420, 1]);
  assert.equal(code(await buy('xp_boost_15', 3)), 'ITEM_UNAVAILABLE');
  const freeze = ok(await buy('streak_freeze', 2), 'ShopPurchase');
  assert.equal(freeze.freezeSlots, 2);
  assert.equal(code(await buy('streak_freeze', 1)), 'FREEZE_CAPACITY');
  const refill = ok(await buy('energy_refill'), 'ShopPurchase');
  assert.equal(refill.energyGrantPending, true);
  const outbox = h.store.dump('p_outbox').map(({ row }) => row.type);
  assert.ok(outbox.includes('energy.granted.v1'));
  const energy = JSON.parse(
    h.store.dump('p_outbox').find(({ row }) => row.type === 'energy.granted.v1').row.payloadJson,
  );
  validate('EnergyGrantedEventPayload', energy);
  const boost = ok(
    await h.call('POST', '/v1/me/boosts', { user: 'alice', body: { itemId: 'xp_boost_15' } }),
    'Boost',
  );
  assert.equal(boost.multiplier, 2);
  assert.equal(
    code(await h.call('POST', '/v1/me/boosts', { user: 'alice', body: { itemId: 'xp_boost_15' } })),
    'ITEM_UNAVAILABLE',
  );
  await h.deliver(
    lessonEvent(
      { occurredAt: new Date(h.clock.now + 60000).toISOString() },
      { completionId: 'boosted', originalCorrect: 10 },
    ),
  );
  const rw = (
    await h.call('GET', '/v1/me/rewards', { user: 'alice', query: 'completionId=boosted' })
  ).body;
  assert.equal(rw.awardXp, 50);
  const ledger = h.store.dump('p_reward_ledger').filter(({ row }) => row.userId === 'alice');
  assert.equal(
    ledger.reduce((s, { row }) => s + row.gemsDelta, 0),
    rw.gems,
  );
});

test('streak repair: inside window once, paid with gems; expired/mismatched rejected', async () => {
  const h = setup({ start: Date.parse('2026-10-05T03:00:00.000Z') });
  await initUser(h, 'alice');
  await h.call('POST', '/v1/billing/purchases', {
    user: 'alice',
    body: {
      productId: 'gems_500',
      kind: 'GEMS',
      platform: 'SIMULATION',
      simulationOutcome: 'ACTIVE',
    },
  });
  for (const d of ['2026-10-05', '2026-10-06', '2026-10-07'])
    await h.deliver(lessonEvent({ occurredAt: `${d}T03:00:00.000Z` }, { completionId: d }));
  h.clock.now = Date.parse('2026-10-10T03:00:00.000Z');
  await h.store.transact((tx) => h.kit.processMissedDays(tx, 'alice'));
  const lostDay = h.store.dump('p_rewards')[0].row.lostStreakDay;
  assert.equal(lostDay, '2026-10-08');
  assert.equal(
    code(
      await h.call('POST', '/v1/me/streak-repair', {
        user: 'alice',
        body: { lostStreakDay: '2026-10-01', payWith: 'GEMS' },
      }),
    ),
    'STREAK_REPAIR_EXPIRED',
  );
  const repaired = ok(
    await h.call('POST', '/v1/me/streak-repair', {
      user: 'alice',
      body: { lostStreakDay: lostDay, payWith: 'GEMS' },
    }),
    'Rewards',
  );
  assert.deepEqual([repaired.gems, h.store.dump('p_rewards')[0].row.currentStreak], [420, 3]);
  assert.equal(
    code(
      await h.call('POST', '/v1/me/streak-repair', {
        user: 'alice',
        body: { lostStreakDay: lostDay, payWith: 'GEMS' },
      }),
    ),
    'STREAK_REPAIR_EXPIRED',
  );
});

test('mock billing: subscription states, entitlement.changed outbox, out-of-order notification ignored', async () => {
  const h = setup();
  await initUser(h, 'alice');
  const free = ok(await h.call('GET', '/v1/me/entitlement', { user: 'alice' }), 'Entitlement');
  assert.deepEqual([free.plan, free.adFree], ['FREE', false]);
  const pending = ok(
    await h.call('POST', '/v1/billing/purchases', {
      user: 'alice',
      body: {
        productId: 'super_monthly',
        kind: 'SUBSCRIPTION',
        platform: 'SIMULATION',
        simulationOutcome: 'PENDING',
      },
    }),
    'Purchase',
  );
  assert.deepEqual([pending.state, pending.entitlement.plan], ['PENDING', 'FREE']);
  const notify = (state, at, id = randomUUID()) =>
    h.kit
      .progressWiring(h.store, {}, { allowSimulatedCommerce: true })
      .routes.find((r) => r.path === '/internal/billing/notifications')
      .handle({
        body: {
          notificationId: id,
          purchaseId: pending.purchaseId,
          platform: 'SIMULATION',
          state,
          occurredAt: at,
        },
        requestId: 'r',
        sender: 'maintainer',
      });
  const t0 = new Date(h.clock.now + 1000).toISOString();
  ok(await notify('ACTIVE', t0), 'Receipt');
  let ent = ok(await h.call('GET', '/v1/me/entitlement', { user: 'alice' }), 'Entitlement');
  assert.deepEqual(
    [ent.plan, ent.status, ent.adFree, ent.conversations],
    ['SUPER', 'ACTIVE', true, false],
  );
  const revoked = new Date(h.clock.now + 3000).toISOString();
  await notify('REVOKED', revoked);
  await notify('ACTIVE', new Date(h.clock.now + 2000).toISOString()); // older: cannot restore
  ent = (await h.call('GET', '/v1/me/entitlement', { user: 'alice' })).body;
  assert.deepEqual([ent.status, ent.adFree], ['REVOKED', false]);
  const events = h.store
    .dump('p_outbox')
    .filter(({ row }) => row.type === 'entitlement.changed.v1');
  assert.equal(events.length, 2);
  for (const e of events) validate('EntitlementEventPayload', JSON.parse(e.row.payloadJson));
  // Canceled keeps access until paid expiry.
  const max = ok(
    await h.call('POST', '/v1/billing/purchases', {
      user: 'alice',
      body: {
        productId: 'max_monthly',
        kind: 'SUBSCRIPTION',
        platform: 'SIMULATION',
        simulationOutcome: 'CANCELED',
      },
    }),
    'Purchase',
  );
  assert.equal(max.entitlement.status, 'CANCELED');
});

test('promo codes: hash lookup, once per user, same NOT_FOUND for unknown/expired/exhausted, concurrent last slot', async () => {
  const h = setup();
  for (const u of ['alice', 'bob', 'carol']) await initUser(h, u);
  await kit.createPromoCode(h.store, {
    code: 'GEMS-100',
    rewardType: 'GEMS',
    gems: 100,
    maxRedemptions: 2,
    startsAt: '2026-01-01T00:00:00.000Z',
  });
  await kit.createPromoCode(h.store, {
    code: 'SUPER7',
    rewardType: 'SUPER_DAYS',
    superDays: 7,
    startsAt: '2026-01-01T00:00:00.000Z',
  });
  await kit.createPromoCode(h.store, {
    code: 'OLDCODE',
    rewardType: 'GEMS',
    gems: 5,
    startsAt: '2025-01-01T00:00:00.000Z',
    endsAt: '2025-02-01T00:00:00.000Z',
  });
  assert.equal(JSON.stringify(h.store.dump('p_promo_codes')).includes('GEMS-100'), false);
  const redeem = (user, c, key) =>
    h.call('POST', '/v1/promo-codes/redeem', { user, key, body: { code: c } });
  const k = randomUUID();
  const a = ok(await redeem('alice', 'gems 100', k), 'PromoRedemption');
  assert.deepEqual(ok(await redeem('alice', 'gems 100', k)), a);
  assert.equal(code(await redeem('alice', 'GEMS-100')), 'PROMO_ALREADY_REDEEMED');
  const [b, c] = await Promise.all([redeem('bob', 'GEMS-100'), redeem('carol', 'GEMS-100')]);
  assert.deepEqual([b.status, c.status].sort(), [200, 404]);
  assert.equal(code(await redeem('carol', 'NOPE1234')), 'NOT_FOUND');
  assert.equal(code(await redeem('carol', 'OLDCODE')), 'NOT_FOUND');
  const sup = ok(await redeem('carol', 'super7'), 'PromoRedemption');
  assert.deepEqual([sup.entitlement.plan, sup.entitlement.source], ['SUPER', 'PROMO']);
  assert.equal((await h.call('GET', '/v1/me/rewards', { user: 'alice' })).body.gems, 120);
});

test('mock ads: free tier only, adEventId replay, daily cap, reward once', async () => {
  const h = setup();
  await initUser(h, 'alice');
  const ad = (kind, placement = 'REWARDED_GEMS', adEventId = randomUUID()) =>
    h.call('POST', '/v1/ad-events', { user: 'alice', body: { adEventId, placement, kind } });
  const id = randomUUID();
  const first = ok(await ad('REWARDED_COMPLETION', 'REWARDED_GEMS', id), 'AdEvent');
  assert.deepEqual(
    [first.dailyIndex, first.rewardGems, first.gems, first.remainingToday],
    [1, 5, 25, 4],
  );
  const again = ok(await ad('REWARDED_COMPLETION', 'REWARDED_GEMS', id));
  assert.equal(again.gems, 25);
  for (let i = 0; i < 4; i++) ok(await ad('REWARDED_COMPLETION'));
  assert.equal(code(await ad('REWARDED_COMPLETION')), 'AD_DAILY_CAP');
  ok(await ad('IMPRESSION', 'LESSON_END_INTERSTITIAL'), 'AdEvent');
  const energy = ok(await ad('REWARDED_COMPLETION', 'REWARDED_ENERGY_REFILL'), 'AdEvent');
  assert.equal(energy.energyGrantPending, true);
  await h.call('POST', '/v1/billing/purchases', {
    user: 'alice',
    body: {
      productId: 'super_monthly',
      kind: 'SUBSCRIPTION',
      platform: 'SIMULATION',
      simulationOutcome: 'ACTIVE',
    },
  });
  assert.equal(code(await ad('IMPRESSION', 'LESSON_END_INTERSTITIAL')), 'AD_NOT_ELIGIBLE');
});

test('family, gifts and referrals: entitlement projection, max 6, once', async () => {
  const h = setup();
  const users = ['own', 'm1', 'm2', 'm3', 'm4', 'm5', 'm6', 'giftee', 'inv', 'new'];
  for (const u of users) await initUser(h, u);
  assert.equal(
    code(await h.call('POST', '/v1/family', { user: 'own', body: { plan: 'SUPER' } })),
    'ENTITLEMENT_REQUIRED',
  );
  await h.call('POST', '/v1/billing/purchases', {
    user: 'own',
    body: {
      productId: 'super_annual',
      kind: 'SUBSCRIPTION',
      platform: 'SIMULATION',
      simulationOutcome: 'ACTIVE',
    },
  });
  const fam = ok(
    await h.call('POST', '/v1/family', { user: 'own', body: { plan: 'SUPER' } }),
    'FamilyGroup',
  );
  for (const m of ['m1', 'm2', 'm3', 'm4', 'm5']) {
    ok(
      await h.call('POST', `/v1/family/${fam.groupId}/members`, {
        user: m,
        body: { inviteCode: fam.inviteCode },
      }),
      'FamilyGroup',
    );
  }
  assert.equal(
    code(
      await h.call('POST', `/v1/family/${fam.groupId}/members`, {
        user: 'm6',
        body: { inviteCode: fam.inviteCode },
      }),
    ),
    'REVISION_CONFLICT',
  );
  assert.equal(
    code(
      await h.call('POST', `/v1/family/${fam.groupId}/members`, {
        user: 'm6',
        body: { inviteCode: 'WRONG123' },
      }),
    ),
    'NOT_FOUND',
  );
  assert.equal((await h.call('GET', '/v1/me/entitlement', { user: 'm1' })).body.plan, 'SUPER');
  ok(
    await h.call('DELETE', `/v1/family/${fam.groupId}/members/m1`, { user: 'own' }),
    'FamilyGroup',
  );
  assert.equal((await h.call('GET', '/v1/me/entitlement', { user: 'm1' })).body.plan, 'FREE');
  assert.equal(
    code(
      await h.call('POST', '/v1/gifts', {
        user: 'own',
        body: {
          recipientUserId: 'giftee',
          plan: 'MAX',
          durationDays: 30,
          note: null,
          simulationOutcome: 'PENDING',
        },
      }),
    ),
    'PURCHASE_PENDING',
  );
  const gift = ok(
    await h.call('POST', '/v1/gifts', {
      user: 'own',
      body: {
        recipientUserId: 'giftee',
        plan: 'MAX',
        durationDays: 30,
        note: 'enjoy',
        simulationOutcome: 'ACTIVE',
      },
    }),
    'Gift',
  );
  assert.equal(
    code(await h.call('POST', `/v1/gifts/${gift.giftId}/redeem`, { user: 'm2' })),
    'NOT_FOUND',
  );
  const ent = ok(
    await h.call('POST', `/v1/gifts/${gift.giftId}/redeem`, { user: 'giftee' }),
    'Entitlement',
  );
  assert.deepEqual([ent.plan, ent.conversations], ['MAX', true]);
  const ref = ok(await h.call('GET', '/v1/me/referral', { user: 'inv' }), 'Referral');
  ok(
    await h.call('POST', '/v1/referrals/redeem', { user: 'new', body: { code: ref.code } }),
    'Receipt',
  );
  assert.equal(
    code(await h.call('POST', '/v1/referrals/redeem', { user: 'inv', body: { code: ref.code } })),
    'NOT_FOUND',
  );
  assert.equal(
    (await h.call('GET', '/v1/me/entitlement', { user: 'new' })).body.source,
    'REFERRAL',
  );
  const after = ok(await h.call('GET', '/v1/me/referral', { user: 'inv' }), 'Referral');
  assert.deepEqual([after.accepted, after.rewarded], [1, 1]);
});

test('social extensions: block/unblock, reports, friend streak invite/accept/extend, interactions once per day', async () => {
  const h = setup();
  for (const u of ['alice', 'bob']) await initUser(h, u, { publicOptIn: true });
  await h.call('POST', '/v1/follows', { user: 'alice', body: { targetUserId: 'bob' } });
  await h.call('POST', '/v1/follows', { user: 'bob', body: { targetUserId: 'alice' } });
  const inv = ok(
    await h.call('POST', '/v1/friend-streaks', { user: 'alice', body: { targetUserId: 'bob' } }),
    'FriendStreak',
  );
  assert.equal(inv.status, 'PENDING');
  assert.equal(
    code(
      await h.call('POST', `/v1/friend-streaks/${inv.pairId}/respond`, {
        user: 'alice',
        body: { accept: true },
      }),
    ),
    'REVISION_CONFLICT',
  );
  const acc = ok(
    await h.call('POST', `/v1/friend-streaks/${inv.pairId}/respond`, {
      user: 'bob',
      body: { accept: true },
    }),
    'FriendStreak',
  );
  assert.equal(acc.status, 'ACTIVE');
  await h.deliver(lessonEvent({}, { userId: 'alice', completionId: 'fa' }));
  await h.deliver(lessonEvent({}, { userId: 'bob', completionId: 'fb' }));
  const list = ok(await h.call('GET', '/v1/friend-streaks', { user: 'alice' }), 'FriendStreakPage');
  assert.deepEqual([list.items[0].length, list.items[0].extendedToday], [1, true]);
  const nudge = {
    targetUserId: 'bob',
    kind: 'NUDGE',
    contextId: 'streak',
    messageKey: 'nudge.keep_going',
  };
  const n1 = ok(
    await h.call('POST', '/v1/interactions', { user: 'alice', body: nudge }),
    'Interaction',
  );
  const n2 = ok(
    await h.call('POST', '/v1/interactions', { user: 'alice', body: nudge }),
    'Interaction',
  );
  assert.equal(n1.operationId, n2.operationId);
  assert.equal(
    code(
      await h.call('POST', '/v1/interactions', {
        user: 'alice',
        body: { ...nudge, messageKey: 'free text' },
      }),
    ),
    'VALIDATION_ERROR',
  );
  const gift = {
    targetUserId: 'bob',
    kind: 'GIFT_BOOST',
    contextId: 'gift',
    messageKey: 'gift_boost.enjoy',
  };
  assert.equal(
    code(await h.call('POST', '/v1/interactions', { user: 'alice', body: gift })),
    'INSUFFICIENT_GEMS',
  );
  await h.call('POST', '/v1/billing/purchases', {
    user: 'alice',
    body: {
      productId: 'gems_500',
      kind: 'GEMS',
      platform: 'SIMULATION',
      simulationOutcome: 'ACTIVE',
    },
  });
  const gb = ok(
    await h.call('POST', '/v1/interactions', { user: 'alice', body: gift }),
    'Interaction',
  );
  assert.deepEqual([gb.gemsCost, gb.gems], [50, 470]);
  assert.equal(h.store.dump('p_boosts').filter(({ row }) => row.userId === 'bob').length, 1);
  ok(
    await h.call('POST', '/v1/user-reports', {
      user: 'alice',
      body: { targetUserId: 'bob', reason: 'SPAM', note: null },
    }),
    'Receipt',
  );
  ok(
    await h.call('POST', '/v1/blocks', { user: 'alice', body: { targetUserId: 'bob' } }),
    'Receipt',
  );
  assert.equal(
    h.store.dump('p_follows').every(({ row }) => row.status === 'REMOVED'),
    true,
  );
  assert.equal(h.store.dump('p_friend_streaks')[0].row.status, 'ENDED');
  assert.equal(
    code(await h.call('POST', '/v1/follows', { user: 'bob', body: { targetUserId: 'alice' } })),
    'USER_BLOCKED',
  );
  assert.equal(
    code(
      await h.call('POST', '/v1/interactions', {
        user: 'bob',
        body: { ...nudge, targetUserId: 'alice' },
      }),
    ),
    'USER_BLOCKED',
  );
  ok(await h.call('DELETE', '/v1/blocks/bob', { user: 'alice' }), 'Receipt');
  assert.equal(h.store.dump('p_blocks').length, 0);
});

test('classrooms, year review and league result screen', async () => {
  const h = setup();
  await initUser(h, 'alice', { publicOptIn: true });
  await h.store.transact(async (tx) => {
    tx.put('p_classrooms', 'room1', {
      classroomId: 'room1',
      teacherUserId: 't',
      name: 'A1 class',
      courseId: 'vi_en',
      joinCodeHash: kit.classroomCodeHash('JOIN-1234'),
      status: 'ACTIVE',
    });
  });
  assert.equal(
    code(
      await h.call('POST', '/v1/classrooms/join', {
        user: 'alice',
        body: { joinCode: 'BAD12345' },
      }),
    ),
    'CLASSROOM_CODE_INVALID',
  );
  ok(
    await h.call('POST', '/v1/classrooms/join', { user: 'alice', body: { joinCode: 'join1234' } }),
    'ClassroomMembership',
  );
  ok(await h.call('DELETE', '/v1/classrooms/room1/membership', { user: 'alice' }), 'Receipt');
  await h.deliver(lessonEvent({}, { completionId: 'y1' }));
  const yr = ok(await h.call('GET', '/v1/me/year-review/2026', { user: 'alice' }), 'YearReview');
  assert.deepEqual([yr.totalXp, yr.activeDays, yr.lessonsCompleted], [19, 1, 1]);
  assert.equal(
    code(await h.call('GET', '/v1/me/year-review/2030', { user: 'alice' })),
    'NOT_FOUND',
  );
  const none = ok(await h.call('GET', '/v1/league/result', { user: 'alice' }), 'LeagueResult');
  assert.equal(none.lastResult, null);
  await h.call('POST', '/v1/league/join', { user: 'alice' });
  h.clock.now = Date.parse('2026-10-19T02:00:00.000Z');
  await kit.settleLeagueWeek(h.store, { pendingBefore: async () => 0 }, '2026-10-12');
  const res = ok(await h.call('GET', '/v1/league/result', { user: 'alice' }), 'LeagueResult');
  assert.deepEqual([res.unseen, res.lastResult.outcome, res.lastResult.rank], [true, 'STAYED', 1]);
  ok(
    await h.call('POST', '/v1/league/result/seen', {
      user: 'alice',
      body: { weekId: '2026-10-12' },
    }),
    'Receipt',
  );
  assert.equal((await h.call('GET', '/v1/league/result', { user: 'alice' })).body.unseen, false);
});

test('promo codes: the user who took the last slot still gets PROMO_ALREADY_REDEEMED', async () => {
  const h = setup();
  await initUser(h, 'solo');
  await initUser(h, 'late');
  await kit.createPromoCode(h.store, {
    code: 'LAST-ONE',
    rewardType: 'GEMS',
    gems: 10,
    maxRedemptions: 1,
    startsAt: '2026-01-01T00:00:00.000Z',
  });
  const redeem = (user) =>
    h.call('POST', '/v1/promo-codes/redeem', { user, body: { code: 'last-one' } });
  assert.equal((await redeem('solo')).status, 200);
  assert.equal(code(await redeem('solo')), 'PROMO_ALREADY_REDEEMED');
  assert.equal(code(await redeem('late')), 'NOT_FOUND');
});
