// P6-GAME-003 Learning energy: spend under energyMode=LIMITED (ENERGY_DEPLETED), free review,
// UNLIMITED default; energy.granted.v1 / entitlement.changed.v1 from Progress through the signed
// inbox (once per eventId, substitution rejected, newest entitlement revision wins); and the
// signed learning-outbox-dispatch scheduler tick.
import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import Ajv from 'ajv/dist/2020.js';
import formats from 'ajv-formats';
import { loadKit } from './helpers/kit.mjs';
import { correctAnswer } from './helpers/answers.mjs';

const kit = await loadKit('energy');
const api = JSON.parse(fs.readFileSync('docs/api/openapi.yaml', 'utf8'));
const ajv = new Ajv({ strict: false });
formats(ajv);
ajv.addSchema({ $id: 'https://x.invalid/s', components: api.components });
const valid = (name, value) => {
  const check = ajv.compile({ $ref: `https://x.invalid/s#/components/schemas/${name}` });
  assert.ok(check(value), `${name}: ${JSON.stringify(check.errors?.slice(0, 3))}`);
};
const progressKey = kit.devKey('progress');
const schedulerKey = kit.devKey('scheduler');

async function app(energyMode, extra = {}) {
  let now = Date.parse('2026-10-12T08:00:00Z');
  const clock = { get: () => now, add: (ms) => (now += ms) };
  const a = await kit.createTestApp({
    nowMs: () => now,
    energyMode,
    keyring: kit.createKeyring([progressKey, schedulerKey, kit.devKey('learning')]),
    ...extra,
  });
  const user = 'nrg';
  const post = (path, body) => a.call('POST', path, { user, body, key: randomUUID() });
  async function signed(path, bodyObject, key = progressKey) {
    const body = JSON.stringify(bodyObject);
    const headers = kit.signServiceRequest({
      key,
      method: 'POST',
      path,
      body,
      nowSeconds: Math.floor(now / 1000),
    });
    return a.call('POST', path, { body, headers });
  }
  const enroll = await post('/v1/enrollments', { courseId: 'vi_en', startPoint: 'beginner' });
  assert.equal(enroll.status, 200, JSON.stringify(enroll.body));
  async function start(mode, lessonId) {
    const path = (await a.call('GET', '/v1/courses/vi_en/path', { user })).body;
    return post('/v1/sessions', {
      courseId: 'vi_en',
      lessonId,
      mode,
      expectedEnrollmentRevision: path.enrollment.revision,
    });
  }
  return { a, user, post, signed, start, clock };
}

const energyEvent = (payload, overrides = {}) => ({
  eventId: randomUUID(),
  type: 'energy.granted.v1',
  schemaVersion: 1,
  producer: 'progress',
  aggregateId: payload.userId,
  occurredAt: '2026-10-12T08:00:00.000Z',
  requestId: randomUUID(),
  payload,
  ...overrides,
});
const entitlementEvent = (payload) => ({
  eventId: randomUUID(),
  type: 'entitlement.changed.v1',
  schemaVersion: 1,
  producer: 'progress',
  aggregateId: payload.userId,
  occurredAt: '2026-10-12T08:00:00.000Z',
  requestId: randomUUID(),
  payload,
});

async function firstLessonId(h) {
  const path = (await h.a.call('GET', '/v1/courses/vi_en/path', { user: h.user })).body;
  const lessonId = path.nodes?.[0]?.lessonIds?.[0];
  assert.ok(lessonId, JSON.stringify(path).slice(0, 400));
  return lessonId;
}

test('energyMode defaults to UNLIMITED: answers spend nothing; config parsing is strict', async () => {
  assert.equal(kit.energyModeFrom(undefined), 'UNLIMITED');
  assert.equal(kit.energyModeFrom('limited'), 'UNLIMITED');
  assert.equal(kit.energyModeFrom('LIMITED'), 'LIMITED');
  const h = await app(undefined);
  const s = (await h.start('LESSON', await firstLessonId(h))).body;
  assert.ok(s.sessionId, JSON.stringify(s));
  const ex = s.bundle.exercises[0];
  const r = await h.post(`/v1/sessions/${s.sessionId}/answers`, {
    exerciseId: ex.id,
    attemptOrdinal: 0,
    answer: correctAnswer(ex),
    assisted: false,
    substituted: false,
    expectedRevision: 0,
  });
  assert.equal(r.status, 200);
  assert.equal(h.a.persistence.dump('l_energy').length, 0);
  const e = (await h.a.call('GET', '/v1/me/energy', { user: h.user })).body;
  valid('Energy', e);
  assert.equal(e.mode, 'UNLIMITED');
});

