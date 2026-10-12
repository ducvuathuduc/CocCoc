// P4-LEARN-002 + P5-LESSON-002 over the real router/use cases (memory adapter, committed content):
// enroll/placement/path, start/answer/complete/abandon, idempotency, two-device conflict,
// uncertain commit, one active session, monotonic frontier and exactly one outbox event.
import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import Ajv from 'ajv/dist/2020.js';
import formats from 'ajv-formats';
import fs from 'node:fs';
import { loadKit } from './helpers/kit.mjs';
import { correctAnswer, wrongAnswer } from './helpers/answers.mjs';

const kit = await loadKit('sessions');
const api = JSON.parse(fs.readFileSync('docs/api/openapi.yaml', 'utf8'));
const ajv = new Ajv({ strict: false });
formats(ajv);
ajv.addSchema({ $id: 'https://x.invalid/s', components: api.components });
const schemas = {};
function valid(name, value) {
  schemas[name] ??= ajv.compile({ $ref: `https://x.invalid/s#/components/schemas/${name}` });
  assert.ok(schemas[name](value), `${name}: ${JSON.stringify(schemas[name].errors?.slice(0, 3))}`);
}

async function app(options) {
  return kit.createTestApp(options);
}
const post = (a, path, user, body, key = randomUUID()) => a.call('POST', path, { user, body, key });

async function enroll(a, user, startPoint = 'beginner', placementSessionId) {
  const r = await post(a, '/v1/enrollments', user, {
    courseId: 'vi_en',
    startPoint,
    ...(placementSessionId ? { placementSessionId } : {}),
  });
  assert.equal(r.status, 200, JSON.stringify(r.body));
  valid('Enrollment', r.body);
  return r.body;
}
async function start(a, user, lessonId, mode = 'LESSON', expectedEnrollmentRevision, key) {
  const path = await a.call('GET', '/v1/courses/vi_en/path', { user });
  const revision =
    expectedEnrollmentRevision ?? (path.status === 200 ? path.body.enrollment.revision : 0);
  return post(
    a,
    '/v1/sessions',
    user,
    { courseId: 'vi_en', lessonId, mode, expectedEnrollmentRevision: revision },
    key,
  );
}
/** Answer every queued item; `wrongIds` get a wrong first attempt then a right retry. */
async function playThrough(a, user, session, { wrongIds = [], assisted = false } = {}) {
  let revision = session.revision;
  const byId = new Map(session.bundle.exercises.map((e) => [e.id, e]));
  const queue = session.bundle.exercises.map((e) => [e.id, 0]);
  while (queue.length) {
    const [exerciseId, attemptOrdinal] = queue.shift();
    const ex = byId.get(exerciseId);
    const wrong = attemptOrdinal === 0 && wrongIds.includes(exerciseId);
    const r = await post(a, `/v1/sessions/${session.sessionId}/answers`, user, {
      exerciseId,
      attemptOrdinal,
      answer: wrong ? wrongAnswer(ex) : correctAnswer(ex),
      assisted,
      substituted: false,
      expectedRevision: revision,
    });
    assert.equal(r.status, 200, JSON.stringify(r.body));
    valid('AnswerResult', r.body);
    assert.equal(r.body.correct, !wrong);
    revision = r.body.sessionRevision;
    if (wrong) queue.push([exerciseId, 1]);
  }
  return revision;
}
async function completeLesson(a, user, lessonId, opts) {
  const s = await start(a, user, lessonId, opts?.mode ?? 'LESSON');
  assert.equal(s.status, 200, JSON.stringify(s.body));
  const revision = await playThrough(a, user, s.body, opts);
  const c = await post(a, `/v1/sessions/${s.body.sessionId}/complete`, user, {
    expectedRevision: revision,
  });
  assert.equal(c.status, 200, JSON.stringify(c.body));
  valid('Completion', c.body);
  return { session: s.body, completion: c.body };
}

