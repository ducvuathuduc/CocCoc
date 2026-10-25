// Phase 5.3 (ADR-0018): AMQP adapter against an in-process broker model. Real-broker behaviour of
// the same topology is checked in tools/scripts/container-check.mjs (pinned RabbitMQ image).
import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { loadTransportKit } from './kit.mjs';

const kit = await loadTransportKit('amqp');
const keyring = kit.createKeyring([kit.devKey('learning'), kit.devKey('progress'), kit.devKey('ai')]);

async function until(check, label, ms = 2000) {
  const started = Date.now();
  while (!(await check())) {
    if (Date.now() - started > ms) throw new Error(`timeout waiting for ${label}`);
    await new Promise((resolve) => setTimeout(resolve, 2));
  }
}

function lessonEvent(overrides = {}, payload = {}) {
  const eventId = overrides.eventId ?? randomUUID();
  return {
    eventId,
    type: 'lesson.completed.v1',
    schemaVersion: 1,
    producer: 'learning',
    aggregateId: 'c-' + eventId.slice(0, 8),
    occurredAt: new Date().toISOString(),
    requestId: eventId,
    payload: { completionId: eventId, userId: 'alice', originalCorrect: 10, ...payload },
    ...overrides,
  };
}

function transport(broker, service, extra = {}) {
  return kit.createAmqpEventTransport({
    url: 'amqp://fake',
    service,
    keyring,
    signingKey: kit.devKey(service),
    connect: broker.connect,
    retryDelayMs: () => 0,
    reconnectDelayMs: () => 5,
    confirmTimeoutMs: 100,
    ...extra,
  });
}

/** Progress-shaped consumer: inbox + one ledger row per completion, committed atomically. */
function receiver() {
  const store = kit.createMemoryOwnerStore('progress', ['p_inbox', 'p_reward_ledger']);
  const state = { failNext: 0, applied: 0 };
  return {
    store,
    state,
    consumer: {
      async consume(event, context) {
        if (state.failNext > 0) {
          state.failNext--;
          throw new Error('consumer down');
        }
        return store.applyInboxEvent(
          { eventId: event.eventId, type: event.type, bodyHash: context.bodyHash },
          async (tx) => {
            state.applied++;
            tx.put('p_reward_ledger', String(event.payload.completionId), { eventId: event.eventId });
          },
        );
      },
    },
  };
}

function receipts() {
  const recorded = new Map();
  const state = { failNext: 0 };
  return {
    recorded,
    state,
    port: {
      async send(receipt) {
        if (state.failNext > 0) {
          state.failNext--;
          throw new Error('producer unreachable');
        }
        const previous = recorded.get(receipt.eventId);
        if (previous && previous.bodyHash !== receipt.bodyHash) throw new Error('conflict');
        recorded.set(receipt.eventId, receipt);
      },
    },
  };
}

async function startConsumer(broker, r, rc) {
  const t = transport(broker, 'progress');
  const handle = await t.consume(
    'progress',
    kit.createReceiptingHandler({ owner: 'progress', consumer: r.consumer, receipts: rc.port }),
  );
  return { t, handle };
}

test('topology: quorum queue with pinned delivery limit, at-least-once DLX and reject-publish', async () => {
  const broker = new kit.FakeAmqpBroker();
  const { t, handle } = await startConsumer(broker, receiver(), receipts());
  const queue = broker.queue('coc.progress.events');
  assert.deepEqual(queue.args, {
    'x-queue-type': 'quorum',
    'x-delivery-limit': 10,
    'x-dead-letter-exchange': 'coc.events.dlx',
    'x-dead-letter-strategy': 'at-least-once',
    'x-overflow': 'reject-publish',
  });
  assert.equal(kit.DELIVERY_LIMIT, 10);
  assert.deepEqual(broker.queue('coc.progress.events.dead').args, { 'x-queue-type': 'quorum' });
  assert.ok(broker.bindings.some((b) => b.queue === 'coc.progress.events.dead' && b.exchange === 'coc.events.dlx'));
  await handle.stop();
  await t.close();
});

