// Scheduler job ticks (/internal/jobs/*) and the Progress outbox relay (CONSISTENCY):
// signed by the scheduler key only, lease/ack/retry/dead-letter, per-type targets, concurrent
// relays deliver once per target, streak rollover, deletion purge retry, league settlement.
import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { initUser, lessonEvent, setup, validate } from './harness.mjs';

const key = (sender, fill) => ({ keyId: `k-${sender}`, sender, secret: Buffer.alloc(32, fill) });
const KEYS = {
  scheduler: key('scheduler', 7),
  maintainer: key('maintainer', 8),
  learning: key('learning', 9),
  progress: key('progress', 10),
};

function signedJobs(h, ports = {}) {
  const wiring = h.kit.progressWiring(h.store, ports);
  const router = h.kit.scopeProgressHandler(
    h.kit.createRouter({
      service: 'progress',
      persistence: h.store,
      mode: 'local-test',
      keyring: h.kit.createKeyring(Object.values(KEYS)),
      routes: wiring.routes,
      eventConsumer: wiring.eventConsumer,
      nowMs: () => h.clock.now,
    }),
  );
  return async function tick(job, { as = 'scheduler', body, sign = true } = {}) {
    const path = `/internal/jobs/${job}`;
    const bodyText = JSON.stringify(
      body ?? { tickId: randomUUID(), scheduledAt: new Date(h.clock.now).toISOString() },
    );
    const headers = sign
      ? h.kit.signServiceRequest({
          key: KEYS[as],
          method: 'POST',
          path,
          body: bodyText,
          nowSeconds: Math.floor(h.clock.now / 1000),
        })
      : {};
    let result;
    await router({
      req: { method: 'POST', path, headers, bodyText, queryString: '' },
      res: { json: (b, status) => (result = { status, body: b }) },
    });
    return result;
  };
}

/** Records deliveries; `answers[target]` decides the outcome (default ack). */
function recorder(answers = {}) {
  const seen = [];
  const deliver = async (target, event) => {
    validate('BusinessEvent', event);
    seen.push({ target, type: event.type, eventId: event.eventId });
    const answer = answers[target];
    return typeof answer === 'function' ? answer(event) : (answer ?? 'ack');
  };
  return { seen, deliver };
}

async function subscribe(h, user, outcome = 'ACTIVE') {
  const r = await h.call('POST', '/v1/billing/purchases', {
    user,
    body: {
      productId: 'super_monthly',
      kind: 'SUBSCRIPTION',
      platform: 'SIMULATION',
      simulationOutcome: outcome,
    },
  });
  assert.equal(r.status, 200, JSON.stringify(r.body));
}

const outboxRows = (h) => h.store.dump('p_outbox').map(({ row }) => row);

test('job routes: scheduler/maintainer signature only; tick body validated; report matches OpenAPI', async () => {
  const h = setup();
  const tick = signedJobs(h, { deliver: recorder().deliver });
  for (const job of [
    'streak-rollover',
    'league-settlement',
    'deletion-purge',
    'progress-outbox-relay',
  ]) {
    const r = await tick(job);
    assert.equal(r.status, 200, `${job} ${JSON.stringify(r.body)}`);
    validate('JobRunReport', r.body);
  }
  assert.equal((await tick('deletion-purge', { as: 'maintainer' })).status, 200);
  assert.equal((await tick('deletion-purge', { as: 'learning' })).status, 403);
  assert.equal((await tick('deletion-purge', { sign: false })).status, 401);
  const bad = await tick('deletion-purge', { body: { tickId: 'x', scheduledAt: 'now' } });
  assert.equal(bad.status, 400);
  const extra = await tick('deletion-purge', {
    body: { tickId: randomUUID(), scheduledAt: new Date().toISOString(), force: true },
  });
  assert.equal(extra.status, 400);
  // The relay without delivery ports fails closed instead of acknowledging anything.
  const closed = signedJobs(h);
  assert.equal((await closed('progress-outbox-relay')).body.error.code, 'SERVICE_NOT_CONFIGURED');
});