test('catalog: list courses, manifest and bundle are published, signed and schema-valid', async () => {
  const a = await app();
  const list = await a.call('GET', '/v1/courses', { user: 'u1' });
  assert.equal(list.status, 200);
  valid('CoursePage', list.body);
  assert.deepEqual(
    list.body.items.map((c) => [c.courseId, c.publishedVersion, c.available]),
    [['vi_en', 'v2', true]],
  );
  const manifest = await a.call('GET', '/v1/courses/vi_en/manifest', { user: 'u1' });
  valid('CourseManifest', manifest.body);
  assert.deepEqual(
    [
      manifest.body.sections.length,
      manifest.body.units.length,
      manifest.body.nodes.length,
      manifest.body.bundles.length,
    ],
    [2, 16, 128, 512],
  );
  const bundle = await a.call('GET', '/v1/lessons/u3n2l1/bundle', { user: 'u1' });
  valid('LessonBundle', bundle.body);
  assert.equal(bundle.body.exercises.length, 13);
  assert.equal(bundle.body.rewardIdentity, 'v2.u3n2l1');
  // Duolingo-style unit: 5 levels of 4-6 lessons, then story, unit review and Legendary.
  const unit1 = manifest.body.nodes.filter((n) => n.unitId === 'u1');
  assert.deepEqual(
    unit1.map((n) => [n.kind, n.lessonIds.length]),
    [
      ['lesson', 4],
      ['lesson', 5],
      ['lesson', 5],
      ['story', 2],
      ['lesson', 6],
      ['lesson', 6],
      ['mastery', 2],
      ['mastery', 2],
    ],
  );
  assert.equal((await a.call('GET', '/v1/lessons/nope/bundle', { user: 'u1' })).status, 404);
  assert.equal((await a.call('GET', '/v1/courses', {})).status, 401, 'no JWT -> 401');
  assert.equal((await a.call('GET', '/v1/courses', { user: 'u1', query: 'bogus=1' })).status, 400);
});

test('enroll beginner: frontier at node 1; re-enroll (any key) returns the current frontier', async () => {
  const a = await app();
  const e = await enroll(a, 'amy');
  assert.deepEqual([e.frontierNodeOrder, e.revision, e.completedLessonIds], [0, 0, []]);
  const path = await a.call('GET', '/v1/courses/vi_en/path', { user: 'amy', query: 'limit=24' });
  valid('Path', path.body);
  assert.deepEqual(
    path.body.nodes.slice(0, 3).map((n) => n.state),
    ['available', 'locked', 'locked'],
  );
  const page = await a.call('GET', '/v1/courses/vi_en/path', { user: 'amy' });
  assert.equal(page.body.nodes.length, 24, 'default page = 24 nodes (3 units)');
  assert.notEqual(page.body.nextCursor, null);
  let seen = 0;
  let cursor = null;
  do {
    const r = await a.call('GET', '/v1/courses/vi_en/path', {
      user: 'amy',
      query: `limit=100${cursor ? `&cursor=${cursor}` : ''}`,
    });
    seen += r.body.nodes.length;
    cursor = r.body.nextCursor;
  } while (cursor);
  assert.equal(seen, 128);
  assert.equal(
    (await a.call('GET', '/v1/courses/vi_en/path', { user: 'bob' })).status,
    404,
    'not enrolled',
  );
});

for (const [correct, unlocksUnit2] of [
  [8, true],
  [7, false],
]) {
  test(`placement ${correct}/10 -> ${unlocksUnit2 ? 'unit 2' : 'node 1'}; no reward event; cannot repeat`, async () => {
    const a = await app();
    const s = await start(a, 'pia', 'placement', 'PLACEMENT', 0);
    assert.equal(s.status, 200, JSON.stringify(s.body));
    const wrongIds = s.body.bundle.exercises.slice(0, 10 - correct).map((e) => e.id);
    const revision = await playThrough(a, 'pia', s.body, { wrongIds });
    const c = await post(a, `/v1/sessions/${s.body.sessionId}/complete`, 'pia', {
      expectedRevision: revision,
    });
    assert.deepEqual(
      [c.body.mode, c.body.originalCorrect, c.body.rewardStatus],
      ['PLACEMENT', correct, 'notEligible'],
    );
    assert.equal(a.persistence.dump('l_outbox').length, 0, 'PLACEMENT emits no lesson.completed');
    const e = await enroll(a, 'pia', 'placement', s.body.sessionId);
    assert.equal(e.frontierNodeOrder, unlocksUnit2 ? 8 : 0);
    const again = await start(a, 'pia', 'placement', 'PLACEMENT');
    assert.equal(again.body.error.code, 'NODE_LOCKED');
    const reEnroll = await enroll(a, 'pia', 'beginner');
    assert.equal(reEnroll.frontierNodeOrder, e.frontierNodeOrder, 'no regression');
  });
}

