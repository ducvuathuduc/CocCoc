import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { setup, initUser, validate } from './harness.mjs';

async function purchase(h, outcome = 'ACTIVE', user = 'alice', key = randomUUID()) {
  const result = await h.call('POST', '/v1/billing/purchases', {
    user,
    key,
    body: {
      productId: 'super_monthly',
      kind: 'SUBSCRIPTION',
      platform: 'SIMULATION',
      simulationOutcome: outcome,
    },
  });
  assert.equal(result.status, 200, JSON.stringify(result.body));
  return validate('Purchase', result.body);
}

test('owned receipt read redacts tokens and hides other accounts', async () => {
  const h = setup();
  await initUser(h, 'alice');
  await initUser(h, 'bob');
  const p = await purchase(h);
  const r = await h.call('GET', `/v1/billing/purchases/${p.purchaseId}`, { user: 'alice' });
  assert.equal(r.status, 200);
  assert.deepEqual(validate('Purchase', r.body), p);
  assert.equal(JSON.stringify(r.body).includes('purchaseToken'), false);
  assert.equal(
    (await h.call('GET', `/v1/billing/purchases/${p.purchaseId}`, { user: 'bob' })).status,
    404,
  );
});

test('receipt read is unavailable after the account deletion tombstone is committed', async () => {
  const h = setup();
  await initUser(h, 'alice');
  const p = await purchase(h);
  const deletion = await h.call('POST', '/v1/me/deletion', {
    user: 'alice',
    key: randomUUID(),
    body: { confirmation: 'DELETE' },
  });
  assert.equal(deletion.status, 202);
  assert.equal(h.store.dump('p_purchases').length, 1);

  const read = await h.call('GET', `/v1/billing/purchases/${p.purchaseId}`, { user: 'alice' });
  assert.equal(read.status, 404);
  assert.equal(read.body.error.code, 'PROFILE_UNAVAILABLE');
});

test('cancel renewal keeps paid access and emits one event across retries', async () => {
  const h = setup();
  await initUser(h, 'alice');
  const p = await purchase(h);
  const key = randomUUID();
  const cancel = () => h.call('POST', '/v1/billing/subscription/cancel', { user: 'alice', key });
  const r = await cancel();
  assert.equal(r.status, 200);
  validate('Entitlement', r.body);
  assert.equal(r.body.status, 'CANCELED');
  assert.equal(r.body.autoRenew, false);
  assert.equal(r.body.adFree, true);
  assert.equal(r.body.expiresAt, p.entitlement.expiresAt);
  assert.deepEqual((await cancel()).body, r.body);
  assert.equal(
    h.store.dump('p_outbox').filter((x) => x.row.type === 'entitlement.changed.v1').length,
    2,
  );
  h.clock.now = Date.parse(p.entitlement.expiresAt);
  const expired = await h.call('GET', '/v1/me/entitlement', { user: 'alice' });
  assert.equal(expired.body.adFree, false);
  assert.equal(expired.body.plan, 'FREE');
});

test('duplicate ACTIVE notifications do not extend paid expiry', async () => {
  const h = setup();
  await initUser(h, 'alice');
  const p = await purchase(h);
  const notify = h.kit
    .progressWiring(h.store, {}, { allowSimulatedCommerce: true })
    .routes.find((r) => r.path === '/internal/billing/notifications');
  h.clock.now += 86400000;
  await notify.handle({
    body: {
      notificationId: randomUUID(),
      purchaseId: p.purchaseId,
      platform: 'SIMULATION',
      state: 'ACTIVE',
      occurredAt: new Date(h.clock.now).toISOString(),
    },
    requestId: 'r',
    sender: 'maintainer',
  });
  const ent = await h.call('GET', '/v1/me/entitlement', { user: 'alice' });
  assert.equal(ent.body.expiresAt, p.entitlement.expiresAt);
});

test('same-state newer billing notification advances ordering; equal and older notifications are ignored', async () => {
  const h = setup();
  await initUser(h, 'alice');
  const p = await purchase(h);
  const notify = h.kit
    .progressWiring(h.store, {}, { allowSimulatedCommerce: true })
    .routes.find((r) => r.path === '/internal/billing/notifications');
  const start = h.clock.now;
  const send = (notificationId, state, offset) =>
    notify.handle({
      body: {
        notificationId,
        purchaseId: p.purchaseId,
        platform: 'SIMULATION',
        state,
        occurredAt: new Date(start + offset).toISOString(),
      },
      requestId: 'r',
      sender: 'maintainer',
    });

  const initial = h.store
    .dump('p_purchases')
    .find(({ row }) => row.purchaseId === p.purchaseId).row;
  const initialOutboxCount = h.store.dump('p_outbox').length;
  await send('newer-active', 'ACTIVE', 2000);
  const advanced = h.store
    .dump('p_purchases')
    .find(({ row }) => row.purchaseId === p.purchaseId).row;
  assert.equal(advanced.lastNotificationId, 'newer-active');
  assert.equal(
    JSON.parse(advanced.vendorStateJson).lastOccurredAt,
    new Date(start + 2000).toISOString(),
  );
  assert.equal(advanced.verifiedAt, initial.verifiedAt);
  assert.equal(h.store.dump('p_outbox').length, initialOutboxCount);

  await send('equal-canceled', 'CANCELED', 2000);
  await send('older-canceled', 'CANCELED', 1000);
  const final = h.store.dump('p_purchases').find(({ row }) => row.purchaseId === p.purchaseId).row;
  assert.equal(final.state, 'ACTIVE');
  assert.equal(final.lastNotificationId, 'newer-active');
  assert.equal(
    JSON.parse(final.vendorStateJson).lastOccurredAt,
    new Date(start + 2000).toISOString(),
  );
  assert.equal(h.store.dump('p_outbox').length, initialOutboxCount);
});

