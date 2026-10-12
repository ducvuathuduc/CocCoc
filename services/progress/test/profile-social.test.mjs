import test from 'node:test';
import assert from 'node:assert/strict';
import { initUser, lessonEvent, setup, validate } from './harness.mjs';

test('initialize: atomic rows, 20 gems once, idempotent across keys; auth and key required', async () => {
  const h = setup();
  const key = '31111111-2222-4333-8444-555555555555';
  const a = await h.call('POST', '/v1/me/initialize', { user: 'alice', key });
  validate('Profile', a.body);
  assert.deepEqual(
    [a.status, a.body.publicOptIn, a.body.learningZone, a.body.dailyGoal],
    [200, false, 'UTC', 10],
  );
  assert.deepEqual(
    (await h.call('POST', '/v1/me/initialize', { user: 'alice', key })).body,
    a.body,
  );
  await h.call('POST', '/v1/me/initialize', { user: 'alice' });
  for (const table of [
    'p_profiles',
    'p_rewards',
    'p_preferences',
    'p_league_profiles',
    'p_entitlements',
    'p_zone_history',
  ]) {
    assert.equal(h.store.dump(table).length, 1, table);
  }
  assert.equal(h.store.dump('p_rewards')[0].row.gems, 20);
  assert.equal(h.store.dump('p_reward_ledger').length, 1);
  const profileRow = h.store.dump('p_profiles')[0].row;
  for (const secret of ['email', 'phone', 'password']) assert.equal(secret in profileRow, false);
  assert.equal((await h.call('POST', '/v1/me/initialize', {})).body.error.code, 'AUTH_REQUIRED');
  assert.equal(
    (await h.call('POST', '/v1/me/initialize', { user: 'bob', key: null })).body.error.code,
    'VALIDATION_ERROR',
  );
  assert.equal(
    (await h.call('GET', '/v1/me', { user: 'nobody' })).body.error.code,
    'PROFILE_UNAVAILABLE',
  );
  // Event before initialization: rewards exist lazily; init adds the 20 gems without losing XP.
  await h.deliver(lessonEvent({}, { userId: 'carol', completionId: 'early' }));
  await initUser(h, 'carol');
  const carol = (await h.call('GET', '/v1/me/rewards', { user: 'carol' })).body;
  assert.deepEqual([carol.studyXp, carol.gems], [19, 20]);
});

test('updateMe: expectedRevision CAS, validation, no cross-user effect', async () => {
  const h = setup();
  const a = await initUser(h, 'alice');
  await initUser(h, 'bob');
  const ok = await h.call('PATCH', '/v1/me', {
    user: 'alice',
    body: { nickname: '  Thành  ', dailyGoal: 20, expectedRevision: a.revision },
  });
  validate('Profile', ok.body);
  assert.deepEqual([ok.body.nickname, ok.body.dailyGoal, ok.body.revision], ['Thành', 20, 1]);
  const stale = await h.call('PATCH', '/v1/me', {
    user: 'alice',
    body: { nickname: 'x', expectedRevision: 0 },
  });
  assert.equal(stale.body.error.code, 'REVISION_CONFLICT');
  const unknown = await h.call('PATCH', '/v1/me', {
    user: 'alice',
    body: { expectedRevision: 1, userId: 'bob' },
  });
  assert.equal(unknown.body.error.code, 'VALIDATION_ERROR');
  assert.equal(
    (await h.call('GET', '/v1/me', { user: 'bob' })).body.nickname.startsWith('user'),
    true,
  );
});

test('social: private/blocked/child unavailable; follow idempotent; friends and public profile projection', async () => {
  const h = setup();
  await initUser(h, 'alice', { publicOptIn: true });
  await initUser(h, 'bob', { publicOptIn: true });
  await initUser(h, 'priv');
  assert.equal(
    (await h.call('GET', '/v1/profiles/priv', { user: 'alice' })).body.error.code,
    'PROFILE_UNAVAILABLE',
  );
  assert.equal(
    (await h.call('POST', '/v1/follows', { user: 'alice', body: { targetUserId: 'priv' } })).body
      .error.code,
    'PROFILE_UNAVAILABLE',
  );
  assert.equal(
    (await h.call('POST', '/v1/follows', { user: 'alice', body: { targetUserId: 'alice' } })).body
      .error.code,
    'VALIDATION_ERROR',
  );
  const f1 = await h.call('POST', '/v1/follows', { user: 'alice', body: { targetUserId: 'bob' } });
  validate('Receipt', f1.body);
  let bob = await h.call('GET', '/v1/profiles/bob', { user: 'alice' });
  validate('PublicProfile', bob.body);
  assert.equal(bob.body.followStatus, 'following');
  assert.equal(Object.keys(bob.body).includes('email'), false);
  await h.call('POST', '/v1/follows', { user: 'bob', body: { targetUserId: 'alice' } });
  bob = await h.call('GET', '/v1/profiles/bob', { user: 'alice' });
  assert.equal(bob.body.followStatus, 'friend');
  const friends = await h.call('GET', '/v1/friends', { user: 'alice' });
  validate('ProfilePage', friends.body);
  assert.deepEqual(
    friends.body.items.map((p) => p.userId),
    ['bob'],
  );
  // Block (row written directly: block endpoints are P9-SOCIAL-002) hides both directions.
  await h.store.transact(async (tx) => {
    tx.put('p_blocks', h.kit.ids.block('bob', 'alice'), { blockerId: 'bob', blockedId: 'alice' });
  });
  assert.equal(
    (await h.call('GET', '/v1/profiles/bob', { user: 'alice' })).body.error.code,
    'PROFILE_UNAVAILABLE',
  );
  assert.equal((await h.call('GET', '/v1/friends', { user: 'alice' })).body.items.length, 0);
  const un = await h.call('DELETE', '/v1/follows/bob', { user: 'alice' });
  assert.equal(un.status, 200);
  validate('Receipt', un.body);
  // CHILD accounts cannot make social writes.
  await initUser(h, 'kid');
  await h.store.transact(async (tx) => {
    const id = h.kit.ids.profile('kid');
    const row = await tx.get('p_profiles', id);
    tx.put('p_profiles', id, {
      ...row,
      ageBand: 'CHILD',
      revision: undefined,
      createdAt: undefined,
      updatedAt: undefined,
    });
  });
  assert.equal(
    (await h.call('POST', '/v1/follows', { user: 'kid', body: { targetUserId: 'bob' } })).body.error
      .code,
    'FORBIDDEN',
  );
});

