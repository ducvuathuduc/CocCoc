// P6-REVIEW-001: review state written in the completion transaction, due list, dynamic private
// review bundle (review_dynamic, 5-20 items, <=64KB), long-term stage advance only on REVIEW.
import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { loadKit } from './helpers/kit.mjs';
import { correctAnswer, wrongAnswer } from './helpers/answers.mjs';

const kit = await loadKit('review');
const DAY = 86400000;

async function setup() {
  let now = Date.parse('2026-10-12T08:00:00Z');
  const a = await kit.createTestApp({ nowMs: () => now });
  const user = 'rev';
  const post = (path, body) => a.call('POST', path, { user, body, key: randomUUID() });
  async function play(lessonId, mode, wrongIds = []) {
    const rev = (await a.call('GET', '/v1/courses/vi_en/path', { user })).body.enrollment.revision;
    const s = await post('/v1/sessions', {
      courseId: 'vi_en',
      lessonId,
      mode,
      expectedEnrollmentRevision: rev,
    });
    assert.equal(s.status, 200, JSON.stringify(s.body));
    let revision = 0;
    for (const ex of s.body.bundle.exercises) {
      const wrong = wrongIds.includes(ex.id);
      const r = await post(`/v1/sessions/${s.body.sessionId}/answers`, {
        exerciseId: ex.id,
        attemptOrdinal: 0,
        answer: wrong ? wrongAnswer(ex) : correctAnswer(ex),
        assisted: false,
        substituted: false,
        expectedRevision: revision,
      });
      assert.equal(r.status, 200, JSON.stringify(r.body));
      revision = r.body.sessionRevision;
    }
    const c = await post(`/v1/sessions/${s.body.sessionId}/complete`, {
      expectedRevision: revision,
    });
    assert.equal(c.status, 200, JSON.stringify(c.body));
    return { session: s.body, completion: c.body };
  }
  await post('/v1/enrollments', { courseId: 'vi_en', startPoint: 'beginner' });
  return { a, user, play, advance: (ms) => (now += ms) };
}

test('lesson completion schedules review items; wrong first attempts reset; nothing due until tomorrow', async () => {
  const { a, user, play, advance } = await setup();
  const { session } = await play('u1n1l1', 'LESSON', ['u1n1l1-e01']);
  const items = a.persistence.dump('l_review_items').map((r) => r.row);
  assert.ok(items.length >= 5, `items=${items.length}`);
  const wrongVocab = session.bundle.exercises[0].vocabularyIds[0];
  const wrong = items.find((i) => i.vocabularyId === wrongVocab);
  assert.deepEqual([wrong.stage, wrong.incorrectCount], [0, 1]);
  let review = await a.call('GET', '/v1/review', { user, query: 'courseId=vi_en' });
  assert.equal(review.status, 200);
  assert.equal(review.body.items.length, 0, 'not due yet');
  advance(DAY + 1000);
  review = await a.call('GET', '/v1/review', { user, query: 'courseId=vi_en&limit=5' });
  assert.equal(review.body.items.length, 5);
  assert.ok(review.body.nextCursor);
  assert.equal(review.body.items[0].mastery, null, 'fewer than 5 attempts -> no percentage');
});

test('REVIEW session: private snapshot bundle from due vocabulary; completion advances stages and emits mode REVIEW', async () => {
  const { a, user, play, advance } = await setup();
  await play('u1n1l1', 'LESSON');
  advance(DAY + 1000);
  const due = (await a.call('GET', '/v1/review', { user, query: 'limit=100' })).body.items;
  const { session, completion } = await play('review_dynamic', 'REVIEW');
  assert.equal(session.bundle.lessonId, 'review_dynamic');
  assert.equal(session.bundle.signatureKeyId, 'server-snapshot-sha512');
  assert.ok(session.bundle.exercises.length >= 5 && session.bundle.exercises.length <= 20);
  assert.ok(JSON.stringify(session.bundle).length <= 65536);
  const covered = new Set(session.bundle.exercises.flatMap((e) => e.vocabularyIds));
  assert.ok(
    due.some((d) => covered.has(d.vocabularyId)),
    'due vocabulary is practiced',
  );
  assert.equal(completion.mode, 'REVIEW');
  const events = a.persistence.dump('l_outbox').map((r) => JSON.parse(r.row.payloadJson));
  assert.deepEqual(events.map((e) => e.payload.mode).sort(), ['LESSON', 'REVIEW']);
  const dueIds = new Set(due.map((d) => d.vocabularyId));
  const advanced = a.persistence
    .dump('l_review_items')
    .map((r) => r.row)
    .filter((r) => covered.has(r.vocabularyId) && dueIds.has(r.vocabularyId));
  assert.ok(
    advanced.length > 0 && advanced.every((r) => r.stage === 2),
    JSON.stringify(advanced.map((r) => r.stage)),
  );
  assert.equal(
    (await a.call('GET', '/v1/lessons/review_dynamic/bundle', { user })).status,
    404,
    'never a public bundle',
  );
  const view = await a.call('GET', `/v1/sessions/${session.sessionId}`, { user });
  assert.deepEqual(
    view.body.bundle.exercises.map((e) => e.id),
    session.bundle.exercises.map((e) => e.id),
  );
});

test('REVIEW with nothing completed -> REVIEW_POOL_EMPTY; wrong lessonId rejected', async () => {
  const { a, user } = await setup();
  const body = (lessonId) => ({
    courseId: 'vi_en',
    lessonId,
    mode: 'REVIEW',
    expectedEnrollmentRevision: 0,
  });
  const empty = await a.call('POST', '/v1/sessions', {
    user,
    key: randomUUID(),
    body: body('review_dynamic'),
  });
  assert.deepEqual([empty.status, empty.body.error.details.reason], [404, 'REVIEW_POOL_EMPTY']);
  const wrong = await a.call('POST', '/v1/sessions', {
    user,
    key: randomUUID(),
    body: body('u1n1l1'),
  });
  assert.equal(wrong.status, 400);
});
