import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { kit, setup, progressKey, learningKey } from '../../services/ai/test/harness.mjs';

// Test-only: execute the unchanged Node AI router with disabled speech. The .NET test replays
// the same route sequence against ASP.NET Core; no production service uses this memory store.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const inputPath = path.join(root, 'backend-dotnet/tests/fixtures/ai-parity-scenarios.json');
const outputPath = path.join(root, 'backend-dotnet/tests/fixtures/ai-node-golden.json');
const scenarioBytes = fs.readFileSync(inputPath);
const scenario = JSON.parse(scenarioBytes);
let now = Date.parse(scenario.now);
const persistence = kit.createMemoryAiPersistence(() => now);
for (const seed of scenario.seedEntitlements ?? []) {
  const projection = {
    plan: seed.plan,
    status: 'ACTIVE',
    expiresAt: null,
    entitlementRevision: 1,
  };
  await persistence.transact(async (tx) => {
    tx.put('a_usage', kit.ids.entitlement(seed.user), {
      userId: seed.user,
      utcDay: 'ENTITLED',
      liveReservedSeconds: 0,
      liveUsedSeconds: 0,
      liveGrants: 0,
      textRequests: 0,
      recordedSpeechSeconds: 0,
      recordedReservedSeconds: 0,
      reservationIdsJson: JSON.stringify(projection),
    });
  });
}
if (scenario.seedVoiceSession) {
  const { user, sessionId, createdAt, expiresAt, epoch, consumedSeconds } =
    scenario.seedVoiceSession;
  const voice = {
    userId: user,
    sessionId,
    providerAlias: 'scripted',
    mode: 'TURN',
    status: 'ACTIVE',
    createdAt,
    expiresAt,
    lastHeartbeatAt: createdAt,
    epoch,
    consumedSeconds,
    configVersion: 'scripted-v1',
    revision: 0,
    updatedAt: createdAt,
  };
  const slot = {
    userId: user,
    sessionId,
    expiresAt,
    epoch,
    revision: 0,
    createdAt,
    updatedAt: createdAt,
  };
  await persistence.transact(async (tx) => {
    tx.put('a_voice_sessions', kit.ids.voiceSession(sessionId), voice);
    tx.put('a_active_slots', kit.ids.slot(user), slot);
  });
}
const wiring = kit.aiWiring({
  persistence,
  nowMs: () => now,
  newId: () => kit.uuidFrom('ai-capabilities-parity'),
  gates: kit.DEFAULT_GATES,
  provider: { kind: 'disabled', configVersion: 'disabled-v1', azureEnabled: false },
});
const router = kit.aiHandler(
  kit.createRouter({
    service: 'ai',
    persistence,
    mode: 'local-test',
    auth: {
      async verify(userId) {
        return { userId };
      },
    },
    keyring: kit.createKeyring([]),
    routes: wiring.routes,
    eventConsumer: wiring.eventConsumer,
    nowMs: () => now,
  }),
);

const results = [];
const variables = {};
function projectRow(id, source) {
  const row = structuredClone(source);
  for (const key of ['feedbackJson', 'payloadJson', 'reservationIdsJson', 'responseJson'])
    if (typeof row[key] === 'string') row[key] = JSON.parse(row[key]);
  return { id, row };
}
for (const [index, step] of scenario.steps.entries()) {
  if (step.inspect) {
    const tables = Object.fromEntries(
      step.inspect.map((table) => [
        table,
        persistence
          .dump(table)
          .filter(({ row }) => row.userId === step.user || row.aggregateId === step.user)
          .map(({ id, row }) => projectRow(id, row))
          .sort((left, right) => (left.id < right.id ? -1 : left.id > right.id ? 1 : 0)),
      ]),
    );
    results.push({ index, kind: 'inspect', tables });
    continue;
  }
  const path = step.path.replace(/\{([A-Za-z][A-Za-z0-9]*)\}/g, (_, name) => {
    const value = variables[name];
    if (typeof value !== 'string') throw new Error(`AI parity variable ${name} is not captured`);
    return value;
  });
  let response;
  const question = path.indexOf('?');
  await router({
    req: {
      method: step.method,
      path: question < 0 ? path : path.slice(0, question),
      headers: {
        authorization: `Bearer ${step.user}`,
        'x-request-id': scenario.requestId,
        ...(step.key ? { 'idempotency-key': step.key } : {}),
      },
      queryString: question < 0 ? (step.queryString ?? '') : path.slice(question + 1),
      ...(Object.hasOwn(step, 'body') ? { bodyText: JSON.stringify(step.body) } : {}),
    },
    res: { json: (body, status) => (response = { status, body }) },
  });
  results.push({ index, kind: 'call', ...response });
  if (step.capture) variables[step.capture] = response.body[step.capture];
}