test('LIMITED: each lesson answer spends one unit; empty battery is ENERGY_DEPLETED for answers and lesson starts', async () => {
  const h = await app('LIMITED');
  const lessonId = await firstLessonId(h);
  const before = (await h.a.call('GET', '/v1/me/energy', { user: h.user })).body;
  valid('Energy', before);
  assert.deepEqual([before.mode, before.balance, before.capacity], ['LIMITED', 25, 25]);
  const s = (await h.start('LESSON', lessonId)).body;
  let revision = 0;
  const answered = s.bundle.exercises.slice(0, 3);
  for (const ex of answered) {
    const r = await h.post(`/v1/sessions/${s.sessionId}/answers`, {
      exerciseId: ex.id,
      attemptOrdinal: 0,
      answer: correctAnswer(ex),
      assisted: false,
      substituted: false,
      expectedRevision: revision,
    });
    assert.equal(r.status, 200, JSON.stringify(r.body));
    revision = r.body.sessionRevision;
  }
  const after = (await h.a.call('GET', '/v1/me/energy', { user: h.user })).body;
  assert.equal(after.balance, 22);
  assert.ok(after.nextUnitAt);
  const session = h.a.persistence.dump('l_sessions').find((x) => x.id === s.sessionId).row;
  assert.equal(session.energySpent, 3);
  // Drain the battery directly, then the next answer and a new lesson are refused.
  const id = kit.ids.energy(h.user);
  await h.a.persistence.transact(async (tx) => {
    const row = await tx.get('l_energy', id);
    tx.put('l_energy', id, {
      ...row,
      balance: 0,
      anchorAt: new Date(h.clock.get()).toISOString(),
      revision: row.revision + 1,
    });
  });
  const next = s.bundle.exercises[3];
  const refused = await h.post(`/v1/sessions/${s.sessionId}/answers`, {
    exerciseId: next.id,
    attemptOrdinal: 0,
    answer: correctAnswer(next),
    assisted: false,
    substituted: false,
    expectedRevision: revision,
  });
  assert.equal(refused.status, 409);
  assert.equal(refused.body.error.code, 'ENERGY_DEPLETED');
  assert.equal(
    h.a.persistence.dump('l_answers').filter((x) => x.row.sessionId === s.sessionId).length,
    3,
  ); // the refused answer wrote nothing
  const restart = await h.start('LESSON', lessonId);
  assert.equal(restart.body.error.code, 'ENERGY_DEPLETED');
  // One unit regenerates after 24h/25.
  h.clock.add(Math.floor(86400000 / 25));
  const regen = (await h.a.call('GET', '/v1/me/energy', { user: h.user })).body;
  assert.equal(regen.balance, 1);
});

test('energy.granted.v1 over the signed inbox: refill once, substitution rejected, other producers refused', async () => {
  const h = await app('LIMITED');
  const id = kit.ids.energy(h.user);
  await h.a.persistence.transact(async (tx) => {
    tx.put('l_energy', id, {
      userId: h.user,
      mode: 'LIMITED',
      balance: 2,
      capacity: 25,
      anchorAt: new Date(h.clock.get()).toISOString(),
      entitlementRevision: 0,
      revision: 0,
      createdAt: new Date(h.clock.get()).toISOString(),
      updatedAt: new Date(h.clock.get()).toISOString(),
    });
  });
  const add = energyEvent({
    operationId: 'op-ad-1',
    userId: h.user,
    amount: 5,
    refillToCapacity: false,
    reason: 'AD',
  });
  valid('BusinessEvent', add);
  const first = await h.signed('/internal/events', add);
  assert.equal(first.status, 200, JSON.stringify(first.body));
  assert.equal(first.body.status, 'accepted');
  const replay = await h.signed('/internal/events', add);
  assert.equal(replay.body.status, 'replayed');
  assert.equal((await h.a.call('GET', '/v1/me/energy', { user: h.user })).body.balance, 7);
  const swapped = await h.signed('/internal/events', {
    ...add,
    payload: { ...add.payload, amount: 50 },
  });
  assert.equal(swapped.body.error.code, 'IDEMPOTENCY_CONFLICT');
  const refill = energyEvent({
    operationId: 'op-shop-1',
    userId: h.user,
    amount: null,
    refillToCapacity: true,
    reason: 'SHOP',
  });
  assert.equal((await h.signed('/internal/events', refill)).status, 200);
  const full = (await h.a.call('GET', '/v1/me/energy', { user: h.user })).body;
  assert.deepEqual([full.balance, full.nextUnitAt], [25, null]);
  // Inconsistent payloads and a Learning-signed event are rejected before any effect.
  const bad = energyEvent({
    operationId: 'x',
    userId: h.user,
    amount: 5,
    refillToCapacity: true,
    reason: 'AD',
  });
  assert.equal((await h.signed('/internal/events', bad)).status, 400);
  const other = energyEvent(
    { operationId: 'y', userId: 'someone', amount: 1, refillToCapacity: false, reason: 'AD' },
    { aggregateId: h.user },
  );
  assert.equal((await h.signed('/internal/events', other)).status, 400);
  const forged = await h.signed(
    '/internal/events',
    energyEvent({
      operationId: 'z',
      userId: h.user,
      amount: 1,
      refillToCapacity: false,
      reason: 'AD',
    }),
    kit.devKey('learning'),
  );
  assert.equal(forged.status, 403);
  // account.deleted.v1 (purge + account.purged.v1) is covered by deletion.test.mjs.
});

