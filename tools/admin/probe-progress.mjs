#!/usr/bin/env node
// Maintainer live probe of the deployed Progress Function through its PUBLIC domain (TEST project
// only). Creates a synthetic Appwrite user + JWT with the server key, exercises init, profile,
// shop, freeze, mock purchase -> entitlement, ad suppression, deletion, checks that a forged
// `x-appwrite-trigger: schedule` from the public domain never reaches the worker, then deletes the
// user and every Progress row it created. Requires APPWRITE_API_KEY (server key) and
// ALLOW_LIVE_PROBE=reviewed-test-project. Prints one JSON report; exit 1 on any failed check.
import { randomUUID } from 'node:crypto';
import { Client, Query, TablesDB, Users } from 'node-appwrite';
import { DEFAULT_ENDPOINT, DEFAULT_PROJECT, loadMaintainer } from './lib.mjs';

if (process.env.ALLOW_LIVE_PROBE !== 'reviewed-test-project') {
  console.error(
    'Set ALLOW_LIVE_PROBE=reviewed-test-project (creates and deletes a synthetic user).',
  );
  process.exit(2);
}
const endpoint = process.env.APPWRITE_ENDPOINT ?? DEFAULT_ENDPOINT;
const projectId = process.env.APPWRITE_PROJECT_ID ?? DEFAULT_PROJECT;
const domain = process.env.COC_PROGRESS_URL ?? 'https://coccoc-progress.sgp.appwrite.run';
const client = new Client()
  .setEndpoint(endpoint)
  .setProject(projectId)
  .setKey(process.env.APPWRITE_API_KEY ?? '');
const users = new Users(client);
const db = new TablesDB(client);
const kit = await loadMaintainer();
const checks = [];
const check = (name, pass, detail) => checks.push({ name, pass: Boolean(pass), detail });

async function call(method, path, { jwt, body, headers = {} } = {}) {
  const h = { ...headers };
  if (jwt) h.authorization = `Bearer ${jwt}`;
  if (method !== 'GET') {
    h['content-type'] = 'application/json';
    h['idempotency-key'] ??= randomUUID();
  }
  const r = await fetch(`${domain}${path}`, {
    method,
    headers: h,
    ...(method !== 'GET' ? { body: JSON.stringify(body ?? {}) } : {}),
  });
  const text = await r.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    json = text;
  }
  return { status: r.status, body: json };
}

const userId = `probe${randomUUID().replace(/-/g, '').slice(0, 12)}`;
let swept = 0;
try {
  await users.create({
    userId,
    email: `${userId}@example.invalid`,
    password: `${randomUUID()}Aa!`,
  });
  const { jwt } = await users.createJWT({ userId });
  check('health', (await call('GET', '/health')).status === 200);
  const forged = await call('GET', '/', { headers: { 'x-appwrite-trigger': 'schedule' } });
  check(
    'forged schedule trigger is not the worker',
    forged.status === 401 && !forged.body?.worker,
    forged.status,
  );
  check('no JWT -> 401', (await call('GET', '/v1/me')).status === 401);
  const init = await call('POST', '/v1/me/initialize', { jwt, body: {} });
  check(
    'initialize 200 (persistence enabled, dynamic key)',
    init.status === 200,
    init.status === 200 ? init.body.userId : init.body,
  );
  const me = await call('GET', '/v1/me', { jwt });
  check('GET /v1/me 200', me.status === 200 && me.body.userId === userId, me.status);
  const shop = await call('GET', '/v1/shop', { jwt });
  check('GET /v1/shop', shop.status === 200 && shop.body.gems === 20, shop.body?.gems);
  const freeze = await call('POST', '/v1/shop/purchases', {
    jwt,
    body: {
      itemId: 'streak_freeze',
      quantity: 1,
      catalogVersion: shop.body?.catalogVersion ?? 'shop-v1',
    },
  });
  check(
    'buy streak_freeze for 20 gems',
    freeze.status === 200 && freeze.body.gems === 0,
    freeze.status === 200 ? freeze.body.gems : freeze.body,
  );
  const poor = await call('POST', '/v1/shop/purchases', {
    jwt,
    body: { itemId: 'energy_refill', quantity: 1, catalogVersion: 'shop-v1' },
  });
  check(
    'INSUFFICIENT_GEMS',
    poor.body?.error?.code === 'INSUFFICIENT_GEMS',
    poor.body?.error?.code,
  );
  const buy = await call('POST', '/v1/billing/purchases', {
    jwt,
    body: {
      productId: 'super_monthly',
      kind: 'SUBSCRIPTION',
      platform: 'SIMULATION',
      simulationOutcome: 'ACTIVE',
    },
  });
  check(
    'mock purchase -> SUPER',
    buy.status === 200 && buy.body.entitlement?.plan === 'SUPER',
    buy.status,
  );
  const ad = await call('POST', '/v1/ad-events', {
    jwt,
    body: { adEventId: randomUUID(), placement: 'REWARDED_GEMS', kind: 'IMPRESSION' },
  });
  check(
    'ads suppressed for SUPER',
    ad.body?.error?.code === 'AD_NOT_ELIGIBLE',
    ad.body?.error?.code,
  );
  const outbox = await db.listRows({
    databaseId: 'cocenglish',
    tableId: 'p_outbox',
    queries: [Query.equal('aggregateId', userId), Query.limit(10)],
  });
  check(
    'entitlement.changed.v1 staged in p_outbox',
    outbox.rows.some((r) => r.type === 'entitlement.changed.v1'),
    outbox.rows.map((r) => `${r.type}:${r.status}:${r.attempt}`),
  );
  const del = await call('POST', '/v1/me/deletion', { jwt, body: { confirmation: 'DELETE' } });
  check('deletion 202', del.status === 202, del.status);
} catch (error) {
  check('probe run', false, error.message);
} finally {
  // Sweep every Progress row naming the synthetic user, then the Appwrite user itself.
  for (const [tableId, spec] of Object.entries(kit.PROGRESS_SCHEMA)) {
    for (const column of ['userId', 'fromUserId', 'toUserId', 'blockerId', 'blockedId'].filter(
      (c) => spec.columns[c],
    )) {
      for (;;) {
        const page = await db.listRows({
          databaseId: 'cocenglish',
          tableId,
          queries: [Query.equal(column, userId), Query.limit(100)],
        });
        if (!page.rows.length) break;
        for (const row of page.rows) {
          await db
            .deleteRow({ databaseId: 'cocenglish', tableId, rowId: row.$id })
            .catch(() => undefined);
          swept++;
        }
      }
    }
  }
  for (;;) {
    const page = await db.listRows({
      databaseId: 'cocenglish',
      tableId: 'p_outbox',
      queries: [Query.equal('aggregateId', userId), Query.limit(100)],
    });
    if (!page.rows.length) break;
    for (const row of page.rows) {
      await db
        .deleteRow({ databaseId: 'cocenglish', tableId: 'p_outbox', rowId: row.$id })
        .catch(() => undefined);
      swept++;
    }
  }
  await users.delete({ userId }).catch(() => undefined);
}
const failed = checks.filter((c) => !c.pass);
console.log(
  JSON.stringify(
    {
      status: failed.length ? 'FAIL' : 'PASS',
      domain,
      passed: checks.length - failed.length,
      total: checks.length,
      swept,
      checks,
    },
    null,
    2,
  ),
);
process.exit(failed.length ? 1 : 0);
