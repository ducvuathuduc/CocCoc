import test from 'node:test';
import assert from 'node:assert/strict';
import { MockCompletionStore } from '../../../.cache/backend-fixtures/mock-completion.mjs';

const command = {
  userId: 'fixture-user',
  sessionId: 'fixture-session',
  key: 'fixture-operation',
  expectedRevision: 1,
};
const readySession = {
  id: command.sessionId,
  userId: command.userId,
  revision: 1,
  attempted: 10,
  required: 10,
  originalCorrect: 8,
  assisted: false,
  completed: false,
};
test('concurrent duplicate completion commits one receipt and one outbox event', async () => {
  const store = new MockCompletionStore([readySession]);
  const [first, replay] = await Promise.all([store.complete(command), store.complete(command)]);
  assert.deepEqual(first, replay);
  assert.equal(store.pendingEvents().length, 1);
  assert.equal(store.pendingEvents()[0].payload.originalCorrect, 8);
});
test('failed atomic commit preserves session and creates no receipt or outbox', async () => {
  const store = new MockCompletionStore([readySession]);
  store.failNextCommit = true;
  await assert.rejects(store.complete(command), /TRANSACTION_FAILED/);
  assert.equal(store.pendingEvents().length, 0);
  assert.equal(store.session(command.sessionId).completed, false);
  await store.complete(command);
  assert.equal(store.pendingEvents().length, 1);
});
test('cross-user access, incomplete attempts and stale revision never emit events', async () => {
  const store = new MockCompletionStore([readySession]);
  await assert.rejects(store.complete({ ...command, userId: 'other-user' }), /FORBIDDEN/);
  await assert.rejects(store.complete({ ...command, expectedRevision: 0 }), /REVISION_CONFLICT/);
  const incomplete = new MockCompletionStore([{ ...readySession, attempted: 9 }]);
  await assert.rejects(incomplete.complete(command), /INCOMPLETE_SESSION/);
  assert.equal(store.pendingEvents().length + incomplete.pendingEvents().length, 0);
});
test('changed payload under same idempotency key conflicts', async () => {
  const store = new MockCompletionStore([readySession]);
  await store.complete(command);
  await assert.rejects(store.complete({ ...command, expectedRevision: 2 }), /IDEMPOTENCY_CONFLICT/);
});
test('retry with a different key still emits one completion for the session', async () => {
  const store = new MockCompletionStore([readySession]);
  const first = await store.complete(command);
  assert.deepEqual(await store.complete({ ...command, key: 'new-operation' }), first);
  assert.equal(store.pendingEvents().length, 1);
});
test('an operation key cannot be reused for a different session of the same user', async () => {
  const store = new MockCompletionStore([readySession, { ...readySession, id: 'second-session' }]);
  await store.complete(command);
  await assert.rejects(
    store.complete({ ...command, sessionId: 'second-session' }),
    /IDEMPOTENCY_CONFLICT/,
  );
  assert.equal(store.pendingEvents().length, 1);
});