test('lesson flow: start pins bundle; answers; complete updates frontier once; event pending; replay is stable', async () => {
  const a = await app();
  await enroll(a, 'leo');
  const key = randomUUID();
  const s = await start(a, 'leo', 'u1n1l1', 'LESSON', 0, key);
  assert.equal(s.status, 200, JSON.stringify(s.body));
  valid('Session', s.body);
  assert.deepEqual(
    [s.body.status, s.body.revision, s.body.bundle.lessonId, s.body.lastFeedback],
    ['ACTIVE', 0, 'u1n1l1', null],
  );
  const replay = await start(a, 'leo', 'u1n1l1', 'LESSON', 0, key);
  assert.equal(replay.body.sessionId, s.body.sessionId, 'same key -> same session');
  const changed = await post(
    a,
    '/v1/sessions',
    'leo',
    { courseId: 'vi_en', lessonId: 'u1n1l2', mode: 'LESSON', expectedEnrollmentRevision: 0 },
    key,
  );
  assert.equal(changed.body.error.code, 'IDEMPOTENCY_CONFLICT');

  const first = s.body.bundle.exercises[0];
  const answerKey = randomUUID();
  const body = {
    exerciseId: first.id,
    attemptOrdinal: 0,
    answer: correctAnswer(first),
    assisted: false,
    substituted: false,
    expectedRevision: 0,
  };
  const r1 = await post(a, `/v1/sessions/${s.body.sessionId}/answers`, 'leo', body, answerKey);
  const r1again = await post(a, `/v1/sessions/${s.body.sessionId}/answers`, 'leo', body, answerKey);
  assert.deepEqual(r1again.body, r1.body, 'duplicate answer returns the same result');
  assert.equal(a.persistence.dump('l_answers').length, 1, 'no double count');
  const conflict = await post(
    a,
    `/v1/sessions/${s.body.sessionId}/answers`,
    'leo',
    { ...body, answer: wrongAnswer(first) },
    answerKey,
  );
  assert.equal(conflict.body.error.code, 'IDEMPOTENCY_CONFLICT');
  const early = await post(a, `/v1/sessions/${s.body.sessionId}/complete`, 'leo', {
    expectedRevision: 1,
  });
  assert.deepEqual([early.status, early.body.error.code], [409, 'SESSION_INCOMPLETE']);
  const view = await a.call('GET', `/v1/sessions/${s.body.sessionId}`, { user: 'leo' });
  valid('Session', view.body);
  assert.deepEqual(
    [view.body.revision, view.body.answerHistory.length, view.body.lastFeedback.correct],
    [1, 1, true],
  );

  const revision = await playThrough(
    a,
    'leo',
    {
      ...view.body,
      bundle: { ...view.body.bundle, exercises: view.body.bundle.exercises.slice(1) },
    },
    { wrongIds: [view.body.bundle.exercises[3].id] },
  );
  const completeKey = randomUUID();
  const c = await post(
    a,
    `/v1/sessions/${s.body.sessionId}/complete`,
    'leo',
    { expectedRevision: revision },
    completeKey,
  );
  assert.equal(c.status, 200, JSON.stringify(c.body));
  valid('Completion', c.body);
  assert.deepEqual(
    [c.body.originalCount, c.body.originalCorrect, c.body.rewardStatus, c.body.needsReviewIds],
    [13, 12, 'pending', []],
  );
  const sameKey = await post(
    a,
    `/v1/sessions/${s.body.sessionId}/complete`,
    'leo',
    { expectedRevision: revision },
    completeKey,
  );
  const newKey = await post(a, `/v1/sessions/${s.body.sessionId}/complete`, 'leo', {
    expectedRevision: revision,
  });
  assert.deepEqual(sameKey.body, c.body);
  assert.deepEqual(newKey.body, c.body, 'retry with a new key returns the original completion');
  const outbox = a.persistence.dump('l_outbox');
  assert.equal(outbox.length, 1, 'exactly one outbox event');
  const event = JSON.parse(outbox[0].row.payloadJson);
  valid('BusinessEvent', event);
  assert.deepEqual(
    [
      event.payload.completionId,
      event.payload.userId,
      event.payload.originalCorrect,
      event.payload.mode,
      outbox[0].row.status,
    ],
    [s.body.sessionId, 'leo', 12, 'LESSON', 'PENDING'],
  );
  const path = await a.call('GET', '/v1/courses/vi_en/path', { user: 'leo' });
  assert.deepEqual(
    [
      path.body.enrollment.completedLessonIds,
      path.body.enrollment.frontierNodeOrder,
      path.body.nodes[0].state,
    ],
    [['u1n1l1'], 0, 'current'],
  );
  assert.equal(a.persistence.dump('l_active_slots').length, 0, 'slot released');
  assert.ok(
    a.persistence.dump('l_review_items').length > 0,
    'review items scheduled in the completion transaction',
  );
});