test('confirmed publish is persistent; the consumer applies once, receipts, then acks', async () => {
  const broker = new kit.FakeAmqpBroker();
  const r = receiver();
  const rc = receipts();
  const { t: consumerT, handle } = await startConsumer(broker, r, rc);
  const producer = transport(broker, 'learning');
  const event = lessonEvent();
  assert.equal(await producer.publish('progress', event), 'confirmed');
  await until(() => rc.recorded.has(event.eventId), 'receipt');
  await until(() => broker.unacked() === 0 && broker.depth('coc.progress.events') === 0, 'ack');
  assert.equal(r.state.applied, 1);
  const receipt = rc.recorded.get(event.eventId);
  assert.deepEqual(receipt, {
    eventId: event.eventId,
    bodyHash: kit.canonicalBodyHash(event),
    producer: 'learning',
    consumer: 'progress',
    outcome: 'applied',
  });
  assert.equal(producer.health().connected, true);
  await handle.stop();
  await consumerT.close();
  await producer.close();
  assert.equal(producer.health().connected, false);
});

test('unroutable (consumer queue never declared) is returned, never confirmed', async () => {
  const broker = new kit.FakeAmqpBroker();
  const producer = transport(broker, 'learning');
  assert.equal(await producer.publish('progress', lessonEvent()), 'returned');
  assert.equal(await kit.publishForTarget(producer, 'progress', lessonEvent()), 'retry');
  await producer.close();
});

test('lost confirm, broker down, closed connection and resource alarm are retries, not success', async () => {
  const broker = new kit.FakeAmqpBroker();
  const { t, handle } = await startConsumer(broker, receiver(), receipts());
  const producer = transport(broker, 'learning');
  broker.dropConfirms = 1;
  await assert.rejects(producer.publish('progress', lessonEvent()), { code: 'DEADLINE_EXCEEDED' });
  assert.equal(await kit.publishForTarget(producer, 'progress', lessonEvent()), 'published');

  broker.setQueueLimit('coc.progress.events', 0);
  assert.equal(await producer.publish('progress', lessonEvent()), 'nacked', 'reject-publish overflow');
  broker.setQueueLimit('coc.progress.events', 1000);

  broker.setAlarm(true);
  await until(() => producer.health().reason === 'BLOCKED', 'blocked');
  assert.equal(await kit.publishForTarget(producer, 'progress', lessonEvent()), 'retry');
  broker.setAlarm(false);
  await until(() => producer.health().reason !== 'BLOCKED', 'unblocked');

  broker.restart();
  broker.down = true;
  assert.equal(await kit.publishForTarget(producer, 'progress', lessonEvent()), 'retry');
  assert.equal(producer.health().connected, false);
  broker.down = false;
  assert.equal(await kit.publishForTarget(producer, 'progress', lessonEvent()), 'published');
  await handle.stop();
  await t.close();
  await producer.close();
});

test('persistent messages survive a broker restart and the consumer reconnects to apply them', async () => {
  const broker = new kit.FakeAmqpBroker();
  const r = receiver();
  const rc = receipts();
  const { t, handle } = await startConsumer(broker, r, rc);
  await handle.stop();
  const producer = transport(broker, 'learning');
  const event = lessonEvent();
  assert.equal(await producer.publish('progress', event), 'confirmed');
  broker.restart();
  assert.equal(broker.depth('coc.progress.events'), 1, 'persistent message kept');
  assert.equal(broker.lostMessages, 0);
  const again = await t.consume(
    'progress',
    kit.createReceiptingHandler({ owner: 'progress', consumer: r.consumer, receipts: rc.port }),
  );
  await until(() => rc.recorded.has(event.eventId), 'receipt after restart');
  // Kill the consumer's connection while idle: it reconnects and keeps consuming.
  for (const connection of [...broker.connections]) broker.kill(connection);
  const later = lessonEvent();
  await until(async () => (await kit.publishForTarget(producer, 'progress', later)) === 'published', 'republish');
  await until(() => rc.recorded.has(later.eventId), 'receipt after reconnect');
  assert.equal(r.state.applied, 2);
  await again.stop();
  await t.close();
  await producer.close();
});

