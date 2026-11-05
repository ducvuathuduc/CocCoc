// FR-ACTIVITY-001/002 (SRS "Authored activity session modes", 2026-10-28): eight authored modes
// over the real router/use cases. Activity modes earn the normal lesson completion event and never
// move the frontier; TEST_OUT/CHECKPOINT gate progression on an authored threshold, emit no reward
// and only move the frontier on pass.
import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { loadKit } from './helpers/kit.mjs';
import { correctAnswer, wrongAnswer } from './helpers/answers.mjs';
import { authoredContent } from './helpers/authored-content.mjs';

const kit = await loadKit('activity-modes');

const post = (a, path, user, body, key = randomUUID()) => a.call('POST', path, { user, body, key });

async function app(options) {
  return kit.createTestApp(options);
}

async function enroll(a, user) {
  const r = await post(a, '/v1/enrollments', user, { courseId: 'vi_en', startPoint: 'beginner' });
  assert.equal(r.status, 200, JSON.stringify(r.body));
  return r.body;
}

async function startActivity(a, user, lessonId, mode, extra = {}) {
  const path = await a.call('GET', '/v1/courses/vi_en/path', { user });
  return post(a, '/v1/sessions', user, {
    courseId: 'vi_en',
    lessonId,
    mode,
    expectedEnrollmentRevision: path.status === 200 ? path.body.enrollment.revision : 0,
    ...extra,
  });
}

/** Answer every queued item; `wrongIds` get a wrong first attempt then a right retry. */
async function playThrough(a, user, session, { wrongIds = [] } = {}) {
  let revision = session.revision;
  const byId = new Map(session.bundle.exercises.map((e) => [e.id, e]));
  const queue = session.bundle.exercises.map((e) => [e.id, 0]);
  while (queue.length) {
    const [exerciseId, attemptOrdinal] = queue.shift();
    const exercise = byId.get(exerciseId);
    const wrong = attemptOrdinal === 0 && wrongIds.includes(exerciseId);
    const r = await post(a, `/v1/sessions/${session.sessionId}/answers`, user, {
      exerciseId,
      attemptOrdinal,
      answer: wrong ? wrongAnswer(exercise) : correctAnswer(exercise),
      assisted: false,
      substituted: false,
      expectedRevision: revision,
    });
    assert.equal(r.status, 200, JSON.stringify(r.body));
    revision = r.body.sessionRevision;
    if (wrong) queue.push([exerciseId, 1]);
  }
  return revision;
}

async function playAndComplete(a, user, session, options) {
  const revision = await playThrough(a, user, session, options);
  return post(a, `/v1/sessions/${session.sessionId}/complete`, user, {
    expectedRevision: revision,
  });
}

async function completeLesson(a, user, lessonId) {
  const started = await startActivity(a, user, lessonId, 'LESSON');
  assert.equal(started.status, 200, JSON.stringify(started.body));
  const completed = await playAndComplete(a, user, started.body);
  assert.equal(completed.status, 200, JSON.stringify(completed.body));
}

// The committed content carries no authored mode configuration, so its authored test-out and
// checkpoint are unavailable and CLASH has no server-known scripted opponent.
const PATCHES = {
  u1n1l1: { passThreshold: 0.8, opponents: ['coach'], defaultOpponentId: 'coach' },
  u1n2l1: { passThreshold: 0.8 },
  u1n3l1: { modes: ['TEST_OUT'] },
};

let authoredAppPromise;
function authoredApp() {
  authoredAppPromise ??= (async () => {
    const authored = await authoredContent(kit, PATCHES);
    const a = await app({ seed: false, files: authored.files });
    const published = await post(a, '/v1/admin/content-versions', 'maintainer-1', {
      ...authored.publication,
      expectedPublishedVersion: null,
    });
    assert.equal(published.status, 200, JSON.stringify(published.body));
    return a;
  })();
  return authoredAppPromise;
}

