// Gated live evidence for the AI service on the Appwrite TEST project. Never in CI.
//   COC_LIVE_APPWRITE_AI=1        in-process: the durable TablesDB adapter under the real router
//                                 (transactions, receipts, inbox, purge) with a synthetic user id.
//   COC_LIVE_AI_HOSTED=1          hosted: coccoc-ai.sgp.appwrite.run with a real synthetic Appwrite
//                                 user + JWT; Progress' scheduled relay delivers entitlement.changed.v1
//                                 and account.deleted.v1 rows staged in p_outbox to AI (ack).
// Both need APPWRITE_PROJECT_ID and APPWRITE_API_KEY (server key; may be the egress-proxy sentinel
// with NODE_USE_ENV_PROXY=1). Every synthetic row and the user are deleted at the end.
import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash, randomBytes, randomUUID } from 'node:crypto';
import { Client, Query, TablesDB } from 'node-appwrite';
import { kit, setup, wav } from './harness.mjs';

const endpoint = process.env.APPWRITE_ENDPOINT ?? 'https://sgp.cloud.appwrite.io/v1';
const projectId = process.env.APPWRITE_PROJECT_ID ?? '';
const apiKey = process.env.APPWRITE_API_KEY ?? '';
const databaseId = 'cocenglish';
const domain = process.env.COC_AI_DOMAIN ?? 'https://coccoc-ai.sgp.appwrite.run';
const A_TABLES = [
  'a_conversations',
  'a_voice_sessions',
  'a_active_slots',
  'a_jobs',
  'a_usage',
  'a_receipts',
];
const inboxId = (eventId) =>
  createHash('sha256').update(`inbox|${eventId}`).digest('hex').slice(0, 32);
const db = () =>
  new TablesDB(new Client().setEndpoint(endpoint).setProject(projectId).setKey(apiKey));

async function sweep(tables, userId, extra = []) {
  let deleted = 0;
  const del = (tableId, rowId) =>
    tables.deleteRow({ databaseId, tableId, rowId }).then(
      () => deleted++,
      () => undefined,
    );
  for (const tableId of A_TABLES) {
    for (;;) {
      const page = await tables.listRows({
        databaseId,
        tableId,
        queries: [Query.equal('userId', userId), Query.limit(100)],
      });
      if (!page.rows.length) break;
      for (const row of page.rows) await del(tableId, row.$id);
    }
  }
  for (const tableId of ['a_outbox', 'p_outbox']) {
    for (;;) {
      const page = await tables.listRows({
        databaseId,
        tableId,
        queries: [Query.equal('aggregateId', userId), Query.limit(100)],
      });
      if (!page.rows.length) break;
      for (const row of page.rows) await del(tableId, row.$id);
    }
  }
  for (const [tableId, rowId] of extra) await del(tableId, rowId);
  return deleted;
}

const tutor = (h, user, scenarioId, learnerText) =>
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

