// ai.practice.completed.v1 (AI -> Progress): PRACTICE credit once per event and per conversation,
// daily practice cap inside the shared study cap, streak / active-day quest effects, never a lesson.
import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { initUser, lessonEvent, rewardsOf, setup } from './harness.mjs';

const AT = '2026-10-12T03:00:00.000Z';
function practiceEvent(overrides = {}, payload = {}) {
  const userId = payload.userId ?? 'alice';
  return {
    eventId: randomUUID(),
    type: 'ai.practice.completed.v1',
    schemaVersion: 1,
    producer: 'ai',
    aggregateId: userId,
    occurredAt: AT,
    requestId: randomUUID(),
    ...overrides,
    payload: {
      completionId: payload.completionId ?? `conv-${randomUUID().slice(0, 8)}`,
      userId,
      kind: 'ROLEPLAY',
      courseId: 'vi_en',
      scenarioId: 'rp_ask_directions',
      xp: 20,
      wordsUsed: 6,
      stars: 3,
      ...payload,
    },
  };
}
const rows = (h, table, userId = 'alice') =>
  h.store.dump(table).filter(({ row }) => row.userId === userId);

test('domain: practice award, boost, 100/day practice cap and shared 1,200 study cap', () => {
  const { kit } = setup();
  const base = { dayStudyXp: 0, dayPracticeXp: 0 };
  assert.deepEqual(kit.computePracticeAward(20, base), {
    rawXp: 20,
    studyXp: 20,
    leagueXp: 20,
    capped: false,
  });
  assert.equal(kit.computePracticeAward(20, { ...base, boostMultiplier: 2 }).studyXp, 40);
  assert.deepEqual(kit.computePracticeAward(20, { ...base, dayPracticeXp: 90 }), {
    rawXp: 20,
    studyXp: 10,
    leagueXp: 10,
    capped: true,
  });
  assert.equal(kit.computePracticeAward(20, { ...base, dayPracticeXp: 100 }).studyXp, 0);
  assert.deepEqual(kit.computePracticeAward(20, { dayStudyXp: 1195, dayPracticeXp: 0 }), {
    rawXp: 20,
    studyXp: 5,
    leagueXp: 5,
    capped: true,
  });
  assert.equal(kit.computePracticeAward(0, base).capped, false);
  assert.throws(() => kit.computePracticeAward(101, base), /PRACTICE_XP_OUT_OF_RANGE/);
  assert.equal(kit.PRACTICE_DAILY_CAP, 100);
});

test('consume: practice credits once per event and per conversation; never counts as a lesson', async () => {
  const h = setup({ start: Date.parse(AT) });
  await initUser(h, 'alice');
  const e = practiceEvent({}, { completionId: 'conv1' });
  assert.equal(await h.deliver(e), 'accepted');
  assert.equal(await h.deliver(e), 'replayed');
  await assert.rejects(h.deliver({ ...e, payload: { ...e.payload, xp: 25 } }), {
    code: 'IDEMPOTENCY_CONFLICT',
  });
  // A different event for the same conversation is acknowledged but never credits twice.
  assert.equal(await h.deliver(practiceEvent({}, { completionId: 'conv1' })), 'accepted');
  const r = await rewardsOf(h, 'alice', 'completionId=conv1');
  assert.deepEqual(
    [r.studyXp, r.leagueXp, r.currentStreak, r.status, r.awardXp],
    [20, 20, 1, 'credited', 20],
  );
  const ledger = rows(h, 'p_reward_ledger').filter(({ row }) => row.kind === 'PRACTICE');
  assert.equal(ledger.length, 1);
  assert.deepEqual(
    [ledger[0].row.completionId, ledger[0].row.studyXpDelta, ledger[0].row.learningDay],
    ['conv1', 20, '2026-10-12'],
  );
  const [day] = rows(h, 'p_day_activity');
  assert.deepEqual(
    [day.row.active, day.row.studyXp, day.row.completedLessons, day.row.goalMet],
    [true, 20, 0, true],
  );
  const quests = Object.fromEntries(rows(h, 'p_quests').map(({ row }) => [row.questId, row]));
  assert.equal(quests.monthly_active_days.metricValue, 1);
  assert.equal(quests.daily_lessons, undefined, 'practice is not a lesson');
  const listed = await h.call('GET', '/v1/quests', { user: 'alice' });
  assert.equal(listed.status, 200);
  const note = h.store.dump('p_notifications').find(({ row }) => row.completionId === 'conv1');
  assert.equal(note.row.status, 'CREDITED');
  assert.equal(h.store.inboxSize, 2);
});

test('consume: daily practice cap; capped completions stay practiced with award 0', async () => {
  const h = setup({ start: Date.parse(AT) });
  await initUser(h, 'alice');
  for (let i = 0; i < 6; i++) {
    assert.equal(await h.deliver(practiceEvent({}, { completionId: `cap${i}` })), 'accepted');
  }
  const last = await rewardsOf(h, 'alice', 'completionId=cap5');
  assert.deepEqual([last.studyXp, last.status, last.awardXp], [100, 'capped', 0]);
  // A lesson the same day still earns its own XP (the practice cap is practice-only).
  assert.equal(
    await h.deliver(lessonEvent({ occurredAt: AT }, { originalCorrect: 10 })),
    'accepted',
  );
  const after = await rewardsOf(h, 'alice');
  assert.deepEqual([after.studyXp, after.currentStreak], [125, 1]);
  // Next learning day: the practice cap resets and the streak extends.
  const next = practiceEvent({ occurredAt: '2026-10-13T03:00:00.000Z' }, { completionId: 'd2' });
  h.clock.now = Date.parse('2026-10-13T03:00:00.000Z');
  assert.equal(await h.deliver(next), 'accepted');
  const d2 = await rewardsOf(h, 'alice', 'completionId=d2');
  assert.deepEqual([d2.awardXp, d2.studyXp, d2.currentStreak], [20, 145, 2]);
});

test('consume: invalid practice payloads are rejected before any write', async () => {
  const h = setup({ start: Date.parse(AT) });
  await initUser(h, 'alice');
  const bad = [
    practiceEvent({}, { xp: 101 }),
    practiceEvent({}, { stars: 4 }),
    practiceEvent({}, { kind: 'LESSON' }),
    practiceEvent({}, { wordsUsed: -1 }),
    practiceEvent({ aggregateId: 'mallory' }),
    practiceEvent({}, { extra: 1 }),
    practiceEvent({}, { scenarioId: '../x' }),
  ];
  for (const e of bad) {
    await assert.rejects(h.deliver(e), { code: 'VALIDATION_ERROR' }, JSON.stringify(e.payload));
  }
  assert.equal(rows(h, 'p_reward_ledger').filter(({ row }) => row.kind === 'PRACTICE').length, 0);
});

test('consume: practice for a deleted account is acknowledged and never credited', async () => {
  const h = setup({ start: Date.parse(AT) });
  await initUser(h, 'alice');
  const del = await h.call('POST', '/v1/me/deletion', {
    user: 'alice',
    body: { confirmation: 'DELETE' },
  });
  assert.equal(del.status, 202, JSON.stringify(del.body));
  assert.equal(await h.deliver(practiceEvent({}, { completionId: 'gone' })), 'accepted');
  assert.equal(rows(h, 'p_reward_ledger').filter(({ row }) => row.kind === 'PRACTICE').length, 0);
});
