import test from 'node:test';
import assert from 'node:assert/strict';
import { initUser, lessonEvent, rewardsOf, setup, validate } from './harness.mjs';

const lesson = { mode: 'LESSON', source: 'ONLINE', originalCount: 10, assisted: false };

test('domain: FR-GAME-001 first/replay/cap formula', async () => {
  const { kit } = setup();
  assert.deepEqual(kit.firstCompletionXp({ ...lesson, originalCorrect: 10 }), {
    ok: true,
    studyXp: 25,
    perfect: true,
  });
  assert.equal(
    kit.firstCompletionXp({ ...lesson, originalCorrect: 10, assisted: true }).studyXp,
    20,
  );
  assert.equal(
    kit.firstCompletionXp({ ...lesson, originalCorrect: 10, source: 'OFFLINE' }).studyXp,
    20,
  );
  assert.equal(
    kit.firstCompletionXp({ ...lesson, mode: 'PLACEMENT', originalCorrect: 7 }).studyXp,
    0,
  );
  assert.equal(kit.firstCompletionXp({ ...lesson, originalCorrect: 11 }).ok, false);
  // vi_en v2 lessons carry 10-15 originals: the 0-10 term is the first-correct share scaled to 10.
  assert.deepEqual(kit.firstCompletionXp({ ...lesson, originalCount: 13, originalCorrect: 13 }), {
    ok: true,
    studyXp: 25,
    perfect: true,
  });
  assert.deepEqual(kit.firstCompletionXp({ ...lesson, originalCount: 15, originalCorrect: 12 }), {
    ok: true,
    studyXp: 18,
    perfect: false,
  });
  assert.equal(
    kit.firstCompletionXp({ ...lesson, originalCount: 4, originalCorrect: 4 }).ok,
    false,
  );
  assert.equal(
    kit.firstCompletionXp({ ...lesson, originalCount: 21, originalCorrect: 1 }).ok,
    false,
  );
  const ctx = { firstCompletion: false, dayStudyXp: 0, dayReplayXp: 25 };
  const replay = kit.computeAward({ ...lesson, originalCorrect: 3 }, ctx);
  assert.deepEqual([replay.kind, replay.studyXp, replay.capped], ['REPLAY', 5, false]);
  const capped = kit.computeAward({ ...lesson, originalCorrect: 3 }, { ...ctx, dayReplayXp: 30 });
  assert.deepEqual([capped.studyXp, capped.capped], [0, true]);
  const review = kit.computeAward(
    { ...lesson, mode: 'REVIEW', originalCount: 12, originalCorrect: 12 },
    { ...ctx, dayReplayXp: 0 },
  );
  assert.deepEqual([review.studyXp, review.leagueXp], [5, 0]);
  const daily = kit.computeAward(
    { ...lesson, originalCorrect: 10 },
    { firstCompletion: true, dayStudyXp: 1190, dayReplayXp: 0 },
  );
  assert.deepEqual([daily.studyXp, daily.capped, daily.leagueXp], [10, true, 10]);
  const offline = kit.computeAward(
    { ...lesson, source: 'OFFLINE', originalCorrect: 10 },
    { firstCompletion: true, dayStudyXp: 0, dayReplayXp: 0 },
  );
  assert.deepEqual([offline.studyXp, offline.leagueXp], [20, 0]);
});

