import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { loadKit, root } from '../../services/learning/test/helpers/kit.mjs';
import { authoredContent } from '../../services/learning/test/helpers/authored-content.mjs';

// Test-only: execute the unchanged Learning router with committed, signature-verified local content
// and the memory adapter. The .NET test replays these exact inputs through ASP.NET Core.
const inputPath = path.join(root, 'backend-dotnet/tests/fixtures/learning-parity-scenarios.json');
const outputPath = path.join(root, 'backend-dotnet/tests/fixtures/learning-node-golden.json');
const scenarioBytes = fs.readFileSync(inputPath);
const scenario = JSON.parse(scenarioBytes);
let now = Date.parse(scenario.now);
const kit = await loadKit('node-parity');
const parityProgressKey = {
  keyId: 'parity-progress',
  sender: 'progress',
  secret: Buffer.alloc(32, 17),
};
const app = await kit.createTestApp({
  root,
  nowMs: () => now,
  energyMode: 'UNLIMITED',
  keyring: kit.createKeyring([parityProgressKey]),
});
const sessionId = kit.rowId('session', 'alice', scenario.sessionKey);
const reviewSessionId = kit.rowId('session', 'alice', scenario.reviewSessionKey);
const activeSessionId = kit.rowId('session', 'alice', scenario.activeSessionKey);

if (scenario.seedRows?.length) {
  await app.persistence.transact(async (tx) => {
    for (const seed of scenario.seedRows) tx.put(seed.table, seed.id, seed.row);
  });
}

function projectRow(table, entry) {
  const row = structuredClone(entry.row);
  for (const [key, value] of Object.entries(row))
    if (key.endsWith('Json') && typeof value === 'string') row[key] = JSON.parse(value);
  if (table === 'l_sessions' && row.source === 'OFFLINE' && row.resultJson?.eventId)
    row.resultJson.eventId = '<generated-event-id>';
  // Node stores this absent optional value as undefined; ASP.NET's row contract stores null.
  delete row.opponentId;
  return { id: entry.id, row };
}

const eventScenario = scenario.eventParity;
const eventNow = Date.parse(eventScenario.now);
const parityLearningKey = {
  keyId: 'parity-learning',
  sender: 'learning',
  secret: Buffer.alloc(32, 51),
};
const eventApp = await kit.createTestApp({
  root,
  nowMs: () => eventNow,
  keyring: kit.createKeyring([parityProgressKey, parityLearningKey]),
  seed: false,
});
await eventApp.persistence.transact(async (tx) => {
  for (let index = 0; index < eventScenario.seed.aliceReviewItems; index++)
    tx.put(`l_review_items`, `alice-review-${String(index).padStart(3, '0')}`, {
      userId: 'alice',
      courseId: 'vi_en',
      vocabularyId: `alice-v${index}`,
    });
  for (let index = 0; index < eventScenario.seed.bobReviewItems; index++)
    tx.put(`l_review_items`, `bob-review-${String(index).padStart(3, '0')}`, {
      userId: 'bob',
      courseId: 'vi_en',
      vocabularyId: `bob-v${index}`,
    });
  tx.put('l_energy', kit.rowId('energy', 'alice'), eventScenario.seed.energy);
});

function projectEventRow(table, entry) {
  const projected = projectRow(table, entry);
  if (table === 'l_outbox' && projected.row.type === 'account.purged.v1') {
    projected.id = '<generated-ack-id>';
    projected.row.eventId = '<generated-ack-id>';
    projected.row.payloadJson.eventId = '<generated-ack-id>';
  }
  return projected;
}

