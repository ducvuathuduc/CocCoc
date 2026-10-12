// FR-AUTH-005 Learning purge: a signed account.deleted.v1 from Progress removes every private
// Learning row of the user (other users untouched), commits the account.purged.v1 acknowledgement
// with the inbox row, replays once per eventId, rejects substitution and forged producers, and the
// acknowledgement is delivered to Progress by the outbox.
import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import Ajv from 'ajv/dist/2020.js';
import formats from 'ajv-formats';
import { loadKit } from './helpers/kit.mjs';
import { correctAnswer, wrongAnswer } from './helpers/answers.mjs';

const kit = await loadKit('deletion');
const api = JSON.parse(fs.readFileSync('docs/api/openapi.yaml', 'utf8'));
const ajv = new Ajv({ strict: false });
formats(ajv);
ajv.addSchema({ $id: 'https://x.invalid/s', components: api.components });
const validEvent = ajv.compile({ $ref: 'https://x.invalid/s#/components/schemas/BusinessEvent' });
const progressKey = kit.devKey('progress');

async function setup() {
  const now = Date.parse('2026-10-12T08:00:00.000Z');
  const delivered = [];
  const a = await kit.createTestApp({
    nowMs: () => now,
    keyring: kit.createKeyring([progressKey, kit.devKey('learning')]),
    deliver: async (event) => {
      delivered.push(event);
      return 'ack';
    },
  });
  const signed = (bodyObject, key = progressKey) => {
    const body = JSON.stringify(bodyObject);
    const headers = kit.signServiceRequest({
      key,
      method: 'POST',
      path: '/internal/events',
      body,
      nowSeconds: Math.floor(now / 1000),
    });
    return a.call('POST', '/internal/events', { body, headers });
  };
  const post = (user, path, body) => a.call('POST', path, { user, body, key: randomUUID() });
  async function learn(user) {
    assert.equal(
      (await post(user, '/v1/enrollments', { courseId: 'vi_en', startPoint: 'beginner' })).status,
      200,
    );
    const s = (
      await post(user, '/v1/sessions', {
        courseId: 'vi_en',
        lessonId: 'u1n1l1',
        mode: 'LESSON',
        expectedEnrollmentRevision: 0,
      })
    ).body;
    let revision = s.revision;
    for (const [i, ex] of s.bundle.exercises.entries()) {
      const r = await post(user, `/v1/sessions/${s.sessionId}/answers`, {
        exerciseId: ex.id,
        attemptOrdinal: 0,
        answer: i === 0 ? wrongAnswer(ex) : correctAnswer(ex),
        assisted: false,
        substituted: false,
        expectedRevision: revision,
      });
      revision = r.body.sessionRevision;
    }
    // retry the first (wrong) item, then complete
    const retry = await post(user, `/v1/sessions/${s.sessionId}/answers`, {
      exerciseId: s.bundle.exercises[0].id,
      attemptOrdinal: 1,
      answer: correctAnswer(s.bundle.exercises[0]),
      assisted: false,
      substituted: false,
      expectedRevision: revision,
    });
    const done = await post(user, `/v1/sessions/${s.sessionId}/complete`, {
      expectedRevision: retry.body.sessionRevision,
    });
    assert.equal(done.status, 200, JSON.stringify(done.body));
    const report = await post(user, '/v1/reports', {
      exerciseId: s.bundle.exercises[1].id,
      lessonVersion: 'v2.u1n1l1',
      category: 'CONTENT',
      note: 'typo',
    });
    assert.ok([200, 202].includes(report.status), JSON.stringify(report.body));
  }
  const rowsOf = (user) =>
    kit.LEARNING_TABLES.flatMap((table) =>
      a.persistence
        .dump(table)
        .filter((r) => r.row.userId === user)
        .map((r) => table),
    );
  return { a, signed, learn, rowsOf, delivered };
}

const deletionEvent = (userId, extra = {}) => ({
  eventId: randomUUID(),
  type: 'account.deleted.v1',
  schemaVersion: 1,
  producer: 'progress',
  aggregateId: userId,
  occurredAt: '2026-10-12T08:00:00.000Z',
  requestId: randomUUID(),
  payload: { userId, requestId: randomUUID() },
  ...extra,
});

