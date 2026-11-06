import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { kit, setup, wav } from '../../services/ai/test/harness.mjs';

// Test-only AssemblyAI fallback differential with Azure failure. Every provider response is
// canned by fetch and all credentials are synthetic; no network request is made.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const scenarioPath = path.join(
  root,
  'backend-dotnet/tests/fixtures/ai-assessment-assembly-parity-scenario.json',
);
const outputPath = path.join(
  root,
  'backend-dotnet/tests/fixtures/ai-assessment-assembly-node-golden.json',
);
const scenarioBytes = fs.readFileSync(scenarioPath);
const scenario = JSON.parse(scenarioBytes);
const now = Date.parse(scenario.now);
const store = kit.createMemoryAiPersistence(() => now);
const audio = wav(scenario.wavSeconds);
const providerRequests = [];
const engine = kit.createSpeechEngine({
  azureKey: 'synthetic-assembly-azure-key',
  azureRegion: scenario.azureRegion,
  assemblyKey: 'synthetic-assemblyai-key',
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

    if (String(url).endsWith('/v2/upload')) {
      return json({ upload_url: scenario.uploadUrl });
    }
    if (String(url).endsWith('/v2/transcript') && request.method === 'POST') {
      return json({ id: scenario.transcriptId });
    }
    if (String(url).endsWith(`/v2/transcript/${scenario.transcriptId}`)) {
      return json({
        status: 'completed',
        text: scenario.transcript,
        confidence: scenario.confidence,
      });
    }
    return new Response('{}', { status: 404 });
  },
});
const harness = setup({ start: now, store, provider: kit.speechProvider(engine) });
const body = {
  jobId: scenario.jobId,
  referenceExerciseId: scenario.referenceExerciseId,
  lessonVersion: scenario.lessonVersion,
  locale: scenario.locale,
  wavBase64: audio.wavBase64,
  audioSha256: audio.audioSha256,
  referenceText: scenario.referenceText,
};
const first = await harness.call('POST', '/v1/assessment-jobs', {
  user: scenario.user,
  idem: scenario.idempotencyKey,
  body,
});
const replay = await harness.call('POST', '/v1/assessment-jobs', {
  user: scenario.user,
  idem: scenario.idempotencyKey,
  body,
});
const read = await harness.call('GET', `/v1/assessment-jobs/${scenario.jobId}`, {
  user: scenario.user,
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
      .filter(({ row }) => row.userId === scenario.user || row.userId === kit.SPEECH_GLOBAL_USER)
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
        first: { status: first.status, body: first.body },
        replay: { status: replay.status, body: replay.body },
        read: { status: read.status, body: read.body },
      },
      tables,
    },
    null,
    2,
  ) + '\n';
if (process.argv.includes('--check')) {
  if (!fs.existsSync(outputPath) || fs.readFileSync(outputPath, 'utf8') !== golden)
    throw new Error('AI AssemblyAI Node parity fixture is stale; regenerate and review the diff.');
} else fs.writeFileSync(outputPath, golden);
console.log(
  JSON.stringify({
    status: 'PASS',
    scope: 'Azure failure with AssemblyAI upload/create/poll via fake HTTP only',
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