test('relay: per-type targets, ack only when every target acknowledged, replay-safe envelope', async () => {
  const h = setup();
  await initUser(h, 'alice');
  await subscribe(h, 'alice'); // entitlement.changed.v1 -> learning + ai
  await initUser(h, 'bob');
  const energy = await h.call('POST', '/v1/ad-events', {
    user: 'bob',
    body: {
      adEventId: randomUUID(),
      placement: 'REWARDED_ENERGY_REFILL',
      kind: 'REWARDED_COMPLETION',
    },
  });
  assert.equal(energy.status, 200, JSON.stringify(energy.body)); // energy.granted.v1 -> learning
  const del = await h.call('POST', '/v1/me/deletion', {
    user: 'bob',
    body: { confirmation: 'DELETE' },
  });
  assert.equal(del.status, 202); // account.deleted.v1 -> learning + ai
  const types = outboxRows(h)
    .map((r) => r.type)
    .sort();
  assert.deepEqual(types, ['account.deleted.v1', 'energy.granted.v1', 'entitlement.changed.v1']);

  // AI is down: Learning-only energy grant acks, the two-target events retry.
  const first = recorder({ ai: 'retry' });
  const report = await h.kit.relayOutbox(h.store, first.deliver, { random: () => 0 });
  assert.deepEqual(report, { leased: 3, acked: 1, retried: 2, dead: 0 });
  const byType = Object.fromEntries(outboxRows(h).map((r) => [r.type, r]));
  assert.equal(byType['energy.granted.v1'].status, 'ACK');
  assert.deepEqual(
    first.seen.filter((s) => s.type === 'energy.granted.v1').map((s) => s.target),
    ['learning'],
  );
  for (const t of ['account.deleted.v1', 'entitlement.changed.v1']) {
    assert.equal(byType[t].status, 'PENDING');
    assert.equal(byType[t].attempt, 1);
    assert.ok(Date.parse(byType[t].nextAttemptAt) > h.clock.now);
  }
  // Not due yet: nothing leased.
  assert.equal((await h.kit.relayOutbox(h.store, first.deliver)).leased, 0);
  h.clock.now += 60_000;
  const second = recorder();
  const again = await h.kit.relayOutbox(h.store, second.deliver);
  assert.deepEqual(again, { leased: 2, acked: 2, retried: 0, dead: 0 });
  assert.deepEqual(second.seen.map((s) => `${s.type}>${s.target}`).sort(), [
    'account.deleted.v1>ai',
    'account.deleted.v1>learning',
    'entitlement.changed.v1>ai',
    'entitlement.changed.v1>learning',
  ]);
  // The same eventId (and envelope) is re-sent to Learning: receivers dedupe by eventId.
  const firstIds = first.seen.map((s) => s.eventId);
  for (const s of second.seen) assert.ok(firstIds.includes(s.eventId));
  const envelope = h.kit.eventOf(outboxRows(h).find((r) => r.type === 'entitlement.changed.v1'));
  assert.deepEqual(
    h.kit.eventOf(outboxRows(h).find((r) => r.type === 'entitlement.changed.v1')),
    envelope,
  );
  assert.equal(envelope.producer, 'progress');
  assert.ok(outboxRows(h).every((r) => r.status === 'ACK' && r.leaseOwner === null));
});

test('relay: non-retryable answer dead-letters; 10 failed attempts dead-letter; lost lease ignored', async () => {
  const h = setup();
  await initUser(h, 'carol');
  await subscribe(h, 'carol');
  const dead = recorder({ learning: 'dead' });
  assert.equal((await h.kit.relayOutbox(h.store, dead.deliver)).dead, 1);
  assert.equal(outboxRows(h)[0].status, 'DEAD');

  const h2 = setup();
  await initUser(h2, 'dan');
  await subscribe(h2, 'dan');
  const flaky = recorder({
    learning: () => {
      throw new Error('socket hang up');
    },
  });
  for (let i = 0; i < 10; i++) {
    await h2.kit.relayOutbox(h2.store, flaky.deliver, { random: () => 1 });
    h2.clock.now += 16 * 60_000;
  }
  const row = outboxRows(h2)[0];
  assert.deepEqual([row.status, row.attempt], ['DEAD', 10]);
  assert.equal(flaky.seen.length, 20); // 10 attempts x (learning, ai)

  // A relay whose lease expired mid-delivery does not overwrite the new owner's outcome.
  const h3 = setup();
  await initUser(h3, 'erin');
  await subscribe(h3, 'erin');
  let other;
  const slow = recorder({
    learning: async () => {
      h3.clock.now += 31_000; // lease (30s) expires while delivering
      other = await h3.kit.relayOutbox(h3.store, recorder().deliver, { owner: 'second' });
      return 'retry';
    },
  });
  await h3.kit.relayOutbox(h3.store, slow.deliver, { owner: 'first' });
  assert.equal(other.acked, 1);
  assert.equal(outboxRows(h3)[0].status, 'ACK');
});

test('relay: concurrent ticks deliver each event once per target', async () => {
  const h = setup();
  for (const u of ['u1', 'u2', 'u3']) {
    await initUser(h, u);
    await subscribe(h, u);
  }
  const shared = recorder();
  const reports = await Promise.all([
    h.kit.relayOutbox(h.store, shared.deliver),
    h.kit.relayOutbox(h.store, shared.deliver),
    h.kit.relayOutbox(h.store, shared.deliver),
  ]);
  assert.equal(
    reports.reduce((n, r) => n + r.acked, 0),
    3,
  );
  const counts = new Map();
  for (const s of shared.seen)
    counts.set(`${s.eventId}>${s.target}`, (counts.get(`${s.eventId}>${s.target}`) ?? 0) + 1);
  assert.equal(counts.size, 6);
  assert.ok([...counts.values()].every((n) => n === 1));
});

