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
    .progressWiring(h.store)
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

test('newer ACTIVE notification cannot resurrect a refunded purchase', async () => {
  const h = setup();
  await initUser(h, 'alice');
  const p = await purchase(h);
  const notify = h.kit
    .progressWiring(h.store)
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