test('entitlement.changed.v1: SUPER makes energy UNLIMITED (no spend); older revision ignored; expiry restores LIMITED', async () => {
  const h = await app('LIMITED');
  const sup = (rev, plan = 'SUPER', status = 'ACTIVE', expiresAt = '2026-11-12T08:00:00.000Z') =>
    entitlementEvent({ userId: h.user, plan, status, expiresAt, entitlementRevision: rev });
  assert.equal((await h.signed('/internal/events', sup(2))).status, 200);
  let e = (await h.a.call('GET', '/v1/me/energy', { user: h.user })).body;
  assert.equal(e.mode, 'UNLIMITED');
  // An older revision (delivered late) never downgrades.
  assert.equal((await h.signed('/internal/events', sup(1, 'FREE'))).status, 200);
  e = (await h.a.call('GET', '/v1/me/energy', { user: h.user })).body;
  assert.equal(e.mode, 'UNLIMITED');
  const s = (await h.start('LESSON', await firstLessonId(h))).body;
  const ex = s.bundle.exercises[0];
  await h.post(`/v1/sessions/${s.sessionId}/answers`, {
    exerciseId: ex.id,
    attemptOrdinal: 0,
    answer: correctAnswer(ex),
    assisted: false,
    substituted: false,
    expectedRevision: 0,
  });
  assert.equal(h.a.persistence.dump('l_energy')[0].row.balance, 25);
  assert.equal((await h.signed('/internal/events', sup(3, 'SUPER', 'EXPIRED'))).status, 200);
  e = (await h.a.call('GET', '/v1/me/energy', { user: h.user })).body;
  assert.deepEqual([e.mode, e.balance], ['LIMITED', 25]);
});

test('learning-outbox-dispatch tick: scheduler-signed, delivers pending completions, fails closed without delivery', async () => {
  const delivered = [];
  const h = await app(undefined, {
    deliver: async (event) => {
      delivered.push(event.eventId);
      return 'retry'; // immediate relay fails: the tick is the backstop
    },
  });
  const lessonId = await firstLessonId(h);
  const s = (await h.start('LESSON', lessonId)).body;
  let revision = 0;
  for (const ex of s.bundle.exercises) {
    revision = (
      await h.post(`/v1/sessions/${s.sessionId}/answers`, {
        exerciseId: ex.id,
        attemptOrdinal: 0,
        answer: correctAnswer(ex),
        assisted: false,
        substituted: false,
        expectedRevision: revision,
      })
    ).body.sessionRevision;
  }
  const done = await h.post(`/v1/sessions/${s.sessionId}/complete`, { expectedRevision: revision });
  assert.equal(done.status, 200, JSON.stringify(done.body));
  assert.equal(delivered.length, 1);
  h.a.deps.deliver = async (event) => {
    delivered.push(event.eventId);
    return 'ack';
  };
  h.clock.add(60_000);
  const tick = { tickId: randomUUID(), scheduledAt: new Date(h.clock.get()).toISOString() };
  const r = await h.signed('/internal/jobs/learning-outbox-dispatch', tick, schedulerKey);
  assert.equal(r.status, 200, JSON.stringify(r.body));
  valid('JobRunReport', r.body);
  assert.deepEqual(
    [r.body.job, r.body.processed, r.body.succeeded],
    ['LEARNING_OUTBOX_DISPATCH', 1, 1],
  );
  assert.equal(h.a.persistence.dump('l_outbox')[0].row.status, 'ACK');
  assert.equal(
    (await h.signed('/internal/jobs/learning-outbox-dispatch', tick, progressKey)).status,
    403,
  );
  delete h.a.deps.deliver;
  const closed = await h.signed('/internal/jobs/learning-outbox-dispatch', tick, schedulerKey);
  assert.equal(closed.body.error.code, 'SERVICE_NOT_CONFIGURED');
});
