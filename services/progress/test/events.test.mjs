import test from 'node:test';
import assert from 'node:assert/strict';
import { MockCompletionStore } from '../../../.cache/backend-fixtures/mock-completion.mjs';
import { MockRewardStore } from '../../../.cache/backend-fixtures/mock-rewards.mjs';
async function event() {
  const source = new MockCompletionStore([
    {
      id: 'session',
      userId: 'learner',
      revision: 0,
      attempted: 10,
      required: 10,
      originalCorrect: 10,
      assisted: false,
      completed: false,
    },
  ]);
  await source.complete({
    sessionId: 'session',
    userId: 'learner',
    key: 'operation',
    expectedRevision: 0,
  });
  return source.pendingEvents()[0];
}
test('delayed and duplicated delivery awards perfect lesson once and isolates users', async () => {
  const receiver = new MockRewardStore();
  const message = await event();
  assert.equal(receiver.xp('learner'), 0);
  await Promise.all([receiver.consume(message), receiver.consume(message)]);
  assert.equal(receiver.xp('learner'), 25);
  assert.equal(receiver.xp('other'), 0);
  assert.equal(receiver.appliedEvents, 1);
});
test('failed receiver commit can retry without leaving inbox or XP', async () => {
  const receiver = new MockRewardStore();
  receiver.failNextCommit = true;
  const message = await event();
  await assert.rejects(receiver.consume(message), /TRANSACTION_FAILED/);
  assert.equal(receiver.appliedEvents, 0);
  assert.equal(receiver.xp('learner'), 0);
  await receiver.consume(message);
  assert.equal(receiver.xp('learner'), 25);
});
test('event ID substitution and unsupported producer are rejected', async () => {
  const receiver = new MockRewardStore();
  const message = await event();
  await receiver.consume(message);
  await assert.rejects(
    receiver.consume({ ...message, payload: { ...message.payload, originalCorrect: 0 } }),
    /EVENT_PAYLOAD_CONFLICT/,
  );
  await assert.rejects(receiver.consume({ ...message, producer: 'ai' }), /EVENT_NOT_ALLOWED/);
});
test('fixture refuses unimplemented reward modes instead of inventing a policy', async () => {
  const receiver = new MockRewardStore();
  const message = await event();
  await assert.rejects(
    receiver.consume({ ...message, payload: { ...message.payload, mode: 'REVIEW' } }),
    /MODE_NOT_IMPLEMENTED/,
  );
});