let outboxNow = Date.parse(scenario.outbox.now);
const outboxPersistence = kit.createMemoryAiPersistence(() => outboxNow);
const outboxEvent = { eventId: scenario.outbox.eventId, ...scenario.outbox.event };
const outboxDeps = {
  persistence: outboxPersistence,
  nowMs: () => outboxNow,
  newId: () => kit.uuidFrom('ai-outbox-parity'),
  gates: kit.DEFAULT_GATES,
  provider: { kind: 'disabled', configVersion: 'disabled-v1', azureEnabled: false },
};
await outboxPersistence.transact(async (tx) => {
  const at = new Date(outboxNow).toISOString();
  tx.put('a_outbox', scenario.outbox.eventId, {
    eventId: scenario.outbox.eventId,
    type: outboxEvent.type,
    schemaVersion: outboxEvent.schemaVersion,
    aggregateId: outboxEvent.aggregateId,
    occurredAt: outboxEvent.occurredAt,
    payloadJson: JSON.stringify(outboxEvent),
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
const outboxResults = [];
for (const [index, outcome] of ['retry', 'ack'].entries()) {
  if (index > 0) outboxNow += 1000;
  const report = await kit.dispatchOutbox(outboxDeps, async () => outcome, {
    owner: scenario.outbox.owner,
    random: () => 0,
  });
  const saved = outboxPersistence
    .dump('a_outbox')
    .find((entry) => entry.id === scenario.outbox.eventId);
  outboxResults.push({ index, report, row: saved ? projectRow(saved.id, saved.row) : null });
}

const immediateSpec = scenario.immediateRelay;
const immediateNow = Date.parse(immediateSpec.now);
const immediatePersistence = kit.createMemoryAiPersistence(() => immediateNow);
const immediateEvent = {
  eventId: immediateSpec.eventId,
  ...scenario.outbox.event,
  requestId: immediateSpec.eventId,
};
const immediateDeps = {
  ...outboxDeps,
  persistence: immediatePersistence,
  nowMs: () => immediateNow,
};
await immediatePersistence.transact(async (tx) => {
  const at = new Date(immediateNow).toISOString();
  tx.put('a_outbox', immediateEvent.eventId, {
    eventId: immediateEvent.eventId,
    type: immediateEvent.type,
    schemaVersion: immediateEvent.schemaVersion,
    aggregateId: immediateEvent.aggregateId,
    occurredAt: immediateEvent.occurredAt,
    payloadJson: JSON.stringify(immediateEvent),
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
  () => immediateDeps,
  async (event) => {
    immediateDeliveredEventIds.push(event.eventId);
    return 'retry';
  },
  1500,
  () => 0,
);
await immediateRelay.afterCommit([immediateEvent.eventId]);
const immediateSaved = immediatePersistence
  .dump('a_outbox')
  .find((entry) => entry.id === immediateEvent.eventId);
const immediateRelayResult = {
  deliveredEventIds: immediateDeliveredEventIds,
  row: immediateSaved ? projectRow(immediateSaved.id, immediateSaved.row) : null,
};

const relaySpec = scenario.httpRelay;
let relayRequest;
const relayOutcomes = [];
for (const [index, response] of relaySpec.responses.entries()) {
  const relayDeliver = kit.httpDeliver({
    key: {
      keyId: relaySpec.keyId,
      sender: 'ai',
      secret: Buffer.from(relaySpec.secretHex, 'hex'),
    },
    progressBaseUrl: relaySpec.baseUrl,
    nowSeconds: () => Date.parse(relaySpec.now) / 1000,
    fetchImpl: async (url, init) => {
      const headers = init.headers;
      if (index === 0) {
        relayRequest = {
          method: init.method,
          url: String(url),
          body: init.body,
          keyId: headers['X-Service-Key-Id'],
          timestamp: headers['X-Service-Timestamp'],
          signature: headers['X-Service-Signature'],
          contentType: headers['Content-Type'],
        };
      }
      return new Response(JSON.stringify(response.body), { status: response.status });
    },
  });
  relayOutcomes.push({
    index,
    status: response.status,
    body: response.body,
    outcome: await relayDeliver(outboxEvent),
  });
}

const eventSpec = scenario.eventParity;
const eventHarness = setup({ start: Date.parse(eventSpec.now) });
await eventHarness.store.transact(async (tx) => {
  for (let index = 0; index < eventSpec.seed.aliceConversations; index++)
    tx.put('a_conversations', `alice-conversation-${String(index).padStart(3, '0')}`, {
      userId: 'alice',
    });
  for (let index = 0; index < eventSpec.seed.bobConversations; index++)
    tx.put('a_conversations', `bob-conversation-${String(index).padStart(3, '0')}`, {
      userId: 'bob',
    });
  for (let index = 0; index < eventSpec.seed.alicePracticeOutbox; index++)
    tx.put('a_outbox', `alice-practice-${String(index).padStart(3, '0')}`, {
      aggregateId: 'alice',
      type: 'ai.practice.completed.v1',
    });
});
const eventResults = [];
for (const [index, step] of eventSpec.steps.entries()) {
  const result = await eventHarness.event(step.type, structuredClone(step.payload), {
    eventId: step.eventId,
    sender: step.sender === 'learning' ? learningKey : progressKey,
    occurredAt: eventSpec.now,
  });
  const body = structuredClone(result.body);
  if (Object.hasOwn(body, 'requestId')) body.requestId = '<request-id>';
  if (body.error && Object.hasOwn(body.error, 'requestId')) body.error.requestId = '<request-id>';
  const tables = Object.fromEntries(
    eventSpec.inspect.map((table) => [
      table,
      eventHarness.store
        .dump(table)
        .map(({ id, row }) => projectRow(id, row))
        .sort((left, right) => (left.id < right.id ? -1 : left.id > right.id ? 1 : 0)),
    ]),
  );
  eventResults.push({ index, status: result.status, body, tables });
}

function sourceFiles(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const file = path.join(directory, entry.name);
    return entry.isDirectory() ? sourceFiles(file) : file.endsWith('.ts') ? [file] : [];
  });
}
const hash = createHash('sha256');
for (const { file, relative } of [
  ...sourceFiles(path.join(root, 'services/ai/src')),
  ...sourceFiles(path.join(root, 'services/shared/src')),
]
  .map((file) => ({ file, relative: path.relative(root, file).split(path.sep).join('/') }))
  .sort((a, b) => (a.relative < b.relative ? -1 : a.relative > b.relative ? 1 : 0)))
  hash.update(relative).update('\0').update(fs.readFileSync(file)).update('\0');
const output =
  JSON.stringify(
    {
      nodeSourceSha256: hash.digest('hex'),
      scenarioSha256: createHash('sha256').update(scenarioBytes).digest('hex'),
      results,
      outboxResults,
      immediateRelay: immediateRelayResult,
      httpRelay: { request: relayRequest, outcomes: relayOutcomes },
      eventParityResults: eventResults,
    },
    null,
    2,
  ) + '\n';
if (process.argv.includes('--check')) {
  if (!fs.existsSync(outputPath) || fs.readFileSync(outputPath, 'utf8') !== output)
    throw new Error('AI Node parity fixture is stale; regenerate and review the diff.');
} else fs.writeFileSync(outputPath, output);
console.log(
  JSON.stringify({
    status: 'PASS',
    scope:
      'Node AI route, dispatcher, signed event consumers and HMAC relay fixtures with speech disabled; no provider or durable parity admission',
    steps: results.length,
    eventSteps: eventResults.length,
    outboxSteps: outboxResults.length,
    immediateRelaySteps: immediateDeliveredEventIds.length,
    httpRelayOutcomes: relayOutcomes.length,
    mode: process.argv.includes('--check') ? 'check' : 'write',
  }),
);
