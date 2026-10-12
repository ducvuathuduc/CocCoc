// Pure rules: lesson queue/retry passes, mastery, placement boundary, frontier, review heuristic.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { loadKit } from './helpers/kit.mjs';

const kit = await loadKit('domain');
const manifest = JSON.parse(fs.readFileSync('content/vi_en/dist/v2/manifest.json', 'utf8'));
const order = ['e1', 'e2', 'e3'];
const a = (exerciseId, attemptOrdinal, correct, assisted = false) => ({
  exerciseId,
  attemptOrdinal,
  correct,
  assisted,
});

test('queue: originals in order, then up to two retry passes over still-wrong items, then done', () => {
  assert.deepEqual(kit.queueState(order, []).next, { exerciseId: 'e1', attemptOrdinal: 0 });
  const log = [a('e1', 0, true), a('e2', 0, false), a('e3', 0, false)];
  assert.deepEqual(kit.queueState(order, log), {
    next: { exerciseId: 'e2', attemptOrdinal: 1 },
    nextOriginalOrdinal: 3,
    retryPass: 1,
  });
  log.push(a('e2', 1, true), a('e3', 1, false));
  assert.deepEqual(kit.queueState(order, log).next, { exerciseId: 'e3', attemptOrdinal: 2 });
  log.push(a('e3', 2, false));
  assert.deepEqual(kit.queueState(order, log), {
    next: null,
    nextOriginalOrdinal: 3,
    retryPass: 2,
  });
  const t = kit.tally(order, log);
  assert.deepEqual(
    [t.originalCorrect, t.originalCount, t.needsReviewIds],
    [1, 3, ['e3']],
    'no endless loop; unresolved -> review',
  );
});

test('mastery needs >=80% first-correct and no hint; placement passes at 8', () => {
  const tallyOf = (correct, assisted = false) => ({
    originalCount: 10,
    originalCorrect: correct,
    assisted,
    needsReviewIds: [],
  });
  assert.equal(kit.masteryPassed(tallyOf(8)), true);
  assert.equal(kit.masteryPassed(tallyOf(7)), false);
  assert.equal(kit.masteryPassed(tallyOf(10, true)), false);
  assert.equal(kit.PLACEMENT_PASS, 8);
  assert.equal(
    kit.placementFrontier(manifest, true),
    manifest.nodes.find((n) => n.unitId === 'u2').order,
  );
  assert.equal(kit.placementFrontier(manifest, false), 0);
});

test('frontier: lessons unlock in order, completing a node advances, completed nodes replay, never regress', () => {
  const start = { frontierNodeOrder: 0, completedLessonIds: [], masteredNodeIds: [] };
  assert.equal(kit.assertLessonUnlocked(manifest, start, 'u1n1l1').nodeId, 'u1n1');
  assert.throws(() => kit.assertLessonUnlocked(manifest, start, 'u1n1l2'), { code: 'NODE_LOCKED' });
  assert.throws(
    () => kit.assertLessonUnlocked(manifest, start, 'u1n2l1'),
    (e) => e.code === 'NODE_LOCKED' && e.details.currentNodeId === 'u1n1',
  );
  const one = kit.completeLesson(manifest, start, 'u1n1l1');
  assert.equal(one.frontierNodeOrder, 0);
  assert.equal(kit.nodeState(manifest.nodes[0], one), 'current');
  const three = kit.completeLesson(manifest, kit.completeLesson(manifest, one, 'u1n1l2'), 'u1n1l3');
  assert.equal(three.frontierNodeOrder, 0, 'level 1 has 4 lessons');
  assert.throws(() => kit.assertLessonUnlocked(manifest, one, 'u1n1l3'), { code: 'NODE_LOCKED' });
  const two = kit.completeLesson(manifest, three, 'u1n1l4');
  assert.equal(two.frontierNodeOrder, 1);
  assert.equal(kit.nodeState(manifest.nodes[0], two), 'completed');
  assert.equal(kit.nodeState(manifest.nodes[1], two), 'available');
  assert.equal(kit.nodeState(manifest.nodes[5], two), 'locked');
  assert.equal(kit.assertLessonUnlocked(manifest, two, 'u1n1l1').nodeId, 'u1n1', 'replay allowed');
  assert.equal(
    kit.completeLesson(manifest, two, 'u1n1l1').frontierNodeOrder,
    1,
    'replay does not regress',
  );
  assert.throws(() => kit.assertMasteryUnlocked(manifest, two, 'u1n2l1'), { code: 'NODE_LOCKED' });
  assert.equal(kit.nodeState(manifest.nodes[0], { ...two, masteredNodeIds: ['u1n1'] }), 'mastered');
});

test('review: 1/3/7/14/30 day intervals, wrong or assisted resets, LESSON exposure does not advance', () => {
  const day = 86400000;
  const t0 = Date.parse('2026-10-12T00:00:00Z');
  let s = kit.applyEvidence(null, { correct: true, assisted: false }, t0, true);
  assert.deepEqual([s.stage, s.dueAt], [1, new Date(t0 + day).toISOString()]);
  const expected = [3, 7, 14, 30, 30];
  for (const days of expected) {
    const next = kit.applyEvidence(s, { correct: true, assisted: false }, t0, true);
    assert.equal(next.dueAt, new Date(t0 + days * day).toISOString());
    s = next;
  }
  assert.equal(s.stage, 4, 'stage capped at 4');
  const held = kit.applyEvidence(s, { correct: true, assisted: false }, t0, false);
  assert.deepEqual([held.stage, held.dueAt], [s.stage, s.dueAt], 'lesson exposure keeps schedule');
  for (const ev of [
    { correct: false, assisted: false },
    { correct: true, assisted: true },
  ]) {
    const reset = kit.applyEvidence(s, ev, t0, true);
    assert.deepEqual([reset.stage, reset.dueAt], [0, new Date(t0 + day).toISOString()]);
  }
  assert.equal(kit.masteryOf([true, true, false, true]), null, 'needs 5 attempts');
  assert.equal(kit.masteryOf([true, true, false, true, true]), 0.8);
  assert.equal(kit.masteryOf(Array(30).fill(true)), 1);
});

test('due order: dueAt, recent mistake, vocabularyId; at most two consecutive of a skill', () => {
  const items = [
    { vocabularyId: 'v3', skillId: 'A', dueAt: '2026-10-01T00:00:00.000Z', lastMistakeAt: null },
    { vocabularyId: 'v1', skillId: 'A', dueAt: '2026-10-01T00:00:00.000Z', lastMistakeAt: null },
    {
      vocabularyId: 'v2',
      skillId: 'A',
      dueAt: '2026-10-01T00:00:00.000Z',
      lastMistakeAt: '2026-10-05T00:00:00.000Z',
    },
    { vocabularyId: 'v4', skillId: 'B', dueAt: '2026-10-03T00:00:00.000Z', lastMistakeAt: null },
  ];
  assert.deepEqual(
    kit.orderDue(items, 20).map((i) => i.vocabularyId),
    ['v2', 'v1', 'v4', 'v3'],
  );
  assert.equal(kit.orderDue(items, 2).length, 2);
});