test('activity: own and followed opt-in milestones, paginated', async () => {
  const h = setup();
  await initUser(h, 'alice', { publicOptIn: true });
  await initUser(h, 'bob', { publicOptIn: true });
  await h.call('POST', '/v1/follows', { user: 'alice', body: { targetUserId: 'bob' } });
  for (let i = 0; i < 5; i++)
    await h.deliver(lessonEvent({}, { userId: 'bob', completionId: `b${i}` }));
  const page = await h.call('GET', '/v1/activity', { user: 'alice', query: 'limit=1' });
  validate('ActivityPage', page.body);
  assert.equal(page.body.items[0].userId, 'bob');
  assert.equal(page.body.items[0].kind, 'MILESTONE');
  assert.equal(
    (await h.call('GET', '/v1/activity', { user: 'alice', query: 'limit=0' })).body.error.code,
    'VALIDATION_ERROR',
  );
});

test('friend quest: deterministic pairing, cooperative 10 completions -> 10 gems each once', async () => {
  const h = setup();
  for (const u of ['alice', 'bob']) await initUser(h, u, { publicOptIn: true });
  await h.call('POST', '/v1/follows', { user: 'alice', body: { targetUserId: 'bob' } });
  await h.call('POST', '/v1/follows', { user: 'bob', body: { targetUserId: 'alice' } });
  const solo = await h.call('POST', '/v1/friend-quests/opt-in', { user: 'bob' });
  validate('Receipt', solo.body);
  await h.deliver(lessonEvent({}, { userId: 'bob', completionId: 'pre' }));
  await h.call('POST', '/v1/friend-quests/opt-in', { user: 'alice' });
  const pairs = h.store.dump('p_friend_quests');
  assert.equal(pairs.length, 1);
  assert.deepEqual(JSON.parse(pairs[0].row.userIdsJson), ['alice', 'bob']);
  assert.equal(pairs[0].row.count, 1);
  for (let i = 0; i < 12; i++) {
    await h.deliver(lessonEvent({}, { userId: i % 2 ? 'alice' : 'bob', completionId: `fq${i}` }));
  }
  const gems = async (u) => (await h.call('GET', '/v1/me/rewards', { user: u })).body.gems;
  assert.deepEqual([await gems('alice'), await gems('bob')], [30, 30]);
  const quests = (await h.call('GET', '/v1/quests', { user: 'alice' })).body;
  validate('QuestPage', quests);
  const fq = quests.items.find((q) => q.period === 'WEEK');
  assert.deepEqual([fq.claimed, fq.metricValue >= 10], [true, true]);
});

test('deletion: tombstone + account.deleted outbox; purge after both owner acks; no re-init', async () => {
  const h = setup();
  await initUser(h, 'alice', { publicOptIn: true });
  await h.deliver(lessonEvent());
  const key = '41111111-2222-4333-8444-555555555555';
  const del = await h.call('POST', '/v1/me/deletion', {
    user: 'alice',
    key,
    body: { confirmation: 'DELETE' },
  });
  assert.deepEqual(
    (
      await h.call('POST', '/v1/me/deletion', {
        user: 'alice',
        key,
        body: { confirmation: 'DELETE' },
      })
    ).body,
    del.body,
  );
  assert.equal(
    (await h.call('POST', '/v1/me/deletion', { user: 'alice', body: { confirmation: 'NO' } })).body
      .error.code,
    'VALIDATION_ERROR',
  );
  const outbox = h.store.dump('p_outbox');
  assert.deepEqual([outbox.length, outbox[0].row.type], [1, 'account.deleted.v1']);
  assert.equal(
    (await h.call('GET', '/v1/me', { user: 'alice' })).body.error.code,
    'PROFILE_UNAVAILABLE',
  );
  assert.equal(
    (await h.call('POST', '/v1/me/initialize', { user: 'alice' })).body.error.code,
    'PROFILE_UNAVAILABLE',
  );
  const ack = (owner) => ({
    eventId: crypto.randomUUID(),
    type: 'account.purged.v1',
    schemaVersion: 1,
    producer: owner,
    aggregateId: 'alice',
    occurredAt: new Date(h.clock.now).toISOString(),
    requestId: 'r',
    payload: { userId: 'alice', requestId: del.body.requestId, owner },
  });
  await h.deliver(ack('learning'));
  assert.equal(h.store.dump('p_deletions')[0].row.status, 'REQUESTED');
  assert.equal(h.store.dump('p_profiles').length, 1);
  await assert.rejects(h.deliver({ ...ack('ai'), producer: 'learning' }), {
    code: 'VALIDATION_ERROR',
  });
  await h.deliver(ack('ai'));
  assert.equal(h.store.dump('p_deletions')[0].row.status, 'COMPLETED');
  for (const table of [
    'p_profiles',
    'p_rewards',
    'p_reward_ledger',
    'p_day_activity',
    'p_receipts',
    'p_preferences',
  ]) {
    assert.equal(h.store.dump(table).length, 0, table);
  }
});
