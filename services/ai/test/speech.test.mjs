// Real-speech provider path with a recorded fetch double (no network): Azure pronunciation
// assessment for assessment jobs and TURN voice turns, AssemblyAI/Deepgram transcription fallback,
// the project-wide Azure daily cap, the warm cache and the quality gate.
import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { checkRows, kit, setup, validate, wav } from './harness.mjs';

function azureBody(display, { accuracy = 92, confidence = 0.93, words } = {}) {
  const ws = words ?? display.replace(/[.,!?]/g, '').split(' ');
  return {
    RecognitionStatus: 'Success',
    DisplayText: display,
    NBest: [
      {
        Confidence: confidence,
        Display: display,
        PronunciationAssessment: {
          AccuracyScore: accuracy,
          FluencyScore: 88,
          CompletenessScore: 100,
          ProsodyScore: 81.5,
          PronScore: 90,
        },
        Words: ws.map((w, i) => ({
          Word: w.toLowerCase(),
          PronunciationAssessment: {
            AccuracyScore: i === 1 ? 41 : 97,
            ErrorType: i === 1 ? 'Mispronunciation' : 'None',
          },
          Phonemes: [
            { Phoneme: 'h', PronunciationAssessment: { AccuracyScore: 95 } },
            { Phoneme: 'ay', PronunciationAssessment: { AccuracyScore: i === 1 ? 30 : 99 } },
          ],
        })),
      },
    ],
  };
}

function fakeFetch(routes) {
  const calls = [];
  const fn = async (url, init = {}) => {
    calls.push({ url, headers: init.headers ?? {} });
    for (const [pattern, handler] of routes) {
      if (url.includes(pattern)) {
        const out = await handler(url, init);
        if (out instanceof Response) return out;
        return new Response(JSON.stringify(out), { status: 200 });
      }
    }
    return new Response('{}', { status: 404 });
  };
  fn.calls = calls;
  return fn;
}

function speechSetup(engineConfig) {
  let h;
  const store = kit.createMemoryAiPersistence(() => Date.parse('2026-10-12T03:00:00Z'));
  const engine = kit.createSpeechEngine({ persistence: store, pollMs: 0, ...engineConfig });
  h = setup({ store, provider: kit.speechProvider(engine) });
  return h;
}

test('parseAzure keeps metrics only behind the quality gate', () => {
  const ok = kit.parseAzure(azureBody('Hi Tom, my name is Lan.'), true);
  assert.equal(ok.assessment.scoreState, 'VALID');
  assert.equal(ok.assessment.accuracy, 92);
  assert.equal(ok.assessment.prosody, 81.5);
  assert.equal(ok.assessment.words[1].errorType, 'Mispronunciation');
  assert.equal(ok.assessment.words[1].phonemes[1].accuracy, 30);
  const low = kit.parseAzure(azureBody('hm', { confidence: 0.2 }), true);
  assert.equal(low.assessment.scoreState, 'NULL_LOW_CONFIDENCE');
  assert.equal(low.assessment.accuracy, null);
  assert.deepEqual(low.assessment.words, []);
  const silent = kit.parseAzure({ RecognitionStatus: 'InitialSilenceTimeout' }, true);
  assert.equal(silent.transcript, '');
  assert.equal(silent.assessment.scoreState, 'NULL_LOW_CONFIDENCE');
});

