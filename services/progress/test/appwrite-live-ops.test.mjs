import test from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import path from 'node:path';
import { promisify } from 'node:util';
import { Client, Query, TablesDB } from 'node-appwrite';
import { setup, validate } from './harness.mjs';
import { kit, repoRoot } from './kit.mjs';

// Gated live run of the P6-GAME-003/P10 Progress operations over the Appwrite TEST project:
// maintainer CLI (promo code, classroom), shop buy, promo redeem, mock ads, mock purchase ->
// entitlement, and the outbox relay leasing/acking only this run's rows. Never in CI. Requires
// COC_LIVE_APPWRITE_PROGRESS=1, APPWRITE_PROJECT_ID and APPWRITE_API_KEY (server key; may be a
// sentinel the egress proxy replaces with NODE_USE_ENV_PROXY=1). Every synthetic row is deleted.
// Global ticks (streak rollover, purge, settlement) are NOT run live: they would touch other rows.
const run = promisify(execFile);
const enabled = process.env.COC_LIVE_APPWRITE_PROGRESS === '1';
const reason =
  'live Progress ops gated: set COC_LIVE_APPWRITE_PROGRESS=1 and APPWRITE_* (test project)';
const endpoint = process.env.APPWRITE_ENDPOINT ?? 'https://sgp.cloud.appwrite.io/v1';
const projectId = process.env.APPWRITE_PROJECT_ID ?? '';
const apiKey = process.env.APPWRITE_API_KEY ?? '';
const databaseId = 'cocenglish';
const USER_COLUMNS = ['userId', 'fromUserId', 'toUserId', 'blockerId', 'blockedId'];

async function cli(script, args) {
  const { stdout } = await run(
    process.execPath,
    [path.join(repoRoot, 'tools/admin', script), ...args],
    {
      cwd: repoRoot,
      env: process.env,
      timeout: 120000,
    },
  );
  return JSON.parse(stdout);
}

async function sweep(db, users, extra) {
  let deleted = 0;
  const del = (tableId, rowId) =>
    db.deleteRow({ databaseId, tableId, rowId }).then(
      () => deleted++,
      () => undefined,
    );
  for (const [tableId, spec] of Object.entries(kit.PROGRESS_SCHEMA)) {
    for (const column of USER_COLUMNS.filter((c) => spec.columns[c])) {
      for (;;) {
        const page = await db.listRows({
          databaseId,
          tableId,
          queries: [Query.equal(column, users), Query.limit(100)],
        });
        if (!page.rows.length) break;
        for (const row of page.rows) await del(tableId, row.$id);
      }
    }
  }
  for (;;) {
    const outbox = await db.listRows({
      databaseId,
      tableId: 'p_outbox',
      queries: [Query.equal('aggregateId', users), Query.limit(100)],
    });
    if (!outbox.rows.length) break;
    for (const row of outbox.rows) await del('p_outbox', row.$id);
  }
  for (const [tableId, rowId] of extra) {
    const exists = await db.getRow({ databaseId, tableId, rowId }).catch(() => null);
    if (exists) await del(tableId, rowId);
  }
  return deleted;
}

