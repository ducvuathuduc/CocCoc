#!/usr/bin/env node
// Maintainer live probe (TEST project only): AI practice XP end to end over the PUBLIC domains.
// A synthetic Appwrite user initializes Progress, buys MAX through the server-side mock provider
// (platform SIMULATION), waits for Progress' relay to project entitlement.changed.v1 into AI,
// completes a Roleplay on coccoc-ai, then waits for ai.practice.completed.v1 to be credited by
// Progress (GET /v1/me/rewards?completionId=<conversationId>). Reports the delivery path (a_outbox
// status/attempt, recent coc-ai schedule executions) and deletes the user plus every row naming it.
// Requires APPWRITE_API_KEY (server key; the egress-proxy sentinel with NODE_USE_ENV_PROXY=1) and
// ALLOW_LIVE_PROBE=reviewed-test-project. Prints one JSON report; exit 1 on any failed check.
import { randomUUID } from 'node:crypto';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { buildSync } from 'esbuild';
import { Client, Query, TablesDB, Users } from 'node-appwrite';
import { DEFAULT_ENDPOINT, DEFAULT_PROJECT, root } from './lib.mjs';

if (process.env.ALLOW_LIVE_PROBE !== 'reviewed-test-project') {
  console.error(
    'Set ALLOW_LIVE_PROBE=reviewed-test-project (creates and deletes a synthetic user).',
  );
  process.exit(2);
}
const endpoint = process.env.APPWRITE_ENDPOINT ?? DEFAULT_ENDPOINT;
const projectId = process.env.APPWRITE_PROJECT_ID ?? DEFAULT_PROJECT;
const apiKey = process.env.APPWRITE_API_KEY ?? '';
const progressUrl = process.env.COC_PROGRESS_URL ?? 'https://coccoc-progress.sgp.appwrite.run';
const aiUrl = process.env.COC_AI_DOMAIN ?? 'https://coccoc-ai.sgp.appwrite.run';
const DB = 'cocenglish';
const SCENARIO = 'rp_ask_directions';
const client = new Client().setEndpoint(endpoint).setProject(projectId).setKey(apiKey);
const users = new Users(client);
const db = new TablesDB(client);
const checks = [];
const evidence = {};
const check = (name, pass, detail) => checks.push({ name, pass: Boolean(pass), detail });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const scenariosFile = path.join(root, `.cache/admin/scenarios-${process.pid}.mjs`);
buildSync({
  entryPoints: [path.join(root, 'services/ai/src/domain/scenarios.ts')],
  outfile: scenariosFile,
  bundle: true,
  platform: 'node',
  target: 'node22',
  format: 'esm',
  logLevel: 'error',
});
const { scenarioById } = await import(pathToFileURL(scenariosFile).href);

async function call(base, method, p, { jwt, body } = {}) {
  const headers = {};
  if (jwt) headers.authorization = `Bearer ${jwt}`;
  if (method !== 'GET') {
    headers['content-type'] = 'application/json';
    headers['idempotency-key'] = randomUUID();
  }
  const r = await fetch(`${base}${p}`, {
    method,
    headers,
    ...(method !== 'GET' ? { body: JSON.stringify(body ?? {}) } : {}),
  });
  const text = await r.text();
  try {
    return { status: r.status, body: JSON.parse(text) };
  } catch {
    return { status: r.status, body: text };
  }
}
async function rows(tableId, queries) {
  const out = [];
  for (let cursor = null; ;) {
    const page = await db.listRows({
      databaseId: DB,
      tableId,
      queries: [...queries, Query.limit(100), ...(cursor ? [Query.cursorAfter(cursor)] : [])],
    });
    out.push(...page.rows);
    if (page.rows.length < 100) return out;
    cursor = page.rows.at(-1).$id;
  }
}

