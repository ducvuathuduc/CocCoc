import test from 'node:test';
import assert from 'node:assert/strict';
import { initUser, lessonEvent, setup, validate } from './harness.mjs';

test('domain: ranking ties and promotion/demotion rules', async () => {
  const { kit } = setup();
  const ranked = kit.rankMembers([
    { userId: 'b', eligibleXp: 10, lastXpAt: '2026-10-12T02:00:00.000Z' },
    { userId: 'a', eligibleXp: 10, lastXpAt: '2026-10-12T02:00:00.000Z' },
    { userId: 'c', eligibleXp: 10, lastXpAt: '2026-10-12T01:00:00.000Z' },
    { userId: 'd', eligibleXp: 0, lastXpAt: null },
  ]);
  assert.deepEqual(
    ranked.map((m) => m.userId),
    ['c', 'a', 'b', 'd'],
  );
  assert.equal(kit.movementFor(1, 9, 3), 'STAY');
  assert.equal(kit.movementFor(5, 10, 3), 'PROMOTE');
  assert.equal(kit.movementFor(6, 10, 3), 'DEMOTE');
  assert.equal(kit.movementFor(30, 30, 0), 'STAY');
  assert.equal(kit.movementFor(1, 30, 9), 'STAY');
});

test('league tie-breaking compares timestamp instants rather than timezone strings', () => {
  const { kit } = setup();
  const ranked = kit.rankMembers([
    { userId: 'z', eligibleXp: 10, lastXpAt: '2026-10-12T08:00:00+07:00' },
    { userId: 'a', eligibleXp: 10, lastXpAt: '2026-10-12T04:00:00Z' },
    { userId: 'b', eligibleXp: 10, lastXpAt: '2026-10-12T05:00:00.000Z' },
    { userId: 'c', eligibleXp: 10, lastXpAt: '2026-10-12T12:00:00+07:00' },
  ]);
  assert.deepEqual(
    ranked.map((member) => member.userId),
    ['z', 'a', 'b', 'c'],
  );
});

test('league: opt-in required, join idempotent, 30-member cohorts under concurrency, eligible XP only', async () => {
  const h = setup();
  await initUser(h, 'priv');
  assert.equal(
    (await h.call('POST', '/v1/league/join', { user: 'priv' })).body.error.code,
    'FORBIDDEN',
  );
  const users = Array.from({ length: 32 }, (_, i) => `u${String(i).padStart(2, '0')}`);
  for (const u of users) await initUser(h, u, { publicOptIn: true });
  const join = async (u) => {
    // A client retries REVISION_CONFLICT with the same Idempotency-Key.
    const key = crypto.randomUUID();
    for (;;) {
      const r = await h.call('POST', '/v1/league/join', { user: u, key });
      if (r.status !== 409) return r;
    }
  };
  const joins = [];
  for (const u of users.slice(0, 26)) joins.push(await join(u));
  joins.push(...(await Promise.all(users.slice(26).map(join))));
  for (const j of joins) assert.equal(j.status, 200, JSON.stringify(j.body));
  const cohorts = new Map();
  for (const { row } of h.store.dump('p_league_members'))
    cohorts.set(row.cohortId, (cohorts.get(row.cohortId) ?? 0) + 1);
  assert.deepEqual(
    [...cohorts.values()].sort((a, b) => b - a),
    [30, 2],
  );
  const again = await h.call('POST', '/v1/league/join', { user: 'u00' });
  assert.equal(again.body.cohortId, joins[0].body.cohortId);
  await h.deliver(lessonEvent({}, { userId: 'u00', completionId: 'on', originalCorrect: 10 }));
  await h.deliver(lessonEvent({}, { userId: 'u00', completionId: 'off', source: 'OFFLINE' }));
  await h.deliver(
    lessonEvent(
      {},
      { userId: 'u00', completionId: 'rv', mode: 'REVIEW', originalCount: 5, originalCorrect: 5 },
    ),
  );
  const view = await h.call('GET', '/v1/league', { user: 'u00' });
  validate('League', view.body);
  assert.deepEqual(
    [view.body.members[0].userId, view.body.members[0].eligibleXp, view.body.members[0].rank],
    ['u00', 25, 1],
  );
  assert.equal((await h.call('GET', '/v1/league', { user: 'priv' })).body.error.code, 'NOT_FOUND');
});