test('consumer outage: bounded retries, then the delivery is dead-lettered and retained', async () => {
  const broker = new kit.FakeAmqpBroker();
  const r = receiver();
  r.state.failNext = 1000;
  const rc = receipts();
  const { t, handle } = await startConsumer(broker, r, rc);
  const producer = transport(broker, 'learning');
  const event = lessonEvent();
  await producer.publish('progress', event);
  await until(() => broker.depth('coc.progress.events.dead') === 1, 'dead letter', 5000);
  assert.equal(broker.depth('coc.progress.events'), 0);
  assert.equal(rc.recorded.size, 0, 'no receipt for an effect that never happened');
  assert.equal(r.state.applied, 0);
  // Attempts: DELIVERY_LIMIT deliveries (counts 0..9), never a tight unbounded loop.
  assert.equal(1000 - r.state.failNext, kit.DELIVERY_LIMIT);
  await handle.stop();
  await t.close();
  await producer.close();
});

test('unavailable DLX target: at-least-once keeps the dead letter instead of dropping it', async () => {
  const broker = new kit.FakeAmqpBroker();
  const r = receiver();
  const { t, handle } = await startConsumer(broker, r, receipts());
  broker.bindings.splice(
    broker.bindings.findIndex((b) => b.queue === 'coc.progress.events.dead'),
    1,
  );
  const producer = transport(broker, 'learning');
  // A forged/invalid event dead-letters immediately.
  await producer.publish('progress', lessonEvent({ type: 'unknown.v1' }));
  await until(() => broker.queue('coc.progress.events').pendingDeadLetters.length === 1, 'retained');
  assert.equal(broker.lostMessages, 0);
  broker.bindings.push({ queue: 'coc.progress.events.dead', exchange: 'coc.events.dlx', pattern: 'progress.#' });
  broker.retryDeadLetters();
  assert.equal(broker.depth('coc.progress.events.dead'), 1);
  await handle.stop();
  await t.close();
  await producer.close();
});

test('envelope: forged, re-signed, producer-mismatched and changed-payload events never apply', async () => {
  const broker = new kit.FakeAmqpBroker();
  const r = receiver();
  const rc = receipts();
  const { t, handle } = await startConsumer(broker, r, rc);
  const producer = transport(broker, 'learning');
  const event = lessonEvent();
  await producer.publish('progress', event);
  await until(() => rc.recorded.has(event.eventId), 'first apply');

  const channel = await (await broker.connect('amqp://fake')).createConfirmChannel();
  const send = (content) =>
    new Promise((resolve) =>
      channel.publish('coc.events', 'progress.lesson.completed.v1', content, { persistent: true }, resolve),
    );
  // 1. Same eventId, different payload, validly signed by Learning: IDEMPOTENCY_CONFLICT.
  await send(kit.signEnvelope(kit.devKey('learning'), { ...event, payload: { ...event.payload, originalCorrect: 1 } }));
  // 2. Signature tampered.
  const tampered = JSON.parse(kit.signEnvelope(kit.devKey('learning'), lessonEvent()).toString());
  tampered.signature = '0'.repeat(64);
  await send(Buffer.from(JSON.stringify(tampered)));
  // 3. AI's valid key claiming a Learning event (producer != signer).
  const forged = JSON.parse(kit.signEnvelope(kit.devKey('learning'), lessonEvent()).toString());
  forged.keyId = 'dev-ai';
  forged.sender = 'ai';
  await send(Buffer.from(JSON.stringify(forged)));
  // 4. Unknown key ID (e.g. retired after rotation) and plain garbage.
  const unknown = JSON.parse(kit.signEnvelope(kit.devKey('learning'), lessonEvent()).toString());
  unknown.keyId = 'retired-key';
  await send(Buffer.from(JSON.stringify(unknown)));
  await send(Buffer.from('not json'));
  // 5. AI may send account.purged.v1 but not lesson.completed.v1 (receiver allowlist).
  await send(kit.signEnvelope(kit.devKey('ai'), lessonEvent({ producer: 'ai' })));
  await until(() => broker.depth('coc.progress.events.dead') === 6, 'six dead letters');
  assert.equal(r.state.applied, 1);
  assert.equal(r.store.inboxSize, 1);
  await handle.stop();
  await t.close();
  await producer.close();
});