for (const mode of ['STORIES', 'ADVENTURE', 'RADIO', 'SIDE_QUEST', 'UNIT_REVIEW']) {
  test(`${mode}: authored completion emits the lesson event and does not move the frontier`, async () => {
    const a = await app();
    const user = `act-${mode}`;
    await enroll(a, user);
    const started = await startActivity(a, user, 'u1n1l1', mode);
    assert.equal(started.status, 200, JSON.stringify(started.body));
    assert.equal(started.body.mode, mode);
    const completed = await playAndComplete(a, user, started.body);
    assert.equal(completed.status, 200, JSON.stringify(completed.body));
    assert.deepEqual(
      [completed.body.mode, completed.body.rewardStatus, completed.body.passed],
      [mode, 'pending', undefined],
    );
    const path = (await a.call('GET', '/v1/courses/vi_en/path', { user })).body;
    assert.deepEqual(
      [path.enrollment.frontierNodeOrder, path.enrollment.completedLessonIds],
      [0, []],
      'no frontier change',
    );
    const outbox = a.persistence.dump('l_outbox');
    assert.equal(outbox.length, 1);
    assert.equal(JSON.parse(outbox[0].row.payloadJson).payload.mode, mode);
    assert.ok(a.persistence.dump('l_review_items').length > 0, 'review evidence recorded');
  });
}

test('CLASH: an unresolved scripted opponent is OPPONENT_UNAVAILABLE; absent is allowed', async () => {
  const a = await app();
  await enroll(a, 'clasher');
  const ghost = await startActivity(a, 'clasher', 'u1n1l1', 'CLASH', { opponentId: 'ghost' });
  assert.deepEqual([ghost.status, ghost.body.error.code], [503, 'OPPONENT_UNAVAILABLE']);
  const started = await startActivity(a, 'clasher', 'u1n1l1', 'CLASH');
  assert.equal(started.status, 200, JSON.stringify(started.body));
  assert.equal(started.body.mode, 'CLASH');
  assert.equal(started.body.opponentId, undefined, 'no authored default opponent');
});

test('authored modes use ACTIVITY_NOT_FOUND for an unknown activity; LESSON keeps NOT_FOUND', async () => {
  const a = await app();
  await enroll(a, 'ghosty');
  const authored = await startActivity(a, 'ghosty', 'nope', 'STORIES');
  assert.deepEqual([authored.status, authored.body.error.code], [404, 'ACTIVITY_NOT_FOUND']);
  const lesson = await startActivity(a, 'ghosty', 'nope', 'LESSON');
  assert.deepEqual([lesson.status, lesson.body.error.code], [404, 'NOT_FOUND']);
});

test('TEST_OUT/CHECKPOINT without an authored passThreshold are MODE_UNAVAILABLE', async () => {
  const a = await app();
  await enroll(a, 'gated');
  for (const mode of ['TEST_OUT', 'CHECKPOINT']) {
    const r = await startActivity(a, 'gated', 'u1n1l1', mode);
    assert.deepEqual(
      [r.status, r.body.error.code],
      [400, 'MODE_UNAVAILABLE'],
      JSON.stringify(r.body),
    );
  }
});

test('TEST_OUT pass marks the target unit complete and advances the frontier with zero reward', async () => {
  const a = await authoredApp();
  const user = 'tout-pass';
  await enroll(a, user);
  const started = await startActivity(a, user, 'u1n1l1', 'TEST_OUT');
  assert.equal(started.status, 200, JSON.stringify(started.body));
  assert.deepEqual([started.body.mode, started.body.passThreshold], ['TEST_OUT', 0.8]);
  assert.equal(
    started.body.bundle.modeConfig,
    undefined,
    'internal config never leaks on the wire',
  );
  const completed = await playAndComplete(a, user, started.body);
  assert.equal(completed.status, 200, JSON.stringify(completed.body));
  assert.deepEqual(
    [completed.body.passed, completed.body.rewardStatus, completed.body.unlockedNodeId],
    [true, 'notEligible', 'u2n1'],
  );
  assert.equal(a.persistence.dump('l_outbox').length, 0, 'no reward-bearing event');
  assert.equal(a.persistence.dump('l_review_items').length, 0, 'no review evidence');
  const path = (await a.call('GET', '/v1/courses/vi_en/path', { user })).body;
  assert.equal(path.enrollment.frontierNodeOrder, 8, 'frontier past unit 1');
  assert.ok(path.enrollment.completedLessonIds.includes('u1n8l2'), 'unit lessons completed');
});