test('newer ACTIVE notification cannot resurrect a refunded purchase', async () => {
  const h = setup();
  await initUser(h, 'alice');
  const p = await purchase(h);
  const notify = h.kit
    .progressWiring(h.store, {}, { allowSimulatedCommerce: true })
    .routes.find((r) => r.path === '/internal/billing/notifications');
  for (const state of ['REFUNDED', 'ACTIVE']) {
    h.clock.now += 1000;
    await notify.handle({
      body: {
        notificationId: randomUUID(),
        purchaseId: p.purchaseId,
        platform: 'SIMULATION',
        state,
        occurredAt: new Date(h.clock.now).toISOString(),
      },
      requestId: 'r',
      sender: 'maintainer',
    });
  }
  const ent = await h.call('GET', '/v1/me/entitlement', { user: 'alice' });
  assert.equal(ent.body.status, 'REVOKED');
  assert.equal(ent.body.adFree, false);
});

for (const [currentState, staleState] of [
  ['ACTIVE', 'REVOKED'],
  ['CANCELED', 'ACTIVE'],
]) {
  test(`newer duplicate ${currentState} keeps older ${staleState} notification from changing access`, async () => {
    const h = setup();
    await initUser(h, 'alice');
    const p = await purchase(h);
    const notify = h.kit
      .progressWiring(h.store, {}, { allowSimulatedCommerce: true })
      .routes.find((r) => r.path === '/internal/billing/notifications');
    const start = h.clock.now;
    const send = (state, offset) =>
      notify.handle({
        body: {
          notificationId: randomUUID(),
          purchaseId: p.purchaseId,
          platform: 'SIMULATION',
          state,
          occurredAt: new Date(start + offset).toISOString(),
        },
        requestId: 'r',
        sender: 'maintainer',
      });
    await send(currentState, 1000);
    const before = await h.call('GET', '/v1/me/entitlement', { user: 'alice' });
    const eventCount = h.store.dump('p_outbox').length;
    await send(currentState, 3000);
    await send(staleState, 2000);
    const after = await h.call('GET', '/v1/me/entitlement', { user: 'alice' });
    assert.deepEqual(after.body, before.body);
    assert.equal(h.store.dump('p_outbox').length, eventCount);
    const receipt = await h.call('GET', `/v1/billing/purchases/${p.purchaseId}`, { user: 'alice' });
    assert.equal(receipt.body.state, currentState);
  });
}

test('invalid billing notification timestamp is rejected without poisoning ordering', async () => {
  const h = setup();
  await initUser(h, 'alice');
  const p = await purchase(h);
  const notify = h.kit
    .progressWiring(h.store, {}, { allowSimulatedCommerce: true })
    .routes.find((r) => r.path === '/internal/billing/notifications');
  await assert.rejects(
    notify.handle({
      body: {
        notificationId: randomUUID(),
        purchaseId: p.purchaseId,
        platform: 'SIMULATION',
        state: 'CANCELED',
        occurredAt: '2026-99-12T03:00:00.000Z',
      },
      requestId: 'r',
      sender: 'maintainer',
    }),
    { code: 'VALIDATION_ERROR' },
  );
  const receipt = await h.call('GET', `/v1/billing/purchases/${p.purchaseId}`, { user: 'alice' });
  assert.equal(receipt.body.state, 'ACTIVE');
});

test('billing notification timestamps normalize like JavaScript Date.parse', async () => {
  const h = setup();
  await initUser(h, 'alice');
  const p = await purchase(h);
  const notify = h.kit
    .progressWiring(h.store, {}, { allowSimulatedCommerce: true })
    .routes.find((r) => r.path === '/internal/billing/notifications');
  const result = await notify.handle({
    body: {
      notificationId: randomUUID(),
      purchaseId: p.purchaseId,
      platform: 'SIMULATION',
      state: 'CANCELED',
      occurredAt: '2027-02-30T24:00:00.000Z',
    },
    requestId: 'r',
    sender: 'maintainer',
  });

  assert.equal(result.status, 200);
  assert.equal(result.body.status, 'accepted');
  const stored = h.store.dump('p_purchases').find((x) => x.row.purchaseId === p.purchaseId).row;
  assert.equal(JSON.parse(stored.vendorStateJson).lastOccurredAt, '2027-03-03T00:00:00.000Z');
  const entitlement = await h.call('GET', '/v1/me/entitlement', { user: 'alice' });
  assert.equal(entitlement.body.status, 'CANCELED');
});