test('locks: later lessons/nodes are locked; not enrolled; stale enrollment revision', async () => {
  const a = await app();
  assert.equal((await start(a, 'nia', 'u1n1l1', 'LESSON', 0)).body.error.code, 'NOT_FOUND');
  await enroll(a, 'nia');
  const locked = await start(a, 'nia', 'u1n2l1', 'LESSON', 0);
  assert.deepEqual(
    [locked.status, locked.body.error.code, locked.body.error.details.currentNodeId],
    [409, 'NODE_LOCKED', 'u1n1'],
  );
  assert.equal((await start(a, 'nia', 'u1n1l2', 'LESSON', 0)).body.error.code, 'NODE_LOCKED');
  assert.equal((await start(a, 'nia', 'u1n1l1', 'LESSON', 5)).body.error.code, 'REVISION_CONFLICT');
  assert.equal((await start(a, 'nia', 'u1n1l1', 'MASTERY', 0)).body.error.code, 'NODE_LOCKED');
});

test('completing every lesson of a level advances the frontier; mastery >=80% marks the node mastered', async () => {
  const a = await app();
  await enroll(a, 'max');
  await completeLesson(a, 'max', 'u1n1l1');
  await completeLesson(a, 'max', 'u1n1l2');
  await completeLesson(a, 'max', 'u1n1l3');
  let path = await a.call('GET', '/v1/courses/vi_en/path', { user: 'max' });
  assert.deepEqual(
    [path.body.enrollment.frontierNodeOrder, path.body.nodes[0].state],
    [0, 'current'],
    'level 1 has 4 lessons: 3 of 4 keeps the frontier',
  );
  const fourth = await completeLesson(a, 'max', 'u1n1l4');
  assert.equal(fourth.completion.enrollmentRevision, 4);
  path = await a.call('GET', '/v1/courses/vi_en/path', { user: 'max' });
  assert.deepEqual(
    [path.body.enrollment.frontierNodeOrder, path.body.nodes[0].state, path.body.nodes[1].state],
    [1, 'completed', 'available'],
  );
  const failed = await completeLesson(a, 'max', 'u1n1l1', {
    mode: 'MASTERY',
    wrongIds: ['u1n1l1-e01', 'u1n1l1-e02', 'u1n1l1-e03'],
  });
  assert.equal(failed.completion.originalCorrect, 10);
  path = await a.call('GET', '/v1/courses/vi_en/path', { user: 'max' });
  assert.equal(path.body.nodes[0].state, 'completed', '10/13 (77%) is practice only');
  await completeLesson(a, 'max', 'u1n1l1', {
    mode: 'MASTERY',
    wrongIds: ['u1n1l1-e01', 'u1n1l1-e02'],
  });
  path = await a.call('GET', '/v1/courses/vi_en/path', { user: 'max' });
  assert.deepEqual(
    [path.body.nodes[0].state, path.body.enrollment.masteredNodeIds],
    ['mastered', ['u1n1']],
  );
  // Replay of a completed lesson: practice, frontier unchanged.
  await completeLesson(a, 'max', 'u1n1l1');
  path = await a.call('GET', '/v1/courses/vi_en/path', { user: 'max' });
  assert.equal(path.body.enrollment.frontierNodeOrder, 1);
});