const eventResults = [];
for (const [index, step] of eventScenario.steps.entries()) {
  const sender = step.sender ?? 'progress';
  const envelope = {
    eventId: step.eventId,
    type: step.type,
    schemaVersion: 1,
    producer: sender,
    aggregateId: step.payload.userId,
    occurredAt: eventScenario.now,
    requestId: step.eventId,
    payload: structuredClone(step.payload),
  };
  const rawBody = JSON.stringify(envelope);
  const key = sender === 'progress' ? parityProgressKey : parityLearningKey;
  const headers = kit.signServiceRequest({
    key,
    method: 'POST',
    path: '/internal/events',
    body: rawBody,
    nowSeconds: Math.floor(eventNow / 1000),
  });
  const response = await eventApp.call('POST', '/internal/events', { body: rawBody, headers });
  const body = structuredClone(response.body);
  if (body?.requestId) body.requestId = '<request-id>';
  if (body?.error?.requestId) body.error.requestId = '<request-id>';
  const tables = Object.fromEntries(
    eventScenario.inspect.map((table) => [
      table,
      eventApp.persistence
        .dump(table)
        .sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0))
        .map((row) => projectEventRow(table, row)),
    ]),
  );
  eventResults.push({ index, status: response.status, body, tables });
}

const results = [];
for (const [index, original] of scenario.steps.entries()) {
  const step = structuredClone(original);
  if (step.seedReview) {
    const seed = step.seedReview;
    await app.persistence.transact(async (tx) => {
      const enrollmentId = kit.rowId('enrollment', 'alice', 'vi_en');
      const enrollment = await tx.get('l_enrollments', enrollmentId);
      if (!enrollment) throw new Error('Learning parity review seed requires the enrollment');
      tx.put('l_enrollments', enrollmentId, {
        ...enrollment,
        completedLessonsJson: JSON.stringify([seed.completedLessonId]),
      });
      tx.put('l_mistakes', kit.rowId('mistake', 'alice', 'vi_en', seed.mistakeExerciseId), {
        userId: 'alice',
        courseId: 'vi_en',
        exerciseId: seed.mistakeExerciseId,
        lessonVersion: 'v2.u1n1l1',
        skillId: 'u1.vocab',
        lastSessionId: sessionId,
        mistakeCount: 1,
        lastMistakeAt: new Date(now - 5 * 60_000).toISOString(),
        resolvedAt: null,
        revision: 0,
        createdAt: new Date(now - 86_400_000).toISOString(),
        updatedAt: new Date(now - 5 * 60_000).toISOString(),
      });
      for (const item of seed.additionalMistakes ?? []) {
        tx.put('l_mistakes', kit.rowId('mistake', 'alice', 'vi_en', item.exerciseId), {
          userId: 'alice',
          courseId: 'vi_en',
          exerciseId: item.exerciseId,
          lessonVersion: 'v2.u1n1l1',
          skillId: 'u1.vocab',
          lastSessionId: sessionId,
          mistakeCount: 1,
          lastMistakeAt: new Date(now - item.minutesAgo * 60_000).toISOString(),
          resolvedAt: null,
          revision: 0,
          createdAt: new Date(now - 86_400_000).toISOString(),
          updatedAt: new Date(now - item.minutesAgo * 60_000).toISOString(),
        });
      }
      for (const item of seed.reviewItems) {
        const lastReviewedAt = new Date(now - 86_400_000).toISOString();
        const firstSeenAt = new Date(now - 10 * 86_400_000).toISOString();
        tx.put('l_review_items', kit.rowId('review', 'alice', 'vi_en', item.vocabularyId), {
          userId: 'alice',
          courseId: 'vi_en',
          vocabularyId: item.vocabularyId,
          skillId: item.skillId,
          stage: 2,
          dueAt: new Date(now - item.dueMinutesAgo * 60_000).toISOString(),
          firstAttemptWindowJson: '[true,false,true,false,true]',
          lastReviewedAt,
          firstSeenAt,
          correctCount: 3,
          incorrectCount: 1,
          halfLifeHours: 24,
          revision: 0,
          createdAt: firstSeenAt,
          updatedAt: lastReviewedAt,
        });
      }
      for (const item of seed.activities ?? []) {
        tx.put(`l_activity_progress`, `activity-${item.activityId}`, {
          userId: 'alice',
          courseId: 'vi_en',
          kind: item.kind,
          activityId: item.activityId,
          completions: item.completions,
          bestScore: item.bestScore,
          stars: item.stars,
          firstCompletedAt: new Date(now - 86_400_000).toISOString(),
          lastCompletedAt: null,
        });
      }
    });
    results.push({ index, kind: 'seed' });
    continue;
  }
  if (step.key === '$sessionKey') step.key = scenario.sessionKey;
  if (step.key === '$reportKey') step.key = scenario.reportKey;
  if (step.key === '$reviewSessionKey') step.key = scenario.reviewSessionKey;
  if (step.key === '$activeSessionKey') step.key = scenario.activeSessionKey;
  const pathSessionId = step.sessionKey
    ? kit.rowId('session', step.user, step.sessionKey)
    : sessionId;
  step.path = step.path
    ?.replaceAll('$sessionId', pathSessionId)
    .replaceAll('$reviewSessionId', reviewSessionId)
    .replaceAll('$activeSessionId', activeSessionId);
  if (step.inspect) {
    const tables = Object.fromEntries(
      step.inspect.map((table) => [
        table,
        app.persistence
          .dump(table)
          .filter((entry) => table !== 'l_receipts' || entry.row.operation !== 'publishContent')
          .sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0))
          .map((row) => projectRow(table, row)),
      ]),
    );
    results.push({ index, kind: 'inspect', tables });
    continue;
  }
  const options = {
    user: step.user,
    headers: {
      'x-request-id': scenario.requestId,
      ...(step.sender
        ? kit.signServiceRequest({
            key: parityProgressKey,
            method: step.method,
            path: step.path,
            query: step.query ?? '',
            allowedQueryKeys: step.query ? ['before'] : [],
            body: '',
            nowSeconds: Math.floor(now / 1000),
          })
        : {}),
    },
    ...(step.key ? { key: step.key } : {}),
    ...(step.query ? { query: step.query } : {}),
    ...('body' in step ? { body: step.body } : {}),
  };
  const response = await app.call(step.method, step.path, options);
  results.push({ index, kind: 'call', status: response.status, body: response.body });
}