test('late deliveries cannot move the last XP timestamp backwards or change tie order', async () => {
  const h = setup({ start: Date.parse('2026-10-12T02:00:00.000Z') });
  for (const user of ['alice', 'bob']) {
    await initUser(h, user, { publicOptIn: true });
    assert.equal((await h.call('POST', '/v1/league/join', { user })).status, 200);
  }
  h.clock.now = Date.parse('2026-10-12T06:00:00.000Z');
  const event = (user, id, hour) =>
    lessonEvent(
      { occurredAt: `2026-10-12T0${hour}:00:00.000Z` },
      { userId: user, completionId: id },
    );
  await h.deliver(event('alice', 'alice-later', 5));
  await h.deliver(event('alice', 'alice-earlier', 3));
  await h.deliver(event('bob', 'bob-earlier', 3));
  await h.deliver(event('bob', 'bob-later', 4));
  const league = await h.call('GET', '/v1/league', { user: 'alice' });
  const members = league.body.members;
  assert.deepEqual(
    members.map((member) => member.userId),
    ['bob', 'alice'],
  );
  assert.equal(members[0].eligibleXp, members[1].eligibleXp);
  const alice = h.store.dump('p_league_members').find(({ row }) => row.userId === 'alice').row;
  assert.equal(alice.lastXpAt, '2026-10-12T05:00:00.000Z');
});

test('settlement: waits for watermark (SETTLING), then closes once with promote/demote', async () => {
  const h = setup({ start: Date.parse('2026-10-12T03:00:00.000Z') });
  const users = Array.from({ length: 12 }, (_, i) => `m${String(i).padStart(2, '0')}`);
  for (const u of users) {
    await initUser(h, u, { publicOptIn: true });
    await h.call('POST', '/v1/league/join', { user: u });
  }
  for (let i = 0; i < users.length; i++) {
    for (let k = 0; k <= i; k++)
      await h.deliver(lessonEvent({}, { userId: users[i], completionId: `${users[i]}-${k}` }));
  }
  h.clock.now = Date.parse('2026-10-19T01:00:00.000Z');
  let pending = 3;
  const watermark = {
    pendingBefore: async (cutoff) => (assert.equal(cutoff, '2026-10-19T00:00:00.000Z'), pending),
  };
  const first = await h.kit.settleLeagueWeek(h.store, watermark, '2026-10-12');
  assert.deepEqual([first.closed.length, first.settling.length], [0, 1]);
  assert.equal(h.store.dump('p_league_runs')[0].row.status, 'SETTLING');
  pending = 0;
  const second = await h.kit.settleLeagueWeek(h.store, watermark, '2026-10-12');
  assert.equal(second.closed.length, 1);
  const third = await h.kit.settleLeagueWeek(h.store, watermark, '2026-10-12');
  assert.equal(third.closed.length, 0);
  const tiers = Object.fromEntries(
    h.store.dump('p_league_profiles').map(({ row }) => [row.userId, row.tier]),
  );
  // Top 5 (most XP: m11..m07) promote from tier 0; bottom 5 stay at tier 0 (no lower tier).
  assert.deepEqual(
    ['m11', 'm10', 'm09', 'm08', 'm07'].map((u) => tiers[u]),
    [1, 1, 1, 1, 1],
  );
  assert.equal(tiers.m00, 0);
  assert.equal(
    h.store.dump('p_league_profiles').every(({ row }) => row.weeksParticipated === 1),
    true,
  );
  await assert.rejects(h.kit.settleLeagueWeek(h.store, watermark, '2026-10-19'), {
    code: 'VALIDATION_ERROR',
  });
});
