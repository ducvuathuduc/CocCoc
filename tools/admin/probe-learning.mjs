#!/usr/bin/env node
// Maintainer live probe of the deployed Learning Function through its PUBLIC domain (TEST project
// only). Creates a synthetic Appwrite user + JWT with the server key, then: course list + manifest
// (published vi_en v2 shape), enroll, getPath, a full online lesson (start -> answer every item ->
// complete), an offline completion (syncOfflineCompletion) for the next lesson, and the frontier
// after both. Optionally (--deletion) requests account deletion in Progress and waits for the
// Learning purge (account.deleted.v1 -> rows gone). Finally deletes every Learning and Progress
// row naming the user and the Appwrite user itself. Requires APPWRITE_API_KEY (server key) and
// ALLOW_LIVE_PROBE=reviewed-test-project. Prints one JSON report; exit 1 on any failed check.
import { randomUUID } from 'node:crypto';
import { Client, Query, TablesDB, Users } from 'node-appwrite';
import { correctAnswer } from '../../services/learning/test/helpers/answers.mjs';
import { DEFAULT_ENDPOINT, DEFAULT_PROJECT, loadMaintainer } from './lib.mjs';

if (process.env.ALLOW_LIVE_PROBE !== 'reviewed-test-project') {
  console.error(
    'Set ALLOW_LIVE_PROBE=reviewed-test-project (creates and deletes a synthetic user).',
  );
  process.exit(2);
}
const endpoint = process.env.APPWRITE_ENDPOINT ?? DEFAULT_ENDPOINT;
const projectId = process.env.APPWRITE_PROJECT_ID ?? DEFAULT_PROJECT;
const learningUrl = process.env.COC_LEARNING_URL ?? 'https://coccoc-learning.sgp.appwrite.run';
const progressUrl = process.env.COC_PROGRESS_URL ?? 'https://coccoc-progress.sgp.appwrite.run';
const withDeletion = process.argv.includes('--deletion');
const client = new Client()
  .setEndpoint(endpoint)
  .setProject(projectId)
  .setKey(process.env.APPWRITE_API_KEY ?? '');
const users = new Users(client);
const db = new TablesDB(client);
const databaseId = 'cocenglish';
const checks = [];
const check = (name, pass, detail) => checks.push({ name, pass: Boolean(pass), detail });
const LEARNING_USER_TABLES = [
  'l_answers',
  'l_sessions',
  'l_active_slots',
  'l_review_items',
  'l_mistakes',
  'l_activity_progress',
  'l_reports',
  'l_receipts',
  'l_enrollments',
  'l_energy',
];

async function call(base, method, path, { jwt, body } = {}) {
  const h = {};
  if (jwt) h.authorization = `Bearer ${jwt}`;
  if (method !== 'GET') {
    h['content-type'] = 'application/json';
    h['idempotency-key'] = randomUUID();
  }
  const r = await fetch(`${base}${path}`, {
    method,
    headers: h,
    ...(method !== 'GET' ? { body: JSON.stringify(body ?? {}) } : {}),
  });
  const text = await r.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    json = text;
  }
  return { status: r.status, body: json };
}
const learning = (method, path, opts) => call(learningUrl, method, path, opts);
const countRows = async (tableId, column, value) =>
  (
    await db.listRows({
      databaseId,
      tableId,
      queries: [Query.equal(column, value), Query.limit(1)],
    })
  ).total;

