// Gated LIVE end-to-end: the real Learning router + use cases on the durable Appwrite adapter
// (TEST project), committed content files read locally. Publishes vi_en/v1 only if the TEST project
// has no vi_en course yet (and then removes it), enrolls a synthetic user, runs a full lesson with
// a wrong answer + retry, two-device conflict, completion with replay, and checks the outbox row.
// Enable: COC_LIVE_LEARNING_APPWRITE=1 APPWRITE_PROJECT_ID=... APPWRITE_API_KEY=... [NODE_USE_ENV_PROXY=1]
import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { Client, Query, TablesDB } from 'node-appwrite';
import { loadKit } from './helpers/kit.mjs';
import { correctAnswer, wrongAnswer } from './helpers/answers.mjs';

const enabled = process.env.COC_LIVE_LEARNING_APPWRITE === '1';
const skip = enabled
  ? false
  : 'live Appwrite gated: set COC_LIVE_LEARNING_APPWRITE=1 and APPWRITE_* env';
const endpoint = process.env.APPWRITE_ENDPOINT ?? 'https://sgp.cloud.appwrite.io/v1';
const projectId = process.env.APPWRITE_PROJECT_ID ?? '';
const apiKey = process.env.APPWRITE_API_KEY ?? '';
const databaseId = 'cocenglish';
const user = `t${Date.now().toString(36)}flow`;
let tables;
let publishedHere = false;
const cleanup = { eventIds: [], sessionIds: [] };

after(async () => {
  if (!enabled || !tables) return;
  const del = (tableId, rowId) =>
    tables.deleteRow({ databaseId, tableId, rowId }).catch(() => undefined);
  for (const tableId of [
    'l_enrollments',
    'l_active_slots',
    'l_sessions',
    'l_answers',
    'l_review_items',
    'l_receipts',
  ]) {
    for (let page = 0; page < 5; page++) {
      const rows = await tables
        .listRows({ databaseId, tableId, queries: [Query.equal('userId', user), Query.limit(100)] })
        .catch(() => ({ rows: [] }));
      if (!rows.rows.length) break;
      for (const row of rows.rows) await del(tableId, row.$id);
    }
  }
  for (const id of cleanup.eventIds) await del('l_outbox', id);
  if (publishedHere) {
    const kit = await loadKit('flow-live');
    await del('l_courses', kit.ids.course('vi_en'));
    await del('l_content_versions', kit.ids.contentVersion('vi_en', 'v1'));
    const receipts = await tables
      .listRows({
        databaseId,
        tableId: 'l_receipts',
        queries: [
          Query.equal('userId', 'system'),
          Query.equal('operation', 'publishContent'),
          Query.limit(100),
        ],
      })
      .catch(() => ({ rows: [] }));
    for (const row of receipts.rows) await del('l_receipts', row.$id);
  }
});

