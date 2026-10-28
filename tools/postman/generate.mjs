#!/usr/bin/env node
// Generates the Postman Collection v2.1 and the two public environments from
// docs/api/openapi.yaml (JSON content despite the .yaml extension).
//
// No third-party dependencies. Output is deterministic: running the generator twice
// produces byte-identical files. `tools/postman/check.mjs` enforces that invariant.
//
// Internal requests are signed by a collection-level pre-request script that mirrors
// services/shared/src/service-hmac.ts: timestamp \n METHOD \n canonicalPathAndQuery \n
// sha256hex(rawBody), HMAC-SHA256, dev-keyring derivation for local runs, and an
// explicit sender allowlist. Mobile clients never sign internal requests.
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '../..');
const SPEC_PATH = path.join(ROOT, 'docs/api/openapi.yaml');
const COLLECTION_PATH = path.join(HERE, 'CocEnglish.postman_collection.json');
const LOCAL_ENV_PATH = path.join(HERE, 'CocEnglish-local.postman_environment.json');
const TEST_ENV_PATH = path.join(HERE, 'CocEnglish-TEST-template.postman_environment.json');

const COLLECTION_SCHEMA = 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json';
const HTTP_METHODS = ['get', 'post', 'put', 'patch', 'delete', 'head', 'options'];
const FIXED_GENERATED_AT = '2026-10-28T00:00:00.000Z';
const OWNER_FOLDERS = ['Learning', 'Progress', 'AI', 'Internal'];

class Raw {
  constructor(text) {
    this.text = text;
  }
}

function sha256Hex(value) {
  return createHash('sha256').update(value).digest('hex');
}