test('delivery long after creation (> 300 s) is accepted: no HTTP freshness rule on queued events', async () => {
  const broker = new kit.FakeAmqpBroker();
  const r = receiver();
  const rc = receipts();
  const { t, handle } = await startConsumer(broker, r, rc);
  const producer = transport(broker, 'learning');
  const old = lessonEvent({ occurredAt: new Date(Date.now() - 6 * 3600_000).toISOString() });
  await producer.publish('progress', old);
  await until(() => rc.recorded.has(old.eventId), 'old event applied');
  assert.equal(r.state.applied, 1);
  await handle.stop();
  await t.close();
  await producer.close();
});

test('key rotation: old and new keys both verify while both are in the receiver keyring', () => {
  const rotated = { keyId: 'learning-2026-11', sender: 'learning', secret: Buffer.alloc(32, 7) };
  const ring = kit.createKeyring([kit.devKey('learning'), rotated]);
  const event = lessonEvent();
  assert.equal(kit.verifyEnvelope(ring, kit.signEnvelope(rotated, event)).keyId, 'learning-2026-11');
  assert.equal(kit.verifyEnvelope(ring, kit.signEnvelope(kit.devKey('learning'), event)).keyId, 'dev-learning');
  const retired = kit.createKeyring([rotated]);
  assert.throws(() => kit.verifyEnvelope(retired, kit.signEnvelope(kit.devKey('learning'), event)), {
    code: 'AUTH_REQUIRED',
  });
  assert.equal(kit.signingKeyFor(ring, 'learning').keyId, 'dev-learning', 'first key signs');
  assert.throws(() => kit.signEnvelope(kit.devKey('ai'), event), { code: 'FORBIDDEN' });
});

test('100 duplicate/reorder trials over the broker keep one effect per event', async () => {
  let seed = 0xc0ffee;
  const next = () => (seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0);
  const broker = new kit.FakeAmqpBroker();
  const r = receiver();
  const rc = receipts();
  const { t, handle } = await startConsumer(broker, r, rc);
  const producer = transport(broker, 'learning');
  let expected = 0;
  for (let trial = 0; trial < 100; trial++) {
    const events = Array.from({ length: 3 }, () => lessonEvent());
    const sends = events.flatMap((event) => [event, event, event]);
    for (let i = sends.length - 1; i > 0; i--) {
      const j = next() % (i + 1);
      [sends[i], sends[j]] = [sends[j], sends[i]];
    }
    if (trial % 10 === 0) rc.state.failNext = 1; // receipt loss mid-trial
    await Promise.all(sends.map((event) => producer.publish('progress', event)));
    expected += 3;
  }
  await until(
    () => broker.depth('coc.progress.events') === 0 && broker.unacked() === 0,
    'drain',
    10_000,
  );
  assert.equal(r.state.applied, expected);
  assert.equal(r.store.inboxSize, expected);
  assert.equal(rc.recorded.size, expected);
  assert.equal(broker.depth('coc.progress.events.dead'), 0);
  await handle.stop();
  await t.close();
  await producer.close();
});
