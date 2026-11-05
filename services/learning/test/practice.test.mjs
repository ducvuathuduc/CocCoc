// P6-REVIEW-002 (mistakes, words), P6-GAME-003 energy read model, P7-PRACTICE-001 activity list,
// P4-LEARN-003 enrollment commands — over the real router (memory adapter, committed content).
import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import Ajv from 'ajv/dist/2020.js';
import formats from 'ajv-formats';
import { loadKit } from './helpers/kit.mjs';
import { correctAnswer, wrongAnswer } from './helpers/answers.mjs';

const kit = await loadKit('practice');
const api = JSON.parse(fs.readFileSync('docs/api/openapi.yaml', 'utf8'));
const ajv = new Ajv({ strict: false });
formats(ajv);
ajv.addSchema({ $id: 'https://x.invalid/s', components: api.components });
const valid = (name, value) => {
  const check = ajv.compile({ $ref: `https://x.invalid/s#/components/schemas/${name}` });
  assert.ok(check(value), `${name}: ${JSON.stringify(check.errors?.slice(0, 3))}`);
};
const DAY = 86400000;

async function setup() {
  let now = Date.parse('2026-10-12T08:00:00Z');
  const a = await kit.createTestApp({ nowMs: () => now });
  const user = 'pra';
  const post = (path, body) => a.call('POST', path, { user, body, key: randomUUID() });
  async function play(lessonId, mode, { wrong = [], wrongAll = false } = {}) {
    const rev = (await a.call('GET', '/v1/courses/vi_en/path', { user })).body.enrollment.revision;
    const s = (
      await post('/v1/sessions', {
        courseId: 'vi_en',
        lessonId,
        mode,
        expectedEnrollmentRevision: rev,
      })
    ).body;
    assert.ok(s.sessionId, JSON.stringify(s));
    let revision = 0;
    const retry = [];
    for (const ex of s.bundle.exercises) {
      const isWrong = wrongAll || wrong.includes(ex.id);
      revision = (
        await post(`/v1/sessions/${s.sessionId}/answers`, {
          exerciseId: ex.id,
          attemptOrdinal: 0,
          answer: isWrong ? wrongAnswer(ex) : correctAnswer(ex),
          assisted: false,
          substituted: false,
          expectedRevision: revision,
        })
      ).body.sessionRevision;
      if (isWrong) retry.push(ex);
    }
    for (const ex of retry) {
      revision = (
        await post(`/v1/sessions/${s.sessionId}/answers`, {
          exerciseId: ex.id,
          attemptOrdinal: 1,
          answer: correctAnswer(ex),
          assisted: false,
          substituted: false,
          expectedRevision: revision,
        })
      ).body.sessionRevision;
    }
    const c = await post(`/v1/sessions/${s.sessionId}/complete`, { expectedRevision: revision });
    assert.equal(c.status, 200, JSON.stringify(c.body));
    return s;
  }
  await post('/v1/enrollments', { courseId: 'vi_en', startPoint: 'beginner' });
  return { a, user, post, play, advance: (ms) => (now += ms) };
}

test('mistakes: first-attempt errors captured (<=10/session), listed, prioritised in REVIEW and resolved by a correct review', async () => {
  const { a, user, play, advance } = await setup();
  await play('u1n1l1', 'LESSON', { wrong: ['u1n1l1-e02', 'u1n1l1-e05'] });
  let page = await a.call('GET', '/v1/mistakes', { user, query: 'courseId=vi_en' });
  assert.equal(page.status, 200, JSON.stringify(page.body));
  valid('MistakePage', page.body);
  assert.deepEqual(page.body.items.map((m) => m.exerciseId).sort(), ['u1n1l1-e02', 'u1n1l1-e05']);
  assert.ok(
    page.body.items.every(
      (m) => m.mistakeCount === 1 && m.resolvedAt === null && m.lessonVersion === 'v2.u1n1l1',
    ),
  );
  await play('u1n1l1', 'LESSON', { wrongAll: true });
  page = await a.call('GET', '/v1/mistakes', { user, query: 'courseId=vi_en&limit=100' });
  assert.equal(page.body.items.length, 10, 'capped at 10 per session, one row per exercise');
  assert.equal(page.body.items.find((m) => m.exerciseId === 'u1n1l1-e02').mistakeCount, 2);
  advance(DAY + 1000);
  const review = await play('review_dynamic', 'REVIEW');
  const reviewIds = review.bundle.exercises.map((e) => e.id);
  assert.ok(
    ['u1n1l1-e02', 'u1n1l1-e05'].every((id) => reviewIds.includes(id)),
    'unresolved mistakes come first',
  );
  page = await a.call('GET', '/v1/mistakes', { user, query: 'courseId=vi_en&limit=100' });
  const open = page.body.items.map((m) => m.exerciseId);
  assert.ok(
    reviewIds.every((id) => !open.includes(id)),
    'correct review answers resolve mistakes',
  );
  const all = await a.call('GET', '/v1/mistakes', {
    user,
    query: 'courseId=vi_en&includeResolved=true&limit=100',
  });
  assert.equal(all.body.items.length, 10);
  assert.ok(all.body.items.some((m) => m.resolvedAt !== null));
  assert.equal((await a.call('GET', '/v1/mistakes', { user })).status, 400, 'courseId is required');
});

