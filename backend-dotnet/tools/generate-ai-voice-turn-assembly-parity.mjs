import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { kit, setup, wav } from '../../services/ai/test/harness.mjs';

// Test-only Azure-failure/AssemblyAI voice-turn differential. Synthetic audio, credentials and
// provider responses are handled entirely by injected fetch; no network request is made.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const scenarioPath = path.join(
  root,
  'backend-dotnet/tests/fixtures/ai-voice-turn-assembly-parity-scenario.json',
);
const outputPath = path.join(
  root,
  'backend-dotnet/tests/fixtures/ai-voice-turn-assembly-node-golden.json',
);
const scenarioBytes = fs.readFileSync(scenarioPath);
const scenario = JSON.parse(scenarioBytes);
const now = Date.parse(scenario.now);
const store = kit.createMemoryAiPersistence(() => now);
const audio = wav(scenario.wavSeconds);
await store.transact(async (tx) => {
  tx.put('a_usage', kit.ids.entitlement(scenario.user), {
    userId: scenario.user,
    utcDay: 'ENTITLED',
    liveReservedSeconds: 0,
    liveUsedSeconds: 0,
    liveGrants: 0,
    textRequests: 0,
    recordedSpeechSeconds: 0,
    recordedReservedSeconds: 0,
    reservationIdsJson: JSON.stringify({
      plan: 'MAX',
      status: 'ACTIVE',
      expiresAt: null,
      entitlementRevision: 1,
    }),
  });
});

const providerRequests = [];
const engine = kit.createSpeechEngine({
  azureKey: 'synthetic-voice-assembly-azure-key',
  azureRegion: scenario.azureRegion,
  assemblyKey: 'synthetic-voice-assemblyai-key',
  persistence: store,
  nowMs: () => now,
  pollMs: 0,
  fetch: async (url, init = {}) => {
    const headers = init.headers ?? {};
    const request = {
      method: init.method ?? 'GET',
      url: String(url),
      contentType: headers['Content-Type'] ?? headers['content-type'] ?? null,
      bodyLength:
        typeof init.body === 'string' ? Buffer.byteLength(init.body) : (init.body?.byteLength ?? 0),
    };
    if (String(url).includes('stt.speech.microsoft.com')) {
      request.pronunciationAssessment = JSON.parse(
        Buffer.from(headers['Pronunciation-Assessment'], 'base64').toString('utf8'),
      );
      providerRequests.push(request);
      return new Response('synthetic Azure outage', { status: 503 });
    }
    const authorization = String(headers.authorization ?? headers.Authorization ?? '');
    request.authorizationScheme = authorization.includes(' ') ? authorization.split(' ')[0] : 'raw';
    if (typeof init.body === 'string') request.jsonBody = JSON.parse(init.body);
    providerRequests.push(request);

    if (String(url).endsWith('/v2/upload')) return json({ upload_url: scenario.uploadUrl });
    if (String(url).endsWith('/v2/transcript') && request.method === 'POST')
      return json({ id: scenario.transcriptId });
    if (String(url).endsWith(`/v2/transcript/${scenario.transcriptId}`))
      return json({
        status: 'completed',
        text: scenario.transcript,
        confidence: scenario.confidence,
      });
    return new Response('{}', { status: 404 });
  },
});
const harness = setup({ start: now, store, provider: kit.speechProvider(engine) });
const session = await harness.call('POST', '/v1/voice-sessions', {
  user: scenario.user,
  idem: scenario.sessionKey,
  body: {
    sessionId: scenario.sessionId,
    scenarioId: scenario.scenarioId,
    mode: 'TURN',
    level: scenario.level,
  },
});
const conversation = await harness.call('POST', '/v1/conversations', {
  user: scenario.user,
  idem: scenario.conversationKey,
  body: {
    kind: scenario.kind,
    courseId: scenario.courseId,
    scenarioId: scenario.scenarioId,
    voiceSessionId: scenario.voiceSessionId,
  },
});
const turnPath = `/v1/voice-sessions/${scenario.sessionId}/turns`;
const turnBody = { turnId: scenario.turnId, epoch: scenario.epoch, ...audio };
const firstTurn = await harness.call('POST', turnPath, {
  user: scenario.user,
  idem: scenario.turnKey,
  body: turnBody,
});
const replayTurn = await harness.call('POST', turnPath, {
  user: scenario.user,
  idem: scenario.turnKey,
  body: turnBody,
});

function projectRow(id, source) {
  const row = structuredClone(source);
  for (const key of [
    'feedbackJson',
    'payloadJson',
    'reservationIdsJson',
    'responseJson',
    'resultJson',
  ])
    if (typeof row[key] === 'string') row[key] = JSON.parse(row[key]);
  return { id, row };
}
const tables = Object.fromEntries(
  scenario.inspect.map((table) => [
    table,
    store
      .dump(table)
      .filter(
        ({ row }) =>
          row.userId === scenario.user ||
          row.aggregateId === scenario.user ||
          row.userId === kit.SPEECH_GLOBAL_USER,
      )
      .map(({ id, row }) => projectRow(id, row))
      .sort((left, right) => (left.id < right.id ? -1 : left.id > right.id ? 1 : 0)),
  ]),
);
const golden =
  JSON.stringify(
    {
      scenarioSha256: createHash('sha256').update(scenarioBytes).digest('hex'),
      providerRequests,
      results: {
        session: { status: session.status, body: session.body },
        conversation: { status: conversation.status, body: conversation.body },
        firstTurn: { status: firstTurn.status, body: firstTurn.body },
        replayTurn: { status: replayTurn.status, body: replayTurn.body },
      },
      tables,
    },
    null,
    2,
  ) + '\n';
if (process.argv.includes('--check')) {
  if (!fs.existsSync(outputPath) || fs.readFileSync(outputPath, 'utf8') !== golden)
    throw new Error(
      'AI voice-turn AssemblyAI Node parity fixture is stale; regenerate and review the diff.',
    );
} else fs.writeFileSync(outputPath, golden);
console.log(
  JSON.stringify({
    status: 'PASS',
    scope: 'Azure failure with AssemblyAI voice-turn fallback via fake HTTP only',
    providerCalls: providerRequests.length,
    mode: process.argv.includes('--check') ? 'check' : 'write',
  }),
);

function json(value) {
  return new Response(JSON.stringify(value), {
    status: 200,
    headers: { 'content-type': 'application/json' },
  });
}
