// SRS "Authored activity session modes (2026-10-28)": STORIES/ADVENTURE/RADIO/SIDE_QUEST/CLASH
// reward like LESSON, UNIT_REVIEW rewards like REVIEW without league XP, and TEST_OUT/CHECKPOINT
// credit nothing. LESSON, REVIEW, MASTERY and PLACEMENT keep their existing rewards.
import test from 'node:test';
import assert from 'node:assert/strict';
import { initUser, lessonEvent, rewardsOf, setup } from './harness.mjs';

const lesson = { mode: 'LESSON', source: 'ONLINE', originalCount: 10, assisted: false };
const ACTIVITY_MODES = ['STORIES', 'ADVENTURE', 'RADIO', 'SIDE_QUEST', 'CLASH'];
const FIRST = { firstCompletion: true, dayStudyXp: 0, dayReplayXp: 0 };
const REPLAY = { firstCompletion: false, dayStudyXp: 0, dayReplayXp: 0 };

test('domain: activity modes use the LESSON first-completion formula', async () => {
  const { kit } = setup();
  for (const mode of ACTIVITY_MODES) {
    assert.deepEqual(kit.firstCompletionXp({ ...lesson, mode, originalCorrect: 10 }), {
      ok: true,
      studyXp: 25,
      perfect: true,
    });
    assert.deepEqual(
      kit.firstCompletionXp({ ...lesson, mode, originalCorrect: 10, assisted: true }),
      {
        ok: true,
        studyXp: 20,
        perfect: false,
      },
    );
    const first = kit.computeAward({ ...lesson, mode, originalCorrect: 10 }, FIRST);
    assert.deepEqual(
      [first.kind, first.studyXp, first.leagueXp, first.perfect],
      ['FIRST', 25, 25, true],
    );
    // Offline first completion omits the perfect bonus and league eligibility, like LESSON.
    const offline = kit.computeAward(
      { ...lesson, mode, originalCorrect: 10, source: 'OFFLINE' },
      FIRST,
    );
    assert.deepEqual([offline.studyXp, offline.leagueXp], [20, 0]);
  }
});

test('domain: activity replay earns 5 XP under the 30/day cap with league XP like LESSON', async () => {
  const { kit } = setup();
  for (const mode of ACTIVITY_MODES) {
    const replay = kit.computeAward({ ...lesson, mode, originalCorrect: 10 }, REPLAY);
    assert.deepEqual([replay.kind, replay.studyXp, replay.leagueXp], ['REPLAY', 5, 5]);
    const partial = kit.computeAward(
      { ...lesson, mode, originalCorrect: 10 },
      { ...REPLAY, dayReplayXp: 28 },
    );
    assert.deepEqual([partial.studyXp, partial.capped], [2, true]);
    const capped = kit.computeAward(
      { ...lesson, mode, originalCorrect: 10 },
      { ...REPLAY, dayReplayXp: 30 },
    );
    assert.deepEqual([capped.studyXp, capped.capped, capped.leagueXp], [0, true, 0]);
  }
});

test('domain: UNIT_REVIEW is replay-only (5 XP, zero league), TEST_OUT/CHECKPOINT credit nothing', async () => {
  const { kit } = setup();
  for (const context of [REPLAY, FIRST]) {
    const unitReview = kit.computeAward(
      { ...lesson, mode: 'UNIT_REVIEW', originalCorrect: 10 },
      context,
    );
    assert.deepEqual([unitReview.kind, unitReview.studyXp, unitReview.leagueXp], ['REPLAY', 5, 0]);
  }
  for (const mode of ['TEST_OUT', 'CHECKPOINT']) {
    const award = kit.computeAward({ ...lesson, mode, originalCorrect: 10 }, FIRST);
    assert.deepEqual(
      [award.kind, award.rawXp, award.studyXp, award.replayXp, award.leagueXp],
      [null, 0, 0, 0, 0],
    );
  }
});

test('domain: LESSON, REVIEW, MASTERY and PLACEMENT rewards are unchanged', async () => {
  const { kit } = setup();
  const cases = {
    LESSON: ['FIRST', 25, 25],
    REVIEW: ['REPLAY', 5, 0],
    MASTERY: ['REPLAY', 5, 0],
    PLACEMENT: [null, 0, 0],
  };
  for (const [mode, expected] of Object.entries(cases)) {
    const award = kit.computeAward({ ...lesson, mode, originalCorrect: 10 }, FIRST);
    assert.deepEqual([award.kind, award.studyXp, award.leagueXp], expected);
  }
});

test('consume: activity first completion is FIRST once, then REPLAY 5; lesson counters stay LESSON-only', async () => {
  const h = setup();
  await initUser(h, 'alice');
  const first = lessonEvent(
    {},
    { completionId: 's1', rewardIdentity: 'story-a', mode: 'STORIES', originalCorrect: 10 },
  );
  assert.equal(await h.deliver(first), 'accepted');
  const replay = lessonEvent(
    {},
    { completionId: 's2', rewardIdentity: 'story-a', mode: 'STORIES', originalCorrect: 10 },
  );
  assert.equal(await h.deliver(replay), 'accepted');
  const r = await rewardsOf(h, 'alice');
  assert.deepEqual([r.studyXp, r.leagueXp], [30, 30]);
  const day = h.store.dump('p_day_activity')[0].row;
  assert.deepEqual([day.completedLessons, day.reviewSessions, day.replayXp], [0, 0, 5]);
  const ledger = h.store
    .dump('p_reward_ledger')
    .filter(({ row }) => row.userId === 'alice' && row.kind !== 'INITIAL')
    .map(({ row }) => [row.kind, row.studyXpDelta, row.leagueXpDelta])
    .sort();
  assert.deepEqual(ledger, [
    ['FIRST', 25, 25],
    ['REPLAY', 5, 5],
  ]);
});

test('consume: UNIT_REVIEW credits 5 study XP, no league XP and no review-session count', async () => {
  const h = setup();
  await initUser(h, 'alice');
  const e = lessonEvent({}, { completionId: 'ur1', rewardIdentity: 'unit-a', mode: 'UNIT_REVIEW' });
  assert.equal(await h.deliver(e), 'accepted');
  const r = await rewardsOf(h, 'alice');
  assert.deepEqual([r.studyXp, r.leagueXp], [5, 0]);
  const day = h.store.dump('p_day_activity')[0].row;
  assert.deepEqual([day.completedLessons, day.reviewSessions, day.replayXp], [0, 0, 5]);
  const ledger = h.store
    .dump('p_reward_ledger')
    .filter(({ row }) => row.userId === 'alice' && row.kind !== 'INITIAL');
  assert.deepEqual(
    ledger.map(({ row }) => [row.kind, row.studyXpDelta, row.leagueXpDelta]),
    [['REPLAY', 5, 0]],
  );
});

test('consume: TEST_OUT and CHECKPOINT are acknowledged but credit nothing', async () => {
  const h = setup();
  await initUser(h, 'alice');
  for (const [index, mode] of ['TEST_OUT', 'CHECKPOINT'].entries()) {
    const e = lessonEvent({}, { completionId: `gate${index}`, mode, originalCorrect: 10 });
    assert.equal(await h.deliver(e), 'accepted');
  }
  const r = await rewardsOf(h, 'alice');
  assert.deepEqual([r.studyXp, r.leagueXp, r.currentStreak], [0, 0, 0]);
  assert.equal(h.store.dump('p_day_activity').length, 0);
  const ledger = h.store
    .dump('p_reward_ledger')
    .filter(({ row }) => row.userId === 'alice' && row.kind !== 'INITIAL');
  assert.equal(ledger.length, 0);
});
