import test from 'node:test';
import assert from 'node:assert/strict';
import { initUser, lessonEvent, rewardsOf, setup, validate } from './harness.mjs';

test('upgrade chest: server receipt, concurrent/repeated claim, wallet and ledger agree', async () => {
  const h = setup();
  await initUser(h, 'alice');
  for (let i = 0; i < 2; i++)
    await h.deliver(lessonEvent({}, { completionId: `chest${i}`, originalCorrect: 8 }));
  const before = await rewardsOf(h, 'alice');
  const body = { periodKey: '2026-10-12', upgradeChest: true };
  const claims = await Promise.all(
    Array.from({ length: 3 }, () =>
      h.call('POST', '/v1/quests/daily_lessons/claim', { user: 'alice', body }),
    ),
  );
  const first = claims[0];
  assert.equal(first.status, 200);
  validate('Rewards', first.body);
  const receipt = first.body.chest;
  assert.ok(receipt);
  assert.equal(receipt.tiers.length, 4);
  assert.equal(receipt.tiers[0], 'COMMON');
  const ranks = ['COMMON', 'RARE', 'EPIC', 'MEGA'];
  for (let i = 1; i < receipt.tiers.length; i++) {
    const delta = ranks.indexOf(receipt.tiers[i]) - ranks.indexOf(receipt.tiers[i - 1]);
    assert.ok(delta === 0 || delta === 1);
  }
  assert.equal(receipt.gems, 5 * 2 ** ranks.indexOf(receipt.tiers[3]));
  for (const claim of claims) assert.deepEqual(claim.body.chest, receipt);
  const again = await h.call('POST', '/v1/quests/daily_lessons/claim', { user: 'alice', body });
  assert.deepEqual(again.body.chest, receipt);
  assert.equal((await rewardsOf(h, 'alice')).gems, before.gems + receipt.gems);
  const ledger = h.store.dump('p_reward_ledger').filter(({ row }) => row.kind === 'QUEST');
  assert.equal(ledger.length, 1);
  assert.equal(ledger[0].row.gemsDelta, receipt.gems);
  assert.equal(ledger[0].row.eventId, receipt.receiptId);
  await initUser(h, 'bob');
  const bobBefore = await rewardsOf(h, 'bob');
  const foreignClaim = await h.call('POST', '/v1/quests/daily_lessons/claim', {
    user: 'bob',
    body,
  });
  assert.equal(foreignClaim.status, 400);
  const forgedSubject = await h.call('POST', '/v1/quests/daily_lessons/claim', {
    user: 'bob',
    body: { ...body, userId: 'alice' },
  });
  assert.equal(forgedSubject.status, 400);
  assert.deepEqual(await rewardsOf(h, 'bob'), bobBefore);
  assert.equal(h.store.dump('p_reward_ledger').filter(({ row }) => row.kind === 'QUEST').length, 1);
});

test('upgrade chest: three successful server rolls reach Mega; failed rolls keep tier', () => {
  const { kit } = setup();
  assert.deepEqual(kit.questChestReceipt(`ch1_${'00'.repeat(12)}`, 5), {
    receiptId: `ch1_${'00'.repeat(12)}`,
    tiers: ['COMMON', 'RARE', 'EPIC', 'MEGA'],
    gems: 40,
  });
  assert.deepEqual(kit.questChestReceipt(`ch1_${'ff'.repeat(12)}`, 5).tiers, [
    'COMMON',
    'COMMON',
    'COMMON',
    'COMMON',
  ]);
});