test('relay over signed HTTP: Learning-shaped receiver accepts progress events, rejects impersonation', async () => {
  const h = setup();
  await initUser(h, 'fay');
  await subscribe(h, 'fay');
  const received = [];
  const receiverStore = h.kit.createMemoryProgressPersistence(() => h.clock.now);
  // Any owner router with the 'learning' allowlist: the shared transport checks signature/type.
  const learningLike = h.kit.createRouter({
    service: 'learning',
    persistence: {
      ...receiverStore,
      service: 'learning',
      kind: 'memory',
      admittedForHosting: false,
      ping: async () => {},
    },
    mode: 'local-test',
    keyring: h.kit.createKeyring([KEYS.progress]),
    eventConsumer: {
      async consume(event) {
        received.push(event.type);
        return 'accepted';
      },
    },
    nowMs: Date.now, // the HTTP client signs with the real clock
  });
  const fetchImpl = async (url, init) => {
    const u = new URL(url);
    let result;
    await learningLike({
      req: {
        method: init.method,
        path: u.pathname,
        headers: init.headers,
        bodyText: init.body ?? '',
        queryString: u.search.slice(1),
      },
      res: { json: (b, status) => (result = { status, body: b }) },
    });
    return new Response(JSON.stringify(result.body), { status: result.status });
  };
  const deliver = h.kit.httpRelayDeliver({
    key: KEYS.progress,
    targets: { learning: 'https://learning.example.invalid' },
    fetchImpl,
  });
  const report = await h.kit.relayOutbox(h.store, deliver);
  // Learning acks; AI has no configured URL so the row stays PENDING (retry), never a false ack.
  assert.deepEqual(report, { leased: 1, acked: 0, retried: 1, dead: 0 });
  assert.deepEqual(received, ['entitlement.changed.v1']);
  const forged = h.kit.httpRelayDeliver({
    key: KEYS.learning,
    targets: { learning: 'https://learning.example.invalid' },
    fetchImpl,
  });
  const event = h.kit.eventOf(outboxRows(h)[0]);
  assert.equal(await forged('learning', event), 'retry'); // unknown key id: 401 -> retry
  assert.equal(h.kit.relayOutcomeForStatus(403), 'dead');
});

test('streak rollover tick consumes freezes once and ends unprotected streaks', async () => {
  const h = setup({ start: Date.parse('2026-10-10T03:00:00Z') });
  await initUser(h, 'alice');
  await initUser(h, 'bob');
  await h.deliver(lessonEvent({ occurredAt: '2026-10-10T03:00:00Z' }, { completionId: 'a1' }));
  await h.deliver(
    lessonEvent({ occurredAt: '2026-10-10T03:00:00Z' }, { completionId: 'b1', userId: 'bob' }),
  );
  assert.equal((await h.call('POST', '/v1/me/freezes', { user: 'alice' })).status, 200);
  h.clock.now = Date.parse('2026-10-13T05:00:00Z');
  const tick = signedJobs(h);
  const r = await tick('streak-rollover');
  assert.equal(r.status, 200);
  validate('JobRunReport', r.body);
  assert.deepEqual([r.body.processed, r.body.succeeded], [2, 2]);
  const rewards = Object.fromEntries(h.store.dump('p_rewards').map(({ row }) => [row.userId, row]));
  assert.deepEqual([rewards.alice.currentStreak, rewards.alice.freezeSlots], [0, 0]);
  assert.equal(rewards.alice.lostStreak, 2); // 10th + protected 11th, then 12th missed
  assert.deepEqual([rewards.bob.currentStreak, rewards.bob.lostStreak], [0, 1]);
  const again = await tick('streak-rollover');
  assert.equal(again.body.processed, 0);
  assert.equal(
    h.store.dump('p_freeze_ledger').filter(({ row }) => row.action === 'CONSUME').length,
    1,
  );
});

test('deletion purge tick retries PURGING tombstones to COMPLETED', async () => {
  const h = setup();
  await initUser(h, 'gus');
  await h.call('POST', '/v1/me/deletion', { user: 'gus', body: { confirmation: 'DELETE' } });
  const id = h.kit.ids.deletion('gus');
  await h.store.transact(async (tx) => {
    const row = await tx.get('p_deletions', id);
    const { revision: _r, createdAt: _c, updatedAt: _u, ...rest } = row;
    tx.put('p_deletions', id, { ...rest, status: 'PURGING', ownerAcksJson: '["ai","learning"]' });
  });
  const tick = signedJobs(h);
  const r = await tick('deletion-purge');
  assert.deepEqual([r.body.processed, r.body.succeeded], [1, 1]);
  assert.equal((await h.store.read('p_deletions', id)).status, 'COMPLETED');
  assert.equal(h.store.dump('p_profiles').length, 0);
  assert.equal((await tick('deletion-purge')).body.processed, 0);
});