test('words: learned vocabulary with lexicon term/translation, strength decay and both sort orders', async () => {
  const { a, user, play, advance } = await setup();
  await play('u1n1l1', 'LESSON');
  const recent = await a.call('GET', '/v1/words', { user, query: 'courseId=vi_en&limit=100' });
  assert.equal(recent.status, 200, JSON.stringify(recent.body));
  valid('WordPage', recent.body);
  assert.ok(recent.body.items.length >= 4, 'level 1 lesson 1 teaches 4 words');
  const hello = recent.body.items.find((w) => w.vocabularyId === 'u1.hello');
  assert.deepEqual([hello.term, hello.translation, hello.strength], ['hello', 'xin chào', 4]);
  const alpha = await a.call('GET', '/v1/words', {
    user,
    query: 'courseId=vi_en&sort=ALPHABETICAL&limit=100',
  });
  const terms = alpha.body.items.map((w) => w.term);
  assert.deepEqual(
    terms,
    [...terms].sort((x, y) => x.localeCompare(y, 'en')),
  );
  advance(10 * DAY);
  const later = await a.call('GET', '/v1/words', { user, query: 'courseId=vi_en&limit=100' });
  assert.ok(
    later.body.items.find((w) => w.vocabularyId === 'u1.hello').strength < 4,
    'strength decays with time',
  );
  assert.equal(
    kit.strengthOf(24, '2026-10-12T00:00:00.000Z', Date.parse('2026-10-13T00:00:00.000Z')),
    2,
  );
});

test('word lexicon does not cache an incomplete result after a content read fails', async () => {
  const manifest = { bundles: [{ lessonId: 'first' }, { lessonId: 'second' }] };
  let unavailable = true;
  const calls = [];
  const content = {
    async bundle(_manifest, lessonId) {
      calls.push(lessonId);
      if (lessonId === 'second' && unavailable) throw new Error('content temporarily unavailable');
      return {
        bundle: {
          exercises: [
            {
              type: 'matchPairs',
              vocabularyIds: [lessonId],
              content: {
                pairs: [{ left: { text: lessonId }, right: { text: `translation-${lessonId}` } }],
              },
            },
          ],
        },
      };
    },
  };
  await assert.rejects(kit.lexiconOf({ content }, manifest), /content temporarily unavailable/);
  unavailable = false;
  const retried = await kit.lexiconOf({ content }, manifest);
  assert.equal(retried.get('second').translation, 'translation-second');
  assert.deepEqual(calls, ['first', 'second', 'first', 'second']);
  const cached = await kit.lexiconOf({ content }, manifest);
  assert.equal(cached, retried);
  assert.equal(calls.length, 4);
});

test('concurrent word lexicon reads share a bounded build and preserve manifest order', async () => {
  const manifest = { bundles: Array.from({ length: 24 }, (_, i) => ({ lessonId: `lesson-${i}` })) };
  let active = 0;
  let maxActive = 0;
  let calls = 0;
  const content = {
    async bundle(_manifest, lessonId) {
      calls++;
      active++;
      maxActive = Math.max(active, maxActive);
      await new Promise((resolve) => setTimeout(resolve, lessonId === 'lesson-0' ? 10 : 1));
      active--;
      return {
        bundle: {
          exercises: [
            {
              type: 'matchPairs',
              vocabularyIds: ['shared'],
              content: { pairs: [{ left: { text: lessonId }, right: { text: lessonId } }] },
            },
          ],
        },
      };
    },
  };
  const result = await Promise.all(
    Array.from({ length: 3 }, () => kit.lexiconOf({ content }, manifest)),
  );
  assert.equal(calls, 24, 'build only once for concurrent requests');
  assert.ok(maxActive > 1 && maxActive <= 8, `bounded parallel reads, got ${maxActive}`);
  assert.equal(result[0], result[1]);
  assert.equal(result[0], result[2]);
  assert.equal(result[0].get('shared').term, 'lesson-0', 'first manifest occurrence wins');
});

