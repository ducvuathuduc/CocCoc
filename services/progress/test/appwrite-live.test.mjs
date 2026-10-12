import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { Client, Query, TablesDB } from 'node-appwrite';
import { lessonEvent, setup, validate } from './harness.mjs';
import { kit } from './kit.mjs';

// Gated live run of the Progress TablesDB adapter (P1-FOUND-002 progress half) against the
// admitted Appwrite TEST project. Never in CI. Requires COC_LIVE_APPWRITE_PROGRESS=1,
// APPWRITE_ENDPOINT, APPWRITE_PROJECT_ID and APPWRITE_API_KEY (server key; may be a sentinel the
// egress proxy replaces on the wire with NODE_USE_ENV_PROXY=1). Every synthetic row is deleted.
const enabled = process.env.COC_LIVE_APPWRITE_PROGRESS === '1';
const reason =
  'live Progress adapter gated: set COC_LIVE_APPWRITE_PROGRESS=1 and APPWRITE_* (test project)';
const endpoint = process.env.APPWRITE_ENDPOINT ?? 'https://sgp.cloud.appwrite.io/v1';
const projectId = process.env.APPWRITE_PROJECT_ID ?? '';
const apiKey = process.env.APPWRITE_API_KEY ?? '';
const databaseId = 'cocenglish';
const USER_COLUMNS = ['userId', 'fromUserId', 'toUserId', 'blockerId', 'blockedId'];

async function sweep(db, users, eventIds) {
  let deleted = 0;
  const del = async (tableId, rowId) => {
    await db.deleteRow({ databaseId, tableId, rowId }).then(
      () => deleted++,
      () => undefined,
    );
  };
  for (const [tableId, spec] of Object.entries(kit.PROGRESS_SCHEMA)) {
    for (const column of USER_COLUMNS.filter((c) => spec.columns[c])) {
      for (;;) {
        const page = await db.listRows({
          databaseId,
          tableId,
          queries: [Query.equal(column, users), Query.limit(100)],
        });
        if (!page.rows.length) break;
        for (const row of page.rows) await del(tableId, row.$id);
      }
    }
  }
  for (const eventId of eventIds) await del('p_inbox', eventId);
  for (const user of users) {
    const outbox = await db.listRows({
      databaseId,
      tableId: 'p_outbox',
      queries: [Query.equal('aggregateId', user), Query.limit(100)],
    });
    for (const row of outbox.rows) await del('p_outbox', row.$id);
  }
  return deleted;
}