const publicationApp = await kit.createTestApp({
  root,
  nowMs: () => Date.parse(scenario.publication.now),
  seed: false,
});
const localPublication = kit
  .loadLocalContent(root)
  .publications.find((publication) => publication.courseId === 'vi_en');
if (!localPublication)
  throw new Error('Learning publication parity requires committed vi_en content');
const publicationBody = { ...localPublication, expectedPublishedVersion: null };
const duplicatePublicationBody = { ...localPublication, expectedPublishedVersion: 'v2' };
const publicationResults = [];
for (const [index, operation] of [
  { key: scenario.publication.publishKey, body: publicationBody },
  { key: scenario.publication.publishKey, body: publicationBody },
  { key: scenario.publication.duplicateKey, body: duplicatePublicationBody },
].entries()) {
  const response = await publicationApp.call('POST', '/v1/admin/content-versions', {
    user: 'maintainer-1',
    key: operation.key,
    headers: { 'x-request-id': scenario.publication.requestId },
    body: operation.body,
  });
  publicationResults.push({ index, kind: 'call', status: response.status, body: response.body });
}
const publicationTables = Object.fromEntries(
  ['l_courses', 'l_content_versions', 'l_receipts'].map((table) => [
    table,
    publicationApp.persistence
      .dump(table)
      .sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0))
      .map((row) => projectRow(table, row)),
  ]),
);
publicationResults.push({
  index: publicationResults.length,
  kind: 'inspect',
  tables: publicationTables,
});