test('TEST_OUT fail changes nothing and reports passed=false', async () => {
  const a = await authoredApp();
  const user = 'tout-fail';
  await enroll(a, user);
  const started = await startActivity(a, user, 'u1n1l1', 'TEST_OUT');
  assert.equal(started.status, 200, JSON.stringify(started.body));
  const wrongIds = started.body.bundle.exercises.slice(0, 4).map((e) => e.id);
  const completed = await playAndComplete(a, user, started.body, { wrongIds });
  assert.equal(completed.status, 200, JSON.stringify(completed.body));
  assert.deepEqual(
    [completed.body.passed, completed.body.rewardStatus, completed.body.unlockedNodeId],
    [false, 'notEligible', undefined],
  );
  assert.equal(a.persistence.dump('l_outbox').length, 0);
  const path = (await a.call('GET', '/v1/courses/vi_en/path', { user })).body;
  assert.deepEqual(
    [path.enrollment.frontierNodeOrder, path.enrollment.completedLessonIds],
    [0, []],
    'fail changes nothing',
  );
});

test('CHECKPOINT is CHECKPOINT_LOCKED until the section prerequisites are complete', async () => {
  const a = await authoredApp();
  await enroll(a, 'chk-locked');
  const blocked = await startActivity(a, 'chk-locked', 'u1n2l1', 'CHECKPOINT');
  assert.deepEqual([blocked.status, blocked.body.error.code], [409, 'CHECKPOINT_LOCKED']);
});

test('CHECKPOINT pass marks the section complete and unlocks the next section', async () => {
  const a = await authoredApp();
  const user = 'chk-pass';
  await enroll(a, user);
  for (const lessonId of ['u1n1l1', 'u1n1l2', 'u1n1l3', 'u1n1l4'])
    await completeLesson(a, user, lessonId);
  const eventsBefore = a.persistence.dump('l_outbox').length;
  const started = await startActivity(a, user, 'u1n2l1', 'CHECKPOINT');
  assert.equal(started.status, 200, JSON.stringify(started.body));
  assert.equal(started.body.passThreshold, 0.8);
  const completed = await playAndComplete(a, user, started.body);
  assert.equal(completed.status, 200, JSON.stringify(completed.body));
  assert.deepEqual(
    [completed.body.passed, completed.body.rewardStatus, completed.body.unlockedNodeId],
    [true, 'notEligible', 'u9n1'],
  );
  assert.equal(a.persistence.dump('l_outbox').length, eventsBefore, 'checkpoint emits no event');
  const path = (await a.call('GET', '/v1/courses/vi_en/path', { user })).body;
  assert.equal(path.enrollment.frontierNodeOrder, 64, 'section 1 completed');
});

test('content that authors a modes list refuses other authored modes with MODE_UNAVAILABLE', async () => {
  const a = await authoredApp();
  await enroll(a, 'modes');
  const story = await startActivity(a, 'modes', 'u1n3l1', 'STORIES');
  assert.deepEqual([story.status, story.body.error.code], [400, 'MODE_UNAVAILABLE']);
  const testOut = await startActivity(a, 'modes', 'u1n3l1', 'TEST_OUT');
  assert.deepEqual([testOut.status, testOut.body.error.code], [400, 'MODE_UNAVAILABLE']);
});

test('CLASH resolves a supplied opponent to the authored scripted set and falls back to the default', async () => {
  const a = await authoredApp();
  const user = 'clash-authored';
  await enroll(a, user);
  const supplied = await startActivity(a, user, 'u1n1l1', 'CLASH', { opponentId: 'coach' });
  assert.equal(supplied.status, 200, JSON.stringify(supplied.body));
  assert.equal(supplied.body.opponentId, 'coach');
  await post(a, `/v1/sessions/${supplied.body.sessionId}/abandon`, user, { expectedRevision: 0 });
  const ghost = await startActivity(a, user, 'u1n1l1', 'CLASH', { opponentId: 'ghost' });
  assert.deepEqual([ghost.status, ghost.body.error.code], [503, 'OPPONENT_UNAVAILABLE']);
  const fallback = await startActivity(a, user, 'u1n1l1', 'CLASH');
  assert.equal(fallback.status, 200, JSON.stringify(fallback.body));
  assert.equal(fallback.body.opponentId, 'coach', 'authored deterministic opponent');
});