test('consume: inbox + ledger + totals commit once; replay, substitution and second event harmless', async () => {
  const h = setup();
  await initUser(h, 'alice');
  const e = lessonEvent({}, { completionId: 'c1', originalCorrect: 10 });
  assert.equal(await h.deliver(e), 'accepted');
  assert.equal(await h.deliver(e), 'replayed');
  await assert.rejects(h.deliver({ ...e, payload: { ...e.payload, originalCorrect: 9 } }), {
    code: 'IDEMPOTENCY_CONFLICT',
  });
  const again = lessonEvent({}, { completionId: 'c1', originalCorrect: 10 });
  assert.equal(await h.deliver(again), 'accepted');
  const r = await rewardsOf(h, 'alice', 'completionId=c1');
  assert.deepEqual(
    [r.studyXp, r.leagueXp, r.gems, r.currentStreak, r.status, r.awardXp],
    [25, 25, 20, 1, 'credited', 25],
  );
  const ledger = h.store.dump('p_reward_ledger').filter(({ row }) => row.userId === 'alice');
  assert.equal(
    ledger.reduce((s, { row }) => s + row.studyXpDelta, 0),
    r.studyXp,
  );
  assert.equal(
    ledger.reduce((s, { row }) => s + row.gemsDelta, 0),
    r.gems,
  );
  assert.equal((await rewardsOf(h, 'alice', 'completionId=unknown')).status, 'pending');
  const note = h.store.dump('p_notifications')[0];
  assert.equal(note.row.status, 'CREDITED');
  assert.deepEqual(h.store.readersOf('p_notifications', note.id), ['alice']);
});

test('consume: failed commit leaves nothing; concurrent duplicate applies once', async () => {
  const h = setup();
  const e = lessonEvent();
  h.store.failNextCommit = true;
  await assert.rejects(h.deliver(e), { code: 'DB_UNAVAILABLE' });
  assert.equal(h.store.inboxSize, 0);
  assert.equal(h.store.dump('p_reward_ledger').length, 0);
  const results = await Promise.all([h.deliver(e), h.deliver(e), h.deliver(e)]);
  assert.deepEqual(results.sort(), ['accepted', 'replayed', 'replayed']);
  assert.equal(h.store.dump('p_reward_ledger').length, 1);
});

test('consume: replay cap, REVIEW, PLACEMENT, invalid and unknown modes', async () => {
  const h = setup();
  await initUser(h, 'alice');
  await h.deliver(
    lessonEvent({}, { completionId: 'first', rewardIdentity: 'L1', originalCorrect: 5 }),
  );
  for (let i = 0; i < 8; i++) {
    await h.deliver(lessonEvent({}, { completionId: `rep${i}`, rewardIdentity: 'L1' }));
  }
  await h.deliver(
    lessonEvent({}, { completionId: 'rev', mode: 'REVIEW', originalCount: 8, originalCorrect: 8 }),
  );
  await h.deliver(lessonEvent({}, { completionId: 'pl', mode: 'PLACEMENT', originalCorrect: 9 }));
  const r = await rewardsOf(h, 'alice');
  assert.equal(r.studyXp, 15 + 30); // replay+review capped at 30/day
  assert.equal(r.leagueXp, 15 + 30 - 0); // replays of online lessons are league eligible; review is not credited (cap)
  const day = h.store.dump('p_day_activity')[0].row;
  assert.deepEqual([day.completedLessons, day.reviewSessions, day.replayXp], [9, 1, 30]);
  assert.equal(
    h.store.dump('p_reward_ledger').filter(({ row }) => row.kind === 'REPLAY' && row.capped).length,
    3,
  );
  await assert.rejects(h.deliver(lessonEvent({}, { originalCorrect: 11 })), {
    code: 'VALIDATION_ERROR',
  });
  await assert.rejects(h.deliver(lessonEvent({}, { mode: 'STORY' })), { code: 'VALIDATION_ERROR' });
});

