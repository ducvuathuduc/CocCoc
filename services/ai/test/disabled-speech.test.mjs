import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { setup, wav } from './harness.mjs';

const disabled = { kind: 'disabled', configVersion: 'disabled-v1', azureEnabled: false };

test('disabled real speech advertises no microphone capability and cannot reserve a slot', async () => {
  const h = setup({ provider: disabled });
  const capabilities = await h.call('GET', '/v1/ai/capabilities', { user: 'alice' });
  assert.equal(capabilities.body.turnSpeech, false);
  assert.equal(capabilities.body.pronunciation, false);
  const lease = await h.call('POST', '/v1/voice-sessions', {
    user: 'alice',
    idem: randomUUID(),
    body: { sessionId: randomUUID(), scenarioId: 'rp_meet_new_friend', mode: 'TURN', level: 'A1' },
  });
  assert.equal(lease.status, 503);
  assert.equal(lease.body.error.code, 'AI_PROVIDER_UNAVAILABLE');
  assert.equal(h.store.dump('a_voice_sessions').length, 0);
  assert.equal(h.store.dump('a_active_slots').length, 0);
});

test('disabling a provider never replaces recorded audio with a scripted transcript', async () => {
  const h = setup();
  const lease = await h.call('POST', '/v1/voice-sessions', {
    user: 'alice',
    idem: randomUUID(),
    body: { sessionId: randomUUID(), scenarioId: 'rp_meet_new_friend', mode: 'TURN', level: 'A1' },
  });
  h.deps.provider = disabled;
  const result = await h.call('POST', `/v1/voice-sessions/${lease.body.sessionId}/turns`, {
    user: 'alice',
    idem: randomUUID(),
    body: { turnId: randomUUID(), epoch: 0, ...wav(2) },
  });
  assert.equal(result.status, 503);
  assert.equal(result.body.error.code, 'AI_PROVIDER_UNAVAILABLE');
  assert.equal(h.store.dump('a_turns').length, 0);
});
