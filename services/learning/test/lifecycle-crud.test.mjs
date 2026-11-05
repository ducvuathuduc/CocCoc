// One end-to-end learner lifecycle over the real Learning and Progress routers with in-memory
// adapters: enroll (create) -> read path/profile -> complete a lesson (update) -> the immediate
// relay signs lesson.completed.v1 over HTTP to Progress (HMAC) -> Progress credits XP and streak ->
// replaying the completion with the same Idempotency-Key is harmless -> abandoning a later session
// (delete) changes nothing. Production handlers and the contract are used as-is.
import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import Ajv from 'ajv/dist/2020.js';
import formats from 'ajv-formats';
import { loadKit } from './helpers/kit.mjs';
import { correctAnswer } from './helpers/answers.mjs';
import { kit as progressKit } from '../../progress/test/kit.mjs';

const learning = await loadKit('lifecycle-crud');

const api = JSON.parse(fs.readFileSync('docs/api/openapi.yaml', 'utf8'));
const ajv = new Ajv({ strict: false });
formats(ajv);
ajv.addSchema({ $id: 'https://coc.invalid/s', components: api.components });
const validators = new Map();
function valid(name, value) {
  if (!validators.has(name)) {
    validators.set(
      name,
      ajv.compile({ $ref: `https://coc.invalid/s#/components/schemas/${name}` }),
    );
  }
  const fn = validators.get(name);
  assert.ok(fn(value), `${name}: ${JSON.stringify(fn.errors?.slice(0, 3))}`);
  return value;
}

/** Real Progress router (memory store, fake subject auth) that verifies the Learning HMAC. */
function progressService(clock) {
  const store = progressKit.createMemoryProgressPersistence(() => clock.now, {
    strictSchema: true,
  });
  const wiring = progressKit.progressWiring(store, {}, { allowSimulatedCommerce: true });
  const router = progressKit.scopeProgressHandler(
    progressKit.createRouter({
      service: 'progress',
      persistence: store,
      mode: 'local-test',
      keyring: progressKit.createKeyring([learning.devKey('learning')]),
      auth: {
        async verify(jwt) {
          return { userId: jwt };
        },
      },
      routes: wiring.routes,
      eventConsumer: wiring.eventConsumer,
      nowMs: () => clock.now,
    }),
  );
  async function call(method, path, { user, body, key, query = '' } = {}) {
    const headers = {};
    if (user) headers.authorization = `Bearer ${user}`;
    if (method !== 'GET') headers['idempotency-key'] = key ?? randomUUID();
    let out;
    await router({
      req: {
        method,
        path,
        headers,
        bodyText: body === undefined ? '' : JSON.stringify(body),
        queryString: query,
      },
      res: { json: (b, status = 200) => (out = { status, body: b }) },
    });
    return out;
  }
  // Learning's signed outbox delivery reaches the Progress router as if over HTTP.
  const fetchImpl = async (url, init) => {
    const target = new URL(url);
    let out;
    await router({
      req: {
        method: init.method,
        path: target.pathname,
        headers: init.headers,
        bodyText: init.body,
        queryString: target.search.slice(1),
      },
      res: { json: (b, status = 200) => (out = { status, body: b }) },
    });
    return new Response(JSON.stringify(out.body), { status: out.status });
  };
  const deliver = learning.httpDeliver({
    key: learning.devKey('learning'),
    progressBaseUrl: 'http://progress.invalid',
    fetchImpl,
  });
  return { store, call, deliver };
}