test(
  'live: Progress over Appwrite TablesDB — init, rewards, dedupe, conflict, social, league, deletion',
  { skip: enabled ? false : reason, timeout: 600000 },
  async (t) => {
    assert.ok(projectId && apiKey, reason);
    const db = new TablesDB(
      new Client().setEndpoint(endpoint).setProject(projectId).setKey(apiKey),
    );
    const store = kit.createAppwriteProgressPersistence({
      endpoint,
      projectId,
      apiKey,
      admitted: false,
    });
    const h = setup({ store, realClock: true });
    const suffix = randomUUID().replace(/-/g, '').slice(0, 10);
    const alice = `cpta${suffix}`;
    const bob = `cptb${suffix}`;
    const eventIds = [];
    const evidence = {};
    const deliver = async (e) => {
      eventIds.push(e.eventId);
      return h.deliver(e);
    };
    try {
      await store.ping();
      const init = await h.call('POST', '/v1/me/initialize', { user: alice });
      assert.equal(init.status, 200, JSON.stringify(init.body));
      validate('Profile', init.body);
      const replay = await h.call('POST', '/v1/me/initialize', { user: alice });
      assert.deepEqual(replay.body.userId, alice);
      await h.call('POST', '/v1/me/initialize', { user: bob });
      for (const [u, rev] of [
        [alice, 0],
        [bob, 0],
      ]) {
        const p = await h.call('PATCH', '/v1/me', {
          user: u,
          body: { publicOptIn: true, expectedRevision: rev },
        });
        assert.equal(p.status, 200, JSON.stringify(p.body));
      }
      const stale = await h.call('PATCH', '/v1/me', {
        user: alice,
        body: { nickname: 'x', expectedRevision: 0 },
      });
      assert.equal(stale.body.error.code, 'REVISION_CONFLICT');
      evidence.init =
        'profile+rewards(20 gems)+INITIAL ledger+prefs+league profile+entitlement+zone history in one tx; replay no second credit; CAS 409';

      const e1 = lessonEvent(
        { occurredAt: new Date().toISOString() },
        { userId: alice, completionId: `c1${suffix}`, originalCorrect: 10 },
      );
      const results = await Promise.all([deliver(e1), deliver(e1)]);
      assert.deepEqual(results.sort(), ['accepted', 'replayed']);
      await assert.rejects(deliver({ ...e1, payload: { ...e1.payload, originalCorrect: 1 } }), {
        code: 'IDEMPOTENCY_CONFLICT',
      });
      await deliver(
        lessonEvent(
          { occurredAt: new Date().toISOString() },
          { userId: alice, completionId: `c2${suffix}`, originalCorrect: 4 },
        ),
      );
      const rw = await h.call('GET', '/v1/me/rewards', {
        user: alice,
        query: `completionId=c1${suffix}`,
      });
      validate('Rewards', rw.body);
      assert.deepEqual(
        [
          rw.body.studyXp,
          rw.body.leagueXp,
          rw.body.gems,
          rw.body.currentStreak,
          rw.body.status,
          rw.body.awardXp,
        ],
        [39, 39, 20, 1, 'credited', 25],
      );
      const ledger = await db.listRows({
        databaseId,
        tableId: 'p_reward_ledger',
        queries: [Query.equal('userId', alice), Query.limit(50)],
      });
      assert.equal(
        ledger.rows.reduce((s, r) => s + r.studyXpDelta, 0),
        39,
      );
      evidence.rewards =
        'concurrent duplicate event -> accepted+replayed (one ledger row); substitution 409; totals == ledger sum';

      // Lost-update race on the same aggregate: two concurrent freeze purchases with 20 gems.
      const buys = await Promise.all([
        h.call('POST', '/v1/me/freezes', { user: alice }),
        h.call('POST', '/v1/me/freezes', { user: alice }),
      ]);
      const codes = buys.map((b) => b.status).sort();
      assert.equal(codes[0], 200, JSON.stringify(buys.map((b) => b.body)));
      assert.ok([409].includes(codes[1]), JSON.stringify(buys.map((b) => b.body)));
      const after = (await h.call('GET', '/v1/me/rewards', { user: alice })).body;
      assert.deepEqual([after.gems, after.freezeSlots], [0, 1]);
      evidence.conflict = `two concurrent freeze buys with 20 gems -> [${buys.map((b) => b.body.error?.code ?? 200).join(', ')}]; gems 0, slots 1 (no double spend)`;

      const follow = await h.call('POST', '/v1/follows', {
        user: alice,
        body: { targetUserId: bob },
      });
      validate('Receipt', follow.body);
      const pub = await h.call('GET', `/v1/profiles/${bob}`, { user: alice });
      validate('PublicProfile', pub.body);
      assert.equal(pub.body.followStatus, 'following');
      const join = await h.call('POST', '/v1/league/join', { user: alice });
      assert.equal(join.status, 200, JSON.stringify(join.body));
      validate('League', join.body);
      evidence.social = 'follow receipt, public projection, league join validated against OpenAPI';

      const del = await h.call('POST', '/v1/me/deletion', {
        user: bob,
        body: { confirmation: 'DELETE' },
      });
      assert.equal(del.status, 202);
      for (const owner of ['learning', 'ai']) {
        await deliver({
          eventId: randomUUID(),
          type: 'account.purged.v1',
          schemaVersion: 1,
          producer: owner,
          aggregateId: bob,
          occurredAt: new Date().toISOString(),
          requestId: 'r',
          payload: { userId: bob, requestId: del.body.requestId, owner },
        });
      }
      const tomb = await store.read('p_deletions', kit.ids.deletion(bob));
      assert.equal(tomb.status, 'COMPLETED');
      assert.equal(await store.read('p_profiles', kit.ids.profile(bob)), null);
      evidence.deletion = 'tombstone+outbox, both owner acks -> purge -> COMPLETED, profile gone';
      t.diagnostic(JSON.stringify(evidence));
    } finally {
      const cohort = (
        await store.read(
          'p_league_members',
          kit.ids.leagueMember(kit.leagueWeek(Date.now()), alice),
        )
      )?.cohortId;
      const deleted = await sweep(db, [alice, bob], eventIds);
      if (cohort) {
        const runId = kit.rowId('p_league_runs', kit.leagueWeek(Date.now()), cohort);
        const run = await store.read('p_league_runs', runId);
        if (run && JSON.parse(run.snapshotJson).members.every((m) => m === alice)) {
          await db
            .deleteRow({ databaseId, tableId: 'p_league_runs', rowId: runId })
            .catch(() => undefined);
        }
      }
      const leftover = await sweep(db, [alice, bob], eventIds);
      t.diagnostic(`cleanup deleted ${deleted} rows; leftover after second sweep ${leftover}`);
      assert.equal(leftover, 0);
    }
  },
);