test('two devices answering the same item with the same revision: exactly one wins', async () => {
  const a = await app();
  await enroll(a, 'duo');
  const s = (await start(a, 'duo', 'u1n1l1')).body;
  const ex = s.bundle.exercises[0];
  const body = (answer) => ({
    exerciseId: ex.id,
    attemptOrdinal: 0,
    answer,
    assisted: false,
    substituted: false,
    expectedRevision: 0,
  });
  const [x, y] = await Promise.all([
    post(a, `/v1/sessions/${s.sessionId}/answers`, 'duo', body(correctAnswer(ex))),
    post(a, `/v1/sessions/${s.sessionId}/answers`, 'duo', body(wrongAnswer(ex))),
  ]);
  const statuses = [x.status, y.status].sort();
  assert.deepEqual(statuses, [200, 409], JSON.stringify([x.body, y.body]));
  const loser = x.status === 409 ? x : y;
  assert.ok(['REVISION_CONFLICT', 'SESSION_CONFLICT'].includes(loser.body.error.code));
  assert.equal(a.persistence.dump('l_answers').length, 1);
  const view = await a.call('GET', `/v1/sessions/${s.sessionId}`, { user: 'duo' });
  assert.equal(view.body.revision, 1);
  // Out-of-order item is refused with the expected item.
  const skip = await post(a, `/v1/sessions/${s.sessionId}/answers`, 'duo', {
    ...body(correctAnswer(s.bundle.exercises[2])),
    exerciseId: s.bundle.exercises[2].id,
    expectedRevision: 1,
  });
  assert.deepEqual(
    [skip.body.error.code, skip.body.error.details.expected.exerciseId],
    ['SESSION_CONFLICT', s.bundle.exercises[1].id],
  );
  // Concurrent completes with different keys -> one completion, one event.
  const revision = await playThrough(a, 'duo', {
    ...view.body,
    bundle: { ...view.body.bundle, exercises: view.body.bundle.exercises.slice(1) },
  });
  const done = await Promise.all(
    [1, 2, 3].map(() =>
      post(a, `/v1/sessions/${s.sessionId}/complete`, 'duo', { expectedRevision: revision }),
    ),
  );
  assert.ok(
    done.every((r) => r.status === 200 && r.body.completionId === s.sessionId),
    JSON.stringify(done.map((d) => d.body)),
  );
  assert.equal(a.persistence.dump('l_outbox').length, 1);
});

test('uncertain commit: a failed completion commit leaves nothing; the same key then commits once', async () => {
  const a = await app();
  await enroll(a, 'unc');
  const s = (await start(a, 'unc', 'u1n1l1')).body;
  const revision = await playThrough(a, 'unc', s);
  const key = randomUUID();
  a.persistence.failNextCommit = true;
  const failed = await post(
    a,
    `/v1/sessions/${s.sessionId}/complete`,
    'unc',
    { expectedRevision: revision },
    key,
  );
  assert.deepEqual(
    [failed.status, failed.body.error.code, failed.body.error.retryable],
    [503, 'DB_UNAVAILABLE', true],
  );
  assert.equal(a.persistence.dump('l_outbox').length, 0);
  assert.equal(
    (await a.call('GET', `/v1/sessions/${s.sessionId}`, { user: 'unc' })).body.status,
    'ACTIVE',
  );
  const ok = await post(
    a,
    `/v1/sessions/${s.sessionId}/complete`,
    'unc',
    { expectedRevision: revision },
    key,
  );
  assert.equal(ok.status, 200);
  assert.equal(a.persistence.dump('l_outbox').length, 1);
});

