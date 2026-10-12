// P5-LESSON-003: outbox -> signed lesson.completed.v1 -> receiver inbox, with lost acks, receiver
// failure, lease expiry, dead letters and the signed watermark endpoint.
import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { loadKit } from './helpers/kit.mjs';
import { correctAnswer } from './helpers/answers.mjs';

const kit = await loadKit('outbox');

/** A Progress-shaped receiver: real shared router + HMAC + inbox dedupe over a memory owner store. */
function receiver() {
  const store = kit.createMemoryOwnerStore('progress', ['p_inbox', 'p_reward_ledger']);
  const keyring = kit.createKeyring([kit.devKey('learning')]);
  const state = { failNext: 0, dropAckNext: 0, applied: 0 };
  const router = kit.createRouter({
    service: 'progress',
    persistence: store,
    mode: 'local-test',
    keyring,
    eventConsumer: {
      async consume(event, context) {
        if (state.failNext > 0) {
          state.failNext--;
          throw new Error('receiver down');
        }
        return store.applyInboxEvent(
          { eventId: event.eventId, type: event.type, bodyHash: context.bodyHash },
          async (tx) => {
            state.applied++;
            tx.put('p_reward_ledger', `${event.payload.completionId}:FIRST`, {
              eventId: event.eventId,
            });
          },
        );
      },
    },
  });
  const fetchImpl = async (url, init) => {
    const u = new URL(url);
    let out;
    await router({
      req: {
        method: init.method,
        path: u.pathname,
        headers: init.headers,
        bodyText: init.body,
        queryString: '',
      },
      res: { json: (body, status = 200) => (out = { body, status }) },
    });
    if (state.dropAckNext > 0) {
      state.dropAckNext--;
      throw new Error('ack lost on the wire');
    }
    return new Response(JSON.stringify(out.body), { status: out.status });
  };
  return {
    store,
    state,
    deliver: kit.httpDeliver({
      key: kit.devKey('learning'),
      progressBaseUrl: 'http://progress.invalid',
      fetchImpl,
    }),
  };
}

async function completedLesson(a, user) {
  const post = (path, body) => a.call('POST', path, { user, body, key: randomUUID() });
  await post('/v1/enrollments', { courseId: 'vi_en', startPoint: 'beginner' });
  const s = (
    await post('/v1/sessions', {
      courseId: 'vi_en',
      lessonId: 'u1n1l1',
      mode: 'LESSON',
      expectedEnrollmentRevision: 0,
    })
  ).body;
  let revision = 0;
  for (const ex of s.bundle.exercises) {
    revision = (
      await post(`/v1/sessions/${s.sessionId}/answers`, {
        exerciseId: ex.id,
        attemptOrdinal: 0,
        answer: correctAnswer(ex),
        assisted: false,
        substituted: false,
        expectedRevision: revision,
      })
    ).body.sessionRevision;
  }
  return (await post(`/v1/sessions/${s.sessionId}/complete`, { expectedRevision: revision })).body;
}

test('immediate relay: completion commits, signed event is accepted once, outbox row ACKed', async () => {
  const r = receiver();
  const a = await kit.createTestApp({ deliver: r.deliver });
  const completion = await completedLesson(a, 'rita');
  assert.equal(completion.rewardStatus, 'pending');
  const [row] = a.persistence.dump('l_outbox');
  assert.equal(row.row.status, 'ACK');
  assert.equal(r.state.applied, 1);
  assert.equal(r.store.inboxSize, 1);
});

test('receiver failure then lost ack: redelivery is harmless, one effect; ACK after success', async () => {
  let now = Date.parse('2026-10-12T08:00:00Z');
  const r = receiver();
  const a = await kit.createTestApp({ nowMs: () => now });
  await completedLesson(a, 'lia');
  r.state.failNext = 1;
  let report = await kit.dispatchOutbox(a.deps, r.deliver, { random: () => 0 });
  assert.deepEqual(report, { leased: 1, acked: 0, retried: 1, dead: 0 });
  let [row] = a.persistence.dump('l_outbox');
  assert.deepEqual([row.row.status, row.row.attempt], ['PENDING', 1]);
  assert.deepEqual(
    await kit.dispatchOutbox(a.deps, r.deliver),
    { leased: 0, acked: 0, retried: 0, dead: 0 },
    'backoff respected',
  );
  now += 60_000;
  r.state.dropAckNext = 1;
  report = await kit.dispatchOutbox(a.deps, r.deliver, { random: () => 0 });
  assert.equal(report.retried, 1, 'receiver committed but ack was lost');
  assert.equal(r.state.applied, 1);
  now += 60_000;
  report = await kit.dispatchOutbox(a.deps, r.deliver);
  assert.equal(report.acked, 1);
  [row] = a.persistence.dump('l_outbox');
  assert.equal(row.row.status, 'ACK');
  assert.equal(r.state.applied, 1, 'exactly one effect at the receiver');
});