test('zone: day selected from immutable history at event server time; midnight and late delivery', async () => {
  const h = setup();
  const init = await initUser(h, 'alice');
  const patched = await h.call('PATCH', '/v1/me', {
    user: 'alice',
    body: { learningZone: 'Asia/Ho_Chi_Minh', expectedRevision: init.revision },
  });
  assert.equal(patched.status, 200);
  validate('Profile', patched.body);
  assert.equal(patched.body.learningZone, 'UTC');
  assert.equal(patched.body.pendingZone, 'Asia/Ho_Chi_Minh');
  assert.equal(patched.body.zoneEffectiveAt, '2026-10-13T00:00:00.000Z');
  // Before effectiveAt: UTC day. 2026-10-12T20:00Z is still the 12th in UTC.
  await h.deliver(lessonEvent({ occurredAt: '2026-10-12T20:00:00.000Z' }, { completionId: 'a' }));
  // After effectiveAt: 2026-10-13T18:00Z is the 14th in Ho Chi Minh (UTC+7).
  await h.deliver(lessonEvent({ occurredAt: '2026-10-13T18:00:00.000Z' }, { completionId: 'b' }));
  const days = h.store
    .dump('p_day_activity')
    .map(({ row }) => [row.day, row.zone])
    .sort();
  assert.deepEqual(days, [
    ['2026-10-12', 'UTC'],
    ['2026-10-14', 'Asia/Ho_Chi_Minh'],
  ]);
  // Second change inside 24h is rate limited; invalid zone rejected.
  const again = await h.call('PATCH', '/v1/me', {
    user: 'alice',
    body: { learningZone: 'Europe/Paris', expectedRevision: patched.body.revision },
  });
  assert.equal(again.body.error.code, 'RATE_LIMITED');
  h.clock.now += 25 * 3600 * 1000;
  const me = (await h.call('GET', '/v1/me', { user: 'alice' })).body;
  assert.equal(me.learningZone, 'Asia/Ho_Chi_Minh');
  const badZone = await h.call('PATCH', '/v1/me', {
    user: 'alice',
    body: { learningZone: 'Mars/Base', expectedRevision: me.revision },
  });
  assert.equal(badZone.body.error.code, 'INVALID_TIMEZONE');
});

test('zone history remains correct for late events after more than 50 changes and at the effective boundary', async () => {
  const h = setup({ start: Date.parse('2026-11-01T03:00:00.000Z') });
  await initUser(h, 'alice');
  const first = Date.parse('2026-08-01T00:00:00.000Z');
  await h.store.transact(async (tx) => {
    for (let i = 0; i < 61; i++) {
      const effectiveAt = new Date(first + i * 86_400_000).toISOString();
      tx.put('p_zone_history', h.kit.ids.zone('alice', effectiveAt), {
        userId: 'alice',
        zone: i === 0 ? 'Asia/Ho_Chi_Minh' : 'UTC',
        effectiveAt,
      });
    }
  });
  for (const [completionId, occurredAt] of [
    ['before', '2026-07-31T23:59:59.999Z'],
    ['boundary', '2026-08-01T07:00:00+07:00'],
    ['late', '2026-08-01T18:00:00.000Z'],
  ]) {
    await h.deliver(lessonEvent({ occurredAt }, { completionId, userId: 'alice' }));
  }
  const actual = h.store.dump('p_day_activity').map(({ row }) => [row.day, row.zone]).sort();
  assert.deepEqual(actual, [
    ['2026-07-31', 'UTC'],
    ['2026-08-01', 'Asia/Ho_Chi_Minh'],
    ['2026-08-02', 'Asia/Ho_Chi_Minh'],
  ]);
});

test('Appwrite adapter receives a UTC indexed upper bound and preserves the exact effective millisecond', async () => {
  const h = setup();
  const calls = [];
  const rows = [
    { $id: 'epoch', userId: 'alice', zone: 'UTC', effectiveAt: '1970-01-01T00:00:00.000Z' },
    { $id: 'change', userId: 'alice', zone: 'Asia/Ho_Chi_Minh', effectiveAt: '2026-08-01T07:00:00+07:00' },
    { $id: 'other', userId: 'bob', zone: 'Europe/Paris', effectiveAt: '2026-07-30T00:00:00.000Z' },
  ];
  const tables = {
    async listRows({ tableId, queries }) {
      assert.equal(tableId, 'p_zone_history');
      const parsed = queries.map((query) => JSON.parse(query));
      calls.push(parsed);
      const owner = parsed.find((query) => query.method === 'equal' && query.attribute === 'userId').values[0];
      const upper = parsed.find((query) => query.method === 'lessThan' && query.attribute === 'effectiveAt').values[0];
      const limit = parsed.find((query) => query.method === 'limit').values[0];
      const selected = rows.filter((row) => row.userId === owner && Date.parse(row.effectiveAt) < Date.parse(upper))
        .sort((a, b) => Date.parse(b.effectiveAt) - Date.parse(a.effectiveAt)).slice(0, limit);
      return { rows: selected, total: selected.length };
    },
  };
  const store = h.kit.createAppwriteProgressPersistence({
    endpoint: 'https://appwrite.invalid/v1', projectId: 'test', apiKey: 'test-key', admitted: false, tables,
  });
  const zone = (instant) => store.transact((tx) => h.kit.zoneAt(tx, 'alice', instant));
  assert.equal(await zone('2026-07-31T23:59:59.999Z'), 'UTC');
  assert.equal(await zone('2026-08-01T07:00:00.000+07:00'), 'Asia/Ho_Chi_Minh');
  assert.equal(await zone('2026-08-01T00:00:00.000Z'), 'Asia/Ho_Chi_Minh');
  assert.equal(calls[0].find((q) => q.method === 'lessThan').values[0], '2026-08-01T00:00:00.000Z');
  assert.equal(calls[1].find((q) => q.method === 'lessThan').values[0], '2026-08-01T00:00:00.001Z');
  assert.ok(calls.every((queries) => queries.some((q) => q.method === 'orderDesc' && q.attribute === 'effectiveAt')));
});

