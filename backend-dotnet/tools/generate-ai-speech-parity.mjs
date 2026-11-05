import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { kit, setup, wav } from '../../services/ai/test/harness.mjs';

// Test-only differential for the Azure assessment path. The provider fetch is always a local
// fake; credentials are synthetic and no network request can leave this process.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const scenarioPath = path.join(
  root,
  'backend-dotnet/tests/fixtures/ai-speech-parity-scenario.json',
);
const outputPath = path.join(root, 'backend-dotnet/tests/fixtures/ai-speech-node-golden.json');
const scenarioBytes = fs.readFileSync(scenarioPath);
const scenario = JSON.parse(scenarioBytes);
let now = Date.parse(scenario.now);
const store = kit.createMemoryAiPersistence(() => now);
const audio = wav(scenario.wavSeconds);
let providerRequest;
const engine = kit.createSpeechEngine({
  azureKey: 'synthetic-parity-key',
  azureRegion: scenario.azureRegion,
  persistence: store,
  nowMs: () => now,
  fetch: async (url, init = {}) => {
    const headers = init.headers ?? {};
    providerRequest = {
      method: init.method,
      url: String(url),
      contentType: headers['Content-Type'] ?? headers['content-type'],
      bodyLength: init.body?.byteLength ?? 0,
      pronunciationAssessment: JSON.parse(
        Buffer.from(headers['Pronunciation-Assessment'], 'base64').toString('utf8'),
      ),
    };
    return new Response(JSON.stringify(scenario.azureResponse), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });
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
now += 24 * 60 * 60 * 1000;
harness.clock.now = now;
const read = await harness.call('GET', `/v1/assessment-jobs/${scenario.jobId}`, {
  user: scenario.user,
});
if (read.body.status !== 'EXPIRED')
  throw new Error('Assessment must expire at the exact 24-hour boundary.');

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
      providerRequest,
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
    throw new Error('AI speech Node parity fixture is stale; regenerate and review the diff.');
} else fs.writeFileSync(outputPath, golden);
console.log(
  JSON.stringify({
    status: 'PASS',
    scope: 'Azure assessment via fake HTTP only',
    providerCalls: 1,
    mode: process.argv.includes('--check') ? 'check' : 'write',
  }),
);