test(
  'live flow: enroll -> lesson with retry -> two-device conflict -> complete once -> outbox PENDING',
  { skip, timeout: 600_000 },
  async () => {
    const kit = await loadKit('flow-live');
    tables = new TablesDB(new Client().setEndpoint(endpoint).setProject(projectId).setKey(apiKey));
    const persistence = kit.createAppwriteLearningPersistence(
      { endpoint, projectId, apiKey, databaseId, admittedForHosting: false },
      tables,
    );
    const existing = await persistence.read('l_courses', kit.ids.course('vi_en'));
    publishedHere = !existing;
    const a = await kit.createTestApp({ persistence, seed: publishedHere });
    const post = (path, body, key = randomUUID()) => a.call('POST', path, { user, body, key });

    const courses = await a.call('GET', '/v1/courses', { user });
    assert.ok(
      courses.body.items.some((c) => c.courseId === 'vi_en'),
      JSON.stringify(courses.body),
    );
    const enroll = await post('/v1/enrollments', { courseId: 'vi_en', startPoint: 'beginner' });
    assert.equal(enroll.status, 200, JSON.stringify(enroll.body));
    const startKey = randomUUID();
    const startBody = {
      courseId: 'vi_en',
      lessonId: 'u1n1l1',
      mode: 'LESSON',
      expectedEnrollmentRevision: 0,
    };
    const [s, sReplay] = await Promise.all([
      post('/v1/sessions', startBody, startKey),
      post('/v1/sessions', startBody, startKey),
    ]);
    assert.equal(s.status, 200, JSON.stringify(s.body));
    assert.equal(
      sReplay.body.sessionId,
      s.body.sessionId,
      'concurrent duplicate start -> one session',
    );
    const session = s.body;
    cleanup.sessionIds.push(session.sessionId);
    const blocked = await post('/v1/sessions', startBody);
    assert.equal(blocked.body.error.code, 'SESSION_CONFLICT');

    const [first, ...rest] = session.bundle.exercises;
    const answer = (ex, ordinal, ans, revision) => ({
      exerciseId: ex.id,
      attemptOrdinal: ordinal,
      answer: ans,
      assisted: false,
      substituted: false,
      expectedRevision: revision,
    });
    const [d1, d2] = await Promise.all([
      post(`/v1/sessions/${session.sessionId}/answers`, answer(first, 0, wrongAnswer(first), 0)),
      post(`/v1/sessions/${session.sessionId}/answers`, answer(first, 0, correctAnswer(first), 0)),
    ]);
    assert.deepEqual([d1.status, d2.status].sort(), [200, 409], JSON.stringify([d1.body, d2.body]));
    let revision = 1;
    const firstWasWrong = (d1.status === 200 ? d1 : d2).body.correct === false;
    for (const ex of rest) {
      const r = await post(
        `/v1/sessions/${session.sessionId}/answers`,
        answer(ex, 0, correctAnswer(ex), revision),
      );
      assert.equal(r.status, 200, JSON.stringify(r.body));
      revision = r.body.sessionRevision;
    }
    if (firstWasWrong) {
      const retry = await post(
        `/v1/sessions/${session.sessionId}/answers`,
        answer(first, 1, correctAnswer(first), revision),
      );
      assert.deepEqual([retry.status, retry.body.retryPass], [200, 1], JSON.stringify(retry.body));
      revision = retry.body.sessionRevision;
    }
    const completeKey = randomUUID();
    const [c1, c2] = await Promise.all([
      post(
        `/v1/sessions/${session.sessionId}/complete`,
        { expectedRevision: revision },
        completeKey,
      ),
      post(`/v1/sessions/${session.sessionId}/complete`, { expectedRevision: revision }),
    ]);
    assert.equal(c1.status, 200, JSON.stringify(c1.body));
    assert.deepEqual(c2.body, c1.body, 'concurrent completes (different keys) -> one completion');
    assert.equal(c1.body.originalCorrect, firstWasWrong ? 9 : 10);
    const outbox = await persistence.list('l_outbox', {
      equal: { aggregateId: session.sessionId },
      limit: 10,
    });
    cleanup.eventIds.push(...outbox.items.map((i) => i.id));
    assert.equal(outbox.total, 1, 'exactly one durable outbox event');
    assert.equal(outbox.items[0].row.status, 'PENDING');
    const path = await a.call('GET', '/v1/courses/vi_en/path', { user });
    assert.deepEqual(path.body.enrollment.completedLessonIds, ['u1n1l1']);
    const reviewRows = await persistence.list('l_review_items', {
      equal: { userId: user },
      limit: 100,
    });
    assert.ok(reviewRows.total > 0);
    // Dispatcher against a fake receiver: lease + ACK durably.
    const report = await kit.dispatchOutbox(a.deps, async () => 'ack', {
      eventIds: outbox.items.map((i) => i.id),
    });
    assert.equal(report.acked, 1);
    assert.equal((await persistence.read('l_outbox', outbox.items[0].id)).status, 'ACK');
  },
);