let outboxNow = Date.parse(scenario.outbox.now);
const outboxApp = await kit.createTestApp({ root, nowMs: () => outboxNow, seed: false });
const eventId = scenario.outbox.eventId;
const outboxEnvelope = {
  eventId,
  type: 'lesson.completed.v1',
  schemaVersion: 1,
  producer: 'learning',
  aggregateId: 'alice',
  occurredAt: new Date(outboxNow).toISOString(),
  requestId: eventId,
  payload: { userId: 'alice', courseId: 'vi_en', sessionId: 'session-parity', originalCorrect: 8 },
};
await outboxApp.persistence.transact(async (tx) => {
  tx.put('l_outbox', eventId, {
    eventId,
    type: outboxEnvelope.type,
    schemaVersion: outboxEnvelope.schemaVersion,
    aggregateId: outboxEnvelope.aggregateId,
    occurredAt: outboxEnvelope.occurredAt,
    payloadJson: JSON.stringify(outboxEnvelope),
    attempt: 0,
    nextAttemptAt: outboxEnvelope.occurredAt,
    leaseOwner: null,
    leaseUntil: null,
    status: 'PENDING',
    ackAt: null,
    revision: 0,
    createdAt: outboxEnvelope.occurredAt,
    updatedAt: outboxEnvelope.occurredAt,
  });
});
const outboxResults = [];
for (const [index, outcome] of ['retry', 'ack'].entries()) {
  if (index > 0) outboxNow += 1000;
  const report = await kit.dispatchOutbox(outboxApp.deps, async () => outcome, {
    owner: scenario.outbox.owner,
    random: () => 0,
  });
  const saved = outboxApp.persistence.dump('l_outbox').find((entry) => entry.id === eventId);
  outboxResults.push({ index, report, row: saved ? projectRow('l_outbox', saved) : null });
}

const dispatchSpec = scenario.dispatchJob;
const dispatchNow = Date.parse(dispatchSpec.now);
const schedulerKey = {
  keyId: 'parity-scheduler',
  sender: 'scheduler',
  secret: Buffer.alloc(32, 34),
};
const dispatchDeliveries = [];
const dispatchApp = await kit.createTestApp({
  root,
  nowMs: () => dispatchNow,
  seed: false,
  keyring: kit.createKeyring([schedulerKey]),
  deliver: async (event) => {
    dispatchDeliveries.push(structuredClone(event));
    return 'ack';
  },
});
const dispatchEvent = dispatchSpec.event;
await dispatchApp.persistence.transact(async (tx) => {
  tx.put('l_outbox', dispatchEvent.eventId, {
    eventId: dispatchEvent.eventId,
    type: dispatchEvent.type,
    schemaVersion: dispatchEvent.schemaVersion,
    aggregateId: dispatchEvent.aggregateId,
    occurredAt: dispatchEvent.occurredAt,
    payloadJson: JSON.stringify(dispatchEvent),
    attempt: 0,
    nextAttemptAt: dispatchEvent.occurredAt,
    leaseOwner: null,
    leaseUntil: null,
    status: 'PENDING',
    ackAt: null,
    revision: 0,
    createdAt: dispatchEvent.occurredAt,
    updatedAt: dispatchEvent.occurredAt,
  });
});
const dispatchPath = '/internal/jobs/learning-outbox-dispatch';
const dispatchBody = dispatchSpec.tick;
const dispatchSignature = kit.signServiceRequest({
  key: schedulerKey,
  method: 'POST',
  path: dispatchPath,
  body: JSON.stringify(dispatchBody),
  nowSeconds: Math.floor(dispatchNow / 1000),
});
const dispatchResponse = await dispatchApp.call('POST', dispatchPath, {
  headers: { 'x-request-id': dispatchSpec.requestId, ...dispatchSignature },
  body: dispatchBody,
});
const dispatchSaved = dispatchApp.persistence
  .dump('l_outbox')
  .find((entry) => entry.id === dispatchEvent.eventId);
const dispatchJobResult = {
  status: dispatchResponse.status,
  body: dispatchResponse.body,
  row: dispatchSaved ? projectRow('l_outbox', dispatchSaved) : null,
  deliveries: dispatchDeliveries,
};