test('one active session per user/course; abandon releases it; expiry frees it; cross-user is NOT_FOUND', async () => {
  let now = Date.parse('2026-10-12T08:00:00Z');
  const a = await app({ nowMs: () => now });
  await enroll(a, 'sol');
  const s1 = (await start(a, 'sol', 'u1n1l1')).body;
  const blocked = await start(a, 'sol', 'u1n1l1');
  assert.deepEqual(
    [blocked.body.error.code, blocked.body.error.details.activeSessionId],
    ['SESSION_CONFLICT', s1.sessionId],
  );
  assert.equal((await a.call('GET', `/v1/sessions/${s1.sessionId}`, { user: 'eve' })).status, 404);
  assert.equal(
    (await post(a, `/v1/sessions/${s1.sessionId}/abandon`, 'eve', { expectedRevision: 0 })).status,
    404,
  );
  const ab = await post(a, `/v1/sessions/${s1.sessionId}/abandon`, 'sol', { expectedRevision: 0 });
  assert.deepEqual([ab.status, ab.body.status], [200, 'accepted']);
  valid('Receipt', ab.body);
  assert.equal(
    (await post(a, `/v1/sessions/${s1.sessionId}/abandon`, 'sol', { expectedRevision: 0 })).body
      .status,
    'replayed',
  );
  assert.equal(
    (await post(a, `/v1/sessions/${s1.sessionId}/complete`, 'sol', { expectedRevision: 1 })).body
      .error.code,
    'SESSION_CONFLICT',
  );
  const s2 = (await start(a, 'sol', 'u1n1l1')).body;
  now += 25 * 3600 * 1000;
  const view = await a.call('GET', `/v1/sessions/${s2.sessionId}`, { user: 'sol' });
  assert.equal(view.body.status, 'EXPIRED');
  const ex = s2.bundle.exercises[0];
  const late = await post(a, `/v1/sessions/${s2.sessionId}/answers`, 'sol', {
    exerciseId: ex.id,
    attemptOrdinal: 0,
    answer: correctAnswer(ex),
    assisted: false,
    substituted: false,
    expectedRevision: 0,
  });
  assert.equal(late.body.error.code, 'SESSION_EXPIRED');
  const s3 = await start(a, 'sol', 'u1n1l1');
  assert.equal(s3.status, 200, 'expired holder is replaced');
});

test('hint marks assisted; capability substitution grades the authored alternative', async () => {
  const a = await app();
  await enroll(a, 'hal');
  await completeLesson(a, 'hal', 'u1n1l1');
  await completeLesson(a, 'hal', 'u1n1l2');
  await completeLesson(a, 'hal', 'u1n1l3');
  const s = (await start(a, 'hal', 'u1n1l4')).body; // level 1 speaking lesson
  const speak = s.bundle.exercises[0];
  assert.equal(speak.type, 'speakRepeat');
  const alt = speak.nonSpeechAlternative;
  const r = await post(a, `/v1/sessions/${s.sessionId}/answers`, 'hal', {
    exerciseId: speak.id,
    attemptOrdinal: 0,
    answer: correctAnswer(alt),
    assisted: true,
    substituted: true,
    expectedRevision: 0,
  });
  assert.equal(r.body.correct, true, JSON.stringify(r.body));
  const rest = {
    ...s,
    revision: 1,
    bundle: { ...s.bundle, exercises: s.bundle.exercises.slice(1) },
  };
  const revision = await playThrough(a, 'hal', rest);
  const c = await post(a, `/v1/sessions/${s.sessionId}/complete`, 'hal', {
    expectedRevision: revision,
  });
  assert.deepEqual([c.body.assisted, c.body.originalCorrect], [true, s.bundle.exercises.length]);
});

test('validation: missing/invalid Idempotency-Key, unknown body fields, wrong answer shape', async () => {
  const a = await app();
  const noKey = await a.call('POST', '/v1/enrollments', {
    user: 'v',
    body: { courseId: 'vi_en', startPoint: 'beginner' },
  });
  assert.deepEqual([noKey.status, noKey.body.error.details.field], [400, 'Idempotency-Key']);
  const extra = await post(a, '/v1/enrollments', 'v', {
    courseId: 'vi_en',
    startPoint: 'beginner',
    xp: 99,
  });
  assert.equal(extra.body.error.details.reason, 'UNKNOWN_FIELD');
  await enroll(a, 'v');
  const s = (await start(a, 'v', 'u1n1l1')).body;
  const ex = s.bundle.exercises[0];
  const shape = await post(a, `/v1/sessions/${s.sessionId}/answers`, 'v', {
    exerciseId: ex.id,
    attemptOrdinal: 0,
    answer: { kind: 'tokens', tokenIds: ['t1'] },
    assisted: false,
    substituted: false,
    expectedRevision: 0,
  });
  assert.deepEqual([shape.status, shape.body.error.details.reason], [400, 'ANSWER_KIND_MISMATCH']);
  assert.equal((await a.call('GET', '/v1/sessions/..%2Fx', { user: 'v' })).status, 404);
});