test('assessment job: Azure scores the reference sentence (VALID, per-word), replay never re-calls', async () => {
  const fetch = fakeFetch([
    ['stt.speech.microsoft.com', () => azureBody('I would like a cup of coffee, please.')],
  ]);
  const h = speechSetup({ azureKey: 'k'.repeat(32), azureRegion: 'eastasia', fetch });
  const jobId = randomUUID();
  const idem = randomUUID();
  const body = {
    jobId,
    referenceExerciseId: 'u3n1l1.e04',
    lessonVersion: 'v2',
    locale: 'en-US',
    referenceText: 'I would like a cup of coffee, please.',
    ...wav(3),
  };
  const created = await h.call('POST', '/v1/assessment-jobs', { user: 'alice', idem, body });
  assert.equal(created.status, 202, JSON.stringify(created.body));
  validate('Assessment', created.body);
  assert.equal(created.body.scoreState, 'VALID');
  assert.equal(created.body.accuracy, 92);
  assert.equal(created.body.completeness, 100);
  assert.equal(created.body.provider, 'azure');
  assert.equal(created.body.scorer, 'azure-pronunciation-assessment');
  assert.equal(created.body.transcript, 'I would like a cup of coffee, please.');
  assert.equal(created.body.words.length, 8);
  assert.deepEqual(created.body.miscues, [{ word: 'would', kind: 'mispronunciation' }]);
  const azureCall = fetch.calls.find((c) => c.url.includes('stt.speech'));
  const pa = JSON.parse(
    Buffer.from(azureCall.headers['Pronunciation-Assessment'], 'base64').toString(),
  );
  assert.equal(pa.ReferenceText, body.referenceText);
  assert.equal(pa.Granularity, 'Phoneme');
  const replay = await h.call('POST', '/v1/assessment-jobs', { user: 'alice', idem, body });
  assert.deepEqual(replay.body, created.body);
  assert.equal(fetch.calls.length, 1);
  const read = await h.call('GET', `/v1/assessment-jobs/${jobId}`, { user: 'alice' });
  assert.equal(read.body.accuracy, 92);
  // Project-wide Azure reservation is counted on the global usage row.
  const global = h.store.dump('a_usage').find((r) => r.row.userId === kit.SPEECH_GLOBAL_USER);
  assert.equal(global.row.recordedSpeechSeconds, 3);
  checkRows(h.store);
});

test('no reference text or no Azure key keeps every metric null', async () => {
  const fetch = fakeFetch([['stt.speech.microsoft.com', () => azureBody('Hello.')]]);
  const h = speechSetup({ azureKey: 'k'.repeat(32), azureRegion: 'eastasia', fetch });
  const created = await h.call('POST', '/v1/assessment-jobs', {
    user: 'alice',
    idem: randomUUID(),
    body: {
      jobId: randomUUID(),
      referenceExerciseId: 'x1',
      lessonVersion: 'v2',
      locale: 'en-US',
      ...wav(1),
    },
  });
  validate('Assessment', created.body);
  assert.equal(created.body.scoreState, 'NULL_UNAVAILABLE');
  assert.equal(created.body.unavailableReason, 'NO_REFERENCE_TEXT');
  assert.equal(fetch.calls.length, 0);
  const caps = await h.call('GET', '/v1/ai/capabilities', { user: 'alice' });
  assert.equal(caps.body.pronunciation, true);
});

test('Azure daily cap reached: AssemblyAI transcribes, score is NULL_UNAVAILABLE DAILY_CAP', async () => {
  const fetch = fakeFetch([
    ['stt.speech.microsoft.com', () => azureBody('never')],
    ['assemblyai.com/v2/upload', () => ({ upload_url: 'https://cdn.assemblyai.com/upload/x' })],
    [
      'assemblyai.com/v2/transcript/',
      () => ({ status: 'completed', text: 'Hello there.', confidence: 0.9 }),
    ],
    ['assemblyai.com/v2/transcript', () => ({ id: 'abc-123' })],
  ]);
  const h = speechSetup({
    azureKey: 'k'.repeat(32),
    azureRegion: 'eastasia',
    assemblyKey: 'a'.repeat(32),
    azureDailySeconds: 2,
    fetch,
  });
  const created = await h.call('POST', '/v1/assessment-jobs', {
    user: 'alice',
    idem: randomUUID(),
    body: {
      jobId: randomUUID(),
      referenceExerciseId: 'x1',
      lessonVersion: 'v2',
      locale: 'en-US',
      referenceText: 'Hello there.',
      ...wav(3),
    },
  });
  validate('Assessment', created.body);
  assert.equal(created.body.scoreState, 'NULL_UNAVAILABLE');
  assert.equal(created.body.unavailableReason, 'DAILY_CAP');
  assert.equal(created.body.transcript, 'Hello there.');
  assert.equal(created.body.provider, 'assemblyai');
  assert.equal(created.body.accuracy, null);
  assert.ok(!fetch.calls.some((c) => c.url.includes('stt.speech')));
});

