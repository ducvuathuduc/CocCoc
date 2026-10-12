// Gated live probe of real speech on the hosted coccoc-ai (COC_LIVE_AI_SPEECH=1): a synthetic user
// sends real recorded/synthesized English WAVs (16 kHz mono PCM16) from COC_SPEECH_WAV_DIR:
//   coffee.wav  -> "I would like a cup of coffee, please."
//   s1..s4.wav  -> the four expected learner lines of rp_meet_new_friend
// and asserts real Azure pronunciation scores (assessment job + TURN voice turns) and a real
// transcript driving a Video Call to completion. Prints only scores/transcripts, never keys.
// Needs APPWRITE_API_KEY (server key, injected), APPWRITE_PROJECT_ENV=test.
import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash, randomBytes, randomUUID } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const endpoint = 'https://sgp.cloud.appwrite.io/v1';
const projectId = '6acc656d0025cc57bd81';
const databaseId = 'cocenglish';
const domain = 'https://coccoc-ai.sgp.appwrite.run';
const apiKey = process.env.APPWRITE_API_KEY;
const dir = process.env.COC_SPEECH_WAV_DIR ?? '';

async function rest(method, route, body) {
  const response = await fetch(`${endpoint}${route}`, {
    method,
    headers: {
      'X-Appwrite-Project': projectId,
      'X-Appwrite-Key': apiKey,
      'Content-Type': 'application/json',
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  if (!response.ok && response.status !== 404)
    throw new Error(`${method} ${route} ${response.status} ${text.slice(0, 200)}`);
  return text ? JSON.parse(text) : {};
}

const audio = (name) => {
  const bytes = fs.readFileSync(path.join(dir, name));
  return {
    wavBase64: bytes.toString('base64'),
    audioSha256: createHash('sha256').update(bytes).digest('hex'),
  };
};
const inboxId = (eventId) =>
  createHash('sha256').update(`inbox|${eventId}`).digest('hex').slice(0, 32);
const brief = (words) =>
  (words ?? []).map(
    (w) =>
      `${w.word}:${w.accuracy}${w.errorType && w.errorType !== 'None' ? `(${w.errorType})` : ''}`,
  );

test(
  'live speech: Azure pronunciation scores + real STT on hosted coccoc-ai',
  {
    skip: process.env.COC_LIVE_AI_SPEECH === '1' ? false : 'set COC_LIVE_AI_SPEECH=1',
    timeout: 600000,
  },
  async (t) => {
    assert.ok(apiKey && dir, 'APPWRITE_API_KEY and COC_SPEECH_WAV_DIR required');
    const user = `spprobe${randomBytes(6).toString('hex')}`;
    const evidence = {};
    await rest('POST', '/users', {
      userId: user,
      email: `${user}@cocenglish-ops.dev`,
      password: `Pr0be-${randomBytes(12).toString('hex')}`,
    });
    try {
      const session = await rest('POST', `/users/${user}/sessions`, {});
      const { jwt } = await rest('POST', `/users/${user}/jwts`, {
        sessionId: session.$id,
        duration: 900,
      });
      const call = async (method, p, body, idem) => {
        const headers = { Authorization: `Bearer ${jwt}`, 'Content-Type': 'application/json' };
        if (idem) headers['Idempotency-Key'] = idem;
        const r = await fetch(`${domain}${p}`, {
          method,
          headers,
          body: body === undefined ? undefined : JSON.stringify(body),
        });
        return { status: r.status, body: await r.json() };
      };
      const caps = await call('GET', '/v1/ai/capabilities');
      evidence.capabilities = {
        configVersion: caps.body.configVersion,
        pronunciation: caps.body.pronunciation,
      };
      assert.equal(caps.body.pronunciation, true, JSON.stringify(caps.body));

      // 1. Assessment job (speakRepeat) — correct reference and a one-word-off reference.
      for (const [label, ref] of [
        ['assessmentMatch', 'I would like a cup of coffee, please.'],
        ['assessmentMismatch', 'I would like a cup of tea, please.'],
      ]) {
        const jobId = randomUUID();
        const job = await call(
          'POST',
          '/v1/assessment-jobs',
          {
            jobId,
            referenceExerciseId: 'ex_live_coffee',
            lessonVersion: 'v2',
            locale: 'en-US',
            referenceText: ref,
            ...audio('coffee.wav'),
          },
          randomUUID(),
        );
        assert.equal(job.status, 202, JSON.stringify(job.body));
        evidence[label] = {
          scoreState: job.body.scoreState,
          transcript: job.body.transcript,
          accuracy: job.body.accuracy,
          fluency: job.body.fluency,
          completeness: job.body.completeness,
          prosody: job.body.prosody,
          provider: job.body.provider,
          words: brief(job.body.words),
          phonemesFirstWord: (job.body.words?.[0]?.phonemes ?? []).length,
          miscues: job.body.miscues,
          reason: job.body.unavailableReason,
        };
      }
      assert.equal(evidence.assessmentMatch.scoreState, 'VALID');

      // 2. Entitlement (MAX) through the Progress relay so a Video Call may start.
      const eventId = randomUUID();
      const now = new Date().toISOString();
      await rest('POST', `/tablesdb/${databaseId}/tables/p_outbox/rows`, {
        rowId: eventId,
        data: {
          eventId,
          type: 'entitlement.changed.v1',
          schemaVersion: 1,
          aggregateId: user,
          occurredAt: now,
          payloadJson: JSON.stringify({
            userId: user,
            plan: 'MAX',
            status: 'ACTIVE',
            expiresAt: null,
            entitlementRevision: 1,
          }),
          attempt: 0,
          nextAttemptAt: now,
          leaseOwner: null,
          leaseUntil: null,
          status: 'PENDING',
          ackAt: null,
          revision: 0,
          createdAt: now,
          updatedAt: now,
        },
      });
      const started = Date.now();
      for (;;) {
        const row = await rest(
          'GET',
          `/tablesdb/${databaseId}/tables/a_inbox/rows/${inboxId(eventId)}`,
        );
        if (row.$id) break;
        assert.ok(Date.now() - started < 240000, 'entitlement relay timeout');
        await new Promise((r) => setTimeout(r, 5000));
      }

      // 3. TURN voice session + Video Call driven by real speech.
      const sessionId = randomUUID();
      const lease = await call(
        'POST',
        '/v1/voice-sessions',
        { sessionId, scenarioId: 'rp_meet_new_friend', mode: 'TURN', level: 'A1' },
        randomUUID(),
      );
      assert.equal(lease.status, 200, JSON.stringify(lease.body));
      const conv = await call(
        'POST',
        '/v1/conversations',
        {
          kind: 'VIDEO_CALL',
          courseId: 'vi_en',
          scenarioId: 'rp_meet_new_friend',
          voiceSessionId: sessionId,
        },
        randomUUID(),
      );
      assert.equal(conv.status, 200, JSON.stringify(conv.body));
      evidence.turns = [];
      for (const name of ['s1.wav', 's2.wav', 's3.wav', 's4.wav']) {
        const turn = await call(
          'POST',
          `/v1/voice-sessions/${sessionId}/turns`,
          { turnId: randomUUID(), epoch: 0, ...audio(name) },
          randomUUID(),
        );
        assert.equal(turn.status, 200, JSON.stringify(turn.body));
        evidence.turns.push({
          transcript: turn.body.transcript,
          reply: turn.body.tutor.tutorText,
          scoreState: turn.body.score?.scoreState ?? null,
          accuracy: turn.body.score?.accuracy ?? null,
          fluency: turn.body.score?.fluency ?? null,
          completeness: turn.body.score?.completeness ?? null,
          prosody: turn.body.score?.prosody ?? null,
          provider: turn.body.score?.transcriptProvider ?? null,
          words: brief(turn.body.score?.words),
        });
      }
      const done = await call(
        'POST',
        `/v1/conversations/${conv.body.conversationId}/complete`,
        { endReason: 'COMPLETED' },
        randomUUID(),
      );
      evidence.videoCall = {
        status: done.body.status,
        stars: done.body.stars,
        error: done.body.error?.code,
      };
      t.diagnostic(JSON.stringify(evidence));
      assert.equal(done.body.status, 'COMPLETED', JSON.stringify(done.body));
    } finally {
      // account.deleted cleanup is covered by appwrite-live; here delete the auth user and rows.
      await rest('DELETE', `/users/${user}`).catch(() => undefined);
      for (const tableId of [
        'a_jobs',
        'a_usage',
        'a_receipts',
        'a_conversations',
        'a_voice_sessions',
        'a_active_slots',
        'a_inbox',
        'a_outbox',
      ]) {
        const list = await rest(
          'GET',
          `/tablesdb/${databaseId}/tables/${tableId}/rows?queries[]=${encodeURIComponent(JSON.stringify({ method: 'equal', attribute: tableId === 'a_outbox' ? 'aggregateId' : 'userId', values: [user] }))}`,
        ).catch(() => ({ rows: [] }));
        for (const row of list.rows ?? [])
          await rest('DELETE', `/tablesdb/${databaseId}/tables/${tableId}/rows/${row.$id}`).catch(
            () => undefined,
          );
      }
    }
  },
);