const userId = `aipx${randomUUID().replace(/-/g, '').slice(0, 12)}`;
const t0 = Date.now();
let swept = 0;
try {
  await users.create({
    userId,
    email: `${userId}@example.invalid`,
    password: `${randomUUID()}Aa!`,
  });
  const { jwt } = await users.createJWT({ userId, duration: 900 });
  const init = await call(progressUrl, 'POST', '/v1/me/initialize', { jwt, body: {} });
  check('progress initialize 200', init.status === 200, init.status);
  const before = await call(progressUrl, 'GET', '/v1/me/rewards', { jwt });
  check('rewards baseline', before.status === 200, before.body?.studyXp);
  evidence.before = { studyXp: before.body?.studyXp, currentStreak: before.body?.currentStreak };

  const start = { kind: 'ROLEPLAY', courseId: 'vi_en', scenarioId: SCENARIO, voiceSessionId: null };
  const denied = await call(aiUrl, 'POST', '/v1/conversations', { jwt, body: start });
  check(
    'FREE user: ENTITLEMENT_REQUIRED',
    denied.body?.error?.code === 'ENTITLEMENT_REQUIRED',
    denied.body?.error?.code,
  );

  const buy = await call(progressUrl, 'POST', '/v1/billing/purchases', {
    jwt,
    body: {
      productId: 'max_monthly',
      kind: 'SUBSCRIPTION',
      platform: 'SIMULATION',
      simulationOutcome: 'ACTIVE',
    },
  });
  check(
    'mock purchase -> MAX',
    buy.status === 200 && buy.body?.entitlement?.plan === 'MAX',
    buy.status === 200 ? buy.body.entitlement : buy.body,
  );

  // Progress relay (immediate + every-minute worker) projects the entitlement into AI.
  let conv = null;
  const entStart = Date.now();
  while (Date.now() - entStart < 240000) {
    const r = await call(aiUrl, 'POST', '/v1/conversations', { jwt, body: start });
    if (r.status === 200) {
      conv = r.body;
      break;
    }
    if (r.body?.error?.code !== 'ENTITLEMENT_REQUIRED') {
      check('start conversation', false, r.body);
      break;
    }
    await sleep(5000);
  }
  evidence.entitlementProjectedAfterSeconds = Math.round((Date.now() - entStart) / 1000);
  check('MAX projected into AI; roleplay started', conv?.conversationId, conv?.conversationId);
  if (!conv) throw new Error('no conversation');

  for (const step of scenarioById(SCENARIO).steps) {
    const r = await call(aiUrl, 'POST', '/v1/tutor', {
      jwt,
      body: {
        requestId: randomUUID(),
        scenarioId: SCENARIO,
        learnerText: step.expect,
        level: 'A1',
        locale: 'en-US',
        feedbackLocale: 'vi-VN',
      },
    });
    if (r.status !== 200) check('tutor turn', false, r.body);
  }
  const done = await call(aiUrl, 'POST', `/v1/conversations/${conv.conversationId}/complete`, {
    jwt,
    body: { endReason: 'COMPLETED' },
  });
  const completedAt = Date.now();
  check('roleplay COMPLETED', done.body?.status === 'COMPLETED', {
    stars: done.body?.stars,
    xpAwarded: done.body?.xpAwarded,
  });
  evidence.roleplay = {
    conversationId: conv.conversationId,
    stars: done.body?.stars,
    xpAwarded: done.body?.xpAwarded,
  };

  let credited = null;
  while (Date.now() - completedAt < 240000) {
    const r = await call(progressUrl, 'GET', `/v1/me/rewards?completionId=${conv.conversationId}`, {
      jwt,
    });
    if (r.status === 200 && r.body.status !== 'pending') {
      credited = r.body;
      break;
    }
    await sleep(5000);
  }
  evidence.creditedAfterSeconds = Math.round((Date.now() - completedAt) / 1000);
  check(
    'Progress credited PRACTICE XP (rewards by completionId)',
    credited && credited.status === 'credited' && credited.awardXp === done.body?.xpAwarded,
    credited,
  );
  check(
    'studyXp increased by the award',
    credited && credited.studyXp === (before.body?.studyXp ?? 0) + (done.body?.xpAwarded ?? -1),
    credited?.studyXp,
  );
  check(
    'streak started by practice',
    credited && credited.currentStreak >= 1,
    credited?.currentStreak,
  );
  const me = await call(progressUrl, 'GET', '/v1/me', { jwt });
  check('getMe 200', me.status === 200, me.status);
  evidence.getMe =
    me.body && typeof me.body === 'object'
      ? Object.fromEntries(
          Object.entries(me.body).filter(([k]) => /xp|streak|plan|entitle|revision/i.test(k)),
        )
      : me.body;
  evidence.rewards = credited;
  const ledger = await rows('p_reward_ledger', [
    Query.equal('userId', userId),
    Query.equal('kind', 'PRACTICE'),
  ]);
  check(
    'one PRACTICE ledger row',
    ledger.length === 1,
    ledger.map((r) => ({
      completionId: r.completionId,
      studyXpDelta: r.studyXpDelta,
      leagueXpDelta: r.leagueXpDelta,
      learningDay: r.learningDay,
      capped: r.capped,
    })),
  );
  const quests = await call(progressUrl, 'GET', '/v1/quests', { jwt });
  evidence.quests = Array.isArray(quests.body?.items)
    ? quests.body.items.map((q) => `${q.questId}:${q.metricValue}/${q.target}`)
    : quests.body;
  const aOut = await rows('a_outbox', [
    Query.equal('aggregateId', userId),
    Query.equal('type', 'ai.practice.completed.v1'),
  ]);
  evidence.aOutbox = aOut.map((r) => ({ status: r.status, attempt: r.attempt, ackAt: r.ackAt }));
  check(
    'a_outbox practice event ACK',
    aOut.length === 1 && aOut[0].status === 'ACK',
    evidence.aOutbox,
  );
  // Scheduled AI worker evidence: recent coc-ai executions triggered by the cron.
  const ex = await fetch(
    `${endpoint}/functions/coc-ai/executions?queries[]=${encodeURIComponent(JSON.stringify({ method: 'equal', attribute: 'trigger', values: ['schedule'] }))}&queries[]=${encodeURIComponent(JSON.stringify({ method: 'orderDesc', attribute: '$createdAt' }))}&queries[]=${encodeURIComponent(JSON.stringify({ method: 'limit', values: [5] }))}`,
    { headers: { 'x-appwrite-project': projectId, 'x-appwrite-key': apiKey } },
  ).then((r) => r.json());
  evidence.aiScheduleExecutions = (ex.executions ?? []).map(
    (e) => `${e.$createdAt} ${e.status} ${e.responseStatusCode}`,
  );
  check(
    'coc-ai cron executing (trigger=schedule, 200)',
    (ex.executions ?? []).some((e) => e.responseStatusCode === 200),
    evidence.aiScheduleExecutions,
  );
} catch (error) {
  check('probe run', false, error.message);
} finally {
  // Sweep: inbox rows of every event about the user, then every row naming the user, then the user.
  const eventIds = new Set();
  for (const tableId of ['p_outbox', 'a_outbox', 'l_outbox']) {
    for (const r of await rows(tableId, [Query.equal('aggregateId', userId)]).catch(() => [])) {
      eventIds.add(r.eventId ?? r.$id);
    }
  }
  const tables = (await db.listTables({ databaseId: DB, queries: [Query.limit(100)] })).tables;
  for (const table of tables) {
    const cols = new Set(table.columns.map((c) => c.key));
    const filters = [];
    for (const c of ['userId', 'fromUserId', 'toUserId', 'blockerId', 'blockedId', 'aggregateId']) {
      if (cols.has(c)) filters.push([Query.equal(c, userId)]);
    }
    if (/_inbox$/.test(table.$id) && cols.has('eventId') && eventIds.size) {
      filters.push([Query.equal('eventId', [...eventIds])]);
    }
    for (const q of filters) {
      for (const r of await rows(table.$id, q).catch(() => [])) {
        await db.deleteRow({ databaseId: DB, tableId: table.$id, rowId: r.$id }).then(
          () => swept++,
          () => undefined,
        );
      }
    }
  }
  await users.delete({ userId }).catch(() => undefined);
}
const failed = checks.filter((c) => !c.pass);
console.log(
  JSON.stringify(
    {
      status: failed.length ? 'FAIL' : 'PASS',
      userId,
      seconds: Math.round((Date.now() - t0) / 1000),
      passed: checks.length - failed.length,
      total: checks.length,
      swept,
      evidence,
      checks,
    },
    null,
    2,
  ),
);
process.exit(failed.length ? 1 : 0);
