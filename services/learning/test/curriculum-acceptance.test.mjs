import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import { correctAnswer } from './helpers/answers.mjs';
import { loadKit } from './helpers/kit.mjs';

const kit = await loadKit('curriculum-acceptance');
const post = (app, route, user, body) => app.call('POST', route, { user, body, key: randomUUID() });

test('published catalog serves all 512 signed lesson bundles through the router', async () => {
  const app = await kit.createTestApp();
  const manifest = await app.call('GET', '/v1/courses/vi_en/manifest', { user: 'catalog-audit' });
  assert.equal(manifest.status, 200);
  assert.equal(manifest.body.bundles.length, 512);

  for (const index of manifest.body.bundles) {
    const response = await app.call('GET', `/v1/lessons/${index.lessonId}/bundle`, {
      user: 'catalog-audit',
    });
    assert.equal(response.status, 200, index.lessonId);
    assert.equal(response.body.lessonId, index.lessonId);
    assert.equal(response.body.lessonVersion, index.lessonVersion);
    assert.ok(response.body.exercises.length > 0, index.lessonId);
  }
});

test('each of 16 unit families starts, answers, and completes through the router', async () => {
  const app = await kit.createTestApp();
  const manifest = (await app.call('GET', '/v1/courses/vi_en/manifest', { user: 'family-audit' }))
    .body;
  assert.equal(manifest.units.length, 16);

  for (const unit of manifest.units) {
    const node = manifest.nodes.find((candidate) => candidate.unitId === unit.unitId);
    assert.ok(node, unit.unitId);
    const lessonId = node.lessonIds[0];
    const user = `family-${unit.unitId}`;
    const enrolled = await post(app, '/v1/enrollments', user, {
      courseId: 'vi_en',
      startPoint: 'beginner',
    });
    assert.equal(enrolled.status, 200, unit.unitId);
    // Select this unit's frontier through the memory test adapter. The session,
    // answers and completion still travel through the production router/use cases.
    await app.persistence.transact(async (tx) => {
      const id = kit.ids.enrollment(user, 'vi_en');
      const row = await tx.get('l_enrollments', id);
      assert.ok(row, unit.unitId);
      tx.put('l_enrollments', id, { ...row, frontierNodeOrder: node.order });
    });
    const started = await post(app, '/v1/sessions', user, {
      courseId: 'vi_en',
      lessonId,
      mode: 'LESSON',
      expectedEnrollmentRevision: 0,
    });
    assert.equal(started.status, 200, `${lessonId}: ${JSON.stringify(started.body)}`);

    let revision = started.body.revision;
    for (const exercise of started.body.bundle.exercises) {
      const answered = await post(app, `/v1/sessions/${started.body.sessionId}/answers`, user, {
        exerciseId: exercise.id,
        attemptOrdinal: 0,
        answer: correctAnswer(exercise),
        assisted: false,
        substituted: false,
        expectedRevision: revision,
      });
      assert.equal(answered.status, 200, `${lessonId}/${exercise.id}`);
      assert.equal(answered.body.correct, true, `${lessonId}/${exercise.id}`);
      revision = answered.body.sessionRevision;
    }
    const completed = await post(app, `/v1/sessions/${started.body.sessionId}/complete`, user, {
      expectedRevision: revision,
    });
    assert.equal(completed.status, 200, `${lessonId}: ${JSON.stringify(completed.body)}`);
    assert.equal(completed.body.sessionId, started.body.sessionId);
    assert.equal(completed.body.originalCount, started.body.bundle.exercises.length);
    assert.equal(completed.body.originalCorrect, started.body.bundle.exercises.length);
    assert.equal(completed.body.rewardStatus, 'pending');
  }
  assert.equal(app.persistence.dump('l_outbox').length, 16);
});