/** Deterministic RFC 4122 version-4-shaped UUID for stable generated fixtures. */
function stableUuid(seed) {
  const hex = sha256Hex(`cocenglish-postman:${seed}`);
  const variant = ((Number.parseInt(hex.slice(16, 18), 16) & 0x3f) | 0x80)
    .toString(16)
    .padStart(2, '0');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-4${hex.slice(13, 16)}-${variant}${hex.slice(18, 20)}-${hex.slice(20, 32)}`;
}

function wavFixture(seconds = 0.1) {
  const data = Buffer.alloc(Math.round(16000 * 2 * seconds));
  const header = Buffer.alloc(44);
  header.write('RIFF', 0, 'ascii');
  header.writeUInt32LE(36 + data.length, 4);
  header.write('WAVE', 8, 'ascii');
  header.write('fmt ', 12, 'ascii');
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(1, 22);
  header.writeUInt32LE(16000, 24);
  header.writeUInt32LE(32000, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write('data', 36, 'ascii');
  header.writeUInt32LE(data.length, 40);
  const bytes = Buffer.concat([header, data]);
  return {
    wavBase64: bytes.toString('base64'),
    audioSha256: sha256Hex(bytes),
  };
}

function loadSpec() {
  return JSON.parse(fs.readFileSync(SPEC_PATH, 'utf8'));
}

function deref(spec, node) {
  let current = node;
  const seen = new Set();
  while (current && typeof current === 'object' && typeof current.$ref === 'string') {
    if (seen.has(current.$ref)) throw new Error(`Circular $ref: ${current.$ref}`);
    seen.add(current.$ref);
    const parts = current.$ref.replace(/^#\//, '').split('/');
    current = parts.reduce((value, part) => value?.[part], spec);
  }
  return current;
}

function operations(spec) {
  const list = [];
  for (const [apiPath, item] of Object.entries(spec.paths)) {
    for (const method of HTTP_METHODS) {
      const op = item[method];
      if (!op) continue;
      list.push({
        method: method.toUpperCase(),
        path: apiPath,
        op,
        operationId: op.operationId,
        owner: op['x-owner'] ?? op.tags?.[0] ?? 'learning',
      });
    }
  }
  return list;
}

function ownerFolder(op) {
  if (op.path === '/health' || op.path === '/ready' || op.path.startsWith('/internal/')) {
    return 'Internal';
  }
  if (op.owner === 'learning') return 'Learning';
  if (op.owner === 'progress') return 'Progress';
  if (op.owner === 'ai') return 'AI';
  throw new Error(`Unknown owner ${op.owner} for ${op.method} ${op.path}`);
}

function baseVar(op) {
  if (!op.path.startsWith('/internal/') && op.path !== '/ready') return `${op.owner}_base_url`;
  if (
    op.path === '/health' ||
    op.path === '/ready' ||
    op.path === '/internal/outbox-watermark' ||
    op.path === '/internal/jobs/learning-outbox-dispatch'
  ) {
    return 'learning_base_url';
  }
  return 'progress_base_url';
}

const PATH_VARIABLES = {
  courseId: '{{courseId}}',
  lessonId: '{{lessonId}}',
  sessionId: '{{sessionId}}',
  userId: '{{targetUserId}}',
  questId: '{{questId}}',
  jobId: '{{assessmentJobId}}',
  pairId: '{{pairId}}',
  classroomId: '{{classroomId}}',
  groupId: '{{groupId}}',
  giftId: '{{giftId}}',
  purchaseId: '{{purchaseId}}',
  conversationId: '{{conversationId}}',
  year: '2026',
};

function operationParameters(spec, op) {
  return (op.op.parameters ?? []).map((parameter) => deref(spec, parameter));
}

function queryParameters(spec, op) {
  const samples = {
    limit: '20',
    courseId: '{{courseId}}',
    includeResolved: 'false',
    sort: 'recent',
    before: '{{watermarkBefore}}',
    kind: op.operationId === 'listConversations' ? 'ROLEPLAY' : 'STORY',
    version: '{{courseVersion}}',
    scenarioId: '{{aiScenarioId}}',
  };
  return operationParameters(spec, op)
    .filter((parameter) => parameter.in === 'query')
    .filter((parameter) => !['cursor', 'completionId'].includes(parameter.name))
    .map((parameter) => ({
      key: parameter.name,
      value: samples[parameter.name] ?? '20',
    }));
}

function requestPath(op) {
  let result = op.path;
  for (const [name, value] of Object.entries(PATH_VARIABLES)) {
    result = result.replaceAll(`{${name}}`, value);
  }
  if (result.replace(/\{\{[^}]+\}\}/g, '').includes('{')) {
    throw new Error(`Unmapped path parameter in ${op.method} ${op.path}`);
  }
  return result;
}

function isUserRoute(op) {
  return !(op.path === '/health' || op.path === '/ready' || op.path.startsWith('/internal/'));
}

function requiresIdempotency(spec, op) {
  return operationParameters(spec, op).some(
    (parameter) => parameter.in === 'header' && parameter.name === 'Idempotency-Key',
  );
}

function idempotencyVariable(operationId) {
  return `idem_${operationId}`;
}

// ---------------------------------------------------------------------------
// Minimal valid JSON examples from OpenAPI schemas
// ---------------------------------------------------------------------------

const STRING_VARIABLES = {
  courseId: 'courseId',
  lessonId: 'lessonId',
  sessionId: 'sessionId',
  exerciseId: 'exerciseId',
  lessonVersion: 'lessonVersion',
  rewardIdentity: 'lessonId',
  bundleHash: 'bundleHash',
  manifestSha256: 'manifestSha256',
  audioSha256: 'audioSha256',
  wavBase64: 'wavBase64',
  targetUserId: 'targetUserId',
  recipientUserId: 'targetUserId',
  questId: 'questId',
  itemId: 'shopItemId',
  productId: 'productId',
  catalogVersion: 'catalogVersion',
  periodKey: 'questPeriodKey',
  weekId: 'leagueWeekId',
  lostStreakDay: 'lostStreakDay',
  nickname: 'nickname',
  joinCode: 'joinCode',
  inviteCode: 'inviteCode',
  scenarioId: 'aiScenarioId',
  requestId: 'tutorRequestId',
  jobId: 'assessmentJobId',
  turnId: 'turnId',
  tickId: 'tickId',
  adEventId: 'adEventId',
  notificationId: 'notificationId',
  operationId: 'offlineOperationId',
  localCompletionId: 'localCompletionId',
  purchaseId: 'purchaseId',
  manifestFileId: 'manifestFileId',
  versionId: 'contentVersionId',
  code: 'promoCode',
};

function sampleString(spec, schema, name, ctx) {
  if (typeof schema.const === 'string') return schema.const;
  if (Array.isArray(schema.enum) && schema.enum.length > 0) return String(schema.enum[0]);
  if (schema.format === 'uuid') {
    if (name === 'sessionId' && ctx.schemaName === 'VoiceRequest') return '{{voiceLeaseRequestId}}';
    if (name === 'requestId') return '{{tutorRequestId}}';
    if (name === 'jobId') return '{{assessmentJobId}}';
    if (name === 'turnId') return '{{turnId}}';
    if (name === 'tickId') return '{{tickId}}';
    if (name === 'adEventId') return '{{adEventId}}';
    if (name === 'operationId') return '{{offlineOperationId}}';
    if (name === 'localCompletionId') return '{{localCompletionId}}';
    return stableUuid(`body:${ctx.operationId ?? 'schema'}:${ctx.schemaName ?? 'inline'}:${name}`);
  }
  if (schema.format === 'date-time') return '2026-10-28T00:00:00Z';
  if (schema.contentEncoding === 'base64' || name === 'wavBase64') return '{{wavBase64}}';
  if (schema.pattern === '^[a-f0-9]{64}$') {
    if (name === 'audioSha256') return '{{audioSha256}}';
    if (name === 'manifestSha256') return '{{manifestSha256}}';
    if (name === 'bundleHash') return '{{bundleHash}}';
    return 'a'.repeat(64);
  }
  if (schema.pattern === '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') return '2026-10-28';
  if (schema.pattern === '^[a-z0-9][a-z0-9_.-]*$') return 'sample.item-1';
  if (schema.pattern === '^[A-Za-z0-9-]+$') return 'SAMPLE-CODE';
  if (STRING_VARIABLES[name]) return `{{${STRING_VARIABLES[name]}}}`;
  return 'sample';
}

function mergeObjectSchemas(schemas) {
  const properties = {};
  const required = [];
  for (const schema of schemas) {
    Object.assign(properties, schema.properties ?? {});
    required.push(...(schema.required ?? []));
  }
  return { type: 'object', properties, required: [...new Set(required)] };
}

function minimalExample(spec, schema, name = '', ctx = {}) {
  const resolved = deref(spec, schema);
  if (!resolved) return null;
  if (resolved.const !== undefined) return resolved.const;
  if (Array.isArray(resolved.enum) && resolved.enum.length > 0) return resolved.enum[0];
  if (resolved.oneOf) {
    let branch = resolved.oneOf[0];
    if (ctx.schemaName === 'Answer') {
      branch = resolved.oneOf.find((entry) => entry.$ref?.endsWith('/ChoiceAnswer')) ?? branch;
    }
    return minimalExample(spec, branch, name, ctx);
  }
  if (resolved.anyOf) {
    const branch = resolved.anyOf.find((entry) => !(entry.type === 'null')) ?? resolved.anyOf[0];
    return minimalExample(spec, branch, name, ctx);
  }
  if (resolved.allOf) {
    const merged = mergeObjectSchemas(resolved.allOf.map((entry) => deref(spec, entry)));
    return minimalExample(spec, merged, name, ctx);
  }
  if (resolved.type === 'object' || resolved.properties) {
    const result = {};
    for (const [property, propertySchema] of Object.entries(resolved.properties ?? {})) {
      if (!(resolved.required ?? []).includes(property)) continue;
      result[property] = minimalExample(spec, propertySchema, property, ctx);
    }
    return result;
  }
  if (resolved.type === 'array') {
    const count = resolved.minItems ?? 0;
    return Array.from({ length: count }, () =>
      minimalExample(spec, resolved.items ?? {}, name, ctx),
    );
  }
  if (resolved.type === 'integer' || resolved.type === 'number') {
    return resolved.minimum ?? 0;
  }
  if (resolved.type === 'boolean') return false;
  if (resolved.type === 'string') return sampleString(spec, resolved, name, ctx);
  return null;
}

function renderBody(value) {
  const raws = [];
  const json = JSON.stringify(value, (key, item) => {
    if (item instanceof Raw) {
      raws.push(item.text);
      return `__COC_RAW_${raws.length - 1}__`;
    }
    return item;
  });
  return json.replace(/"__COC_RAW_(\d+)__"/g, (match, index) => raws[Number(index)]);
}

function schemaRefName(spec, schema) {
  if (!schema?.$ref) return undefined;
  return schema.$ref.split('/').pop();
}

/** Operation-specific request bodies; each value is schema-valid and uses captured vars. */
function requestBody(spec, op, operationId) {
  const bodySchema = op.requestBody?.content?.['application/json']?.schema;
  if (!bodySchema) return null;
  const schemaName = schemaRefName(spec, bodySchema);
  const ctx = { operationId, schemaName };
  const bodies = {
    enrollCourse: { courseId: '{{courseId}}', startPoint: 'beginner' },
    startSession: {
      courseId: '{{courseId}}',
      lessonId: '{{lessonId}}',
      mode: 'LESSON',
      expectedEnrollmentRevision: new Raw('{{expectedRevision}}'),
    },
    submitAnswer: {
      exerciseId: '{{exerciseId}}',
      attemptOrdinal: 0,
      answer: { kind: 'choice', choiceId: '{{choiceId}}' },
      assisted: false,
      substituted: false,
      expectedRevision: new Raw('{{sessionRevision}}'),
    },
    completeSession: { expectedRevision: new Raw('{{sessionRevision}}') },
    abandonSession: { expectedRevision: new Raw('{{sessionRevision}}') },
    syncOfflineCompletion: {
      operationId: '{{offlineOperationId}}',
      localCompletionId: '{{localCompletionId}}',
      courseId: '{{courseId}}',
      lessonId: '{{lessonId}}',
      lessonVersion: '{{lessonVersion}}',
      bundleHash: '{{bundleHash}}',
      expectedEnrollmentRevision: new Raw('{{expectedRevision}}'),
      answers: [],
    },
    createReport: {
      exerciseId: '{{exerciseId}}',
      lessonVersion: '{{lessonVersion}}',
      category: 'CONTENT',
      note: 'Postman synthetic report. No learner data.',
    },
    publishContent: {
      courseId: '{{courseId}}',
      versionId: '{{contentVersionId}}',
      manifestFileId: '{{manifestFileId}}',
      manifestSha256: '{{manifestSha256}}',
      expectedPublishedVersion: null,
    },
    updateMe: {
      nickname: '{{nickname}}',
      publicOptIn: true,
      expectedRevision: new Raw('{{profileRevision}}'),
    },
    updatePreferences: {
      notificationsOff: [],
      smartScheduling: true,
      expectedRevision: new Raw('{{preferencesRevision}}'),
    },
    claimQuest: { periodKey: '{{questPeriodKey}}', upgradeChest: false },
    deleteAccount: { confirmation: 'DELETE' },
    tutorFeedback: {
      requestId: '{{tutorRequestId}}',
      learnerText: 'Hello, I would like a coffee, please.',
      level: 'A1',
      locale: 'en-US',
      feedbackLocale: 'vi-VN',
    },
    createVoiceSession: {
      sessionId: '{{voiceLeaseRequestId}}',
      scenarioId: '{{aiScenarioId}}',
      mode: 'TURN',
      level: 'A1',
    },
    heartbeatVoiceSession: {
      epoch: new Raw('{{voiceEpoch}}'),
      elapsedSeconds: 5,
      turnCount: 1,
    },
    createAssessment: {
      jobId: '{{assessmentJobId}}',
      referenceExerciseId: '{{exerciseId}}',
      lessonVersion: '{{lessonVersion}}',
      locale: 'en-US',
      wavBase64: '{{wavBase64}}',
      audioSha256: '{{audioSha256}}',
      referenceText: 'hello',
    },
    submitVoiceTurn: {
      turnId: '{{turnId}}',
      epoch: new Raw('{{voiceEpoch}}'),
      wavBase64: '{{wavBase64}}',
      audioSha256: '{{audioSha256}}',
    },
    switchCourse: { expectedRevision: new Raw('{{expectedRevision}}') },
    resetCourse: { expectedRevision: new Raw('{{expectedRevision}}') },
    sendFeedback: {
      topic: 'general',
      message: 'Synthetic Postman feedback. No learner data.',
      appVersion: '1.0.0',
      platform: 'ANDROID',
    },
    buyItem: {
      itemId: '{{shopItemId}}',
      quantity: 1,
      catalogVersion: '{{catalogVersion}}',
    },
    activateBoost: { itemId: '{{boostItemId}}' },
    repairStreak: { lostStreakDay: '{{lostStreakDay}}', payWith: 'GEMS' },
    inviteFriendStreak: { targetUserId: '{{targetUserId}}' },
    respondFriendStreak: { accept: true },
    sendInteraction: {
      targetUserId: '{{targetUserId}}',
      kind: 'HIGH_FIVE',
      contextId: '{{courseId}}',
      messageKey: 'high_five',
    },
    blockUser: { targetUserId: '{{targetUserId}}' },
    reportUser: {
      targetUserId: '{{targetUserId}}',
      reason: 'SPAM',
      note: null,
    },
    joinClassroom: { joinCode: '{{joinCode}}' },
    markLeagueResultSeen: { weekId: '{{leagueWeekId}}' },
    verifyPurchase: {
      productId: '{{productId}}',
      kind: 'SUBSCRIPTION',
      platform: 'SIMULATION',
      simulationOutcome: 'ACTIVE',
    },
    billingNotification: {
      notificationId: '{{notificationId}}',
      purchaseId: '{{purchaseId}}',
      platform: 'SIMULATION',
      state: 'ACTIVE',
      occurredAt: '2026-10-28T00:00:00Z',
    },
    createFamily: { plan: 'SUPER' },
    joinFamily: { inviteCode: '{{inviteCode}}' },
    sendGift: {
      recipientUserId: '{{targetUserId}}',
      plan: 'SUPER',
      durationDays: 30,
      note: null,
      simulationOutcome: 'PENDING',
    },
    redeemReferral: { code: '{{referralCode}}' },
    redeemPromoCode: { code: '{{promoCode}}' },
    recordAdEvent: {
      adEventId: '{{adEventId}}',
      placement: 'LESSON_END_INTERSTITIAL',
      kind: 'IMPRESSION',
    },
    startConversation: {
      kind: 'ROLEPLAY',
      courseId: '{{courseId}}',
      scenarioId: '{{aiScenarioId}}',
      voiceSessionId: null,
    },
    completeConversation: { endReason: 'COMPLETED' },
  };
  if (bodies[operationId]) return bodies[operationId];
  if (schemaName === 'JobTickRequest') {
    return {
      tickId: '{{tickId}}',
      scheduledAt: '2026-10-28T00:00:00Z',
      limit: 10,
      ...(operationId === 'runLeagueSettlement' ? { weekId: '{{leagueWeekId}}' } : {}),
    };
  }
  if (schemaName === 'BusinessEvent') {
    return internalEventBody('{{eventId}}', 13);
  }
  return minimalExample(spec, bodySchema, '', ctx);
}

function internalEventBody(eventId, correct) {
  return {
    eventId,
    type: 'lesson.completed.v1',
    schemaVersion: 1,
    producer: 'learning',
    aggregateId: 'completion-postman-001',
    occurredAt: '2026-10-28T00:00:00Z',
    requestId: 'request-postman-001',
    payload: {
      completionId: 'completion-postman-001',
      userId: 'user-a',
      courseId: 'vi_en',
      lessonVersion: 'v2.u1n1l1',
      rewardIdentity: 'u1n1l1',
      source: 'ONLINE',
      mode: 'LESSON',
      originalCount: 13,
      originalCorrect: correct,
      assisted: false,
    },
  };
}

// ---------------------------------------------------------------------------
// Test scripts
// ---------------------------------------------------------------------------

function documentedStatuses(op) {
  return Object.keys(op.responses)
    .map(Number)
    .filter((value) => Number.isFinite(value))
    .sort((a, b) => a - b);
}

function commonTestLines(op) {
  const statuses = documentedStatuses(op);
  const lines = [
    `const documentedStatuses = [${statuses.join(', ')}];`,
    'pm.test("status is documented by OpenAPI", function () {',
    '  pm.expect(documentedStatuses).to.include(pm.response.code);',
    '});',
    'pm.test("response is JSON", function () {',
    '  pm.expect((pm.response.headers.get("Content-Type") || "")).to.include("application/json");',
    '});',
    'if (pm.response.code >= 400) {',
    '  pm.test("error envelope matches the OpenAPI Error schema", function () {',
    '    const body = pm.response.json();',
    '    pm.expect(body).to.have.property("error");',
    '    const error = body.error;',
    '    pm.expect(Object.keys(error).sort()).to.eql(["code", "details", "message", "requestId", "retryable"]);',
    '    pm.expect(error.code).to.be.a("string");',
    '    pm.expect(error.message).to.be.a("string");',
    '    pm.expect(error.requestId).to.be.a("string");',
    '    pm.expect(error.details).to.be.an("object");',
    '    pm.expect(error.retryable).to.be.a("boolean");',
    '  });',
    '} else {',
    '  pm.test("success response is a JSON object", function () {',
    '    const body = pm.response.json();',
    '    pm.expect(body).to.be.an("object");',
    '  });',
    '}',
  ];
  if (op.operationId === 'getHealth') {
    lines.unshift(
      'pm.test("health status is 200", function () {',
      '  pm.response.to.have.status(200);',
      '});',
    );
  }
  if (op.operationId === 'getReadiness') {
    lines.unshift(
      'if (pm.environment.get("service_signing_mode") === "dev-keyring") {',
      '  pm.test("dev /ready fails closed with 503", function () {',
      '    pm.response.to.have.status(503);',
      '  });',
      '  pm.test("dev /ready reports SERVICE_NOT_CONFIGURED", function () {',
      '    pm.expect(pm.response.json().error.code).to.eql("SERVICE_NOT_CONFIGURED");',
      '  });',
      '}',
    );
  }
  return lines;
}

const CAPTURES = {
  listCourses: [
    ['items[0].courseId', 'courseId'],
    ['items[0].publishedVersion', 'courseVersion'],
  ],
  getManifest: [['courseVersion', 'courseVersion']],
  enrollCourse: [['revision', 'expectedRevision']],
  getPath: [
    ['enrollment.revision', 'expectedRevision'],
    ['nodes[0].lessonIds[0]', 'lessonId'],
  ],
  startSession: [
    ['sessionId', 'sessionId'],
    ['revision', 'sessionRevision'],
    ['lessonVersion', 'lessonVersion'],
  ],
  submitAnswer: [
    ['sessionRevision', 'sessionRevision'],
    ['nextOriginalOrdinal', 'nextOriginalOrdinal'],
  ],
  completeSession: [
    ['completionId', 'completionId'],
    ['enrollmentRevision', 'expectedRevision'],
    ['rewardStatus', 'lastRewardStatus'],
  ],
  syncOfflineCompletion: [
    ['completionId', 'completionId'],
    ['enrollmentRevision', 'expectedRevision'],
  ],
  getMe: [['revision', 'profileRevision']],
  updateMe: [['revision', 'profileRevision']],
  initializeProfile: [
    ['revision', 'profileRevision'],
    ['userId', 'userIdA'],
  ],
  getPreferences: [['revision', 'preferencesRevision']],
  updatePreferences: [['revision', 'preferencesRevision']],
  getRewards: [['revision', 'rewardRevision']],
  listQuests: [
    ['items[0].questId', 'questId'],
    ['items[0].periodKey', 'questPeriodKey'],
  ],
  claimQuest: [['revision', 'rewardRevision']],
  buyFreeze: [['revision', 'rewardRevision']],
  listShop: [
    ['catalogVersion', 'catalogVersion'],
    ['items[0].itemId', 'shopItemId'],
  ],
  buyItem: [['operationId', 'shopPurchaseOperationId']],
  getEnergy: [['revision', 'energyRevision']],
  getPublicProfile: [['userId', 'profileUserId']],
  listFriends: [['items[0].userId', 'friendUserId']],
  getLeague: [
    ['weekId', 'leagueWeekId'],
    ['cohortId', 'leagueCohortId'],
  ],
  getLeagueResult: [['unseen', 'leagueResultUnseen']],
  getEntitlement: [['revision', 'entitlementRevision']],
  verifyPurchase: [
    ['purchaseId', 'purchaseId'],
    ['entitlement.revision', 'entitlementRevision'],
  ],
  createVoiceSession: [
    ['sessionId', 'voiceSessionId'],
    ['epoch', 'voiceEpoch'],
  ],
  heartbeatVoiceSession: [['epoch', 'voiceEpoch']],
  closeVoiceSession: [['epoch', 'voiceEpoch']],
  createAssessment: [['jobId', 'assessmentJobId']],
  getAssessment: [['jobId', 'assessmentJobId']],
  startConversation: [['conversationId', 'conversationId']],
  completeConversation: [['conversationId', 'conversationId']],
  createFamily: [
    ['groupId', 'groupId'],
    ['inviteCode', 'inviteCode'],
  ],
  joinFamily: [['groupId', 'groupId']],
  sendGift: [['giftId', 'giftId']],
  getReferral: [['code', 'referralCode']],
  recordAdEvent: [['adEventId', 'adEventId']],
  consumeEvent: [['status', 'lastEventStatus']],
  getYearReview: [['year', 'yearReviewYear']],
};

function accessExpression(nestedPath) {
  let expression = 'body';
  const segments = nestedPath.replace(/\[(\d+)\]/g, '.$1').split('.');
  for (const segment of segments) {
    if (/^\d+$/.test(segment)) {
      expression = `${expression} && ${expression}[${segment}]`;
    } else {
      expression = `${expression} && ${expression}.${segment}`;
    }
  }
  return expression;
}

function captureLines(operationId) {
  const captures = CAPTURES[operationId];
  if (!captures || captures.length === 0) return [];
  const lines = [
    'if (pm.response.code >= 200 && pm.response.code < 300) {',
    '  const body = pm.response.json();',
  ];
  for (const [nestedPath, variable] of captures) {
    lines.push(
      `  const ${variable}Value = ${accessExpression(nestedPath)};`,
      `  if (${variable}Value !== undefined && ${variable}Value !== null) {`,
      `    pm.environment.set("${variable}", String(${variable}Value));`,
      '  }',
    );
  }
  lines.push('}');
  if (operationId === 'startSession') {
    lines.push(
      'if (pm.response.code === 200) {',
      '  const body = pm.response.json();',
      '  try {',
      '    const exercises = (body.bundle && body.bundle.exercises) || [];',
      '    const answers = exercises.map(function (exercise) {',
      '      let answer = null;',
      '      const rule = exercise.gradingRule || {};',
      '      if (["choice", "listenChoice", "imageChoice", "storyQuestion"].indexOf(exercise.type) !== -1) {',
      '        answer = { kind: "choice", choiceId: rule.correctChoiceId };',
      '      } else if (exercise.type === "matchPairs") {',
      '        answer = {',
      '          kind: "pairs",',
      '          matches: ((exercise.content && exercise.content.pairs) || []).map(function (pair) {',
      '            return { leftId: pair.left.id, rightId: pair.right.id };',
      '          }),',
      '        };',
      '      } else if (exercise.type === "wordBank" || exercise.type === "sentenceOrder") {',
      '        answer = { kind: "tokens", tokenIds: rule.correctTokenIds || [] };',
      '      } else if (["fillBlank", "textTranslation", "dictation", "speakRepeat", "dialogueTurn"].indexOf(exercise.type) !== -1) {',
      '        answer = { kind: "text", text: (rule.acceptedText || [""])[0] };',
      '      } else {',
      '        throw new Error("Unsupported authored exercise type: " + exercise.type);',
      '      }',
      '      return { exerciseId: exercise.id, answer: answer };',
      '    });',
      '    pm.environment.set("sessionAnswers", JSON.stringify(answers));',
      '    pm.environment.set("sessionExerciseCount", String(answers.length));',
      '    if (exercises[0] && exercises[0].id) pm.environment.set("exerciseId", exercises[0].id);',
      '  } catch (error) {',
      '    pm.environment.set("sessionAnswers", "[]");',
      '    pm.test("authored answer plan is available", function () { throw error; });',
      '  }',
      '}',
    );
  }
  return lines;
}

function exactStatusLines(status, code) {
  const lines = [
    `pm.test("status is ${status}", function () {`,
    `  pm.response.to.have.status(${status});`,
    '});',
  ];
  if (code) {
    lines.push(
      `pm.test("error code is ${code}", function () {`,
      `  pm.expect(pm.response.json().error.code).to.eql("${code}");`,
      '});',
    );
  }
  return lines;
}

function scenarioTestLines(status, code, extra = []) {
  return [
    ...exactStatusLines(status, code),
    'pm.test("response is JSON", function () {',
    '  pm.expect((pm.response.headers.get("Content-Type") || "")).to.include("application/json");',
    '});',
    'if (pm.response.code >= 400) {',
    '  pm.test("error envelope is complete", function () {',
    '    const error = pm.response.json().error;',
    '    pm.expect(Object.keys(error).sort()).to.eql(["code", "details", "message", "requestId", "retryable"]);',
    '  });',
    '}',
    ...extra,
  ];
}

// ---------------------------------------------------------------------------
// Postman item builders
// ---------------------------------------------------------------------------

function makeUrl(base, apiPath, query) {
  const search = query.length
    ? `?${query.map((entry) => `${entry.key}=${entry.value}`).join('&')}`
    : '';
  return {
    raw: `${base}${apiPath}${search}`,
    host: [base],
    path: apiPath.split('/').filter(Boolean),
    ...(query.length
      ? { query: query.map((entry) => ({ key: entry.key, value: entry.value })) }
      : {}),
  };
}

function makeItem({
  name,
  description,
  method,
  base,
  apiPath,
  query = [],
  headers = [],
  body = null,
  tests = [],
  preRequest = null,
}) {
  const allHeaders = [...headers];
  if (body !== null && !allHeaders.some((header) => header.key.toLowerCase() === 'content-type')) {
    allHeaders.push({ key: 'Content-Type', value: 'application/json', type: 'text' });
  }
  const event = [];
  if (preRequest) {
    event.push({
      listen: 'prerequest',
      script: { type: 'text/javascript', exec: preRequest },
    });
  }
  event.push({ listen: 'test', script: { type: 'text/javascript', exec: tests } });
  return {
    name,
    event,
    request: {
      method,
      header: allHeaders,
      url: makeUrl(base, apiPath, query),
      description,
      ...(body !== null
        ? {
            body: {
              mode: 'raw',
              raw: body,
              options: { raw: { language: 'json' } },
            },
          }
        : {}),
    },
    response: [],
  };
}

const TOKEN_B_OPERATIONS = new Set(['deleteAccount', 'joinFamily', 'redeemGift', 'redeemReferral']);

function userHeaders(op, overrideToken) {
  const headers = [{ key: 'Accept', value: 'application/json', type: 'text' }];
  headers.push({
    key: 'Authorization',
    value: `Bearer ${overrideToken ?? (TOKEN_B_OPERATIONS.has(op.operationId) ? '{{token_b}}' : '{{token_a}}')}`,
    type: 'text',
  });
  return headers;
}

function baselineItem(spec, op) {
  const query = queryParameters(spec, op);
  const bodyObject = requestBody(spec, op.op, op.operationId);
  const body = bodyObject === null ? null : renderBody(bodyObject);
  const headers = isUserRoute(op)
    ? userHeaders(op)
    : [{ key: 'Accept', value: 'application/json', type: 'text' }];
  if (isUserRoute(op) && requiresIdempotency(spec, op)) {
    headers.push({
      key: 'Idempotency-Key',
      value: `{{${idempotencyVariable(op.operationId)}}}`,
      type: 'text',
    });
  }
  const summary = op.op.summary ?? op.op.description ?? '';
  const authLine = isUserRoute(op)
    ? TOKEN_B_OPERATIONS.has(op.operationId)
      ? 'Authorization: `Bearer {{token_b}}` (second synthetic user, used for isolation, family join, gift/referral redemption and account deletion).'
      : 'Authorization: `Bearer {{token_a}}` (Appwrite JWT).'
    : op.path === '/health'
      ? 'No authentication.'
      : 'Internal HMAC (`X-Service-*`) computed by the collection pre-request script.';
  const idempotencyLine = requiresIdempotency(spec, op)
    ? `Idempotency-Key: \`{{${idempotencyVariable(op.operationId)}}}\` (scenario-specific UUID; replay reuses it).`
    : 'No Idempotency-Key parameter for this operation.';
  const description = [
    `OpenAPI operation: \`${op.method} ${op.path}\` (\`${op.operationId}\`)`,
    '',
    `Owner: **${ownerFolder(op)}**. ${summary}`,
    '',
    `Auth: ${authLine}`,
    idempotencyLine,
    '',
    'Tests assert that the status is one of the OpenAPI-documented statuses, that JSON is returned, and that every error uses the canonical error envelope. Positive and negative chains live in the scenario folders.',
  ].join('\n');
  return makeItem({
    name: `${op.operationId} (${op.method} ${op.path})`,
    description,
    method: op.method,
    base: `{{${baseVar(op)}}}`,
    apiPath: requestPath(op),
    query,
    headers,
    body,
    tests: [...commonTestLines(op.op), ...captureLines(op.operationId)],
  });
}

function scenarioItem({
  name,
  description,
  method,
  base,
  apiPath,
  query = [],
  headers,
  body = null,
  status,
  code,
  extraTests = [],
  captures = [],
  preRequest = null,
}) {
  return makeItem({
    name,
    description,
    method,
    base,
    apiPath,
    query,
    headers,
    body: body === null ? null : renderBody(body),
    tests: [...scenarioTestLines(status, code), ...captures, ...extraTests],
    preRequest,
  });
}

const LEARNING_CATEGORY = {
  listCourses: 'Catalog',
  getManifest: 'Catalog',
  getBundle: 'Catalog',
  enrollCourse: 'Enrollment',
  getPath: 'Enrollment',
  getEnergy: 'Enrollment',
  startSession: 'Sessions',
  getSession: 'Sessions',
  submitAnswer: 'Sessions',
  completeSession: 'Sessions',
  abandonSession: 'Sessions',
  syncOfflineCompletion: 'Sessions',
  getReview: 'Review',
  listMistakes: 'Review',
  listWords: 'Review',
  listActivityProgress: 'Review',
  createReport: 'Reports & publishing',
  publishContent: 'Reports & publishing',
  switchCourse: 'Course lifecycle',
  resetCourse: 'Course lifecycle',
  removeCourse: 'Course lifecycle',
};

const PROGRESS_CATEGORY = {
  getMe: 'Profile',
  updateMe: 'Profile',
  initializeProfile: 'Profile',
  getPreferences: 'Profile',
  updatePreferences: 'Profile',
  getRewards: 'Rewards & quests',
  listQuests: 'Rewards & quests',
  claimQuest: 'Rewards & quests',
  buyFreeze: 'Shop & economy',
  listShop: 'Shop & economy',
  buyItem: 'Shop & economy',
  activateBoost: 'Shop & economy',
  repairStreak: 'Shop & economy',
  getPublicProfile: 'Social',
  followUser: 'Social',
  unfollowUser: 'Social',
  listFriends: 'Social',
  listFriendStreaks: 'Social',
  inviteFriendStreak: 'Social',
  respondFriendStreak: 'Social',
  sendInteraction: 'Social',
  blockUser: 'Social',
  unblockUser: 'Social',
  reportUser: 'Social',
  listActivity: 'Social',
  joinLeague: 'League',
  getLeague: 'League',
  optInFriendQuest: 'League',
  getLeagueResult: 'League',
  markLeagueResultSeen: 'League',
  getYearReview: 'Year review',
  getEntitlement: 'Entitlement & billing',
  verifyPurchase: 'Entitlement & billing',
  getPurchase: 'Entitlement & billing',
  cancelSubscription: 'Entitlement & billing',
  createFamily: 'Family',
  joinFamily: 'Family',
  removeFamilyMember: 'Family',
  sendGift: 'Gifts & referrals',
  redeemGift: 'Gifts & referrals',
  getReferral: 'Gifts & referrals',
  redeemReferral: 'Gifts & referrals',
  redeemPromoCode: 'Gifts & referrals',
  recordAdEvent: 'Gifts & referrals',
  sendFeedback: 'Classrooms & feedback',
  joinClassroom: 'Classrooms & feedback',
  leaveClassroom: 'Classrooms & feedback',
  getLearningStats: 'Learning stats',
  deleteAccount: 'Account deletion',
};

const AI_CATEGORY = {
  getCapabilities: 'Capabilities & tutor',
  tutorFeedback: 'Capabilities & tutor',
  createVoiceSession: 'Voice',
  heartbeatVoiceSession: 'Voice',
  submitVoiceTurn: 'Voice',
  closeVoiceSession: 'Voice',
  createAssessment: 'Assessment',
  getAssessment: 'Assessment',
  listConversations: 'Conversations',
  startConversation: 'Conversations',
  completeConversation: 'Conversations',
};

const INTERNAL_CATEGORY = {
  getHealth: 'Health & readiness',
  getReadiness: 'Health & readiness',
  consumeEvent: 'Events & watermark',
  getOutboxWatermark: 'Events & watermark',
  runStreakRollover: 'Scheduler jobs',
  runLeagueSettlement: 'Scheduler jobs',
  runDeletionPurge: 'Scheduler jobs',
  runProgressOutboxRelay: 'Scheduler jobs',
  runLearningOutboxDispatch: 'Scheduler jobs',
  billingNotification: 'Billing notifications',
};

const OPERATION_ORDER = {
  Learning: [
    'listCourses',
    'getManifest',
    'getBundle',
    'enrollCourse',
    'getPath',
    'getEnergy',
    'startSession',
    'getSession',
    'submitAnswer',
    'completeSession',
    'abandonSession',
    'syncOfflineCompletion',
    'getReview',
    'listMistakes',
    'listWords',
    'listActivityProgress',
    'createReport',
    'publishContent',
    'switchCourse',
    'resetCourse',
    'removeCourse',
  ],
  Progress: [
    'getMe',
    'updateMe',
    'initializeProfile',
    'getPreferences',
    'updatePreferences',
    'getRewards',
    'listQuests',
    'claimQuest',
    'buyFreeze',
    'listShop',
    'buyItem',
    'activateBoost',
    'repairStreak',
    'getPublicProfile',
    'followUser',
    'listFriends',
    'listFriendStreaks',
    'inviteFriendStreak',
    'respondFriendStreak',
    'sendInteraction',
    'blockUser',
    'reportUser',
    'unfollowUser',
    'unblockUser',
    'listActivity',
    'joinLeague',
    'getLeague',
    'optInFriendQuest',
    'getLeagueResult',
    'markLeagueResultSeen',
    'getYearReview',
    'getEntitlement',
    'verifyPurchase',
    'getPurchase',
    'cancelSubscription',
    'createFamily',
    'joinFamily',
    'removeFamilyMember',
    'sendGift',
    'redeemGift',
    'getReferral',
    'redeemReferral',
    'redeemPromoCode',
    'recordAdEvent',
    'sendFeedback',
    'joinClassroom',
    'leaveClassroom',
    'getLearningStats',
    'deleteAccount',
  ],
  AI: [
    'getCapabilities',
    'tutorFeedback',
    'createVoiceSession',
    'heartbeatVoiceSession',
    'submitVoiceTurn',
    'closeVoiceSession',
    'createAssessment',
    'getAssessment',
    'listConversations',
    'startConversation',
    'completeConversation',
  ],
  Internal: [
    'getHealth',
    'getReadiness',
    'consumeEvent',
    'getOutboxWatermark',
    'runStreakRollover',
    'runLeagueSettlement',
    'runDeletionPurge',
    'runProgressOutboxRelay',
    'runLearningOutboxDispatch',
    'billingNotification',
  ],
};

function categoryFor(op, folder) {
  const map =
    folder === 'Learning'
      ? LEARNING_CATEGORY
      : folder === 'Progress'
        ? PROGRESS_CATEGORY
        : folder === 'AI'
          ? AI_CATEGORY
          : INTERNAL_CATEGORY;
  return map[op.operationId] ?? 'Other';
}

function sortOperations(folder, list) {
  const order = OPERATION_ORDER[folder] ?? [];
  const index = new Map(order.map((operationId, position) => [operationId, position]));
  return [...list].sort((left, right) => {
    const leftIndex = index.has(left.operationId) ? index.get(left.operationId) : 10_000;
    const rightIndex = index.has(right.operationId) ? index.get(right.operationId) : 10_000;
    if (leftIndex !== rightIndex) return leftIndex - rightIndex;
    return left.path.localeCompare(right.path) || left.method.localeCompare(right.method);
  });
}

function groupIntoCategories(folder, items, categoryMap) {
  const order = [];
  const groups = new Map();
  for (const { op, item } of items) {
    const category = categoryMap[op.operationId] ?? 'Other';
    if (!groups.has(category)) {
      groups.set(category, []);
      order.push(category);
    }
    groups.get(category).push(item);
  }
  return order.map((category) => ({
    name: category,
    description: `${folder} operations in the ${category} area. Each request is generated from docs/api/openapi.yaml.`,
    item: groups.get(category),
  }));
}

// ---------------------------------------------------------------------------
// Scenario folders
// ---------------------------------------------------------------------------

function authHeaders(token = '{{token_a}}') {
  return [
    { key: 'Accept', value: 'application/json', type: 'text' },
    { key: 'Authorization', value: `Bearer ${token}`, type: 'text' },
  ];
}

function withIdempotency(headers, key) {
  return [...headers, { key: 'Idempotency-Key', value: `{{${key}}}`, type: 'text' }];
}

function goldenPathFolder() {
  const items = [];
  items.push(
    scenarioItem({
      name: 'Initialize profile A',
      description:
        'Golden path step 1. Initializes token A profile (dev token `dev-user-a` -> subject `user-a`). Captures the profile revision used by optimistic updates.',
      method: 'POST',
      base: '{{progress_base_url}}',
      apiPath: '/v1/me/initialize',
      headers: withIdempotency(authHeaders('{{token_a}}'), 'idem_scenario_init_a'),
      status: 200,
      captures: [
        'if (pm.response.code === 200) { pm.environment.set("profileRevision", String(pm.response.json().revision)); pm.environment.set("userIdA", String(pm.response.json().userId)); }',
      ],
    }),
    scenarioItem({
      name: 'Initialize profile B',
      description:
        'Golden path step 2. Initializes the second synthetic user. B is used for isolation, follow, family and gift scenarios.',
      method: 'POST',
      base: '{{progress_base_url}}',
      apiPath: '/v1/me/initialize',
      headers: withIdempotency(authHeaders('{{token_b}}'), 'idem_scenario_init_b'),
      status: 200,
      captures: [
        'if (pm.response.code === 200) { pm.environment.set("profileRevisionB", String(pm.response.json().revision)); pm.environment.set("userIdB", String(pm.response.json().userId)); pm.environment.set("targetUserId", String(pm.response.json().userId)); }',
      ],
    }),
    scenarioItem({
      name: 'Make profile A public',
      description:
        'Golden path step 3. Enables league participation and a public profile projection for A.',
      method: 'PATCH',
      base: '{{progress_base_url}}',
      apiPath: '/v1/me',
      headers: withIdempotency(authHeaders('{{token_a}}'), 'idem_scenario_patch_a'),
      body: {
        nickname: 'Learner A',
        publicOptIn: true,
        expectedRevision: new Raw('{{profileRevision}}'),
      },
      status: 200,
      captures: [
        'if (pm.response.code === 200) pm.environment.set("profileRevision", String(pm.response.json().revision));',
      ],
    }),
    scenarioItem({
      name: 'Make profile B public',
      description:
        'Golden path step 4. Makes B discoverable so `getPublicProfile` and `followUser` have a valid target.',
      method: 'PATCH',
      base: '{{progress_base_url}}',
      apiPath: '/v1/me',
      headers: withIdempotency(authHeaders('{{token_b}}'), 'idem_scenario_patch_b'),
      body: {
        nickname: 'Learner B',
        publicOptIn: true,
        expectedRevision: new Raw('{{profileRevisionB}}'),
      },
      status: 200,
      captures: [
        'if (pm.response.code === 200) pm.environment.set("profileRevisionB", String(pm.response.json().revision));',
      ],
    }),
    scenarioItem({
      name: 'Purchase simulated MAX for A',
      description:
        'Golden path step 5. Simulation-only purchase (no real money, no provider). Grants MAX so conversation and family scenarios are testable. The same product is replayed in the idempotency folder under a different key.',
      method: 'POST',
      base: '{{progress_base_url}}',
      apiPath: '/v1/billing/purchases',
      headers: withIdempotency(authHeaders('{{token_a}}'), 'idem_scenario_golden_purchase'),
      body: {
        productId: 'max_monthly',
        kind: 'SUBSCRIPTION',
        platform: 'SIMULATION',
        simulationOutcome: 'ACTIVE',
      },
      status: 200,
      captures: [
        'if (pm.response.code === 200) { pm.environment.set("purchaseId", String(pm.response.json().purchaseId)); pm.environment.set("entitlementRevision", String(pm.response.json().entitlement.revision)); }',
      ],
    }),
    scenarioItem({
      name: 'List courses',
      description: 'Golden path step 6. Discovers the seeded local course and captures `courseId`.',
      method: 'GET',
      base: '{{learning_base_url}}',
      apiPath: '/v1/courses',
      query: [{ key: 'limit', value: '20' }],
      headers: authHeaders('{{token_a}}'),
      status: 200,
      captures: [
        'if (pm.response.code === 200 && pm.response.json().items && pm.response.json().items[0]) { pm.environment.set("courseId", String(pm.response.json().items[0].courseId)); pm.environment.set("courseVersion", String(pm.response.json().items[0].publishedVersion)); }',
      ],
    }),
    scenarioItem({
      name: 'Enroll in the seeded course',
      description:
        'Golden path step 7. Beginner enrollment. Re-running against the same in-memory process returns the current enrollment; restart services for a clean synthetic state.',
      method: 'POST',
      base: '{{learning_base_url}}',
      apiPath: '/v1/enrollments',
      headers: withIdempotency(authHeaders('{{token_a}}'), 'idem_scenario_golden_enroll'),
      body: { courseId: '{{courseId}}', startPoint: 'beginner' },
      status: 200,
      captures: [
        'if (pm.response.code === 200) pm.environment.set("expectedRevision", String(pm.response.json().revision));',
      ],
    }),
    scenarioItem({
      name: 'Read path and capture lesson',
      description:
        'Golden path step 8. Captures the first available lesson and enrollment revision.',
      method: 'GET',
      base: '{{learning_base_url}}',
      apiPath: '/v1/courses/{{courseId}}/path',
      query: [{ key: 'limit', value: '20' }],
      headers: authHeaders('{{token_a}}'),
      status: 200,
      captures: [
        'if (pm.response.code === 200) { const body = pm.response.json(); pm.environment.set("expectedRevision", String(body.enrollment.revision)); const lesson = body.nodes && body.nodes[0] && body.nodes[0].lessonIds && body.nodes[0].lessonIds[0]; if (lesson) pm.environment.set("lessonId", String(lesson)); }',
      ],
    }),
    scenarioItem({
      name: 'Start lesson session',
      description:
        'Golden path step 9. Starts the seeded lesson, captures `sessionId`, `sessionRevision`, `lessonVersion`, `exerciseId` and a compact answer plan generated from the returned bundle. The plan is used by the 20 answer steps so the chain is not hard-coded to exercise text.',
      method: 'POST',
      base: '{{learning_base_url}}',
      apiPath: '/v1/sessions',
      headers: withIdempotency(authHeaders('{{token_a}}'), 'idem_scenario_start_golden'),
      body: {
        courseId: '{{courseId}}',
        lessonId: '{{lessonId}}',
        mode: 'LESSON',
        expectedEnrollmentRevision: new Raw('{{expectedRevision}}'),
      },
      status: 200,
      captures: captureLines('startSession').concat([
        'if (pm.response.code === 200) { const body = pm.response.json(); pm.environment.set("sessionId", String(body.sessionId)); pm.environment.set("sessionRevision", String(body.revision)); pm.environment.set("lessonVersion", String(body.lessonVersion)); }',
      ]),
    }),
  );

  for (let index = 0; index < 20; index += 1) {
    const ordinal = String(index + 1).padStart(2, '0');
    items.push(
      scenarioItem({
        name: `Answer ${ordinal} (generated from bundle)`,
        description: [
          'Golden path step 10. Builds the answer body in the request pre-request script from the compact `sessionAnswers` plan captured by "Start lesson session".',
          '',
          'The body is rebuilt from the current `sessionRevision` so optimistic concurrency stays correct. Extra steps beyond the lesson exercise count call `pm.execution.skipRequest()`.',
        ].join('\n'),
        method: 'POST',
        base: '{{learning_base_url}}',
        apiPath: '/v1/sessions/{{sessionId}}/answers',
        headers: withIdempotency(authHeaders('{{token_a}}'), `idem_scenario_answer_${ordinal}`),
        body: {
          exerciseId: '{{exerciseId}}',
          attemptOrdinal: 0,
          answer: { kind: 'choice', choiceId: '{{choiceId}}' },
          assisted: false,
          substituted: false,
          expectedRevision: 0,
        },
        status: 200,
        preRequest: [
          `var answerIndex = ${index};`,
          'var plan = [];',
          'try { plan = JSON.parse(pm.environment.get("sessionAnswers") || "[]"); } catch (error) { plan = []; }',
          'if (!Array.isArray(plan) || plan.length === 0) throw new Error("No captured authored answer plan; start the lesson first");',
          'var planned = plan[answerIndex];',
          'if (!planned || !planned.answer) {',
          '  if (pm.execution && pm.execution.skipRequest) pm.execution.skipRequest();',
          '} else {',
          '  var body = {',
          '    exerciseId: planned.exerciseId,',
          '    attemptOrdinal: 0,',
          '    answer: planned.answer,',
          '    assisted: false,',
          '    substituted: false,',
          '    expectedRevision: Number(pm.environment.get("sessionRevision") || 0),',
          '  };',
          '  pm.request.body.raw = JSON.stringify(body);',
          '}',
        ],
        extraTests: [
          'if (pm.response.code === 200) {',
          '  const body = pm.response.json();',
          '  pm.test("answer is graded correct by the authored content", function () { pm.expect(body.correct).to.eql(true); });',
          '  pm.environment.set("sessionRevision", String(body.sessionRevision));',
          '  pm.environment.set("nextOriginalOrdinal", String(body.nextOriginalOrdinal));',
          '}',
        ],
      }),
    );
  }

  items.push(
    scenarioItem({
      name: 'Complete lesson session',
      description:
        'Golden path step 11. Completes the fully answered session; captures `completionId` and the next enrollment revision.',
      method: 'POST',
      base: '{{learning_base_url}}',
      apiPath: '/v1/sessions/{{sessionId}}/complete',
      headers: withIdempotency(authHeaders('{{token_a}}'), 'idem_scenario_complete'),
      body: { expectedRevision: new Raw('{{sessionRevision}}') },
      status: 200,
      captures: captureLines('completeSession'),
      extraTests: [
        'if (pm.response.code === 200) {',
        '  const body = pm.response.json();',
        '  pm.test("all authored originals were graded", function () { pm.expect(body.originalCorrect).to.eql(body.originalCount); });',
        '  pm.environment.set("sessionId", String(body.sessionId));',
        '}',
      ],
    }),
    scenarioItem({
      name: 'Read rewards for the completion',
      description:
        'Golden path step 12. Reads the Progress projection for the completion event. Dev mode relays the signed event immediately; if a durable runner shows `pending`, retry after the outbox worker runs.',
      method: 'GET',
      base: '{{progress_base_url}}',
      apiPath: '/v1/me/rewards',
      query: [{ key: 'completionId', value: '{{completionId}}' }],
      headers: authHeaders('{{token_a}}'),
      status: 200,
      captures: [
        'if (pm.response.code === 200) pm.environment.set("rewardRevision", String(pm.response.json().revision));',
      ],
      preRequest: [
        '// Dev relays lesson.completed.v1 immediately; give that in-process delivery a moment',
        '// before reading the Progress projection. Hosted runners can remove this wait and retry',
        '// the request after the outbox worker acknowledges.',
        'var waitUntil = Date.now() + 500;',
        'while (Date.now() < waitUntil) { /* bounded local wait */ }',
      ],
      extraTests: [
        'if (pm.response.code === 200) {',
        '  const body = pm.response.json();',
        '  pm.test("reward is credited for the captured completion", function () { pm.expect(body.status).to.eql("credited"); });',
        '  pm.test("reward completion matches the completion id", function () { pm.expect(String(body.completionId)).to.eql(pm.environment.get("completionId")); });',
        '  pm.test("study XP was awarded", function () { pm.expect(body.studyXp).to.be.above(0); });',
        '}',
      ],
    }),
    scenarioItem({
      name: 'Read current profile after the chain',
      description:
        'Golden path step 13. Confirms the Progress profile is readable after the reward projection.',
      method: 'GET',
      base: '{{progress_base_url}}',
      apiPath: '/v1/me',
      headers: authHeaders('{{token_a}}'),
      status: 200,
      captures: [
        'if (pm.response.code === 200) pm.environment.set("profileRevision", String(pm.response.json().revision));',
      ],
    }),
  );

  return {
    name: 'Golden path (enroll -> answers -> complete -> rewards)',
    description:
      'Ordered positive chain across Learning and Progress. Run this first against a freshly restarted `pnpm dev:services` with `COC_DEV_AUTH=1`. It initializes both synthetic users, grants simulated MAX to A, completes the seeded lesson, and asserts the reward is credited.',
    item: items,
  };
}

function learningIdempotencyFolder() {
  return {
    name: 'Idempotency (Learning)',
    description:
      'Each mutation uses a fixed scenario UUID in the environment. Replay requests reuse the SAME key and body. The changed-body request reuses the key with a different valid body and must return 409 IDEMPOTENCY_CONFLICT. Never generate a new key for the replay step.',
    item: [
      scenarioItem({
        name: 'Enroll (first write)',
        description:
          'First enroll write for the idempotency scenario. Exact 200 and the response is stored for comparison.',
        method: 'POST',
        base: '{{learning_base_url}}',
        apiPath: '/v1/enrollments',
        headers: withIdempotency(authHeaders('{{token_a}}'), 'idem_scenario_enroll'),
        body: { courseId: '{{courseId}}', startPoint: 'beginner' },
        status: 200,
        extraTests: [
          'pm.environment.set("idem_enroll_response", JSON.stringify(pm.response.json()));',
        ],
      }),
      scenarioItem({
        name: 'Enroll replay (same key + same body)',
        description:
          'Replays the exact key and body from "Enroll (first write)". The server must return the original receipt/result, not enroll twice.',
        method: 'POST',
        base: '{{learning_base_url}}',
        apiPath: '/v1/enrollments',
        headers: withIdempotency(authHeaders('{{token_a}}'), 'idem_scenario_enroll'),
        body: { courseId: '{{courseId}}', startPoint: 'beginner' },
        status: 200,
        extraTests: [
          'pm.test("replay returns the original enrollment body", function () {',
          '  const first = JSON.parse(pm.environment.get("idem_enroll_response"));',
          '  pm.expect(pm.response.json()).to.eql(first);',
          '});',
        ],
      }),
      scenarioItem({
        name: 'Enroll changed body (same key) -> 409',
        description:
          'Same idempotency key with a different valid body. The canonical body hash differs, so the server must return 409 IDEMPOTENCY_CONFLICT. This documents the rule: a key identifies one request body.',
        method: 'POST',
        base: '{{learning_base_url}}',
        apiPath: '/v1/enrollments',
        headers: withIdempotency(authHeaders('{{token_a}}'), 'idem_scenario_enroll'),
        body: { courseId: '{{courseId}}', startPoint: 'placement' },
        status: 409,
        code: 'IDEMPOTENCY_CONFLICT',
      }),
      scenarioItem({
        name: 'Start session (first write)',
        description:
          'First start-session write for the idempotency scenario. Uses the current enrollment revision captured by the golden path.',
        method: 'POST',
        base: '{{learning_base_url}}',
        apiPath: '/v1/sessions',
        headers: withIdempotency(authHeaders('{{token_a}}'), 'idem_scenario_session'),
        body: {
          courseId: '{{courseId}}',
          lessonId: '{{lessonId}}',
          mode: 'LESSON',
          expectedEnrollmentRevision: new Raw('{{expectedRevision}}'),
        },
        status: 200,
        extraTests: [
          'pm.environment.set("idem_start_response", JSON.stringify(pm.response.json()));',
          'if (pm.response.code === 200) { pm.environment.set("sessionId", String(pm.response.json().sessionId)); pm.environment.set("sessionRevision", String(pm.response.json().revision)); }',
        ],
      }),
      scenarioItem({
        name: 'Start session replay (same key + same body)',
        description:
          'Replays the exact key/body. The same session identity and revision must come back; no second session is created.',
        method: 'POST',
        base: '{{learning_base_url}}',
        apiPath: '/v1/sessions',
        headers: withIdempotency(authHeaders('{{token_a}}'), 'idem_scenario_session'),
        body: {
          courseId: '{{courseId}}',
          lessonId: '{{lessonId}}',
          mode: 'LESSON',
          expectedEnrollmentRevision: new Raw('{{expectedRevision}}'),
        },
        status: 200,
        extraTests: [
          'pm.test("replay returns the original session body", function () {',
          '  pm.expect(pm.response.json()).to.eql(JSON.parse(pm.environment.get("idem_start_response")));',
          '});',
        ],
      }),
      scenarioItem({
        name: 'Start session changed body (same key) -> 409',
        description:
          'Same key with a different valid mode. Must return 409 IDEMPOTENCY_CONFLICT before creating another session.',
        method: 'POST',
        base: '{{learning_base_url}}',
        apiPath: '/v1/sessions',
        headers: withIdempotency(authHeaders('{{token_a}}'), 'idem_scenario_session'),
        body: {
          courseId: '{{courseId}}',
          lessonId: '{{lessonId}}',
          mode: 'MASTERY',
          expectedEnrollmentRevision: new Raw('{{expectedRevision}}'),
        },
        status: 409,
        code: 'IDEMPOTENCY_CONFLICT',
      }),
      scenarioItem({
        name: 'Abandon session (first write)',
        description:
          'Abandons the session created by this folder so the baseline session requests start from a clean active-session state.',
        method: 'POST',
        base: '{{learning_base_url}}',
        apiPath: '/v1/sessions/{{sessionId}}/abandon',
        headers: withIdempotency(authHeaders('{{token_a}}'), 'idem_scenario_abandon'),
        body: { expectedRevision: new Raw('{{sessionRevision}}') },
        status: 200,
        extraTests: [
          'pm.environment.set("idem_abandon_response", JSON.stringify(pm.response.json()));',
          'pm.environment.set("abandonConflictRevision", String(Number(pm.environment.get("sessionRevision")) + 1));',
        ],
      }),
      scenarioItem({
        name: 'Abandon replay (same key + same body)',
        description: 'Replays abandon with the same key/body and expects the original receipt.',
        method: 'POST',
        base: '{{learning_base_url}}',
        apiPath: '/v1/sessions/{{sessionId}}/abandon',
        headers: withIdempotency(authHeaders('{{token_a}}'), 'idem_scenario_abandon'),
        body: { expectedRevision: new Raw('{{sessionRevision}}') },
        status: 200,
        extraTests: [
          'pm.test("replay returns the original abandon receipt", function () {',
          '  pm.expect(pm.response.json()).to.eql(JSON.parse(pm.environment.get("idem_abandon_response")));',
          '});',
        ],
      }),
      scenarioItem({
        name: 'Abandon changed body (same key) -> 409',
        description:
          'Same abandon key with a different expected revision. Empty/unrelated mutations must not be silently accepted.',
        method: 'POST',
        base: '{{learning_base_url}}',
        apiPath: '/v1/sessions/{{sessionId}}/abandon',
        headers: withIdempotency(authHeaders('{{token_a}}'), 'idem_scenario_abandon'),
        body: { expectedRevision: new Raw('{{abandonConflictRevision}}') },
        status: 409,
        code: 'IDEMPOTENCY_CONFLICT',
      }),
    ],
  };
}

function progressIdempotencyFolder() {
  return {
    name: 'Idempotency (Progress)',
    description:
      'Simulated purchase idempotency for token B. Same key/body replays the original purchase; a changed product with the same key returns 409.',
    item: [
      scenarioItem({
        name: 'Purchase (first write)',
        description: 'First simulated MAX purchase for B. No real money or provider call.',
        method: 'POST',
        base: '{{progress_base_url}}',
        apiPath: '/v1/billing/purchases',
        headers: withIdempotency(authHeaders('{{token_b}}'), 'idem_scenario_purchase'),
        body: {
          productId: 'max_monthly',
          kind: 'SUBSCRIPTION',
          platform: 'SIMULATION',
          simulationOutcome: 'ACTIVE',
        },
        status: 200,
        extraTests: [
          'pm.environment.set("idem_purchase_response", JSON.stringify(pm.response.json()));',
          'pm.environment.set("purchaseIdB", String(pm.response.json().purchaseId));',
        ],
      }),
      scenarioItem({
        name: 'Purchase replay (same key + same body)',
        description: 'Replays the exact purchase key/body and compares the full original response.',
        method: 'POST',
        base: '{{progress_base_url}}',
        apiPath: '/v1/billing/purchases',
        headers: withIdempotency(authHeaders('{{token_b}}'), 'idem_scenario_purchase'),
        body: {
          productId: 'max_monthly',
          kind: 'SUBSCRIPTION',
          platform: 'SIMULATION',
          simulationOutcome: 'ACTIVE',
        },
        status: 200,
        extraTests: [
          'pm.test("replay returns the original purchase", function () {',
          '  pm.expect(pm.response.json()).to.eql(JSON.parse(pm.environment.get("idem_purchase_response")));',
          '});',
        ],
      }),
      scenarioItem({
        name: 'Purchase changed body (same key) -> 409',
        description:
          'Same key with a different product. Must conflict rather than grant a second entitlement.',
        method: 'POST',
        base: '{{progress_base_url}}',
        apiPath: '/v1/billing/purchases',
        headers: withIdempotency(authHeaders('{{token_b}}'), 'idem_scenario_purchase'),
        body: {
          productId: 'super_monthly',
          kind: 'SUBSCRIPTION',
          platform: 'SIMULATION',
          simulationOutcome: 'ACTIVE',
        },
        status: 409,
        code: 'IDEMPOTENCY_CONFLICT',
      }),
    ],
  };
}

function aiIdempotencyFolder() {
  return {
    name: 'Idempotency (AI)',
    description:
      'Scripted TURN voice-session idempotency. No paid provider is contacted; the dev composition uses the scripted adapter.',
    item: [
      scenarioItem({
        name: 'Create TURN voice session (first write)',
        description: 'Creates a scripted TURN lease and captures its session id and epoch.',
        method: 'POST',
        base: '{{ai_base_url}}',
        apiPath: '/v1/voice-sessions',
        headers: withIdempotency(authHeaders('{{token_a}}'), 'idem_scenario_voice'),
        body: {
          sessionId: '{{voiceLeaseRequestId}}',
          scenarioId: '{{aiScenarioId}}',
          mode: 'TURN',
          level: 'A1',
        },
        status: 200,
        extraTests: [
          'pm.environment.set("idem_voice_response", JSON.stringify(pm.response.json()));',
          'pm.environment.set("voiceSessionId", String(pm.response.json().sessionId));',
          'pm.environment.set("voiceEpoch", String(pm.response.json().epoch));',
        ],
      }),
      scenarioItem({
        name: 'Create voice session replay (same key + same body)',
        description: 'Same key/body must return the original lease, not mint another one.',
        method: 'POST',
        base: '{{ai_base_url}}',
        apiPath: '/v1/voice-sessions',
        headers: withIdempotency(authHeaders('{{token_a}}'), 'idem_scenario_voice'),
        body: {
          sessionId: '{{voiceLeaseRequestId}}',
          scenarioId: '{{aiScenarioId}}',
          mode: 'TURN',
          level: 'A1',
        },
        status: 200,
        extraTests: [
          'pm.test("replay returns the original lease", function () {',
          '  pm.expect(pm.response.json()).to.eql(JSON.parse(pm.environment.get("idem_voice_response")));',
          '});',
        ],
      }),
      scenarioItem({
        name: 'Create voice session changed body (same key) -> 409',
        description:
          'Same key with a different scenario. Must return 409 IDEMPOTENCY_CONFLICT and not remint.',
        method: 'POST',
        base: '{{ai_base_url}}',
        apiPath: '/v1/voice-sessions',
        headers: withIdempotency(authHeaders('{{token_a}}'), 'idem_scenario_voice'),
        body: {
          sessionId: '{{voiceLeaseRequestId}}',
          scenarioId: 'rp_meet_new_friend',
          mode: 'TURN',
          level: 'A1',
        },
        status: 409,
        code: 'IDEMPOTENCY_CONFLICT',
      }),
      scenarioItem({
        name: 'Close the idempotency voice session',
        description:
          'Closes the scripted lease so later baseline voice requests do not inherit it.',
        method: 'POST',
        base: '{{ai_base_url}}',
        apiPath: '/v1/voice-sessions/{{voiceSessionId}}/close',
        headers: authHeaders('{{token_a}}'),
        status: 200,
      }),
    ],
  };
}

function internalIdempotencyFolder() {
  return {
    name: 'Idempotency and HMAC negatives (Internal)',
    description:
      'Proves the signed event path: first delivery accepted, same event replayed, changed payload conflicts, a valid key from an unauthorized sender is forbidden, and an unsigned request is rejected. The pre-request script removes the `X-Coc-Signing-Sender` helper header before sending; it never reaches the wire.',
    item: [
      scenarioItem({
        name: 'Deliver lesson.completed.v1 (Learning key)',
        description:
          'First delivery of a sample completion event signed with the Learning dev key. Body and eventId are fixed so the replay step is meaningful.',
        method: 'POST',
        base: '{{progress_base_url}}',
        apiPath: '/internal/events',
        headers: [
          { key: 'Accept', value: 'application/json', type: 'text' },
          { key: 'X-Coc-Signing-Sender', value: 'learning', type: 'text' },
        ],
        body: internalEventBody('5b8f0e6a-2f4c-4a3d-9c71-0c7d5b9a1e01', 13),
        status: 200,
        extraTests: [
          'pm.test("first signed delivery is accepted", function () { pm.expect(pm.response.json().status).to.eql("accepted"); });',
        ],
      }),
      scenarioItem({
        name: 'Replay same event (same eventId + same body)',
        description:
          'Byte-identical event signed again. Progress must answer `replayed`; the inbox hash is the dedupe identity.',
        method: 'POST',
        base: '{{progress_base_url}}',
        apiPath: '/internal/events',
        headers: [
          { key: 'Accept', value: 'application/json', type: 'text' },
          { key: 'X-Coc-Signing-Sender', value: 'learning', type: 'text' },
        ],
        body: internalEventBody('5b8f0e6a-2f4c-4a3d-9c71-0c7d5b9a1e01', 13),
        status: 200,
        extraTests: [
          'pm.test("replay is reported without applying effects again", function () { pm.expect(pm.response.json().status).to.eql("replayed"); });',
        ],
      }),
      scenarioItem({
        name: 'Changed payload with same eventId -> 409',
        description:
          'Same eventId but `originalCorrect` changed. The body hash differs, so the receiver must answer 409 IDEMPOTENCY_CONFLICT rather than accept a substituted payload.',
        method: 'POST',
        base: '{{progress_base_url}}',
        apiPath: '/internal/events',
        headers: [
          { key: 'Accept', value: 'application/json', type: 'text' },
          { key: 'X-Coc-Signing-Sender', value: 'learning', type: 'text' },
        ],
        body: internalEventBody('5b8f0e6a-2f4c-4a3d-9c71-0c7d5b9a1e01', 12),
        status: 409,
        code: 'IDEMPOTENCY_CONFLICT',
      }),
      scenarioItem({
        name: 'AI key impersonating Learning producer -> 403',
        description:
          'A valid AI HMAC signature with a body whose `producer` is Learning. The signature verifies, but the receiver sender allowlist rejects it with FORBIDDEN.',
        method: 'POST',
        base: '{{progress_base_url}}',
        apiPath: '/internal/events',
        headers: [
          { key: 'Accept', value: 'application/json', type: 'text' },
          { key: 'X-Coc-Signing-Sender', value: 'ai', type: 'text' },
        ],
        body: internalEventBody('7c9b1f2d-3e4a-4b5c-8d6e-1f2a3b4c5d02', 13),
        status: 403,
        code: 'FORBIDDEN',
      }),
      scenarioItem({
        name: 'Unsigned internal request -> 401',
        description:
          'The helper header `X-Coc-Signing-Sender: none` disables signing. Progress must fail closed with AUTH_REQUIRED, even when the JSON body is valid.',
        method: 'POST',
        base: '{{progress_base_url}}',
        apiPath: '/internal/events',
        headers: [
          { key: 'Accept', value: 'application/json', type: 'text' },
          { key: 'X-Coc-Signing-Sender', value: 'none', type: 'text' },
        ],
        body: internalEventBody('9d1e2f3a-4b5c-4d6e-8f70-1a2b3c4d5e03', 13),
        status: 401,
        code: 'AUTH_REQUIRED',
      }),
    ],
  };
}

// ---------------------------------------------------------------------------
// Collection-level HMAC pre-request script
// ---------------------------------------------------------------------------

const PRE_REQUEST_SCRIPT = String.raw`
// Collection-level pre-request script. Implements services/shared/src/service-hmac.ts:
// canonical path (RFC3986 re-encoded segments), canonical query (sorted, duplicate/unknown
// keys rejected), timestamp + "\n" + METHOD + "\n" + pathAndQuery + "\n" + sha256(rawBody),
// HMAC-SHA256, and an explicit sender policy. It also removes the local helper header
// X-Coc-Signing-Sender before the request is sent.
var COC_SENDERS = ["learning", "progress", "ai", "maintainer", "scheduler"];

function cocRfc3986(value) {
  return encodeURIComponent(value).replace(/[!'()*]/g, function (character) {
    return "%" + character.charCodeAt(0).toString(16).toUpperCase();
  });
}

function cocStrictDecode(value) {
  if (/%(?![0-9A-Fa-f]{2})/.test(value)) throw new Error("VALIDATION_ERROR: invalid percent escape");
  try {
    return decodeURIComponent(value);
  } catch (error) {
    throw new Error("VALIDATION_ERROR: invalid percent encoding");
  }
}

function cocCanonicalPath(rawPath) {
  if (rawPath.charAt(0) !== "/") throw new Error("VALIDATION_ERROR: path must start with /");
  if (rawPath === "/") return "/";
  return "/" + rawPath.slice(1).split("/").map(function (segment) {
    var decoded = cocStrictDecode(segment);
    if (!decoded || decoded === "." || decoded === ".." || decoded.indexOf("/") !== -1) {
      throw new Error("VALIDATION_ERROR: invalid path segment");
    }
    return cocRfc3986(decoded);
  }).join("/");
}

function cocCanonicalQuery(rawQuery, allowedKeys) {
  var query = rawQuery.charAt(0) === "?" ? rawQuery.slice(1) : rawQuery;
  if (!query) return "";
  var seen = {};
  var keys = [];
  query.split("&").forEach(function (part) {
    if (!part) throw new Error("VALIDATION_ERROR: empty query part");
    var index = part.indexOf("=");
    var key = cocStrictDecode(index < 0 ? part : part.slice(0, index));
    var value = index < 0 ? "" : cocStrictDecode(part.slice(index + 1));
    if (allowedKeys.indexOf(key) === -1 || Object.prototype.hasOwnProperty.call(seen, key)) {
      throw new Error("VALIDATION_ERROR: unknown or duplicate query key " + key);
    }
    seen[key] = value;
    keys.push(key);
  });
  keys.sort();
  return "?" + keys.map(function (key) {
    return cocRfc3986(key) + "=" + cocRfc3986(seen[key]);
  }).join("&");
}

function cocSignRequest(input) {
  var method = String(input.method).toUpperCase();
  var timestamp = String(Math.floor(input.nowSeconds));
  var pathAndQuery = cocCanonicalPath(input.path) + cocCanonicalQuery(input.query || "", input.allowedQueryKeys || []);
  var bodyHash = input.crypto.sha256Hex(input.body || "");
  var signingString = timestamp + "\n" + method + "\n" + pathAndQuery + "\n" + bodyHash;
  return {
    "X-Service-Key-Id": input.keyId,
    "X-Service-Timestamp": timestamp,
    "X-Service-Signature": input.crypto.hmacSha256Hex(signingString, input.secretHex),
  };
}

function cocDefaultSender(path) {
  if (path === "/ready") return "maintainer";
  if (path === "/internal/events") return "learning";
  if (path === "/internal/outbox-watermark") return "progress";
  if (path === "/internal/billing/notifications") return "maintainer";
  if (path.indexOf("/internal/jobs/") === 0) return "scheduler";
  throw new Error("No signing policy for " + path);
}

function cocAllowedSenders(path) {
  if (path === "/ready") return ["maintainer", "learning", "progress", "ai"];
  if (path === "/internal/events") return ["learning", "progress", "ai"];
  if (path === "/internal/outbox-watermark") return ["progress", "maintainer"];
  if (path === "/internal/billing/notifications") return ["maintainer"];
  if (path.indexOf("/internal/jobs/") === 0) return ["scheduler", "maintainer"];
  return [];
}

function cocAllowedQueryKeys(path) {
  return path === "/internal/outbox-watermark" ? ["before"] : [];
}

function cocPostmanCrypto() {
  return {
    sha256Hex: function (value) {
      return CryptoJS.SHA256(value).toString(CryptoJS.enc.Hex);
    },
    hmacSha256Hex: function (value, secretHex) {
      return CryptoJS.HmacSHA256(value, CryptoJS.enc.Hex.parse(secretHex)).toString(CryptoJS.enc.Hex);
    },
  };
}

if (typeof pm !== "undefined" && pm.request) {
  if (!pm.request.headers.get("X-Request-ID")) {
    pm.request.headers.upsert({ key: "X-Request-ID", value: pm.variables.replaceIn("{{$guid}}") });
  }
  var resolvedUrl = pm.variables.replaceIn(pm.request.url.toString());
  var parsedUrl = /^[a-zA-Z][a-zA-Z0-9+.-]*:\/\/[^/?#]+([^?#]*)(\?[^#]*)?/.exec(resolvedUrl);
  if (!parsedUrl) throw new Error("Cannot parse request URL: " + resolvedUrl);
  var requestPath = parsedUrl[1] || "/";
  var rawQuery = parsedUrl[2] ? parsedUrl[2].slice(1) : "";
  if (requestPath === "/ready" || requestPath.indexOf("/internal/") === 0) {
    var override = pm.request.headers.get("X-Coc-Signing-Sender");
    pm.request.headers.remove("X-Coc-Signing-Sender");
    pm.request.headers.remove("X-Service-Key-Id");
    pm.request.headers.remove("X-Service-Timestamp");
    pm.request.headers.remove("X-Service-Signature");
    if (override !== "none") {
      var sender = override || cocDefaultSender(requestPath);
      if (COC_SENDERS.indexOf(sender) === -1) throw new Error("Unknown signing sender: " + sender);
      if (cocAllowedSenders(requestPath).indexOf(sender) === -1) {
        throw new Error("Sender " + sender + " is not allowed for " + requestPath);
      }
      var mode = pm.environment.get("service_signing_mode") || "dev-keyring";
      var keyId = pm.environment.get("service_key_id_" + sender);
      var secretHex = pm.environment.get("service_secret_hex_" + sender);
      var cryptoAdapter = cocPostmanCrypto();
      if (!secretHex) {
        if (mode !== "dev-keyring") {
          throw new Error("Missing service_secret_hex_" + sender + " for signing mode " + mode);
        }
        keyId = keyId || "dev-" + sender;
        secretHex = cryptoAdapter.sha256Hex("cocenglish-dev-only:" + sender);
      }
      if (!keyId) throw new Error("Missing service_key_id_" + sender);
      var rawTemplate = pm.request.body && pm.request.body.raw ? pm.request.body.raw : "";
      var rawBody = pm.variables.replaceIn(rawTemplate);
      if (rawTemplate && rawBody !== rawTemplate) pm.request.body.raw = rawBody;
      var signed = cocSignRequest({
        method: pm.request.method,
        path: requestPath,
        query: rawQuery,
        allowedQueryKeys: cocAllowedQueryKeys(requestPath),
        body: rawBody,
        keyId: keyId,
        secretHex: secretHex,
        nowSeconds: Math.floor(Date.now() / 1000),
        crypto: cryptoAdapter,
      });
      Object.keys(signed).forEach(function (name) {
        pm.request.headers.upsert({ key: name, value: signed[name] });
      });
    }
  }
}
`;

// ---------------------------------------------------------------------------
// Environments
// ---------------------------------------------------------------------------

function environmentRows(spec, kind) {
  const local = kind === 'local';
  const wav = wavFixture();
  const uuid = (seed) => stableUuid(`env:${seed}`);
  const rows = [];
  const add = (key, value = '', type = 'default') => rows.push({ key, value, type, enabled: true });
  const secret = (key) => add(key, '', 'secret');

  add('learning_base_url', local ? 'http://127.0.0.1:4101' : 'https://learning.test.invalid');
  add('progress_base_url', local ? 'http://127.0.0.1:4102' : 'https://progress.test.invalid');
  add('ai_base_url', local ? 'http://127.0.0.1:4103' : 'https://ai.test.invalid');

  secret('token_a');
  secret('token_b');
  secret('token_maintainer');

  add('service_signing_mode', local ? 'dev-keyring' : 'keyring');
  for (const sender of ['learning', 'progress', 'ai', 'maintainer', 'scheduler']) {
    add(`service_key_id_${sender}`, local ? `dev-${sender}` : '');
    secret(`service_secret_hex_${sender}`);
  }

  add('courseId', 'vi_en');
  add('courseVersion', 'v2');
  add('lessonId', 'u1n1l1');
  add('lessonVersion', 'v2.u1n1l1');
  add('sessionId', 'session-placeholder');
  add('completionId', 'completion-placeholder');
  add('exerciseId', 'u1n1l1-e01');
  add('choiceId', 'c2');
  add('expectedRevision', '0');
  add('sessionRevision', '0');
  add('abandonConflictRevision', '1');
  add('profileRevision', '0');
  add('profileRevisionB', '0');
  add('preferencesRevision', '0');
  add('rewardRevision', '0');
  add('entitlementRevision', '0');
  add('energyRevision', '0');
  add('nextOriginalOrdinal', '0');
  add('sessionAnswers', '[]');
  add('sessionExerciseCount', '0');
  add('userIdA', '');
  add('userIdB', '');
  add('targetUserId', 'user-b');
  add('profileUserId', 'user-b');
  add('friendUserId', '');

  add('questId', 'daily_lessons');
  add('questPeriodKey', '2026-10-28');
  add('leagueWeekId', '2026-10-26');
  add('leagueCohortId', '');
  add('leagueResultUnseen', 'false');
  add('purchaseId', 'purchase-placeholder');
  add('purchaseIdB', '');
  add('shopPurchaseOperationId', '');
  add('productId', 'max_monthly');
  add('shopItemId', 'streak_freeze');
  add('boostItemId', 'xp_boost');
  add('catalogVersion', 'shop-v1');
  add('groupId', 'group-placeholder');
  add('inviteCode', 'FAMILY2026');
  add('giftId', 'gift-placeholder');
  add('pairId', 'pair-placeholder');
  add('classroomId', 'classroom-placeholder');
  add('joinCode', 'CLASS2026');
  add('conversationId', 'conversation-placeholder');
  add('assessmentJobId', uuid('assessmentJobId'));
  add('voiceSessionId', 'voice-session-placeholder');
  add('voiceLeaseRequestId', uuid('voiceLeaseRequestId'));
  add('voiceEpoch', '0');
  add('turnId', uuid('turnId'));
  add('tickId', uuid('tickId'));
  add('adEventId', uuid('adEventId'));
  add('notificationId', 'sim-notification-001');
  add('eventId', '3f0c2b1e-4a5d-4c8e-9f10-123456789abc');
  add('offlineOperationId', uuid('offlineOperationId'));
  add('localCompletionId', uuid('localCompletionId'));
  add('tutorRequestId', uuid('tutorRequestId'));
  add('aiScenarioId', 'rp_cafe_order');
  add('nickname', 'Coc Learner');
  add('promoCode', 'WELCOME2026');
  add('referralCode', 'FRIEND2026');
  add('bundleHash', 'b'.repeat(64));
  add('manifestSha256', 'c'.repeat(64));
  add('manifestFileId', 'manifest-dev-v2');
  add('contentVersionId', 'dev-v2');
  add('watermarkBefore', '2026-10-28T00:00:00Z');
  add('lostStreakDay', '2026-10-27');
  add('yearReviewYear', '2026');
  add('wavBase64', wav.wavBase64);
  add('audioSha256', wav.audioSha256);

  const scenarioKeys = [
    'init_a',
    'init_b',
    'patch_a',
    'patch_b',
    'golden_purchase',
    'golden_enroll',
    'start_golden',
    'complete',
    'enroll',
    'session',
    'abandon',
    'purchase',
    'voice',
  ];
  for (const key of scenarioKeys) add(`idem_scenario_${key}`, uuid(`idem_scenario_${key}`));
  for (let index = 1; index <= 20; index += 1) {
    const ordinal = String(index).padStart(2, '0');
    add(`idem_scenario_answer_${ordinal}`, uuid(`idem_scenario_answer_${ordinal}`));
  }
  for (const op of operations(spec)) {
    if (requiresIdempotency(spec, op)) {
      add(`idem_${op.operationId}`, uuid(`idem_${op.operationId}`));
    }
  }
  return rows;
}

function buildEnvironment(spec, kind) {
  const local = kind === 'local';
  return {
    id: stableUuid(`environment:${kind}`),
    name: local ? 'CocEnglish Local' : 'CocEnglish TEST template',
    values: environmentRows(spec, kind),
    _postman_variable_scope: 'environment',
    _postman_exported_at: FIXED_GENERATED_AT,
    _postman_exported_using: 'CocEnglish tools/postman/generate.mjs',
  };
}

// ---------------------------------------------------------------------------
// Collection assembly
// ---------------------------------------------------------------------------

function buildCollection(spec) {
  const ops = operations(spec);
  const byFolder = Object.fromEntries(OWNER_FOLDERS.map((folder) => [folder, []]));
  for (const op of ops) byFolder[ownerFolder(op)].push(op);

  const baselineByFolder = {};
  const represented = new Set();
  for (const folder of OWNER_FOLDERS) {
    const sorted = sortOperations(folder, byFolder[folder]);
    baselineByFolder[folder] = sorted.map((op) => {
      const key = `${op.method} ${op.path}`;
      if (represented.has(key)) throw new Error(`Duplicate OpenAPI operation ${key}`);
      represented.add(key);
      return { op, item: baselineItem(spec, op) };
    });
  }
  for (const op of ops) {
    if (!represented.has(`${op.method} ${op.path}`)) {
      throw new Error(`Missing OpenAPI operation ${op.method} ${op.path} (${op.operationId})`);
    }
  }

  const folderItems = [];
  const learningCategories = groupIntoCategories(
    'Learning',
    baselineByFolder.Learning,
    LEARNING_CATEGORY,
  );
  folderItems.push({
    name: 'Learning',
    description:
      'Learning-owned business operations plus the golden path and idempotency scenarios. Learning owns l_* tables, sessions, grading, review and the outbox.',
    item: [goldenPathFolder(), learningIdempotencyFolder(), ...learningCategories],
  });

  folderItems.push({
    name: 'Progress',
    description:
      'Progress-owned business operations plus simulated commerce idempotency. Progress owns p_* tables, XP ledger, streak, quests, leagues and social projections.',
    item: [
      progressIdempotencyFolder(),
      ...groupIntoCategories('Progress', baselineByFolder.Progress, PROGRESS_CATEGORY),
    ],
  });

  folderItems.push({
    name: 'AI',
    description:
      'AI-owned business operations plus scripted voice idempotency. AI owns a_* tables; provider calls stay disabled/scripted locally.',
    item: [aiIdempotencyFolder(), ...groupIntoCategories('AI', baselineByFolder.AI, AI_CATEGORY)],
  });

  folderItems.push({
    name: 'Internal',
    description:
      'Shared /health, signed /ready, /internal/events, /internal/outbox-watermark, scheduler ticks and the signed billing notification. Every internal request is signed by the collection pre-request script with raw-body hashing and canonical path/query handling.',
    item: [
      internalIdempotencyFolder(),
      ...groupIntoCategories('Internal', baselineByFolder.Internal, INTERNAL_CATEGORY),
    ],
  });

  const counts = Object.fromEntries(
    OWNER_FOLDERS.map((folder) => [folder, baselineByFolder[folder].length]),
  );
  return {
    info: {
      _postman_id: stableUuid('collection:CocEnglish'),
      name: 'CocEnglish API',
      description: [
        'Generated from `docs/api/openapi.yaml` by `tools/postman/generate.mjs`. Do not hand-edit.',
        '',
        `Baseline coverage: ${ops.length} OpenAPI operations (Learning ${counts.Learning}, Progress ${counts.Progress}, AI ${counts.AI}, Internal ${counts.Internal}).`,
        '',
        'Tokens and service secrets are intentionally empty in both environments. Set `token_a=dev-user-a` and `token_b=dev-user-b` for the local environment with `COC_DEV_AUTH=1`; use real Appwrite JWTs for TEST. Internal HMAC headers are computed by the collection pre-request script and never by mobile clients.',
        '',
        'Each baseline operation request asserts documented status membership and the canonical error envelope. The Golden path folder asserts exact positive statuses and captures IDs/revisions. Idempotency folders replay the same key/body and assert a changed body with the same key returns 409 IDEMPOTENCY_CONFLICT.',
      ].join('\n'),
      schema: COLLECTION_SCHEMA,
    },
    item: folderItems,
    event: [
      {
        listen: 'prerequest',
        script: { type: 'text/javascript', exec: PRE_REQUEST_SCRIPT.split('\n') },
      },
    ],
  };
}

function buildArtifacts() {
  const spec = loadSpec();
  const collection = buildCollection(spec);
  const localEnvironment = buildEnvironment(spec, 'local');
  const testEnvironment = buildEnvironment(spec, 'test');
  return {
    spec,
    collection,
    localEnvironment,
    testEnvironment,
    collectionText: `${JSON.stringify(collection, null, 2)}\n`,
    localEnvironmentText: `${JSON.stringify(localEnvironment, null, 2)}\n`,
    testEnvironmentText: `${JSON.stringify(testEnvironment, null, 2)}\n`,
  };
}

function writeArtifacts(artifacts) {
  fs.writeFileSync(COLLECTION_PATH, artifacts.collectionText);
  fs.writeFileSync(LOCAL_ENV_PATH, artifacts.localEnvironmentText);
  fs.writeFileSync(TEST_ENV_PATH, artifacts.testEnvironmentText);
}

function main() {
  const artifacts = buildArtifacts();
  writeArtifacts(artifacts);
  const counts = {};
  for (const folder of artifacts.collection.item) {
    let baseline = 0;
    const walk = (items) => {
      for (const item of items) {
        if (item.request) {
          if (item.request.description?.startsWith('OpenAPI operation:')) baseline += 1;
        } else if (item.item) {
          walk(item.item);
        }
      }
    };
    walk(folder.item);
    counts[folder.name] = baseline;
  }
  console.log(
    `Generated ${path.relative(ROOT, COLLECTION_PATH)} with ${Object.values(counts).reduce((sum, value) => sum + value, 0)} operations ` +
      `(${Object.entries(counts)
        .map(([name, count]) => `${name} ${count}`)
        .join(', ')}).`,
  );
  console.log(
    `Generated ${path.relative(ROOT, LOCAL_ENV_PATH)} and ${path.relative(ROOT, TEST_ENV_PATH)}.`,
  );
}

const isMain = process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;
if (isMain) main();

export {
  buildArtifacts,
  buildCollection,
  buildEnvironment,
  COLLECTION_PATH,
  LOCAL_ENV_PATH,
  TEST_ENV_PATH,
  PRE_REQUEST_SCRIPT,
  documentedStatuses,
  loadSpec,
  operations,
  ownerFolder,
  stableUuid,
  wavFixture,
};