const userId = `probe${randomUUID().replace(/-/g, '').slice(0, 12)}`;
const sessionIds = [];
let swept = 0;
try {
  await users.create({
    userId,
    email: `${userId}@example.invalid`,
    password: `${randomUUID()}Aa!`,
  });
  const { jwt } = await users.createJWT({ userId });
  check('health', (await learning('GET', '/health')).status === 200);
  check('no JWT -> 401', (await learning('GET', '/v1/courses')).status === 401);
  const courses = await learning('GET', '/v1/courses', { jwt });
  check(
    'courses: vi_en published v2',
    courses.status === 200 &&
      courses.body.items?.some((c) => c.courseId === 'vi_en' && c.publishedVersion === 'v2'),
    courses.status === 200 ? courses.body.items : courses.body,
  );
  const manifest = await learning('GET', '/v1/courses/vi_en/manifest', { jwt });
  const shape = manifest.body?.sections
    ? [
        manifest.body.sections.length,
        manifest.body.units.length,
        manifest.body.nodes.length,
        manifest.body.bundles.length,
      ]
    : manifest.body;
  check('manifest 2/16/128/512', JSON.stringify(shape) === '[2,16,128,512]', shape);
  const enroll = await learning('POST', '/v1/enrollments', {
    jwt,
    body: { courseId: 'vi_en', startPoint: 'beginner' },
  });
  check(
    'enroll beginner',
    enroll.status === 200,
    enroll.status === 200 ? enroll.body.revision : enroll.body,
  );
  const path = await learning('GET', '/v1/courses/vi_en/path', { jwt });
  const first = path.body?.nodes?.[0];
  check(
    'getPath: 24-node page, level 1 has 4 lessons and is available',
    path.status === 200 &&
      path.body.nodes.length === 24 &&
      first.lessonIds.length === 4 &&
      first.state === 'available' &&
      path.body.nextCursor !== null,
    path.status === 200 ? { first, next: path.body.nextCursor } : path.body,
  );
  // Online lesson u1n1l1.
  const start = await learning('POST', '/v1/sessions', {
    jwt,
    body: { courseId: 'vi_en', lessonId: 'u1n1l1', mode: 'LESSON', expectedEnrollmentRevision: 0 },
  });
  check(
    'start lesson u1n1l1',
    start.status === 200 && start.body.bundle?.lessonVersion === 'v2.u1n1l1',
    start.status === 200 ? start.body.bundle.exercises.length : start.body,
  );
  if (start.status !== 200) throw new Error('cannot continue without a session');
  sessionIds.push(start.body.sessionId);
  let revision = start.body.revision;
  let allCorrect = true;
  for (const ex of start.body.bundle.exercises) {
    const r = await learning('POST', `/v1/sessions/${start.body.sessionId}/answers`, {
      jwt,
      body: {
        exerciseId: ex.id,
        attemptOrdinal: 0,
        answer: correctAnswer(ex),
        assisted: false,
        substituted: false,
        expectedRevision: revision,
      },
    });
    if (r.status !== 200 || !r.body.correct) allCorrect = false;
    revision = r.body?.sessionRevision ?? revision;
  }
  check('answers graded correct', allCorrect);
  const done = await learning('POST', `/v1/sessions/${start.body.sessionId}/complete`, {
    jwt,
    body: { expectedRevision: revision },
  });
  const n = start.body.bundle.exercises.length;
  check(
    'complete lesson',
    done.status === 200 && done.body.originalCorrect === n && done.body.source === 'ONLINE',
    done.status === 200 ? { ...done.body, needsReviewIds: undefined } : done.body,
  );
  // Offline completion of u1n1l2 against the pinned bundle.
  const index = manifest.body.bundles.find((b) => b.lessonId === 'u1n1l2');
  const bundle = (await learning('GET', '/v1/lessons/u1n1l2/bundle', { jwt })).body;
  const offline = await learning('POST', '/v1/offline-completions', {
    jwt,
    body: {
      operationId: randomUUID(),
      localCompletionId: randomUUID(),
      courseId: 'vi_en',
      lessonId: 'u1n1l2',
      lessonVersion: index.lessonVersion,
      bundleHash: index.sha256,
      expectedEnrollmentRevision: done.body.enrollmentRevision,
      answers: bundle.exercises.map((ex) => ({
        exerciseId: ex.id,
        attemptOrdinal: 0,
        answer: correctAnswer(ex),
        assisted: false,
        substituted: false,
      })),
    },
  });
  check(
    'offline completion u1n1l2 (source OFFLINE)',
    offline.status === 200 && offline.body.source === 'OFFLINE',
    offline.status === 200 ? offline.body.completionId : offline.body,
  );
  if (offline.status === 200) sessionIds.push(offline.body.sessionId);
  const after = await learning('GET', '/v1/courses/vi_en/path', { jwt });
  check(
    'frontier after online + offline',
    JSON.stringify(after.body?.enrollment?.completedLessonIds) === '["u1n1l1","u1n1l2"]',
    after.body?.enrollment,
  );
  const outbox = await db.listRows({
    databaseId,
    tableId: 'l_outbox',
    queries: [Query.equal('aggregateId', sessionIds), Query.limit(10)],
  });
  check(
    'lesson.completed.v1 rows in l_outbox',
    outbox.rows.length === sessionIds.length,
    outbox.rows.map((r) => `${r.type}:${r.status}:${r.attempt}`),
  );
  if (withDeletion) {
    await call(progressUrl, 'POST', '/v1/me/initialize', { jwt, body: {} });
    const del = await call(progressUrl, 'POST', '/v1/me/deletion', {
      jwt,
      body: { confirmation: 'DELETE' },
    });
    check('progress deletion 202', del.status === 202, del.status);
    let remaining = -1;
    for (let i = 0; i < 18; i++) {
      remaining = await countRows('l_enrollments', 'userId', userId);
      if (remaining === 0) break;
      await new Promise((r) => setTimeout(r, 5000));
    }
    check('account.deleted.v1 purged Learning rows (<=90s)', remaining === 0, { remaining });
  }
} catch (error) {
  check('probe run', false, error.message);
} finally {
  for (const tableId of LEARNING_USER_TABLES) {
    for (;;) {
      const page = await db
        .listRows({
          databaseId,
          tableId,
          queries: [Query.equal('userId', userId), Query.limit(100)],
        })
        .catch(() => ({ rows: [] }));
      if (!page.rows.length) break;
      for (const row of page.rows) {
        await db.deleteRow({ databaseId, tableId, rowId: row.$id }).catch(() => undefined);
        swept++;
      }
    }
  }
  for (const aggregate of [...sessionIds, userId]) {
    const page = await db
      .listRows({
        databaseId,
        tableId: 'l_outbox',
        queries: [Query.equal('aggregateId', aggregate), Query.limit(100)],
      })
      .catch(() => ({ rows: [] }));
    for (const row of page.rows) {
      await db
        .deleteRow({ databaseId, tableId: 'l_outbox', rowId: row.$id })
        .catch(() => undefined);
      swept++;
    }
  }
  const kit = await loadMaintainer();
  for (const [tableId, spec] of Object.entries(kit.PROGRESS_SCHEMA)) {
    for (const column of ['userId', 'fromUserId', 'toUserId', 'aggregateId'].filter(
      (c) => spec.columns[c],
    )) {
      for (const value of column === 'aggregateId' ? [userId, ...sessionIds] : [userId]) {
        for (;;) {
          const page = await db
            .listRows({
              databaseId,
              tableId,
              queries: [Query.equal(column, value), Query.limit(100)],
            })
            .catch(() => ({ rows: [] }));
          if (!page.rows.length) break;
          for (const row of page.rows) {
            await db.deleteRow({ databaseId, tableId, rowId: row.$id }).catch(() => undefined);
            swept++;
          }
        }
      }
    }
  }
  await users.delete({ userId }).catch(() => undefined);
  let left = 0;
  for (const tableId of LEARNING_USER_TABLES)
    left += await countRows(tableId, 'userId', userId).catch(() => 0);
  check('cleanup: no Learning row left for the synthetic user', left === 0, { left });
}
const failed = checks.filter((c) => !c.pass);
console.log(
  JSON.stringify(
    {
      status: failed.length ? 'FAIL' : 'PASS',
      domain: learningUrl,
      userId,
      passed: checks.length - failed.length,
      total: checks.length,
      swept,
      checks,
    },
    null,
    2,
  ),
);
process.exit(failed.length ? 1 : 0);
