import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { checkRows, setup, validate, wav } from './harness.mjs';

const voice = (h, user, mode = 'TURN', sessionId = randomUUID()) =>
  h.call('POST', '/v1/voice-sessions', {
    user,
    idem: randomUUID(),
    body: { sessionId, scenarioId: 'rp_meet_new_friend', mode, level: 'A1' },
  });

test('LIVE is disabled; TURN session has one active slot, heartbeat and idempotent close', async () => {
  const h = setup();
  const live = await voice(h, 'alice', 'LIVE');
  assert.equal(live.status, 503);
  assert.equal(live.body.error.code, 'NATIVE_LIVE_DISABLED');
  const lease = await voice(h, 'alice');
  assert.equal(lease.status, 200);
  validate('VoiceLease', lease.body);
  assert.equal(lease.body.ephemeralToken, null);
  assert.equal((await voice(h, 'alice')).body.error.code, 'ACTIVE_VOICE_SESSION');
  const id = lease.body.sessionId;
  const beat = await h.call('POST', `/v1/voice-sessions/${id}/heartbeat`, {
    user: 'alice',
    body: { epoch: 0, elapsedSeconds: 12, turnCount: 1 },
  });
  validate('VoiceState', beat.body);
  assert.equal(beat.body.accountedSeconds, 12);
  const wrongEpoch = await h.call('POST', `/v1/voice-sessions/${id}/heartbeat`, {
    user: 'alice',
    body: { epoch: 3, elapsedSeconds: 12, turnCount: 1 },
  });
  assert.equal(wrongEpoch.body.error.code, 'VOICE_EPOCH_CONFLICT');
  assert.equal(
    (await h.call('POST', `/v1/voice-sessions/${id}/close`, { user: 'bob', body: {} })).body.error
      .code,
    'NOT_FOUND',
  );
  const closed = await h.call('POST', `/v1/voice-sessions/${id}/close`, {
    user: 'alice',
    body: {},
  });
  assert.equal(closed.body.status, 'CLOSED');
  const closedAgain = await h.call('POST', `/v1/voice-sessions/${id}/close`, {
    user: 'alice',
    body: {},
  });
  assert.deepEqual(closedAgain.body, closed.body);
  assert.equal((await voice(h, 'alice')).status, 200);
  checkRows(h.store);
});

test('scripted TURN speech drives a Video Call conversation to completion', async () => {
  const h = setup();
  await h.grant('alice');
  const lease = await voice(h, 'alice');
  const sessionId = lease.body.sessionId;
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
  const audio = wav(2);
  const transcripts = [];
  for (let i = 0; i < 4; i++) {
    const turnIdem = randomUUID();
    const body = { turnId: randomUUID(), epoch: 0, ...audio };
    const turn = await h.call('POST', `/v1/voice-sessions/${sessionId}/turns`, {
      user: 'alice',
      idem: turnIdem,
      body,
    });
    assert.equal(turn.status, 200, JSON.stringify(turn.body));
    validate('TurnResult', turn.body);
    assert.equal(turn.body.score, null);
    assert.equal(turn.body.tutor.assessedPronunciation, false);
    transcripts.push(turn.body.transcript);
    // Replay with the same key does not advance the script.
    const replay = await h.call('POST', `/v1/voice-sessions/${sessionId}/turns`, {
      user: 'alice',
      idem: turnIdem,
      body,
    });
    assert.deepEqual(replay.body, turn.body);
  }
  assert.equal(transcripts[0], 'Hi Tom, my name is Lan.');
  const done = await h.call('POST', `/v1/conversations/${conv.body.conversationId}/complete`, {
    user: 'alice',
    idem: randomUUID(),
    body: { endReason: 'COMPLETED' },
  });
  assert.equal(done.body.status, 'COMPLETED');
  assert.equal(done.body.turnCount, 4);
  assert.ok(done.body.stars >= 2);
  // Completion closed the voice session and released the slot.
  const session = h.store.dump('a_voice_sessions')[0].row;
  assert.equal(session.status, 'CLOSED');
  assert.equal(h.store.dump('a_active_slots').length, 0);
  const usage = h.store.dump('a_usage').find((r) => r.row.utcDay === '2026-10-12');
  assert.equal(usage.row.recordedSpeechSeconds, 8);
  checkRows(h.store);
});

test('bad audio is INVALID_AUDIO; assessment returns a null-score mock result, owner-only', async () => {
  const h = setup();
  const lease = await voice(h, 'alice');
  const audio = wav(1);
  const mismatch = await h.call('POST', `/v1/voice-sessions/${lease.body.sessionId}/turns`, {
    user: 'alice',
    idem: randomUUID(),
    body: {
      turnId: randomUUID(),
      epoch: 0,
      wavBase64: audio.wavBase64,
      audioSha256: '0'.repeat(64),
    },
  });
  assert.equal(mismatch.body.error.code, 'INVALID_AUDIO');
  const junk = Buffer.from('this is not a wav file at all, just text bytes here....');
  const long = {
    wavBase64: junk.toString('base64'),
    audioSha256: createHash('sha256').update(junk).digest('hex'),
  };
  const tooLong = await h.call('POST', '/v1/assessment-jobs', {
    user: 'alice',
    idem: randomUUID(),
    body: {
      jobId: randomUUID(),
      referenceExerciseId: 'ex1',
      lessonVersion: 'v2',
      locale: 'en-US',
      ...long,
    },
  });
  assert.equal(tooLong.body.error.code, 'INVALID_AUDIO');
  const jobId = randomUUID();
  const created = await h.call('POST', '/v1/assessment-jobs', {
    user: 'alice',
    idem: randomUUID(),
    body: { jobId, referenceExerciseId: 'ex1', lessonVersion: 'v2', locale: 'en-US', ...audio },
  });
  assert.equal(created.status, 202);
  validate('Assessment', created.body);
  assert.equal(created.body.scoreState, 'NULL_UNAVAILABLE');
  assert.equal(created.body.accuracy, null);
  assert.equal(created.body.unavailableReason, 'AZURE_DISABLED');
  const read = await h.call('GET', `/v1/assessment-jobs/${jobId}`, { user: 'alice' });
  assert.deepEqual(read.body, created.body);
  assert.equal(
    (await h.call('GET', `/v1/assessment-jobs/${jobId}`, { user: 'bob' })).body.error.code,
    'NOT_FOUND',
  );
  checkRows(h.store);
});