test(
  'live adapter: AI flows over Appwrite TablesDB (gate, turns, complete once, purge)',
  {
    skip: process.env.COC_LIVE_APPWRITE_AI === '1' ? false : 'set COC_LIVE_APPWRITE_AI=1',
    timeout: 600000,
  },
  async (t) => {
    assert.ok(projectId && apiKey);
    const store = kit.createAppwriteAiPersistence({
      endpoint,
      projectId,
      apiKey,
      admittedForHosting: true,
    });
    const h = setup({ store, realClock: true });
    const user = `aiprobe${randomBytes(6).toString('hex')}`;
    const tables = db();
    const extra = [];
    const evidence = {};
    try {
      await store.ping();
      const denied = await h.call('POST', '/v1/conversations', {
        user,
        idem: randomUUID(),
        body: {
          kind: 'ROLEPLAY',
          courseId: 'vi_en',
          scenarioId: 'rp_cafe_order',
          voiceSessionId: null,
        },
      });
      assert.equal(denied.body.error?.code, 'ENTITLEMENT_REQUIRED');
      const grant = await h.grant(user, 'MAX', 1);
      assert.equal(grant.body.status, 'accepted');
      extra.push(['a_inbox', inboxId(grant.envelope.eventId)]);
      assert.equal(
        (
          await h.event('entitlement.changed.v1', grant.envelope.payload, {
            eventId: grant.envelope.eventId,
            occurredAt: grant.envelope.occurredAt,
          })
        ).body.status,
        'replayed',
      );
      const idem = randomUUID();
      const body = {
        kind: 'ROLEPLAY',
        courseId: 'vi_en',
        scenarioId: 'rp_cafe_order',
        voiceSessionId: null,
      };
      // Concurrent duplicate start with one key: one conversation, same response.
      const [s1, s2] = await Promise.all([
        h.call('POST', '/v1/conversations', { user, idem, body }),
        h.call('POST', '/v1/conversations', { user, idem, body }),
      ]);
      assert.equal(s1.status, 200, JSON.stringify(s1.body));
      assert.deepEqual(s1.body, s2.body);
      const id = s1.body.conversationId;
      for (const step of kit.scenarioById('rp_cafe_order').steps) {
        const turn = await tutor(h, user, 'rp_cafe_order', step.expect);
        assert.equal(turn.status, 200, JSON.stringify(turn.body));
      }
      const doneIdem = randomUUID();
      const [c1, c2] = await Promise.all([
        h.call('POST', `/v1/conversations/${id}/complete`, {
          user,
          idem: doneIdem,
          body: { endReason: 'COMPLETED' },
        }),
        h.call('POST', `/v1/conversations/${id}/complete`, {
          user,
          idem: doneIdem,
          body: { endReason: 'COMPLETED' },
        }),
      ]);
      assert.equal(c1.status, 200, JSON.stringify(c1.body));
      assert.deepEqual(c1.body, c2.body);
      assert.equal(c1.body.status, 'COMPLETED');
      const outbox = await tables.listRows({
        databaseId,
        tableId: 'a_outbox',
        queries: [Query.equal('aggregateId', user)],
      });
      assert.equal(outbox.total, 1);
      evidence.complete = {
        stars: c1.body.stars,
        xp: c1.body.xpAwarded,
        wordsUsed: c1.body.wordsUsed,
        outbox: outbox.rows[0].type,
      };
      const listed = await h.call('GET', '/v1/conversations', { user });
      assert.equal(listed.body.items.length, 1);
      const del = await h.event('account.deleted.v1', { userId: user, requestId: randomUUID() });
      assert.equal(del.status, 200, JSON.stringify(del.body));
      extra.push(['a_inbox', inboxId(del.envelope.eventId)]);
      for (const tableId of A_TABLES) {
        const left = await tables.listRows({
          databaseId,
          tableId,
          queries: [Query.equal('userId', user)],
        });
        assert.equal(left.total, 0, `${tableId} purged`);
      }
      const acks = await tables.listRows({
        databaseId,
        tableId: 'a_outbox',
        queries: [Query.equal('aggregateId', user)],
      });
      evidence.purge = acks.rows.map((r) => r.type);
      assert.deepEqual(evidence.purge, ['account.purged.v1']);
      t.diagnostic(JSON.stringify(evidence));
    } finally {
      t.diagnostic(`cleanup deleted ${await sweep(tables, user, extra)} rows`);
    }
  },
);

