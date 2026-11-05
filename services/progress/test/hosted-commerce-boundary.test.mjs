import test from 'node:test';
import assert from 'node:assert/strict';
import { setup, initUser } from './harness.mjs';

test('real composition rejects simulated purchase before it grants wallet or entitlement', async () => {
  const h = setup({ allowSimulatedCommerce: false });
  await initUser(h, 'alice');
  const before = await h.call('GET', '/v1/me/rewards', { user: 'alice' });
  const result = await h.call('POST', '/v1/billing/purchases', {
    user: 'alice',
    body: {
      productId: 'gems_500',
      kind: 'GEMS',
      platform: 'SIMULATION',
      simulationOutcome: 'ACTIVE',
    },
  });
  assert.equal(result.status, 503);
  assert.equal(result.body.error.code, 'SERVICE_NOT_CONFIGURED');
  const after = await h.call('GET', '/v1/me/rewards', { user: 'alice' });
  assert.deepEqual(after.body, before.body);
  assert.equal(h.store.dump('p_purchases').length, 0);
});

test('default real wiring blocks every simulation writer before parsing or storage', async () => {
  const h = setup();
  const routes = h.kit.progressWiring(h.store).routes;
  for (const path of [
    '/v1/billing/purchases',
    '/internal/billing/notifications',
    '/v1/gifts',
    '/v1/gifts/{giftId}/redeem',
    '/v1/ad-events',
  ]) {
    const route = routes.find((r) => r.method === 'POST' && r.path === path);
    assert.ok(route, path);
    await assert.rejects(async () => route.handle({ body: {}, requestId: 'r', userId: 'alice' }), {
      code: 'SERVICE_NOT_CONFIGURED',
    });
  }
  assert.equal(h.store.dump('p_purchases').length, 0);
});