test('lifecycle CRUD: enroll -> complete -> signed reward credit -> idempotent replay -> abandon', async () => {
  // One instant for both services: HMAC skew is checked against it and the reward day/streak
  // derive from the same lesson time.
  const clock = { now: Date.now() };
  const progress = progressService(clock);
  const app = await learning.createTestApp({ nowMs: () => clock.now, deliver: progress.deliver });
  const user = 'lifecycle';
  const post = (path, body, key = randomUUID()) => app.call('POST', path, { user, body, key });
  const progressPost = (path, body) => progress.call('POST', path, { user, body });
  const rewards = async (query = '') => {
    const r = await progress.call('GET', '/v1/me/rewards', { user, query });
    assert.equal(r.status, 200, JSON.stringify(r.body));
    return valid('Rewards', r.body);
  };
  const path = async () => {
    const r = await app.call('GET', '/v1/courses/vi_en/path', { user });
    assert.equal(r.status, 200, JSON.stringify(r.body));
    return valid('Path', r.body);
  };

  // CREATE: a Progress profile and an enrollment at the head of vi_en.
  assert.equal((await progressPost('/v1/me/initialize')).status, 200);
  const enrollment = await post('/v1/enrollments', { courseId: 'vi_en', startPoint: 'beginner' });
  assert.equal(enrollment.status, 200, JSON.stringify(enrollment.body));
  valid('Enrollment', enrollment.body);
  assert.deepEqual(
    [
      enrollment.body.frontierNodeOrder,
      enrollment.body.revision,
      enrollment.body.completedLessonIds,
    ],
    [0, 0, []],
  );

  // READ: the learner's path and profile start empty.
  const first = await path();
  assert.deepEqual(
    first.nodes.slice(0, 2).map((node) => node.state),
    ['available', 'locked'],
  );
  const me = await progress.call('GET', '/v1/me', { user });
  assert.equal(me.status, 200, JSON.stringify(me.body));
  valid('Profile', me.body);
  const before = await rewards();
  assert.deepEqual([before.studyXp, before.currentStreak], [0, 0]);

  // UPDATE: play a lesson correctly and complete it.
  async function completeLesson(lessonId) {
    const current = await path();
    const started = await post('/v1/sessions', {
      courseId: 'vi_en',
      lessonId,
      mode: 'LESSON',
      expectedEnrollmentRevision: current.enrollment.revision,
    });
    assert.equal(started.status, 200, JSON.stringify(started.body));
    valid('Session', started.body);
    const fresh = await app.call('GET', `/v1/sessions/${started.body.sessionId}`, { user });
    assert.deepEqual([fresh.body.status, fresh.body.revision], ['ACTIVE', 0]);
    assert.deepEqual(fresh.body.answerHistory, []);
    let revision = 0;
    for (const exercise of started.body.bundle.exercises) {
      const answered = await post(`/v1/sessions/${started.body.sessionId}/answers`, {
        exerciseId: exercise.id,
        attemptOrdinal: 0,
        answer: correctAnswer(exercise),
        assisted: false,
        substituted: false,
        expectedRevision: revision,
      });
      assert.equal(answered.status, 200, JSON.stringify(answered.body));
      assert.equal(answered.body.correct, true);
      revision = answered.body.sessionRevision;
    }
    const key = randomUUID();
    const completed = await post(
      `/v1/sessions/${started.body.sessionId}/complete`,
      { expectedRevision: revision },
      key,
    );
    assert.equal(completed.status, 200, JSON.stringify(completed.body));
    valid('Completion', completed.body);
    return { sessionId: started.body.sessionId, key, revision, completion: completed.body };
  }

  const lesson = await completeLesson('u1n1l1');
  const completedView = await app.call('GET', `/v1/sessions/${lesson.sessionId}`, { user });
  assert.equal(completedView.body.status, 'COMPLETED');
  // A level node unlocks only after all four of its lessons: finish the node to move the frontier.
  for (const lessonId of ['u1n1l2', 'u1n1l3', 'u1n1l4']) await completeLesson(lessonId);
  const advanced = await path();
  assert.deepEqual(
    [
      advanced.enrollment.frontierNodeOrder,
      advanced.enrollment.completedLessonIds.length,
      advanced.nodes[0].state,
      advanced.nodes[1].state,
    ],
    [1, 4, 'completed', 'available'],
  );

  // The completion event was signed, relayed and acknowledged; Progress credited the real award.
  const outbox = app.persistence.dump('l_outbox');
  assert.equal(outbox.length, 4);
  assert.ok(outbox.every((row) => row.row.status === 'ACK'));
  for (const row of outbox) valid('BusinessEvent', JSON.parse(row.row.payloadJson));
  const credited = await rewards(`completionId=${lesson.sessionId}`);
  assert.equal(credited.status, 'credited');
  assert.ok(credited.awardXp > 0, `awardXp: ${credited.awardXp}`);
  assert.ok(credited.studyXp > 0, `studyXp: ${credited.studyXp}`);
  assert.equal(credited.currentStreak, 1);
  const lessonLedger = () =>
    progress.store
      .dump('p_reward_ledger')
      .filter(({ row }) => row.userId === user && row.kind !== 'INITIAL');
  const ledger = lessonLedger();
  assert.equal(ledger.length, 4);
  assert.ok(ledger.every(({ row }) => row.studyXpDelta > 0));
  assert.equal(
    ledger.reduce((sum, { row }) => sum + row.studyXpDelta, 0),
    credited.studyXp,
  );
  assert.equal(progress.store.inboxSize, 4);

  // Idempotency: replaying the same completion with the same key returns the same result and
  // adds neither an outbox event nor XP.
  const replay = await post(
    `/v1/sessions/${lesson.sessionId}/complete`,
    { expectedRevision: lesson.revision },
    lesson.key,
  );
  assert.equal(replay.status, 200, JSON.stringify(replay.body));
  assert.deepEqual(replay.body, lesson.completion);
  assert.equal(app.persistence.dump('l_outbox').length, 4);
  assert.equal(progress.store.inboxSize, 4);
  const afterReplay = await rewards();
  assert.deepEqual(
    [afterReplay.studyXp, afterReplay.leagueXp, afterReplay.currentStreak],
    [credited.studyXp, credited.leagueXp, credited.currentStreak],
  );
  assert.equal(lessonLedger().length, 4);

  // DELETE/abandon: a started session that is abandoned never completes or credits anything.
  const open = await post('/v1/sessions', {
    courseId: 'vi_en',
    lessonId: 'u1n2l1',
    mode: 'LESSON',
    expectedEnrollmentRevision: advanced.enrollment.revision,
  });
  assert.equal(open.status, 200, JSON.stringify(open.body));
  const abandoned = await post(`/v1/sessions/${open.body.sessionId}/abandon`, {
    expectedRevision: open.body.revision,
  });
  assert.equal(abandoned.status, 200, JSON.stringify(abandoned.body));
  const abandonedView = await app.call('GET', `/v1/sessions/${open.body.sessionId}`, { user });
  assert.equal(abandonedView.body.status, 'ABANDONED');
  const lateCompletion = await post(`/v1/sessions/${open.body.sessionId}/complete`, {
    expectedRevision: 0,
  });
  assert.equal(lateCompletion.body.error.code, 'SESSION_CONFLICT');
  const finalPath = await path();
  assert.deepEqual(
    [finalPath.enrollment.frontierNodeOrder, finalPath.enrollment.completedLessonIds],
    [1, ['u1n1l1', 'u1n1l2', 'u1n1l3', 'u1n1l4']],
  );
  assert.equal(app.persistence.dump('l_outbox').length, 4);
  const afterAbandon = await rewards();
  assert.deepEqual(
    [afterAbandon.studyXp, afterAbandon.currentStreak],
    [credited.studyXp, credited.currentStreak],
  );
  assert.equal(progress.store.inboxSize, 4);
});