test('upgrade chest: replay keeps the historical ledger amount after catalog reward changes', async () => {
  const h = setup();
  await initUser(h, 'alice');
  for (let i = 0; i < 2; i++)
    await h.deliver(lessonEvent({}, { completionId: `historical${i}`, originalCorrect: 8 }));

  const operation = `ch1_${'00'.repeat(12)}`;
  const historicalGems = 24;
  const questId = h.kit.ids.quest('alice', 'DAY', '2026-10-12', 'daily_lessons');
  const rewardsId = h.kit.ids.rewards('alice');
  await h.store.transact(async (tx) => {
    const quest = await tx.get('p_quests', questId);
    const rewards = await tx.get('p_rewards', rewardsId);
    const { revision: _qr, createdAt: _qc, updatedAt: _qu, ...questData } = quest;
    const { revision: _rr, createdAt: _rc, updatedAt: _ru, ...rewardData } = rewards;
    tx.put('p_quests', questId, {
      ...questData,
      claimed: true,
      claimOperationId: operation,
    });
    tx.put('p_reward_ledger', h.kit.ids.ledger('alice', operation, 'QUEST'), {
      eventId: operation,
      completionId: operation,
      userId: 'alice',
      rewardIdentity: 'daily_lessons',
      kind: 'QUEST',
      studyXpDelta: 0,
      leagueXpDelta: 0,
      gemsDelta: historicalGems,
      learningDay: '2026-10-12',
      leagueWeek: '2026-W42',
      occurredAt: '2026-10-12T03:00:00.000Z',
      capped: false,
    });
    tx.put('p_rewards', rewardsId, {
      ...rewardData,
      gems: Number(rewardData.gems) + historicalGems,
    });
  });
  const walletBefore = await rewardsOf(h, 'alice');
  const ledgerBefore = h.store.dump('p_reward_ledger');

  const replay = await h.call('POST', '/v1/quests/daily_lessons/claim', {
    user: 'alice',
    body: { periodKey: '2026-10-12', upgradeChest: true },
  });

  assert.equal(replay.status, 200);
  assert.deepEqual(replay.body.chest, {
    receiptId: operation,
    tiers: ['COMMON', 'RARE', 'EPIC', 'MEGA'],
    gems: historicalGems,
  });
  assert.deepEqual(await rewardsOf(h, 'alice'), walletBefore);
  assert.deepEqual(h.store.dump('p_reward_ledger'), ledgerBefore);
});

test('upgrade chest: replay fails closed when its immutable ledger is missing or invalid', async () => {
  for (const ledgerGems of [null, 0]) {
    const h = setup();
    await initUser(h, 'alice');
    for (let i = 0; i < 2; i++)
      await h.deliver(
        lessonEvent({}, { completionId: `invalid-ledger-${ledgerGems}-${i}`, originalCorrect: 8 }),
      );
    const operation = `ch1_${'00'.repeat(12)}`;
    const questId = h.kit.ids.quest('alice', 'DAY', '2026-10-12', 'daily_lessons');
    await h.store.transact(async (tx) => {
      const quest = await tx.get('p_quests', questId);
      const { revision: _r, createdAt: _c, updatedAt: _u, ...questData } = quest;
      tx.put('p_quests', questId, {
        ...questData,
        claimed: true,
        claimOperationId: operation,
      });
      if (ledgerGems !== null) {
        tx.put('p_reward_ledger', h.kit.ids.ledger('alice', operation, 'QUEST'), {
          eventId: operation,
          completionId: operation,
          userId: 'alice',
          rewardIdentity: 'daily_lessons',
          kind: 'QUEST',
          studyXpDelta: 0,
          leagueXpDelta: 0,
          gemsDelta: ledgerGems,
          learningDay: '2026-10-12',
          leagueWeek: '2026-W42',
          occurredAt: '2026-10-12T03:00:00.000Z',
          capped: false,
        });
      }
    });
    const walletBefore = await rewardsOf(h, 'alice');
    const ledgerBefore = h.store.dump('p_reward_ledger');

    const replay = await h.call('POST', '/v1/quests/daily_lessons/claim', {
      user: 'alice',
      body: { periodKey: '2026-10-12', upgradeChest: true },
    });

    assert.equal(replay.status, 500);
    assert.equal(replay.body.error.code, 'INTERNAL_ERROR');
    assert.equal(replay.body.error.details.reason, 'CHEST_LEDGER_MISSING_OR_INVALID');
    assert.deepEqual(await rewardsOf(h, 'alice'), walletBefore);
    assert.deepEqual(h.store.dump('p_reward_ledger'), ledgerBefore);
  }
});

test('upgrade chest: incomplete claims and client-supplied outcomes cannot award gems', async () => {
  const h = setup();
  await initUser(h, 'alice');
  const before = await rewardsOf(h, 'alice');
  for (const body of [
    { periodKey: '2026-10-12', upgradeChest: true },
    { periodKey: '2026-10-12', upgradeChest: 'yes' },
    { periodKey: '2026-10-12', upgradeChest: true, gems: 999 },
    { periodKey: '2026-10-12', upgradeChest: true, tiers: ['EPIC'] },
  ]) {
    const r = await h.call('POST', '/v1/quests/daily_lessons/claim', { user: 'alice', body });
    assert.equal(r.status, 400);
  }
  assert.equal((await rewardsOf(h, 'alice')).gems, before.gems);
  assert.equal(h.store.dump('p_reward_ledger').filter(({ row }) => row.kind === 'QUEST').length, 0);
});
