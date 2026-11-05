import test from 'node:test';
import assert from 'node:assert/strict';
import { initUser, lessonEvent, setup, validate } from './harness.mjs';

function statsOf(h, user) {
  return h.call('GET', '/v1/me/learning-stats', { user }).then((response) => {
    assert.equal(response.status, 200, JSON.stringify(response.body));
    return validate('LearningStats', response.body);
  });
}

test('empty history returns 28 zero days ending at the server learning day', async () => {
  const h = setup();
  await initUser(h, 'alice');

  const stats = await statsOf(h, 'alice');

  assert.equal(stats.learningZone, 'UTC');
  assert.equal(stats.days.length, 28);
  assert.equal(stats.days.at(-1).day, '2026-10-12');
  assert.equal(stats.days[0].day, '2026-09-15');
  assert.ok(
    stats.days.every(
      (day) =>
        day.studyXp === 0 &&
        day.completedLessons === 0 &&
        day.reviewSessions === 0 &&
        day.originalCorrect === 0 &&
        day.active === false &&
        day.trackedOriginalCount === 0 &&
        day.trackedOriginalCorrect === 0,
    ),
  );
});

test('lesson activity fills the current day and tracked first-attempt accuracy', async () => {
  const h = setup();
  await initUser(h, 'alice');
  await h.deliver(
    lessonEvent({}, { completionId: 'stats-1', originalCount: 10, originalCorrect: 9 }),
  );

  const stats = await statsOf(h, 'alice');
  const day = stats.days.find((entry) => entry.day === '2026-10-12');

  assert.ok(day.studyXp > 0);
  assert.deepEqual(
    [day.completedLessons, day.trackedOriginalCount, day.trackedOriginalCorrect, day.active],
    [1, 10, 9, true],
  );
});

test('old activity is outside the 28-day window and other users stay empty', async () => {
  const h = setup();
  await initUser(h, 'alice');
  await initUser(h, 'bob');
  await h.deliver(
    lessonEvent({ occurredAt: '2026-09-01T03:00:00.000Z' }, { completionId: 'stats-old' }),
  );

  const alice = await statsOf(h, 'alice');
  assert.equal(alice.days.at(-1).day, '2026-10-12');
  assert.equal(alice.days[0].day, '2026-09-15');
  assert.equal(
    alice.days.some((entry) => entry.day === '2026-09-01'),
    false,
  );

  const bob = await statsOf(h, 'bob');
  assert.ok(
    bob.days.every(
      (entry) =>
        entry.active === false &&
        entry.studyXp === 0 &&
        entry.completedLessons === 0 &&
        entry.trackedOriginalCount === 0,
    ),
  );
});