const immediateSpec = scenario.immediateRelay;
const immediateNow = Date.parse(immediateSpec.now);
const immediateApp = await kit.createTestApp({ root, nowMs: () => immediateNow, seed: false });
const immediateEnvelope = {
  ...outboxEnvelope,
  eventId: immediateSpec.eventId,
  occurredAt: new Date(immediateNow).toISOString(),
  requestId: immediateSpec.eventId,
};
await immediateApp.persistence.transact(async (tx) => {
  const at = new Date(immediateNow).toISOString();
  tx.put('l_outbox', immediateSpec.eventId, {
    eventId: immediateSpec.eventId,
    type: immediateEnvelope.type,
    schemaVersion: immediateEnvelope.schemaVersion,
    aggregateId: immediateEnvelope.aggregateId,
    occurredAt: immediateEnvelope.occurredAt,
    payloadJson: JSON.stringify(immediateEnvelope),
    attempt: 0,
    nextAttemptAt: at,
    leaseOwner: null,
    leaseUntil: null,
    status: 'PENDING',
    ackAt: null,
    revision: 0,
    createdAt: at,
    updatedAt: at,
  });
});
const immediateDeliveredEventIds = [];
const immediateRelay = kit.createImmediateRelay(
  () => immediateApp.deps,
  async (event) => {
    immediateDeliveredEventIds.push(event.eventId);
    return 'retry';
  },
  1500,
  () => 0,
);
await immediateRelay.afterCommit([immediateSpec.eventId]);
const immediateSaved = immediateApp.persistence
  .dump('l_outbox')
  .find((row) => row.id === immediateSpec.eventId);
const immediateRelayResult = {
  deliveredEventIds: immediateDeliveredEventIds,
  row: immediateSaved ? projectRow('l_outbox', immediateSaved) : null,
};

const completionParity = scenario.completionParity;
let completionNow = Date.parse(completionParity.now);
const completionContent = await authoredContent(kit, {
  u1n1l1: {
    modes: ['STORIES', 'ADVENTURE', 'RADIO', 'SIDE_QUEST', 'CLASH', 'UNIT_REVIEW', 'TEST_OUT'],
    passThreshold: 0.8,
    opponents: ['coach'],
    defaultOpponentId: 'coach',
  },
  u1n2l1: { modes: ['CHECKPOINT'], passThreshold: 0.8 },
});
const completionApp = await kit.createTestApp({
  root,
  nowMs: () => completionNow,
  energyMode: 'UNLIMITED',
  files: completionContent.files,
  seed: false,
});
const completionPublication = await completionApp.call('POST', '/v1/admin/content-versions', {
  user: 'maintainer-1',
  key: 'ab000000-0000-4000-8000-000000000099',
  headers: { 'x-request-id': completionParity.requestId },
  body: { ...completionContent.publication, expectedPublishedVersion: null },
});
if (completionPublication.status !== 200)
  throw new Error(
    `Learning completion parity publication failed: ${JSON.stringify(completionPublication.body)}`,
  );
