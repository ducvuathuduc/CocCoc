import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { checkRows, kit, learningKey, setup, validate } from './harness.mjs';

test('entitlement.changed.v1: inbox dedupe, newest revision wins, invalid payload rejected', async () => {
  const h = setup();
  const eventId = randomUUID();
  const first = await h.grant('alice', 'MAX', 5);
  assert.equal(first.body.status, 'accepted');
  const dup = await h.event('entitlement.changed.v1', first.envelope.payload, {
    eventId: first.envelope.eventId,
  });
  assert.equal(dup.status, 200);
  assert.equal(dup.body.status, 'replayed');
  // Older revision arriving late does not downgrade.
  await h.grant('alice', 'FREE', 4);
  const row = h.store.dump('a_usage').find((r) => r.row.utcDay === 'ENTITLED');
  assert.equal(JSON.parse(row.row.reservationIdsJson).plan, 'MAX');
  await h.grant('alice', 'FREE', 6);
  const after = h.store.dump('a_usage').find((r) => r.row.utcDay === 'ENTITLED');
  assert.equal(JSON.parse(after.row.reservationIdsJson).plan, 'FREE');
  const bad = await h.event(
    'entitlement.changed.v1',
    { userId: 'alice', plan: 'GOLD', status: 'ACTIVE', expiresAt: null, entitlementRevision: 7 },
    { eventId },
  );
  assert.equal(bad.status, 400);
  const extra = await h.event('entitlement.changed.v1', {
    userId: 'alice',
    plan: 'MAX',
    status: 'ACTIVE',
    expiresAt: null,
    entitlementRevision: 8,
    x: 1,
  });
  assert.equal(extra.status, 400);
  // Substituted payload under a used eventId.
  const sub = await h.event(
    'entitlement.changed.v1',
    { ...first.envelope.payload, plan: 'SUPER' },
    { eventId: first.envelope.eventId },
  );
  assert.equal(sub.status, 409);
  assert.equal(sub.body.error.code, 'IDEMPOTENCY_CONFLICT');
  // Wrong producer.
  const forged = await h.event('entitlement.changed.v1', first.envelope.payload, {
    sender: learningKey,
  });
  assert.equal(forged.status, 403);
  checkRows(h.store);
});

test('account.deleted.v1 purges every a_ row of the user in batches and acknowledges once', async () => {
  const h = setup();
  await h.grant('alice');
  await h.grant('bob');
  // Lots of alice rows: conversations + receipts + usage.
  for (let i = 0; i < 50; i++) {
    const r = await h.call('POST', '/v1/conversations', {
      user: 'alice',
      idem: randomUUID(),
      body: {
        kind: 'ROLEPLAY',
        courseId: 'vi_en',
        scenarioId: kit.SCENARIOS[i % 12].id,
        voiceSessionId: null,
      },
    });
    assert.equal(r.status, 200);
  }
  await h.call('POST', '/v1/conversations', {
    user: 'bob',
    idem: randomUUID(),
    body: {
      kind: 'ROLEPLAY',
      courseId: 'vi_en',
      scenarioId: 'rp_cafe_order',
      voiceSessionId: null,
    },
  });
  const aliceRows = () =>
    ['a_conversations', 'a_receipts', 'a_usage', 'a_voice_sessions', 'a_active_slots', 'a_jobs']
      .flatMap((t) => h.store.dump(t))
      .filter((r) => r.row.userId === 'alice').length;
  assert.ok(aliceRows() > kit.PURGE_BATCH);
  const requestId = randomUUID();
  const del = await h.event('account.deleted.v1', { userId: 'alice', requestId });
  assert.equal(del.status, 200);
  assert.equal(del.body.status, 'accepted');
  assert.equal(aliceRows(), 0);
  assert.ok(h.store.dump('a_conversations').some((r) => r.row.userId === 'bob'));
  const acks = h.store.dump('a_outbox').filter((r) => r.row.type === 'account.purged.v1');
  assert.equal(acks.length, 1);
  const ack = JSON.parse(acks[0].row.payloadJson);
  validate('BusinessEvent', ack);
  assert.deepEqual(ack.payload, { userId: 'alice', requestId, owner: 'ai' });
  const again = await h.event(
    'account.deleted.v1',
    { userId: 'alice', requestId },
    { eventId: del.envelope.eventId },
  );
  assert.equal(again.body.status, 'replayed');
  assert.equal(
    h.store.dump('a_outbox').filter((r) => r.row.type === 'account.purged.v1').length,
    1,
  );
  // After deletion the user is FREE again (projection purged).
  const blocked = await h.call('POST', '/v1/conversations', {
    user: 'alice',
    idem: randomUUID(),
    body: {
      kind: 'ROLEPLAY',
      courseId: 'vi_en',
      scenarioId: 'rp_cafe_order',
      voiceSessionId: null,
    },
  });
  assert.equal(blocked.body.error.code, 'ENTITLEMENT_REQUIRED');
  const invalid = await h.event('account.deleted.v1', { userId: 'alice', requestId: 'nope' });
  assert.equal(invalid.status, 400);
  checkRows(h.store);
});

test('outbox dispatcher: ack, retry with backoff, dead-letter; unknown-type 400 retries', async () => {
  const h = setup();
  await h.grant('alice');
  const conv = await h.call('POST', '/v1/conversations', {
    user: 'alice',
    idem: randomUUID(),
    body: {
      kind: 'ROLEPLAY',
      courseId: 'vi_en',
      scenarioId: 'rp_cafe_order',
      voiceSessionId: null,
    },
  });
  for (const step of kit.scenarioById('rp_cafe_order').steps) {
    await h.call('POST', '/v1/tutor', {
      user: 'alice',
      body: {
        requestId: randomUUID(),
        scenarioId: 'rp_cafe_order',
        learnerText: step.expect,
        level: 'A1',
        locale: 'en-US',
        feedbackLocale: 'vi-VN',
      },
    });
  }
  await h.call('POST', `/v1/conversations/${conv.body.conversationId}/complete`, {
    user: 'alice',
    idem: randomUUID(),
    body: { endReason: 'COMPLETED' },
  });
  assert.equal(
    kit.outcomeForStatus(400, { error: { code: 'VALIDATION_ERROR', details: { field: 'type' } } }),
    'retry',
  );
  assert.equal(kit.outcomeForStatus(400, { error: { code: 'VALIDATION_ERROR' } }), 'dead');
  assert.equal(kit.outcomeForStatus(409, { error: { code: 'IDEMPOTENCY_CONFLICT' } }), 'dead');
  assert.equal(kit.outcomeForStatus(503, null), 'retry');
  const seen = [];
  let answer = 'retry';
  const deliver = async (event) => {
    seen.push(event);
    return answer;
  };
  const r1 = await kit.dispatchOutbox(h.deps, deliver, { random: () => 0 });
  assert.deepEqual(r1, { leased: 1, acked: 0, retried: 1, dead: 0 });
  const r2 = await kit.dispatchOutbox(h.deps, deliver, { random: () => 0 });
  assert.equal(r2.leased, 0, 'not due before backoff');
  h.clock.now += 60_000;
  answer = 'ack';
  const r3 = await kit.dispatchOutbox(h.deps, deliver);
  assert.deepEqual(r3, { leased: 1, acked: 1, retried: 0, dead: 0 });
  assert.equal(seen[0].eventId, seen[1].eventId);
  assert.equal(h.store.dump('a_outbox')[0].row.status, 'ACK');
  checkRows(h.store);
});