test('account.deleted.v1 purges the user, keeps others, acks with account.purged.v1 once', async () => {
  const h = await setup();
  await h.learn('gone');
  await h.learn('stay');
  const before = new Set(h.rowsOf('gone'));
  for (const table of [
    'l_enrollments',
    'l_sessions',
    'l_answers',
    'l_review_items',
    'l_receipts',
    'l_reports',
    'l_mistakes',
  ])
    assert.ok(before.has(table), `fixture wrote ${table}`);
  const stayBefore = h.rowsOf('stay').length;
  const event = deletionEvent('gone');
  assert.ok(validEvent(event), JSON.stringify(validEvent.errors));
  h.delivered.length = 0;
  const r = await h.signed(event);
  assert.equal(r.status, 200, JSON.stringify(r.body));
  assert.equal(r.body.status, 'accepted');
  assert.deepEqual(h.rowsOf('gone'), [], 'no private Learning row left');
  assert.equal(h.a.persistence.dump('l_energy').filter((x) => x.row.userId === 'gone').length, 0);
  assert.equal(h.rowsOf('stay').length, stayBefore, 'other users untouched');
  const acks = h.a.persistence
    .dump('l_outbox')
    .map((x) => JSON.parse(x.row.payloadJson))
    .filter((e) => e.type === 'account.purged.v1');
  assert.equal(acks.length, 1);
  assert.ok(validEvent(acks[0]), JSON.stringify(validEvent.errors));
  assert.deepEqual(acks[0].payload, {
    userId: 'gone',
    requestId: event.payload.requestId,
    owner: 'learning',
  });
  assert.deepEqual(
    h.delivered.map((e) => e.type),
    ['account.purged.v1'],
    'acknowledgement relayed immediately to Progress',
  );
  // Replay: same event -> replayed, no second ack; substitution -> 409.
  const replay = await h.signed(event);
  assert.deepEqual([replay.status, replay.body.status], [200, 'replayed']);
  const swapped = await h.signed({ ...event, requestId: 'other' });
  assert.equal(swapped.body.error?.code, 'IDEMPOTENCY_CONFLICT', JSON.stringify(swapped.body));
  assert.equal(
    h.a.persistence
      .dump('l_outbox')
      .filter((x) => JSON.parse(x.row.payloadJson).type === 'account.purged.v1').length,
    1,
  );
  // The deleted user has no enrollment any more.
  assert.equal((await h.a.call('GET', '/v1/courses/vi_en/path', { user: 'gone' })).status, 404);
});

test('account.deleted.v1 validation: payload/aggregate mismatch 400; non-Progress producer 403; empty user acks', async () => {
  const h = await setup();
  const mismatch = deletionEvent('a1', { aggregateId: 'a2' });
  assert.equal((await h.signed(mismatch)).status, 400);
  const extra = deletionEvent('a1');
  extra.payload.email = 'x@example.invalid';
  assert.equal((await h.signed(extra)).status, 400);
  const forged = await h.signed(
    deletionEvent('a1', { producer: 'learning' }),
    kit.devKey('learning'),
  );
  assert.equal(forged.status, 403);
  const nobody = await h.signed(deletionEvent('never-enrolled'));
  assert.deepEqual([nobody.status, nobody.body.status], [200, 'accepted']);
});

test('purgeUserRows removes more than one batch per table', async () => {
  const h = await setup();
  const { persistence } = h.a;
  await persistence.transact(async (tx) => {
    for (let i = 0; i < 85; i++)
      tx.put('l_review_items', `big${i}`, {
        userId: 'big',
        courseId: 'vi_en',
        vocabularyId: `v${i}`,
      });
  });
  await persistence.transact(async (tx) => {
    for (let i = 85; i < 170; i++)
      tx.put('l_review_items', `big${i}`, {
        userId: 'big',
        courseId: 'vi_en',
        vocabularyId: `v${i}`,
      });
  });
  const r = await h.signed(deletionEvent('big'));
  assert.equal(r.status, 200, JSON.stringify(r.body));
  assert.equal(h.rowsOf('big').length, 0);
});