test('lease: an expired lease is re-leased by another worker; the stale worker cannot settle it', async () => {
  let now = Date.parse('2026-10-12T08:00:00Z');
  const r = receiver();
  const a = await kit.createTestApp({ nowMs: () => now });
  await completedLesson(a, 'kim');
  // Worker A leases, then stalls past the lease before delivering.
  let releaseA;
  const stalled = new Promise((resolve) => (releaseA = resolve));
  const slowDeliver = async (event) => {
    await stalled;
    return r.deliver(event);
  };
  const workerA = kit.dispatchOutbox(a.deps, slowDeliver, { owner: 'worker-a' });
  await new Promise((resolve) => setTimeout(resolve, 20));
  assert.equal(a.persistence.dump('l_outbox')[0].row.leaseOwner, 'worker-a');
  now += kit.LEASE_MS + 1;
  const workerB = await kit.dispatchOutbox(a.deps, r.deliver, { owner: 'worker-b' });
  assert.equal(workerB.acked, 1);
  releaseA();
  await workerA;
  const [row] = a.persistence.dump('l_outbox');
  assert.deepEqual([row.row.status, r.state.applied], ['ACK', 1]);
});

test('dead letter after 10 failures and on payload substitution; watermark counts undelivered incl. DEAD', async () => {
  let now = Date.parse('2026-10-12T08:00:00Z');
  const a = await kit.createTestApp({
    nowMs: () => now,
    keyring: kit.createKeyring([kit.devKey('progress'), kit.devKey('ai')]),
  });
  await completedLesson(a, 'ded');
  const failing = async () => 'retry';
  for (let i = 0; i < kit.DEAD_AFTER; i++) {
    await kit.dispatchOutbox(a.deps, failing, { random: () => 0 });
    now += 20 * 60_000;
  }
  const [row] = a.persistence.dump('l_outbox');
  assert.deepEqual([row.row.status, row.row.attempt], ['DEAD', 10]);
  assert.equal(kit.outcomeForStatus(409, 'IDEMPOTENCY_CONFLICT'), 'dead');
  assert.equal(kit.outcomeForStatus(503, 'DB_UNAVAILABLE'), 'retry');

  const before = new Date(now + 1000).toISOString();
  const signed = (key, path, query) => ({
    ...kit.signServiceRequest({
      key,
      method: 'GET',
      path,
      query,
      allowedQueryKeys: ['before'],
      body: '',
      nowSeconds: Math.floor(now / 1000),
    }),
  });
  const query = `before=${encodeURIComponent(before)}`;
  const ok = await a.call('GET', '/internal/outbox-watermark', {
    query,
    headers: signed(kit.devKey('progress'), '/internal/outbox-watermark', query),
  });
  assert.equal(ok.status, 200, JSON.stringify(ok.body));
  assert.deepEqual([ok.body.pendingBefore, ok.body.oldestUndeliveredAt], [1, row.row.occurredAt]);
  const early = `before=${encodeURIComponent('2020-01-01T00:00:00Z')}`;
  const none = await a.call('GET', '/internal/outbox-watermark', {
    query: early,
    headers: signed(kit.devKey('progress'), '/internal/outbox-watermark', early),
  });
  assert.deepEqual([none.body.pendingBefore, none.body.oldestUndeliveredAt], [0, null]);
  const unsigned = await a.call('GET', '/internal/outbox-watermark', { query });
  assert.equal(unsigned.status, 401);
  const wrongSender = await a.call('GET', '/internal/outbox-watermark', {
    query,
    headers: signed(kit.devKey('ai'), '/internal/outbox-watermark', query),
  });
  assert.equal(wrongSender.status, 403);
});