test('streak: consecutive, gap resets with lost streak, late event fills gap without double counting', async () => {
  const h = setup({ start: Date.parse('2026-10-20T03:00:00.000Z') });
  await initUser(h, 'alice');
  const at = (day) => `${day}T03:00:00.000Z`;
  for (const day of ['2026-10-01', '2026-10-02', '2026-10-04']) {
    await h.deliver(lessonEvent({ occurredAt: at(day) }, { completionId: `d${day}` }));
  }
  let rw = h.store.dump('p_rewards')[0].row;
  assert.deepEqual(
    [rw.currentStreak, rw.streakStartDay, rw.lostStreak, rw.lostStreakDay],
    [1, '2026-10-04', 2, '2026-10-04'],
  );
  await h.deliver(lessonEvent({ occurredAt: at('2026-10-03') }, { completionId: 'late' }));
  rw = h.store.dump('p_rewards')[0].row;
  assert.deepEqual([rw.currentStreak, rw.streakStartDay, rw.bestStreak], [4, '2026-10-01', 4]);
  await h.deliver(lessonEvent({ occurredAt: at('2026-10-03') }, { completionId: 'late2' }));
  assert.equal(h.store.dump('p_rewards')[0].row.currentStreak, 4);
});

test('streak: uncapped recompute anchored by streakStartDay beyond the 365-day window', async () => {
  const { kit } = setup();
  const latest = '2027-12-31';
  const windowStart = kit.addDays(latest, -364);
  const days = new Set(Array.from({ length: 365 }, (_, i) => kit.addDays(windowStart, i)));
  days.delete(kit.addDays(latest, -10));
  assert.equal(kit.recomputeStreak(days, latest, windowStart, '2025-01-01').currentStreak, 10);
  days.add(kit.addDays(latest, -10));
  const full = kit.recomputeStreak(days, latest, windowStart, '2025-01-01');
  assert.equal(full.currentStreak, kit.daysBetween('2025-01-01', latest) + 1);
  assert.ok(full.currentStreak > 365);
});

