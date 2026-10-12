// FR-LESSON-007 / FR-SYNC-001 syncOfflineCompletion: full server regrade of an offline answer log
// against the pinned signed bundle, queue-order replay, one completion per localCompletionId,
// source OFFLINE on the completion and the lesson.completed.v1 event, frontier advance.
import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import Ajv from 'ajv/dist/2020.js';
import formats from 'ajv-formats';
import { loadKit } from './helpers/kit.mjs';
import { correctAnswer, wrongAnswer } from './helpers/answers.mjs';

const kit = await loadKit('offline');
const api = JSON.parse(fs.readFileSync('docs/api/openapi.yaml', 'utf8'));
const ajv = new Ajv({ strict: false });
formats(ajv);
ajv.addSchema({ $id: 'https://x.invalid/s', components: api.components });
const valid = (name, value) => {
  const check = ajv.compile({ $ref: `https://x.invalid/s#/components/schemas/${name}` });
  assert.ok(check(value), `${name}: ${JSON.stringify(check.errors?.slice(0, 3))}`);
};

async function setup() {
  const a = await kit.createTestApp();
  const user = 'off';
  const post = (path, body, key = randomUUID()) => a.call('POST', path, { user, body, key });
  assert.equal(
    (await post('/v1/enrollments', { courseId: 'vi_en', startPoint: 'beginner' })).status,
    200,
  );
  const manifest = (await a.call('GET', '/v1/courses/vi_en/manifest', { user })).body;
  const pinned = async (lessonId) => {
    const index = manifest.bundles.find((b) => b.lessonId === lessonId);
    const bundle = (await a.call('GET', `/v1/lessons/${lessonId}/bundle`, { user })).body;
    return { index, bundle };
  };
  return { a, user, post, pinned };
}
/** Answer log as the offline client records it: originals, then a retry for each wrong one. */
function log(bundle, wrongIds = []) {
  const answers = bundle.exercises.map((ex) => ({
    exerciseId: ex.id,
    attemptOrdinal: 0,
    answer: wrongIds.includes(ex.id) ? wrongAnswer(ex) : correctAnswer(ex),
    assisted: false,
    substituted: false,
  }));
  for (const id of wrongIds) {
    const ex = bundle.exercises.find((e) => e.id === id);
    answers.push({
      exerciseId: id,
      attemptOrdinal: 1,
      answer: correctAnswer(ex),
      assisted: false,
      substituted: false,
    });
  }
  return answers;
}
const request = (index, answers, revision, extra = {}) => ({
  operationId: randomUUID(),
  localCompletionId: randomUUID(),
  courseId: 'vi_en',
  lessonId: index.lessonId,
  lessonVersion: index.lessonVersion,
  bundleHash: index.sha256,
  expectedEnrollmentRevision: revision,
  answers,
  ...extra,
});

test('offline completion: regraded, source OFFLINE, frontier + event, deduped by localCompletionId', async () => {
  const h = await setup();
  const { index, bundle } = await h.pinned('u1n1l1');
  const wrong = [bundle.exercises[2].id];
  const body = request(index, log(bundle, wrong), 0);
  valid('OfflineCompletionRequest', body);
  const r = await h.post('/v1/offline-completions', body);
  assert.equal(r.status, 200, JSON.stringify(r.body));
  valid('Completion', r.body);
  assert.deepEqual(
    [r.body.source, r.body.mode, r.body.originalCount, r.body.originalCorrect, r.body.rewardStatus],
    ['OFFLINE', 'LESSON', bundle.exercises.length, bundle.exercises.length - 1, 'pending'],
  );
  const path = (await h.a.call('GET', '/v1/courses/vi_en/path', { user: h.user })).body;
  assert.deepEqual(path.enrollment.completedLessonIds, ['u1n1l1']);
  const events = h.a.persistence.dump('l_outbox').map((x) => JSON.parse(x.row.payloadJson));
  assert.equal(events.length, 1);
  valid('BusinessEvent', events[0]);
  assert.deepEqual(
    [events[0].payload.source, events[0].payload.rewardIdentity, events[0].payload.completionId],
    ['OFFLINE', 'v2.u1n1l1', r.body.completionId],
  );
  // Same localCompletionId under a new Idempotency-Key/operationId: original completion, no event.
  const again = await h.post('/v1/offline-completions', { ...body, operationId: randomUUID() });
  assert.deepEqual(again.body, r.body);
  assert.equal(h.a.persistence.dump('l_outbox').length, 1, 'exactly one event');
  // A different log under the same localCompletionId is a conflict.
  const changed = await h.post('/v1/offline-completions', {
    ...body,
    answers: log(bundle),
  });
  assert.equal(changed.body.error?.code, 'IDEMPOTENCY_CONFLICT', JSON.stringify(changed.body));
});

test('offline completion: client verdicts are regraded; order, completeness, hash, lock and revision enforced', async () => {
  const h = await setup();
  const { index, bundle } = await h.pinned('u1n1l1');
  // A wrong answer the client claims was right still counts as wrong and needs its retry.
  const lying = log(bundle);
  lying[0] = { ...lying[0], answer: wrongAnswer(bundle.exercises[0]) };
  const incomplete = await h.post('/v1/offline-completions', request(index, lying, 0));
  assert.equal(incomplete.body.error?.code, 'SESSION_INCOMPLETE', JSON.stringify(incomplete.body));
  const swapped = log(bundle);
  [swapped[0], swapped[1]] = [swapped[1], swapped[0]];
  const order = await h.post('/v1/offline-completions', request(index, swapped, 0));
  assert.deepEqual([order.status, order.body.error?.details?.reason], [400, 'OUT_OF_ORDER']);
  const badHash = await h.post(
    '/v1/offline-completions',
    request(index, log(bundle), 0, { bundleHash: 'a'.repeat(64) }),
  );
  assert.equal(badHash.body.error?.details?.reason, 'BUNDLE_MISMATCH');
  const stale = await h.post('/v1/offline-completions', request(index, log(bundle), 3));
  assert.equal(stale.body.error?.code, 'REVISION_CONFLICT');
  const later = await h.pinned('u1n2l1');
  const locked = await h.post(
    '/v1/offline-completions',
    request(later.index, log(later.bundle), 0),
  );
  assert.equal(locked.body.error?.code, 'NODE_LOCKED');
  const unknown = await h.post('/v1/offline-completions', {
    ...request(index, log(bundle), 0),
    extra: 1,
  });
  assert.equal(unknown.status, 400);
  assert.equal(h.a.persistence.dump('l_outbox').length, 0, 'nothing committed');
});
