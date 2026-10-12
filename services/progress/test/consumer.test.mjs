import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import {
  createDisabledProgressPersistence,
  createMemoryProgressPersistence,
  createProgressEventConsumer,
  firstCompletionXp,
} from '../../../.cache/backend-fixtures/foundation-testkit.mjs';

const lesson = { mode: 'LESSON', source: 'ONLINE', originalCount: 10, assisted: false };
function event(overrides = {}) {
  return {
    eventId: randomUUID(),
    type: 'lesson.completed.v1',
    schemaVersion: 1,
    producer: 'learning',
    aggregateId: 'completion-1',
    occurredAt: '2026-10-12T07:00:00.000Z',
    requestId: randomUUID(),
    payload: {
      completionId: 'completion-1',
      userId: 'learner',
      courseId: 'vi_en',
      lessonVersion: 'v1',
      rewardIdentity: 'lesson-1',
      ...lesson,
      originalCorrect: 9,
      ...overrides,
    },
  };
}
const ctx = (e) => ({ bodyHash: JSON.stringify(e), requestId: 'r', sender: 'learning' });

test('domain: SRS FR-GAME-001 first-completion formula', () => {
  assert.deepEqual(firstCompletionXp({ ...lesson, originalCorrect: 10 }), {
    ok: true,
    studyXp: 25,
    perfect: true,
  });
  assert.equal(firstCompletionXp({ ...lesson, originalCorrect: 10, assisted: true }).studyXp, 20);
  assert.equal(
    firstCompletionXp({ ...lesson, originalCorrect: 10, source: 'OFFLINE' }).studyXp,
    20,
  );
  assert.equal(firstCompletionXp({ ...lesson, originalCorrect: 0 }).studyXp, 10);
  assert.equal(firstCompletionXp({ ...lesson, mode: 'PLACEMENT', originalCorrect: 7 }).studyXp, 0);
  assert.equal(firstCompletionXp({ ...lesson, originalCorrect: 11 }).ok, false);
  assert.equal(firstCompletionXp({ ...lesson, mode: 'PRACTICE', originalCorrect: 5 }).ok, false);
});

test('application: inbox + FIRST ledger row commit once; replay is harmless', async () => {
  const store = createMemoryProgressPersistence();
  const consumer = createProgressEventConsumer(store);
  const e = event();
  assert.equal(await consumer.consume(e, ctx(e)), 'accepted');
  assert.equal(await consumer.consume(e, ctx(e)), 'replayed');
  const row = await store.read('p_reward_ledger', 'learner:completion-1:FIRST');
  assert.equal(row.studyXpDelta, 19);
  assert.equal(row.kind, 'FIRST');
  // A second event for the same completion does not double-award.
  const again = event();
  assert.equal(await consumer.consume(again, ctx(again)), 'accepted');
  assert.equal(
    (await store.read('p_reward_ledger', 'learner:completion-1:FIRST')).eventId,
    e.eventId,
  );
});

test('application: failed commit leaves nothing; invalid results and unimplemented types fail closed', async () => {
  const store = createMemoryProgressPersistence();
  const consumer = createProgressEventConsumer(store);
  const e = event();
  store.failNextCommit = true;
  await assert.rejects(consumer.consume(e, ctx(e)), { code: 'DB_UNAVAILABLE' });
  assert.equal(store.inboxSize, 0);
  assert.equal(await store.read('p_reward_ledger', 'learner:completion-1:FIRST'), null);
  const bad = event({ originalCorrect: 12 });
  await assert.rejects(consumer.consume(bad, ctx(bad)), { code: 'VALIDATION_ERROR' });
  const purge = { ...event(), type: 'account.purged.v1', payload: {} };
  await assert.rejects(consumer.consume(purge, ctx(purge)), { code: 'SERVICE_NOT_CONFIGURED' });
  const hosted = createProgressEventConsumer(createDisabledProgressPersistence());
  await assert.rejects(hosted.consume(e, ctx(e)), { code: 'SERVICE_NOT_CONFIGURED' });
});
