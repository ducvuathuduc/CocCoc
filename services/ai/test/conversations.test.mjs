import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { checkRows, kit, setup, validate } from './harness.mjs';

const start = (h, user, scenarioId = 'rp_cafe_order', extra = {}) =>
  h.call('POST', '/v1/conversations', {
    user,
    idem: extra.idem ?? randomUUID(),
    body: { kind: 'ROLEPLAY', courseId: 'vi_en', scenarioId, voiceSessionId: null, ...extra.body },
  });
const say = (h, user, scenarioId, learnerText) =>
  h.call('POST', '/v1/tutor', {
    user,
    body: {
      requestId: randomUUID(),
      scenarioId,
      learnerText,
      level: 'A1',
      locale: 'en-US',
      feedbackLocale: 'vi-VN',
    },
  });

test('scripted provider ships >= 10 A1-A2 scenarios in real English with valid ids', () => {
  assert.ok(kit.SCENARIOS.length >= 10);
  for (const s of kit.SCENARIOS) {
    assert.match(s.id, /^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$/);
    assert.ok(['A1', 'A2'].includes(s.level));
    assert.ok(s.steps.length >= 4 && s.targetWords.length >= 6);
    for (const step of s.steps) {
      assert.match(step.partner, /^[A-Z].*[.?!]$/);
      // The model answer must count as on-topic for its own step.
      assert.ok(kit.onTopic(step, step.expect), `${s.id}: "${step.expect}"`);
    }
  }
});

test('start is gated by the projected plan: FREE -> ENTITLEMENT_REQUIRED, MAX -> ACTIVE', async () => {
  const h = setup();
  const denied = await start(h, 'alice');
  assert.equal(denied.status, 403);
  assert.equal(denied.body.error.code, 'ENTITLEMENT_REQUIRED');
  assert.equal((await h.grant('alice', 'SUPER', 1)).status, 200);
  assert.equal((await start(h, 'alice')).body.error.code, 'ENTITLEMENT_REQUIRED');
  assert.equal((await h.grant('alice', 'MAX', 2)).status, 200);
  const ok = await start(h, 'alice');
  assert.equal(ok.status, 200);
  validate('Conversation', ok.body);
  assert.equal(ok.body.status, 'ACTIVE');
  assert.equal(ok.body.feedback, null);
  // Expired MAX falls back to FREE.
  await h.grant('alice', 'MAX', 3, { expiresAt: new Date(h.clock.now - 1000).toISOString() });
  assert.equal((await start(h, 'alice')).body.error.code, 'ENTITLEMENT_REQUIRED');
  // Gate is configurable per feature.
  const open = setup({ gates: { ROLEPLAY: 'FREE', VIDEO_CALL: 'MAX' } });
  assert.equal((await start(open, 'bob')).status, 200);
  assert.equal(
    (await start(open, 'bob', 'rp_cafe_order', { body: { kind: 'VIDEO_CALL' } })).body.error.code,
    'ENTITLEMENT_REQUIRED',
  );
  checkRows(h.store);
});