test('league settlement tick: SETTLING without watermark, CLOSED once watermark is zero', async () => {
  const h = setup();
  for (const u of ['l1', 'l2']) {
    await initUser(h, u, { publicOptIn: true });
    assert.equal((await h.call('POST', '/v1/league/join', { user: u })).status, 200);
  }
  h.clock.now += 8 * 24 * 3600 * 1000;
  const blind = signedJobs(h);
  const pending = await blind('league-settlement');
  assert.equal(pending.status, 200, JSON.stringify(pending.body));
  assert.deepEqual([pending.body.succeeded, pending.body.retried], [0, 1]);
  assert.equal(h.store.dump('p_league_runs')[0].row.status, 'SETTLING');
  const zero = signedJobs(h, { watermark: { pendingBefore: async () => 0 } });
  const closed = await zero('league-settlement');
  assert.deepEqual([closed.body.succeeded, closed.body.retried], [1, 0]);
  assert.equal(h.store.dump('p_league_runs')[0].row.status, 'CLOSED');
  assert.equal((await zero('league-settlement')).body.processed, 0);
  const future = await zero('league-settlement', {
    body: { tickId: randomUUID(), scheduledAt: new Date().toISOString(), weekId: '2099-01-05' },
  });
  assert.equal(future.status, 400);
});

test('worker: cron cadence by UTC minute; one failing job never blocks the others', async () => {
  const h = setup({ start: Date.parse('2026-10-12T10:05:00Z') });
  const seen = recorder();
  const at5 = await h.kit.runProgressWorker(h.store, { deliver: seen.deliver }, h.clock.now);
  assert.deepEqual(Object.keys(at5.jobs).sort(), [
    'deletionPurge',
    'outboxRelay',
    'streakRollover',
  ]);
  const at15 = await h.kit.runProgressWorker(h.store, {}, Date.parse('2026-10-12T10:15:00Z'));
  assert.deepEqual(Object.keys(at15.jobs).sort(), ['deletionPurge', 'leagueSettlement']);
  const at7 = await h.kit.runProgressWorker(
    h.store,
    { deliver: seen.deliver },
    Date.parse('2026-10-12T10:07:00Z'),
  );
  assert.deepEqual(Object.keys(at7.jobs).sort(), ['deletionPurge', 'outboxRelay']);
});

test('appwrite entry helpers: plain request copy survives lazy getters; dynamic key scoped and stripped', async () => {
  const { kit } = setup();
  const raw = {
    method: 'GET',
    path: '/health',
    headers: { 'X-Appwrite-Key': 'dyn-key', 'x-appwrite-trigger': 'schedule' },
    bodyText: '',
    queryString: '',
    get bodyJson() {
      throw new Error('lazy bodyJson on empty body');
    },
  };
  const req = kit.plainRequest(raw);
  assert.deepEqual(Object.keys(req).sort(), [
    'bodyText',
    'headers',
    'method',
    'path',
    'queryString',
  ]);
  assert.equal(kit.isScheduledExecution(req), false); // schedule mode only at `/`
  assert.equal(kit.isScheduledExecution({ ...req, path: '/' }), true);
  const inside = await kit.withExecutionKey(req, async () => kit.currentExecutionKey());
  assert.equal(inside, 'dyn-key');
  assert.equal(req.headers['x-appwrite-key'], undefined);
  assert.equal(kit.currentExecutionKey(), undefined);
});

test('hosted entry: Appwrite req with lazy getters, GET /health 200, cron fails closed when disabled', async () => {
  const { repoRoot } = await import('./kit.mjs');
  const { pathToFileURL } = await import('node:url');
  const mod = await import(
    pathToFileURL(`${repoRoot}/services/progress/dist/function.mjs`).href + `?t=${Date.now()}`
  );
  const call = async (path, headers = {}) => {
    let out;
    await mod.default({
      req: {
        method: 'GET',
        path,
        headers,
        bodyText: '',
        get bodyJson() {
          throw new Error('lazy bodyJson on empty body');
        },
      },
      res: { json: (body, status = 200) => (out = { status, body }) },
      log: () => undefined,
    });
    return out;
  };
  assert.equal((await call('/health')).status, 200);
  const cron = await call('/', { 'x-appwrite-trigger': 'schedule', 'x-appwrite-key': 'k' });
  assert.deepEqual([cron.status, cron.body.status], [503, 'SERVICE_NOT_CONFIGURED']);
  assert.equal((await call('/v1/me')).status, 503); // no auth configured in this env: fail closed
});