async function rest(method, route, body) {
  const response = await fetch(`${endpoint}${route}`, {
    method,
    headers: {
      'X-Appwrite-Project': projectId,
      'X-Appwrite-Key': apiKey,
      'Content-Type': 'application/json',
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  if (!response.ok && response.status !== 404)
    throw new Error(`${method} ${route} ${response.status} ${text.slice(0, 200)}`);
  return text ? JSON.parse(text) : {};
}

test(
  'live hosted: coccoc-ai with a synthetic user; Progress relay delivers to AI (ack)',
  {
    skip: process.env.COC_LIVE_AI_HOSTED === '1' ? false : 'set COC_LIVE_AI_HOSTED=1',
    timeout: 900000,
  },
  async (t) => {
    assert.ok(projectId && apiKey);
    const tables = db();
    const user = `aiprobe${randomBytes(6).toString('hex')}`;
    const password = `Pr0be-${randomBytes(12).toString('hex')}`;
    const extra = [];
    const evidence = {};
    await rest('POST', '/users', { userId: user, email: `${user}@cocenglish-ops.dev`, password });
    try {
      const session = await rest('POST', `/users/${user}/sessions`, {});
      const { jwt } = await rest('POST', `/users/${user}/jwts`, {
        sessionId: session.$id,
        duration: 900,
      });
      const call = async (method, path, body, idem) => {
        const headers = { Authorization: `Bearer ${jwt}`, 'Content-Type': 'application/json' };
        if (idem) headers['Idempotency-Key'] = idem;
        const response = await fetch(`${domain}${path}`, {
          method,
          headers,
          body: body === undefined ? undefined : JSON.stringify(body),
        });
        return { status: response.status, body: await response.json() };
      };
      const stage = async (type, payload) => {
        const eventId = randomUUID();
        const now = new Date().toISOString();
        await tables.createRow({
          databaseId,
          tableId: 'p_outbox',
          rowId: eventId,
          data: {
            eventId,
            type,
            schemaVersion: 1,
            aggregateId: user,
            occurredAt: now,
            payloadJson: JSON.stringify(payload),
            attempt: 0,
            nextAttemptAt: now,
            leaseOwner: null,
            leaseUntil: null,
            status: 'PENDING',
            ackAt: null,
            revision: 0,
            createdAt: now,
            updatedAt: now,
          },
        });
        extra.push(['a_inbox', inboxId(eventId)]);
        return eventId;
      };
      const waitInbox = async (eventId, label) => {
        const started = Date.now();
        while (Date.now() - started < 240000) {
          const row = await tables
            .getRow({ databaseId, tableId: 'a_inbox', rowId: inboxId(eventId) })
            .catch(() => null);
          if (row) {
            const p = await tables
              .getRow({ databaseId, tableId: 'p_outbox', rowId: eventId })
              .catch(() => null);
            evidence[label] = {
              deliveredAfterSeconds: Math.round((Date.now() - started) / 1000),
              pOutbox: p ? { status: p.status, attempt: p.attempt } : 'gone',
            };
            return row;
          }
          await new Promise((r) => setTimeout(r, 5000));
        }
        throw new Error(`${label}: Progress relay did not deliver ${eventId} to AI within 240 s`);
      };

      const caps = await call('GET', '/v1/ai/capabilities');
      assert.equal(caps.status, 200, JSON.stringify(caps.body));
      evidence.capabilities = {
        configVersion: caps.body.configVersion,
        turnSpeech: caps.body.turnSpeech,
        pronunciation: caps.body.pronunciation,
      };
      const startBody = {
        kind: 'ROLEPLAY',
        courseId: 'vi_en',
        scenarioId: 'rp_ask_directions',
        voiceSessionId: null,
      };
      const denied = await call('POST', '/v1/conversations', startBody, randomUUID());
      assert.equal(denied.body.error?.code, 'ENTITLEMENT_REQUIRED', JSON.stringify(denied.body));

      const grantId = await stage('entitlement.changed.v1', {
        userId: user,
        plan: 'MAX',
        status: 'ACTIVE',
        expiresAt: null,
        entitlementRevision: 1,
      });
      await waitInbox(grantId, 'entitlementRelay');

      const conv = await call('POST', '/v1/conversations', startBody, randomUUID());
      assert.equal(conv.status, 200, JSON.stringify(conv.body));
      const lines = [];
      for (const step of kit.scenarioById('rp_ask_directions').steps) {
        const r = await call('POST', '/v1/tutor', {
          requestId: randomUUID(),
          scenarioId: 'rp_ask_directions',
          learnerText: step.expect,
          level: 'A1',
          locale: 'en-US',
          feedbackLocale: 'vi-VN',
        });
        assert.equal(r.status, 200, JSON.stringify(r.body));
        lines.push(r.body.tutorText);
      }
      const done = await call(
        'POST',
        `/v1/conversations/${conv.body.conversationId}/complete`,
        { endReason: 'COMPLETED' },
        randomUUID(),
      );
      assert.equal(done.body.status, 'COMPLETED', JSON.stringify(done.body));
      const practice = await tables.listRows({
        databaseId,
        tableId: 'a_outbox',
        queries: [
          Query.equal('aggregateId', user),
          Query.equal('type', 'ai.practice.completed.v1'),
        ],
      });
      assert.equal(practice.total, 1);
      evidence.roleplay = {
        stars: done.body.stars,
        xp: done.body.xpAwarded,
        lastLine: lines.at(-1),
        outbox: { status: practice.rows[0].status, attempt: practice.rows[0].attempt },
      };

      // Scripted TURN speech + Video Call (real speech mode is covered by speech-live.test.mjs:
      // a silent clip is correctly not recognized there, so the script would not advance).
      const audio = wav(1);
      if (caps.body.pronunciation) {
        evidence.videoCall = 'speech provider active: see speech-live.test.mjs';
      } else {
        const sessionId = randomUUID();
        const lease = await call(
          'POST',
          '/v1/voice-sessions',
          { sessionId, scenarioId: 'rp_phone_pizza', mode: 'TURN', level: 'A1' },
          randomUUID(),
        );
        assert.equal(lease.status, 200, JSON.stringify(lease.body));
        const call2 = await call(
          'POST',
          '/v1/conversations',
          {
            kind: 'VIDEO_CALL',
            courseId: 'vi_en',
            scenarioId: 'rp_phone_pizza',
            voiceSessionId: sessionId,
          },
          randomUUID(),
        );
        assert.equal(call2.status, 200, JSON.stringify(call2.body));
        const transcripts = [];
        for (let i = 0; i < 4; i++) {
          const turn = await call(
            'POST',
            `/v1/voice-sessions/${sessionId}/turns`,
            { turnId: randomUUID(), epoch: 0, ...audio },
            randomUUID(),
          );
          assert.equal(turn.status, 200, JSON.stringify(turn.body));
          transcripts.push(turn.body.transcript);
        }
        const done2 = await call(
          'POST',
          `/v1/conversations/${call2.body.conversationId}/complete`,
          { endReason: 'COMPLETED' },
          randomUUID(),
        );
        assert.equal(done2.body.status, 'COMPLETED', JSON.stringify(done2.body));
        evidence.videoCall = { firstTranscript: transcripts[0], stars: done2.body.stars };
      }
      const jobId = randomUUID();
      const job = await call(
        'POST',
        '/v1/assessment-jobs',
        { jobId, referenceExerciseId: 'ex_live', lessonVersion: 'v2', locale: 'en-US', ...audio },
        randomUUID(),
      );
      assert.equal(job.status, 202, JSON.stringify(job.body));
      const read = await call('GET', `/v1/assessment-jobs/${jobId}`);
      evidence.assessment = {
        scoreState: read.body.scoreState,
        accuracy: read.body.accuracy,
        reason: read.body.unavailableReason,
      };
      const list = await call('GET', '/v1/conversations');
      evidence.history = list.body.items.map((c) => `${c.kind}:${c.status}:${c.stars}`);

      // account.deleted.v1 through the Progress relay: AI purges and acknowledges.
      const delId = await stage('account.deleted.v1', { userId: user, requestId: randomUUID() });
      await waitInbox(delId, 'deletionRelay');
      for (const tableId of A_TABLES) {
        const left = await tables.listRows({
          databaseId,
          tableId,
          queries: [Query.equal('userId', user)],
        });
        assert.equal(left.total, 0, `${tableId} purged`);
      }
      const acks = await tables.listRows({
        databaseId,
        tableId: 'a_outbox',
        queries: [Query.equal('aggregateId', user)],
      });
      evidence.purgeAck = acks.rows.map((r) => ({
        type: r.type,
        status: r.status,
        attempt: r.attempt,
      }));
      for (const r of acks.rows) {
        const pin = await tables
          .getRow({ databaseId, tableId: 'p_inbox', rowId: r.eventId })
          .catch(() => null);
        if (pin) extra.push(['p_inbox', r.eventId]);
      }
      t.diagnostic(JSON.stringify(evidence));
    } finally {
      await rest('DELETE', `/users/${user}`).catch(() => undefined);
      t.diagnostic(`cleanup deleted ${await sweep(tables, user, extra)} rows`);
    }
  },
);