const completionResults = [];
async function seedCompletionCase(testCase) {
  const userId = testCase.user;
  const sessionId = testCase.sessionId;
  const nowIso = new Date(completionNow).toISOString();
  const earlierIso = new Date(completionNow - 86_400_000).toISOString();
  const { manifest } = await completionApp.deps.content.published('vi_en');
  const sourceBundle = (
    await completionApp.deps.content.bundle(
      manifest,
      testCase.lessonId === 'review_dynamic' ? 'u1n1l1' : testCase.lessonId,
    )
  ).bundle;
  const exercises =
    testCase.lessonId === 'review_dynamic' ? [sourceBundle.exercises[0]] : sourceBundle.exercises;
  const bundle =
    testCase.lessonId === 'review_dynamic'
      ? {
          ...sourceBundle,
          lessonId: 'review_dynamic',
          lessonVersion: 'review.dynamic.v1',
          rewardIdentity: 'review_dynamic',
          exercises,
        }
      : sourceBundle;
  const exerciseIds = exercises.map((exercise) => exercise.id);
  const vocabularyIds = [...new Set(exercises.flatMap((exercise) => exercise.vocabularyIds ?? []))];
  const expectedRevision = exercises.length + (testCase.retryWrong ? 1 : 0);
  const completedLessons =
    testCase.enrollment === 'mastery' || testCase.enrollment === 'checkpoint'
      ? ['u1n1l1', 'u1n1l2', 'u1n1l3', 'u1n1l4']
      : [];
  const baseEnrollment = {
    userId,
    courseId: 'vi_en',
    courseVersion: 'v2',
    frontierNodeOrder: completedLessons.length ? 1 : 0,
    completedLessonsJson: JSON.stringify(completedLessons),
    masteredNodesJson: '[]',
    legendaryNodesJson: '[]',
    placementUsed: false,
    active: true,
    proficiencyScore: 0,
    lastPracticedAt: null,
    removedAt: null,
    revision: 4,
    createdAt: earlierIso,
    updatedAt: earlierIso,
  };
  await completionApp.persistence.transact(async (tx) => {
    if (testCase.enrollment !== 'none')
      tx.put('l_enrollments', kit.rowId('enrollment', userId, 'vi_en'), baseEnrollment);
    tx.put('l_sessions', sessionId, {
      userId,
      courseId: 'vi_en',
      lessonId: testCase.lessonId,
      lessonVersion: bundle.lessonVersion,
      rewardIdentity: bundle.rewardIdentity,
      mode: testCase.mode,
      source: 'ONLINE',
      status: 'ACTIVE',
      activityId: null,
      opponentId: null,
      bundleHash: bundle.manifestHash,
      bundleSnapshotJson: testCase.lessonId === 'review_dynamic' ? JSON.stringify(bundle) : null,
      nextOriginalOrdinal: exercises.length,
      retryPass: testCase.retryWrong ? 1 : 0,
      assisted: testCase.assisted,
      energySpent: 0,
      energyEarned: 0,
      startedAt: earlierIso,
      expiresAt: new Date(completionNow + 86_400_000).toISOString(),
      completedAt: null,
      resultJson: '{}',
      revision: expectedRevision,
      createdAt: earlierIso,
      updatedAt: nowIso,
    });
    tx.put('l_active_slots', kit.rowId('slot', userId, 'vi_en'), {
      userId,
      courseId: 'vi_en',
      sessionId,
      expiresAt: new Date(completionNow + 86_400_000).toISOString(),
      createdAt: earlierIso,
      updatedAt: nowIso,
      revision: 0,
    });
    for (const [index, exercise] of exercises.entries()) {
      const attempts = testCase.retryWrong && index === 0 ? [false, true] : [testCase.correct];
      for (const [attemptOrdinal, attemptCorrect] of attempts.entries()) {
        const receivedAt = new Date(completionNow + attemptOrdinal).toISOString();
        tx.put('l_answers', kit.rowId('answer', sessionId, exercise.id, String(attemptOrdinal)), {
          sessionId,
          userId,
          exerciseId: exercise.id,
          attemptOrdinal,
          answerJson: '{}',
          correct: attemptCorrect,
          assisted: testCase.assisted,
          substituted: false,
          receivedAt,
          resultJson: '{}',
          createdAt: receivedAt,
          updatedAt: receivedAt,
          revision: 0,
        });
      }
      tx.put('l_mistakes', kit.rowId('mistake', userId, 'vi_en', exercise.id), {
        userId,
        courseId: 'vi_en',
        exerciseId: exercise.id,
        lessonVersion: sourceBundle.lessonVersion,
        skillId: exercise.skillIds?.[0] ?? 'general',
        lastSessionId: 'prior-session',
        mistakeCount: 1,
        lastMistakeAt: earlierIso,
        resolvedAt: null,
        revision: 0,
        createdAt: earlierIso,
        updatedAt: earlierIso,
      });
    }
    for (const vocabularyId of vocabularyIds) {
      tx.put('l_review_items', kit.rowId('review', userId, 'vi_en', vocabularyId), {
        userId,
        courseId: 'vi_en',
        vocabularyId,
        skillId: 'u1.vocab',
        stage: 2,
        dueAt: earlierIso,
        firstAttemptWindowJson: '[true,false,true,false,true]',
        lastReviewedAt: earlierIso,
        firstSeenAt: new Date(completionNow - 10 * 86_400_000).toISOString(),
        correctCount: 3,
        incorrectCount: 1,
        halfLifeHours: 72,
        revision: 0,
        createdAt: new Date(completionNow - 10 * 86_400_000).toISOString(),
        updatedAt: earlierIso,
      });
    }
  });
  return expectedRevision;
}