test('a failed shared lexicon build settles the batch before a clean retry', async () => {
  const manifest = { bundles: Array.from({ length: 8 }, (_, i) => ({ lessonId: `l${i}` })) };
  let active = 0;
  let calls = 0;
  let shouldFail = true;
  const content = {
    async bundle(_manifest, lessonId) {
      active++;
      calls++;
      try {
        await new Promise((resolve) => setTimeout(resolve, lessonId === 'l0' ? 1 : 10));
        if (lessonId === 'l0' && shouldFail) throw new Error('unavailable');
        return { bundle: { exercises: [] } };
      } finally {
        active--;
      }
    },
  };
  const first = await Promise.allSettled(
    Array.from({ length: 3 }, () => kit.lexiconOf({ content }, manifest)),
  );
  assert.ok(first.every((result) => result.status === 'rejected'));
  assert.equal(active, 0);
  assert.equal(calls, 8);
  shouldFail = false;
  await kit.lexiconOf({ content }, manifest);
  assert.equal(active, 0);
  assert.equal(calls, 16);
});

test('energy: UNLIMITED by default; LIMITED regenerates lazily to capacity', async () => {
  const { a, user } = await setup();
  const e = await a.call('GET', '/v1/me/energy', { user });
  valid('Energy', e.body);
  assert.deepEqual(
    [e.body.mode, e.body.balance, e.body.capacity, e.body.nextUnitAt],
    ['UNLIMITED', 25, 25, null],
  );
  const t0 = Date.parse('2026-10-12T00:00:00Z');
  const row = {
    mode: 'LIMITED',
    balance: 20,
    capacity: 25,
    anchorAt: '2026-10-12T00:00:00.000Z',
    revision: 3,
  };
  const unit = Math.floor(DAY / 25);
  const v1 = kit.energyView(row, t0 + 2 * unit + 5);
  valid('Energy', v1);
  assert.deepEqual(
    [v1.balance, v1.nextUnitAt, v1.fullAt],
    [22, new Date(t0 + 3 * unit).toISOString(), new Date(t0 + 5 * unit).toISOString()],
  );
  const full = kit.energyView(row, t0 + DAY);
  assert.deepEqual([full.balance, full.nextUnitAt, full.fullAt], [25, null, null]);
});

test('activities: schema-valid empty library until activity sessions exist; kind filter validated', async () => {
  const { a, user } = await setup();
  const r = await a.call('GET', '/v1/activities', { user, query: 'courseId=vi_en&kind=STORY' });
  valid('ActivityProgressPage', r.body);
  assert.deepEqual(r.body.items, []);
  assert.equal(
    (await a.call('GET', '/v1/activities', { user, query: 'courseId=vi_en&kind=BOGUS' })).status,
    400,
  );
});

test('enrollment commands: reset clears progress (revision CAS), remove hides the course, re-enroll revives it', async () => {
  const { a, user, play } = await setup();
  for (const lessonId of ['u1n1l1', 'u1n1l2', 'u1n1l3', 'u1n1l4']) await play(lessonId, 'LESSON');
  let path = (await a.call('GET', '/v1/courses/vi_en/path', { user })).body;
  assert.equal(path.enrollment.frontierNodeOrder, 1);
  const stale = await a.call('POST', '/v1/enrollments/vi_en/reset', {
    user,
    key: randomUUID(),
    body: { expectedRevision: 0 },
  });
  assert.equal(stale.body.error.code, 'REVISION_CONFLICT');
  const reset = await a.call('POST', '/v1/enrollments/vi_en/reset', {
    user,
    key: randomUUID(),
    body: { expectedRevision: path.enrollment.revision },
  });
  valid('Enrollment', reset.body);
  assert.deepEqual([reset.body.frontierNodeOrder, reset.body.completedLessonIds], [0, []]);
  const sw = await a.call('POST', '/v1/enrollments/vi_en/activate', {
    user,
    key: randomUUID(),
    body: { expectedRevision: reset.body.revision },
  });
  assert.equal(sw.status, 200, JSON.stringify(sw.body));
  const removeKey = randomUUID();
  const removed = await a.call('DELETE', '/v1/enrollments/vi_en', { user, key: removeKey });
  assert.equal(removed.status, 200, JSON.stringify(removed.body));
  valid('Receipt', removed.body);
  assert.deepEqual(
    (await a.call('DELETE', '/v1/enrollments/vi_en', { user, key: removeKey })).body,
    removed.body,
    'idempotent',
  );
  assert.equal((await a.call('GET', '/v1/courses/vi_en/path', { user })).status, 404);
  const back = await a.call('POST', '/v1/enrollments', {
    user,
    key: randomUUID(),
    body: { courseId: 'vi_en', startPoint: 'beginner' },
  });
  assert.equal(back.status, 200);
  path = (await a.call('GET', '/v1/courses/vi_en/path', { user })).body;
  assert.equal(path.enrollment.frontierNodeOrder, 0);
});