test('TURN voice turn: real transcript drives the script and carries an Azure TurnScore', async () => {
  const fetch = fakeFetch([
    ['stt.speech.microsoft.com', () => azureBody('Hi Tom, my name is Lan.')],
  ]);
  const h = speechSetup({ azureKey: 'k'.repeat(32), azureRegion: 'eastasia', fetch });
  await h.grant('alice');
  const sessionId = randomUUID();
  const lease = await h.call('POST', '/v1/voice-sessions', {
    user: 'alice',
    idem: randomUUID(),
    body: { sessionId, scenarioId: 'rp_meet_new_friend', mode: 'TURN', level: 'A1' },
  });
  assert.equal(lease.status, 200);
  const conv = await h.call('POST', '/v1/conversations', {
    user: 'alice',
    idem: randomUUID(),
    body: {
      kind: 'VIDEO_CALL',
      courseId: 'vi_en',
      scenarioId: 'rp_meet_new_friend',
      voiceSessionId: sessionId,
    },
  });
  assert.equal(conv.status, 200);
  const idem = randomUUID();
  const body = { turnId: randomUUID(), epoch: 0, ...wav(2) };
  const turn = await h.call('POST', `/v1/voice-sessions/${sessionId}/turns`, {
    user: 'alice',
    idem,
    body,
  });
  assert.equal(turn.status, 200, JSON.stringify(turn.body));
  validate('TurnResult', turn.body);
  assert.equal(turn.body.transcript, 'Hi Tom, my name is Lan.');
  assert.equal(turn.body.score.scoreState, 'VALID');
  assert.equal(turn.body.score.referenceText, 'Hi Tom, my name is Lan.');
  assert.equal(turn.body.score.transcriptProvider, 'azure');
  assert.equal(turn.body.tutor.assessedPronunciation, true);
  const replay = await h.call('POST', `/v1/voice-sessions/${sessionId}/turns`, {
    user: 'alice',
    idem,
    body,
  });
  assert.deepEqual(replay.body, turn.body);
  assert.equal(fetch.calls.length, 1);
  checkRows(h.store);
});

test('every provider down: empty transcript, script does not advance, FAILED score', async () => {
  const fetch = fakeFetch([
    ['stt.speech.microsoft.com', () => new Response('err', { status: 500 })],
    ['api.deepgram.com', () => new Response('err', { status: 401 })],
  ]);
  const h = speechSetup({
    azureKey: 'k'.repeat(32),
    azureRegion: 'eastasia',
    deepgramKey: 'd'.repeat(40),
    fetch,
  });
  await h.grant('alice');
  const sessionId = randomUUID();
  await h.call('POST', '/v1/voice-sessions', {
    user: 'alice',
    idem: randomUUID(),
    body: { sessionId, scenarioId: 'rp_meet_new_friend', mode: 'TURN', level: 'A1' },
  });
  await h.call('POST', '/v1/conversations', {
    user: 'alice',
    idem: randomUUID(),
    body: {
      kind: 'VIDEO_CALL',
      courseId: 'vi_en',
      scenarioId: 'rp_meet_new_friend',
      voiceSessionId: sessionId,
    },
  });
  const turn = await h.call('POST', `/v1/voice-sessions/${sessionId}/turns`, {
    user: 'alice',
    idem: randomUUID(),
    body: { turnId: randomUUID(), epoch: 0, ...wav(1) },
  });
  validate('TurnResult', turn.body);
  assert.equal(turn.body.transcript, '');
  assert.equal(turn.body.score.scoreState, 'FAILED');
  assert.match(turn.body.tutor.tutorText, /^Let's try again/);
});

test('speechFromEnv needs COC_AI_PROVIDER=speech and a key', () => {
  const store = kit.createMemoryAiPersistence(() => 0);
  assert.equal(kit.speechFromEnv({ COC_AZURE_SPEECH_KEY: 'x'.repeat(32) }, store), null);
  assert.equal(kit.speechFromEnv({ COC_AI_PROVIDER: 'speech' }, store), null);
  const e = kit.speechFromEnv(
    {
      COC_AI_PROVIDER: 'speech',
      COC_AZURE_SPEECH_KEY: 'x'.repeat(32),
      COC_AZURE_SPEECH_REGION: 'eastasia',
      COC_DEEPGRAM_API_KEY: 'y'.repeat(40),
    },
    store,
  );
  assert.equal(e.azure, true);
  assert.deepEqual(e.fallbacks, ['deepgram']);
});