function projectCompletionRow(table, entry) {
  const projected = projectRow(table, entry);
  const row = projected.row;
  if (table === 'l_sessions' && row.resultJson?.eventId)
    row.resultJson.eventId = '<generated-event-id>';
  if (table === 'l_outbox') {
    projected.id = '<generated-event-id>';
    row.eventId = '<generated-event-id>';
    if (row.payloadJson?.eventId) row.payloadJson.eventId = '<generated-event-id>';
  }
  return projected;
}

for (const [index, testCase] of completionParity.cases.entries()) {
  const expectedRevision = await seedCompletionCase(testCase);
  const response = await completionApp.call('POST', `/v1/sessions/${testCase.sessionId}/complete`, {
    user: testCase.user,
    key: testCase.key,
    headers: { 'x-request-id': completionParity.requestId },
    body: { expectedRevision },
  });
  const tables = Object.fromEntries(
    completionParity.tables.map((table) => {
      const selected = completionApp.persistence
        .dump(table)
        .filter((entry) => {
          if (table === 'l_outbox') return entry.row.aggregateId === testCase.sessionId;
          if (table === 'l_answers') return entry.row.sessionId === testCase.sessionId;
          if (table === 'l_receipts')
            return entry.row.userId === testCase.user && entry.row.operation === 'completeSession';
          return entry.row.userId === testCase.user;
        })
        .sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0))
        .map((entry) => projectCompletionRow(table, entry));
      return [table, selected];
    }),
  );
  completionResults.push({
    index,
    name: testCase.name,
    status: response.status,
    body: response.body,
    tables,
  });
}

function sourceFiles(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const file = path.join(directory, entry.name);
    return entry.isDirectory() ? sourceFiles(file) : file.endsWith('.ts') ? [file] : [];
  });
}
const hash = createHash('sha256');
for (const file of [
  ...sourceFiles(path.join(root, 'services/learning/src')),
  ...sourceFiles(path.join(root, 'services/shared/src')),
]
  .map((file) => ({ file, relative: path.relative(root, file).split(path.sep).join('/') }))
  .sort((a, b) => (a.relative < b.relative ? -1 : a.relative > b.relative ? 1 : 0)))
  hash.update(file.relative).update('\0').update(fs.readFileSync(file.file)).update('\0');

const output =
  JSON.stringify(
    {
      nodeSourceSha256: hash.digest('hex'),
      scenarioSha256: createHash('sha256').update(scenarioBytes).digest('hex'),
      results,
      eventResults,
      publicationResults,
      outboxResults,
      dispatchJobResult,
      immediateRelay: immediateRelayResult,
      completionResults,
    },
    null,
    2,
  ) + '\n';
if (process.argv.includes('--check')) {
  if (!fs.existsSync(outputPath) || fs.readFileSync(outputPath, 'utf8') !== output)
    throw new Error('Learning Node parity fixture is stale; regenerate and review the diff.');
} else fs.writeFileSync(outputPath, output);
console.log(
  JSON.stringify({
    status: 'PASS',
    scope: 'Node Learning fixture only; no durable parity admission',
    steps: results.length,
    eventSteps: eventResults.length,
    publicationSteps: publicationResults.length,
    outboxSteps: outboxResults.length,
    dispatchJob: dispatchJobResult.status,
    immediateRelaySteps: immediateDeliveredEventIds.length,
    completionCases: completionResults.length,
    mode: process.argv.includes('--check') ? 'check' : 'write',
  }),
);