test('freeze: buy debits 20 gems once per key, capacity and funds enforced; worker consumes once, no late refund', async () => {
  const h = setup({ start: Date.parse('2026-10-10T03:00:00.000Z') });
  await initUser(h, 'alice');
  await h.deliver(lessonEvent({ occurredAt: '2026-10-10T03:00:00.000Z' }, { completionId: 'x1' }));
  const key = '11111111-2222-4333-8444-555555555555';
  const bought = await h.call('POST', '/v1/me/freezes', { user: 'alice', key });
  assert.equal(bought.status, 200);
  validate('Rewards', bought.body);
  assert.deepEqual([bought.body.gems, bought.body.freezeSlots], [0, 1]);
  const replay = await h.call('POST', '/v1/me/freezes', { user: 'alice', key });
  assert.deepEqual(replay.body, bought.body);
  assert.equal(
    (await h.call('POST', '/v1/me/freezes', { user: 'alice' })).body.error.code,
    'INSUFFICIENT_GEMS',
  );
  const rewards = h.store.dump('p_rewards')[0];
  // Missed 2026-10-11 and 2026-10-12 with one freeze: first protected, then the streak ends.
  h.clock.now = Date.parse('2026-10-13T05:00:00.000Z');
  const result = await h.store.transact((tx) => h.kit.processMissedDays(tx, 'alice'));
  assert.deepEqual(result, { protectedDays: ['2026-10-11'], lostStreak: 2 });
  const again = await h.store.transact((tx) => h.kit.processMissedDays(tx, 'alice'));
  assert.deepEqual(again, { protectedDays: [], lostStreak: null });
  assert.equal(
    h.store.dump('p_freeze_ledger').filter(({ row }) => row.action === 'CONSUME').length,
    1,
  );
  // Late event on the protected day marks it active but never refunds the freeze.
  await h.deliver(
    lessonEvent({ occurredAt: '2026-10-11T03:00:00.000Z' }, { completionId: 'late' }),
  );
  const after = h.store.dump('p_rewards')[0].row;
  assert.equal(after.freezeSlots, 0);
  assert.ok(rewards);
  // Capacity: 2 purchasable without Streak Society.
  assert.equal(h.kit.freezeCapacity(10), 2);
  assert.equal(h.kit.freezeCapacity(400), 5);
});

test('quests: daily metrics, claim once (double click), incomplete rejected; achievements tiers once', async () => {
  const h = setup();
  await initUser(h, 'alice');
  for (let i = 0; i < 5; i++)
    await h.deliver(lessonEvent({}, { completionId: `q${i}`, originalCorrect: 8 }));
  const list = await h.call('GET', '/v1/quests', { user: 'alice' });
  validate('QuestPage', list.body);
  const lessons = list.body.items.find((q) => q.questId === 'daily_lessons');
  assert.deepEqual([lessons.metricValue, lessons.periodKey], [5, '2026-10-12']);
  const key = '21111111-2222-4333-8444-555555555555';
  const body = { periodKey: '2026-10-12' };
  const [a, b] = await Promise.all([
    h.call('POST', '/v1/quests/daily_lessons/claim', { user: 'alice', key, body }),
    h.call('POST', '/v1/quests/daily_lessons/claim', { user: 'alice', key, body }),
  ]);
  assert.deepEqual(a.body, b.body);
  validate('Rewards', a.body);
  assert.equal(a.body.gems, 25);
  const other = await h.call('POST', '/v1/quests/daily_lessons/claim', { user: 'alice', body });
  assert.equal(other.body.gems, 25);
  const review = await h.call('POST', '/v1/quests/daily_review/claim', { user: 'alice', body });
  assert.equal(review.body.error.code, 'VALIDATION_ERROR');
  const conflict = await h.call('POST', '/v1/quests/daily_correct/claim', {
    user: 'alice',
    key,
    body,
  });
  assert.equal(conflict.body.error.code, 'IDEMPOTENCY_CONFLICT');
  const ach = h.store.dump('p_achievements').map(({ row }) => `${row.achievementId}:${row.tier}`);
  assert.deepEqual(ach, ['lessons:1']);
  const me = (await h.call('GET', '/v1/me', { user: 'alice' })).body;
  assert.deepEqual(me.achievementIds, ['lessons']);
});

test('tombstoned user: events are acknowledged without rewards', async () => {
  const h = setup();
  await initUser(h, 'alice');
  const del = await h.call('POST', '/v1/me/deletion', {
    user: 'alice',
    body: { confirmation: 'DELETE' },
  });
  assert.equal(del.status, 202);
  validate('DeletionReceipt', del.body);
  assert.equal(await h.deliver(lessonEvent()), 'accepted');
  assert.equal(
    h.store.dump('p_reward_ledger').filter(({ row }) => row.kind !== 'INITIAL').length,
    0,
  );
});