test(
  'live: Progress ops over Appwrite — CLI promo/classroom, shop, promo redeem, ads, mock billing, relay',
  { skip: enabled ? false : reason, timeout: 900000 },
  async (t) => {
    assert.ok(projectId && apiKey, reason);
    const db = new TablesDB(
      new Client().setEndpoint(endpoint).setProject(projectId).setKey(apiKey),
    );
    const store = kit.createAppwriteProgressPersistence({
      endpoint,
      projectId,
      apiKey,
      admitted: false,
    });
    const h = setup({ store, realClock: true });
    const suffix = randomUUID().replace(/-/g, '').slice(0, 10);
    const alice = `cpoa${suffix}`;
    const bob = `cpob${suffix}`;
    const extra = [];
    const evidence = {};
    const ok = (r, schema) => {
      assert.ok(r.status >= 200 && r.status < 300, JSON.stringify(r.body));
      return schema ? validate(schema, r.body) : r.body;
    };
    try {
      await store.ping();
      for (const u of [alice, bob]) ok(await h.call('POST', '/v1/me/initialize', { user: u }));

      // Maintainer CLI against the same project: one-use GEMS promo, then a classroom.
      const promo = await cli('promo.mjs', [
        'create',
        '--type',
        'GEMS',
        '--gems',
        '500',
        '--max',
        '1',
        '--prefix',
        'LIVE',
        '--note',
        `live-test ${suffix}`,
      ]);
      extra.push(['p_promo_codes', kit.rowId('p_promo_codes', promo.promoId)]);
      const redeemed = ok(
        await h.call('POST', '/v1/promo-codes/redeem', { user: alice, body: { code: promo.code } }),
        'PromoRedemption',
      );
      assert.deepEqual([redeemed.rewardType, redeemed.gems], ['GEMS', 500]);
      const twice = await h.call('POST', '/v1/promo-codes/redeem', {
        user: alice,
        body: { code: promo.code },
      });
      assert.equal(twice.body.error.code, 'PROMO_ALREADY_REDEEMED');
      const exhausted = await h.call('POST', '/v1/promo-codes/redeem', {
        user: bob,
        body: { code: promo.code },
      });
      assert.equal(exhausted.body.error.code, 'NOT_FOUND');
      const listed = await cli('promo.mjs', ['list', '--limit', '20']);
      const mine = listed.promos.find((p) => p.promoId === promo.promoId);
      assert.deepEqual([mine.redeemedCount, mine.maxRedemptions], [1, 1]);
      evidence.promo =
        'CLI create (hash only) -> redeem +500 gems once; repeat PROMO_ALREADY_REDEEMED; exhausted NOT_FOUND; CLI list redeemedCount 1';

      const room = await cli('classroom.mjs', [
        'create',
        '--name',
        `Live ${suffix}`,
        '--teacher',
        alice,
      ]);
      extra.push(['p_classrooms', kit.rowId('p_classrooms', room.classroomId)]);
      const joined = ok(
        await h.call('POST', '/v1/classrooms/join', {
          user: bob,
          body: { joinCode: room.joinCode },
        }),
        'ClassroomMembership',
      );
      assert.equal(joined.classroomId, room.classroomId);
      await cli('classroom.mjs', ['archive', '--id', room.classroomId]);
      const archived = await h.call('POST', '/v1/classrooms/join', {
        user: alice,
        body: { joinCode: room.joinCode },
      });
      assert.equal(archived.body.error.code, 'CLASSROOM_CODE_INVALID');
      evidence.classroom = 'CLI create -> join by code -> CLI archive -> CLASSROOM_CODE_INVALID';

      // Shop.
      const shop = ok(await h.call('GET', '/v1/shop', { user: alice }), 'Shop');
      assert.equal(shop.gems, 520);
      const key = randomUUID();
      const boost = ok(
        await h.call('POST', '/v1/shop/purchases', {
          user: alice,
          key,
          body: { itemId: 'xp_boost_15', quantity: 1, catalogVersion: shop.catalogVersion },
        }),
        'ShopPurchase',
      );
      const replay = await h.call('POST', '/v1/shop/purchases', {
        user: alice,
        key,
        body: { itemId: 'xp_boost_15', quantity: 1, catalogVersion: shop.catalogVersion },
      });
      assert.deepEqual(replay.body.gems, boost.gems);
      const refill = ok(
        await h.call('POST', '/v1/shop/purchases', {
          user: alice,
          body: { itemId: 'energy_refill', quantity: 1, catalogVersion: shop.catalogVersion },
        }),
        'ShopPurchase',
      );
      assert.deepEqual([boost.gems, refill.gems, refill.energyGrantPending], [420, 370, true]);
      evidence.shop =
        'xp_boost 100 gems once per key (replay same), energy_refill 50 gems + energy.granted.v1';

      // Mock ads (free tier), then mock purchase -> entitlement suppresses ads.
      const adId = randomUUID();
      const ad = ok(
        await h.call('POST', '/v1/ad-events', {
          user: alice,
          body: { adEventId: adId, placement: 'REWARDED_GEMS', kind: 'REWARDED_COMPLETION' },
        }),
        'AdEvent',
      );
      const adAgain = ok(
        await h.call('POST', '/v1/ad-events', {
          user: alice,
          body: { adEventId: adId, placement: 'REWARDED_GEMS', kind: 'REWARDED_COMPLETION' },
        }),
      );
      assert.deepEqual([ad.rewardGems, ad.gems, adAgain.gems], [5, 375, 375]);
      ok(
        await h.call('POST', '/v1/ad-events', {
          user: alice,
          body: {
            adEventId: randomUUID(),
            placement: 'REWARDED_ENERGY_REFILL',
            kind: 'REWARDED_COMPLETION',
          },
        }),
        'AdEvent',
      );
      const purchase = ok(
        await h.call('POST', '/v1/billing/purchases', {
          user: alice,
          body: {
            productId: 'super_monthly',
            kind: 'SUBSCRIPTION',
            platform: 'SIMULATION',
            simulationOutcome: 'ACTIVE',
          },
        }),
        'Purchase',
      );
      assert.deepEqual([purchase.state, purchase.entitlement.plan], ['ACTIVE', 'SUPER']);
      const ent = ok(await h.call('GET', '/v1/me/entitlement', { user: alice }), 'Entitlement');
      assert.deepEqual([ent.plan, ent.adFree, ent.unlimitedEnergy], ['SUPER', true, true]);
      const noAd = await h.call('POST', '/v1/ad-events', {
        user: alice,
        body: { adEventId: randomUUID(), placement: 'REWARDED_GEMS', kind: 'IMPRESSION' },
      });
      assert.equal(noAd.body.error.code, 'AD_NOT_ELIGIBLE');
      evidence.adsBilling =
        'rewarded gems +5 once per adEventId; energy ad -> energy.granted.v1; SIMULATION SUPER ACTIVE -> entitlement + entitlement.changed.v1; ads then AD_NOT_ELIGIBLE';

      // Relay over the live table, restricted to this run's rows (never other tenants' events).
      const rows = await db.listRows({
        databaseId,
        tableId: 'p_outbox',
        queries: [Query.equal('aggregateId', [alice, bob]), Query.limit(100)],
      });
      const rowIds = rows.rows.map((r) => r.$id);
      const types = rows.rows.map((r) => r.type).sort();
      assert.deepEqual(types, ['energy.granted.v1', 'energy.granted.v1', 'entitlement.changed.v1']);
      const seen = [];
      const first = await kit.relayOutbox(
        store,
        async (target, event) => {
          validate('BusinessEvent', event);
          seen.push(`${event.type}>${target}`);
          return target === 'ai' ? 'retry' : 'ack';
        },
        { rowIds, random: () => 0 },
      );
      assert.deepEqual(first, { leased: 3, acked: 2, retried: 1, dead: 0 });
      const after = await db.listRows({
        databaseId,
        tableId: 'p_outbox',
        queries: [Query.equal('aggregateId', [alice, bob]), Query.limit(100)],
      });
      const status = Object.fromEntries(after.rows.map((r) => [r.type + r.$id, r.status]));
      assert.equal(Object.values(status).filter((s) => s === 'ACK').length, 2);
      const pending = after.rows.find((r) => r.type === 'entitlement.changed.v1');
      assert.deepEqual([pending.status, pending.attempt], ['PENDING', 1]);
      evidence.relay = `live lease+settle on this run's rows: ${JSON.stringify(first)}; deliveries ${seen.sort().join(', ')}`;
      t.diagnostic(JSON.stringify(evidence));
    } finally {
      const deleted = await sweep(db, [alice, bob], extra);
      const leftover = await sweep(db, [alice, bob], extra);
      t.diagnostic(`cleanup deleted ${deleted} rows; leftover after second sweep ${leftover}`);
      assert.equal(leftover, 0);
    }
  },
);