test('text turns follow the script; complete once -> stars/XP/feedback + one outbox event', async () => {
  const h = setup();
  await h.grant('alice');
  const idem = randomUUID();
  const started = await start(h, 'alice', 'rp_cafe_order', { idem });
  const replay = await start(h, 'alice', 'rp_cafe_order', { idem });
  assert.deepEqual(replay.body, started.body);
  const id = started.body.conversationId;

  const off = await say(h, 'alice', 'rp_cafe_order', 'My dog is brown.');
  validate('TutorResult', off.body);
  assert.equal(off.body.correction, 'I would like a coffee, please.');
  assert.match(off.body.tutorText, /^Let's try again\./);
  const early = await h.call('POST', `/v1/conversations/${id}/complete`, {
    user: 'alice',
    idem: randomUUID(),
    body: { endReason: 'COMPLETED' },
  });
  assert.equal(early.body.error.code, 'SESSION_INCOMPLETE');

  const answers = [
    'I would like a coffee with milk, please.',
    'A large one, please.',
    'Milk and no sugar, thank you.',
    'To go, please.',
  ];
  let last;
  for (const text of answers) {
    last = await say(h, 'alice', 'rp_cafe_order', text);
    assert.equal(last.status, 200);
    assert.equal(last.body.correction, null);
    assert.equal(last.body.source, 'authored');
  }
  assert.equal(last.body.tutorText, 'Here is your coffee. Have a nice day!');

  const doneIdem = randomUUID();
  const done = await h.call('POST', `/v1/conversations/${id}/complete`, {
    user: 'alice',
    idem: doneIdem,
    body: { endReason: 'COMPLETED' },
  });
  assert.equal(done.status, 200);
  validate('Conversation', done.body);
  assert.equal(done.body.status, 'COMPLETED');
  assert.equal(done.body.turnCount, 5);
  assert.equal(done.body.stars, 3);
  assert.equal(done.body.xpAwarded, 20);
  assert.ok(done.body.wordsUsed >= 4);
  assert.ok(done.body.feedback.usedWords.includes('coffee'));

  // Same key replays; a new key answers the stored result without a second event.
  const again = await h.call('POST', `/v1/conversations/${id}/complete`, {
    user: 'alice',
    idem: doneIdem,
    body: { endReason: 'COMPLETED' },
  });
  assert.deepEqual(again.body, done.body);
  const other = await h.call('POST', `/v1/conversations/${id}/complete`, {
    user: 'alice',
    idem: randomUUID(),
    body: { endReason: 'USER_EXIT' },
  });
  assert.equal(other.body.status, 'COMPLETED');
  const outbox = h.store.dump('a_outbox');
  assert.equal(outbox.length, 1);
  const event = JSON.parse(outbox[0].row.payloadJson);
  validate('BusinessEvent', event);
  assert.equal(event.type, 'ai.practice.completed.v1');
  assert.deepEqual(event.payload, {
    completionId: id,
    userId: 'alice',
    kind: 'ROLEPLAY',
    courseId: 'vi_en',
    scenarioId: 'rp_cafe_order',
    xp: 20,
    wordsUsed: done.body.wordsUsed,
    stars: 3,
  });
  assert.equal(outbox[0].row.status, 'PENDING');

  // Another user cannot see or complete it.
  const foreign = await h.call('POST', `/v1/conversations/${id}/complete`, {
    user: 'mallory',
    idem: randomUUID(),
    body: { endReason: 'COMPLETED' },
  });
  assert.equal(foreign.body.error.code, 'NOT_FOUND');
  checkRows(h.store);
});

test('list: newest first, filters, cursor paging, expired ACTIVE reads EXPIRED; USER_EXIT abandons', async () => {
  const h = setup();
  await h.grant('alice');
  const ids = [];
  for (const scenario of ['rp_cafe_order', 'rp_ask_directions', 'rp_doctor_visit']) {
    ids.push((await start(h, 'alice', scenario)).body.conversationId);
    h.clock.now += 60_000;
  }
  const exit = await h.call('POST', `/v1/conversations/${ids[1]}/complete`, {
    user: 'alice',
    idem: randomUUID(),
    body: { endReason: 'USER_EXIT' },
  });
  assert.equal(exit.body.status, 'ABANDONED');
  assert.equal(exit.body.xpAwarded, 0);
  const page1 = await h.call('GET', '/v1/conversations', { user: 'alice', query: 'limit=2' });
  validate('ConversationPage', page1.body);
  assert.deepEqual(
    page1.body.items.map((c) => c.conversationId),
    [ids[2], ids[1]],
  );
  assert.ok(page1.body.nextCursor);
  const page2 = await h.call('GET', '/v1/conversations', {
    user: 'alice',
    query: `limit=2&cursor=${page1.body.nextCursor}`,
  });
  assert.deepEqual(
    page2.body.items.map((c) => c.conversationId),
    [ids[0]],
  );
  assert.equal(page2.body.nextCursor, null);
  const filtered = await h.call('GET', '/v1/conversations', {
    user: 'alice',
    query: 'scenarioId=rp_doctor_visit&kind=ROLEPLAY',
  });
  assert.equal(filtered.body.items.length, 1);
  h.clock.now += 31 * 60_000;
  const later = await h.call('GET', '/v1/conversations', { user: 'alice' });
  assert.equal(later.body.items.find((c) => c.conversationId === ids[0]).status, 'EXPIRED');
  assert.equal((await h.call('GET', '/v1/conversations', { user: 'bob' })).body.items.length, 0);
  assert.equal(
    (await h.call('GET', '/v1/conversations', { user: 'alice', query: 'bogus=1' })).status,
    400,
  );
  // Starting the same scenario again abandons the older active run.
  const fresh = setup();
  await fresh.grant('alice');
  const a = (await start(fresh, 'alice')).body.conversationId;
  await start(fresh, 'alice');
  const rows = fresh.store.dump('a_conversations');
  assert.equal(rows.find((r) => r.id === a).row.status, 'ABANDONED');
  checkRows(h.store);
});

test('capabilities report the scripted provider truthfully', async () => {
  const h = setup();
  const caps = await h.call('GET', '/v1/ai/capabilities', { user: 'alice' });
  validate('Capabilities', caps.body);
  assert.equal(caps.body.nativeLive, false);
  assert.equal(caps.body.pronunciation, false);
  assert.equal(caps.body.pronunciationReason, 'AZURE_DISABLED');
  const fallback = await say(h, 'alice', null, 'Hello teacher');
  assert.equal(fallback.body.source, 'fallback');
  validate('TutorResult', fallback.body);
});
