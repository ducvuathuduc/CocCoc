import test from 'node:test';
import assert from 'node:assert/strict';
import { initUser, lessonEvent, rewardsOf, setup } from './harness.mjs';

test('100 local fault/reorder trials keep one ledger effect per committed completion', async () => {
  let seed = 0x5eeda11;
  const next = () => {
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
    return seed;
  };
  for (let trial = 0; trial < 100; trial++) {
    const h = setup();
    await initUser(h, 'alice');
    await initUser(h, 'bob');
    const baselineInbox = h.store.inboxSize;
    const baselineLedger = h.store.dump('p_reward_ledger');
    const events = Array.from({ length: 3 }, (_, index) =>
      lessonEvent(
        { occurredAt: new Date(h.clock.now - (3 - index) * 1000).toISOString() },
        { completionId: `trial-${trial}-${index}`, originalCorrect: 10 },
      ),
    );
    h.store.failNextCommit = true;
    await assert.rejects(h.deliver(events[0]), { code: 'DB_UNAVAILABLE' });
    assert.equal(
      h.store.inboxSize,
      baselineInbox,
      `trial ${trial}: failed commit left an inbox row`,
    );
    assert.deepEqual(h.store.dump('p_reward_ledger'), baselineLedger);

    const deliveries = events.flatMap((event) => [event, event, event]);
    for (let index = deliveries.length - 1; index > 0; index--) {
      const other = next() % (index + 1);
      [deliveries[index], deliveries[other]] = [deliveries[other], deliveries[index]];
    }
    const outcomes = await Promise.all(deliveries.map((event) => h.deliver(event)));
    assert.equal(outcomes.filter((outcome) => outcome === 'accepted').length, 3);
    assert.equal(outcomes.filter((outcome) => outcome === 'replayed').length, 6);
    const ledger = h.store.dump('p_reward_ledger').filter(({ row }) => row.userId === 'alice');
    assert.equal(h.store.dump('p_reward_ledger').length, baselineLedger.length + 3);
    const rewards = await rewardsOf(h, 'alice');
    assert.equal(rewards.studyXp, 75);
    assert.equal(rewards.leagueXp, 75);
    assert.equal(
      ledger.reduce((sum, { row }) => sum + row.studyXpDelta, 0),
      rewards.studyXp,
    );
    assert.equal((await rewardsOf(h, 'bob')).studyXp, 0);

    await assert.rejects(
      h.deliver({ ...events[0], payload: { ...events[0].payload, originalCorrect: 9 } }),
      { code: 'IDEMPOTENCY_CONFLICT' },
    );
    assert.equal((await rewardsOf(h, 'alice')).studyXp, 75);
  }
});
