// Live probes against an explicitly admitted Appwrite TEST project (P1-FOUND-002 / P1-OPS-001 cloud half).
// Never run by CI. Requires: APPWRITE_PROJECT_ENV=test, ALLOW_LIVE_PROBE=reviewed-test-project,
// APPWRITE_ENDPOINT (https), APPWRITE_PROJECT_ID, APPWRITE_API_KEY (server key; never printed).
// Creates two throwaway users (synthetic emails), signs one in with email/password through the Account API,
// mints a short-lived JWT, runs the gated Account.get test, then transaction/conflict and permission probes.
// Every synthetic row and both users are deleted in finally. Output: JSON evidence without secrets or JWTs.
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
import { Account, Client, ID, Permission, Query, Role, Storage, TablesDB, Users } from 'node-appwrite';

// Client-side (JWT/session) calls must reach Appwrite directly, never through an egress proxy that may attach the
// server key: otherwise a "client" probe would silently run with server privileges. Resolve the undici that
// node-appwrite bundles and give user clients a plain verifying Agent (TLS verification stays on).
const undici = createRequire(createRequire(import.meta.url).resolve('node-appwrite'))('undici');
const direct = new undici.Agent();
const userClient = (jwt) => {
  const client = new Client().setEndpoint(endpoint).setProject(project).setJWT(jwt);
  client.config.selfSigned = true; // routes through client.selfSignedAgent; we supply a verifying agent below
  client.selfSignedAgent = direct;
  return client;
};

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
if (process.env.APPWRITE_PROJECT_ENV !== 'test' || process.env.ALLOW_LIVE_PROBE !== 'reviewed-test-project') throw new Error('Live probes only run against an explicitly admitted test project.');
const { APPWRITE_ENDPOINT: endpoint, APPWRITE_PROJECT_ID: project, APPWRITE_API_KEY: key } = process.env;
if (!endpoint?.startsWith('https://') || !project || !key) throw new Error('Missing private Appwrite test configuration.');

const databaseId = 'cocenglish';
const admin = new Client().setEndpoint(endpoint).setProject(project).setKey(key);
const users = new Users(admin);
const db = new TablesDB(admin);
const results = [];
const record = (name, pass, detail) => {
  results.push({ name, pass, detail });
  console.error(JSON.stringify({ probe: name, pass, detail }));
};
const probe = async (name, fn) => {
  try {
    const detail = await fn();
    record(name, true, detail);
  } catch (error) {
    record(name, false, `${error.code ?? ''} ${error.type ?? ''} ${error.message}`.trim());
  }
};
const expectError = async (promise, codes) => {
  try {
    await promise;
  } catch (error) {
    if (codes.includes(error.code)) return `${error.code} ${error.type}`;
    throw error;
  }
  throw new Error(`expected error ${codes.join('/')}, operation succeeded`);
};
const now = () => new Date().toISOString();
const synthetic = () => `probe${crypto.randomBytes(8).toString('hex')}`;

// Account API email/password session with only the project header, then JWT from that session cookie.
async function jwtFor(email, password) {
  const headers = { 'content-type': 'application/json', 'x-appwrite-project': project };
  const session = await undici.fetch(`${endpoint}/account/sessions/email`, { method: 'POST', headers, body: JSON.stringify({ email, password }), dispatcher: direct });
  if (session.status !== 201) throw new Error(`session ${session.status} ${(await session.text()).slice(0, 200)}`);
  const cookies = session.headers.getSetCookie().map((c) => c.split(';')[0]).filter((c) => c.startsWith('a_session_'));
  if (!cookies.length) throw new Error('no session cookie returned');
  const jwt = await undici.fetch(`${endpoint}/account/jwts`, { method: 'POST', headers: { ...headers, cookie: cookies.join('; ') }, dispatcher: direct });
  if (jwt.status !== 201) throw new Error(`jwt ${jwt.status} ${(await jwt.text()).slice(0, 200)}`);
  const token = (await jwt.json()).jwt;
  const me = await new Account(userClient(token)).get();
  if (me.$id !== email.split('@')[0]) throw new Error('JWT does not map to the signed-in user');
  return token;
}

const created = { users: [], rows: [] };
const tracked = async (tableId, rowId, data, permissions, transactionId) => {
  created.rows.push({ tableId, rowId });
  return db.createRow({ databaseId, tableId, rowId, data, ...(permissions ? { permissions } : {}), ...(transactionId ? { transactionId } : {}) });
};
const blockRow = () => ({ blockerId: synthetic().slice(0, 36), blockedId: synthetic().slice(0, 36), revision: 0, createdAt: now(), updatedAt: now() });

try {
  const password = crypto.randomBytes(18).toString('base64url');
  const [alice, bob] = [synthetic(), synthetic()];
  for (const id of [alice, bob]) {
    await users.create({ userId: id, email: `${id}@example.com`, password, name: 'coc probe (synthetic)' });
    created.users.push(id);
  }
  const aliceJwt = await jwtFor(`${alice}@example.com`, password);
  const bobJwt = await jwtFor(`${bob}@example.com`, password);
  const asUser = (jwt) => new TablesDB(userClient(jwt));

  await probe('auth.account-get-live-test', async () => {
    const run = spawnSync(process.execPath, ['--test', 'services/shared/test/appwrite-live.test.mjs'], {
      cwd: root,
      encoding: 'utf8',
      // Direct connection (no egress proxy, no server key) so Account.get runs purely on the user JWT.
      env: { ...Object.fromEntries(Object.entries(process.env).filter(([k]) => k !== 'NODE_USE_ENV_PROXY' && !k.startsWith('APPWRITE_'))), COC_LIVE_APPWRITE_PROBE: '1', COC_PROBE_ENDPOINT: endpoint, COC_PROBE_PROJECT: project, COC_PROBE_JWT: aliceJwt },
    });
    const summary = (run.stdout.match(/^# (pass|fail|skipped) \d+$/gm) ?? []).join(', ');
    if (run.status !== 0 || !/# pass 1/.test(run.stdout) || /# skipped [1-9]/.test(run.stdout)) throw new Error(`node --test exit ${run.status}: ${summary} ${run.stderr.slice(0, 300)}`);
    return `node --test appwrite-live.test.mjs: ${summary} (valid JWT -> Account.get subject; tampered JWT rejected)`;
  });

  // --- Transactions (TablesDB) ---
  await probe('tx.staged-invisible-then-commit', async () => {
    const tx = await db.createTransaction({ ttl: 60 });
    const rowId = ID.unique();
    await tracked('p_blocks', rowId, blockRow(), undefined, tx.$id);
    await expectError(db.getRow({ databaseId, tableId: 'p_blocks', rowId }), [404]);
    await db.updateTransaction({ transactionId: tx.$id, commit: true });
    const row = await db.getRow({ databaseId, tableId: 'p_blocks', rowId });
    return `staged row hidden before commit (404), visible after commit (revision ${row.revision})`;
  });
  await probe('tx.rollback-discards', async () => {
    const tx = await db.createTransaction({ ttl: 60 });
    const rowId = ID.unique();
    await tracked('p_blocks', rowId, blockRow(), undefined, tx.$id);
    await db.updateTransaction({ transactionId: tx.$id, rollback: true });
    return `after rollback: ${await expectError(db.getRow({ databaseId, tableId: 'p_blocks', rowId }), [404])}`;
  });
  await probe('tx.partial-commit-prevented-on-unique-violation', async () => {
    const existing = blockRow();
    await tracked('p_blocks', ID.unique(), existing);
    const tx = await db.createTransaction({ ttl: 60 });
    const okId = ID.unique();
    const dupId = ID.unique();
    await tracked('p_blocks', okId, blockRow(), undefined, tx.$id);
    let stagedOrCommitError;
    try {
      await tracked('p_blocks', dupId, { ...blockRow(), blockerId: existing.blockerId, blockedId: existing.blockedId }, undefined, tx.$id);
      stagedOrCommitError = await expectError(db.updateTransaction({ transactionId: tx.$id, commit: true }), [409]);
    } catch (error) {
      if (error.code !== 409) throw error;
      stagedOrCommitError = `409 at staging`;
      await db.updateTransaction({ transactionId: tx.$id, rollback: true }).catch(() => {});
    }
    const ok = await expectError(db.getRow({ databaseId, tableId: 'p_blocks', rowId: okId }), [404]);
    return `duplicate unique(blockerId,blockedId) -> ${stagedOrCommitError}; sibling staged row not committed (${ok})`;
  });
  await probe('tx.concurrent-update-conflict', async () => {
    const rowId = ID.unique();
    await tracked('p_blocks', rowId, blockRow());
    const t1 = await db.createTransaction({ ttl: 60 });
    const t2 = await db.createTransaction({ ttl: 60 });
    await db.updateRow({ databaseId, tableId: 'p_blocks', rowId, data: { revision: 1, updatedAt: now() }, transactionId: t1.$id });
    await db.updateRow({ databaseId, tableId: 'p_blocks', rowId, data: { revision: 1, updatedAt: now() }, transactionId: t2.$id });
    await db.updateTransaction({ transactionId: t1.$id, commit: true });
    let second;
    try {
      await db.updateTransaction({ transactionId: t2.$id, commit: true });
      second = 'committed';
    } catch (error) {
      second = `${error.code} ${error.type}`;
    }
    const row = await db.getRow({ databaseId, tableId: 'p_blocks', rowId });
    if (second === 'committed') throw new Error(`second transaction on same row committed without conflict (final revision ${row.revision}); services must keep revision CAS`);
    return `first commit ok; second commit on same row rejected: ${second}; final revision ${row.revision}`;
  });
  await probe('tx.out-of-band-write-conflict', async () => {
    const rowId = ID.unique();
    await tracked('p_blocks', rowId, blockRow());
    const tx = await db.createTransaction({ ttl: 60 });
    await db.updateRow({ databaseId, tableId: 'p_blocks', rowId, data: { revision: 1, updatedAt: now() }, transactionId: tx.$id });
    await db.updateRow({ databaseId, tableId: 'p_blocks', rowId, data: { revision: 5, updatedAt: now() } });
    let outcome;
    try {
      await db.updateTransaction({ transactionId: tx.$id, commit: true });
      outcome = 'committed';
    } catch (error) {
      outcome = `${error.code} ${error.type}`;
    }
    const row = await db.getRow({ databaseId, tableId: 'p_blocks', rowId });
    if (outcome === 'committed') throw new Error(`tx committed over out-of-band write (final revision ${row.revision})`);
    return `out-of-band write after staging -> commit rejected: ${outcome}; final revision ${row.revision}`;
  });

  // --- Permissions (client JWT, no API key) ---
  await probe('perm.client-cannot-create-valid-rows', async () => {
    // Fully valid rows, so a rejection is the permission model (no table grants), not schema validation.
    const rows = {
      p_blocks: { ...blockRow(), blockerId: alice },
      p_notifications: { userId: alice, completionId: synthetic().slice(0, 36), status: 'PENDING', profileRevision: 0, rewardRevision: 0, revision: 0, createdAt: now(), updatedAt: now() },
      p_zone_history: { userId: alice, zone: 'Asia/Ho_Chi_Minh', effectiveAt: now() },
    };
    const out = [];
    for (const [tableId, data] of Object.entries(rows)) {
      const rowId = ID.unique();
      created.rows.push({ tableId, rowId });
      out.push(`${tableId}:${await expectError(asUser(aliceJwt).createRow({ databaseId, tableId, rowId, data }), [401, 403])}`);
    }
    return out.join(', ');
  });
  await probe('perm.client-list-without-grant-sees-nothing', async () => {
    await tracked('p_blocks', ID.unique(), { ...blockRow(), blockerId: alice });
    try {
      const list = await asUser(aliceJwt).listRows({ databaseId, tableId: 'p_blocks', queries: [Query.limit(5)] });
      if (list.rows.length) throw new Error(`client saw ${list.rows.length} p_blocks rows`);
      return 'listRows on p_blocks (own blockerId row exists, no row grant) -> 0 rows';
    } catch (error) {
      if ([401, 403].includes(error.code)) return `listRows on p_blocks -> ${error.code} ${error.type}`;
      throw error;
    }
  });
  await probe('perm.p_notifications-owner-read-only', async () => {
    const rowId = ID.unique();
    await tracked('p_notifications', rowId, { userId: alice, completionId: synthetic().slice(0, 36), status: 'PENDING', profileRevision: 0, rewardRevision: 0, revision: 0, createdAt: now(), updatedAt: now() }, [Permission.read(Role.user(alice))]);
    const own = await asUser(aliceJwt).getRow({ databaseId, tableId: 'p_notifications', rowId });
    const other = await expectError(asUser(bobJwt).getRow({ databaseId, tableId: 'p_notifications', rowId }), [404, 401, 403]);
    const update = await expectError(asUser(aliceJwt).updateRow({ databaseId, tableId: 'p_notifications', rowId, data: { status: 'CREDITED' } }), [401, 403, 404]);
    const del = await expectError(asUser(aliceJwt).deleteRow({ databaseId, tableId: 'p_notifications', rowId }), [401, 403, 404]);
    return `owner read ok (${own.status}); other user ${other}; owner update ${update}; owner delete ${del}`;
  });
  await probe('perm.bucket-client-upload-denied', async () => {
    const storage = new Storage(userClient(aliceJwt));
    const { InputFile } = await import('node-appwrite/file');
    return `createFile learning-assets -> ${await expectError(storage.createFile({ bucketId: 'learning-assets', fileId: ID.unique(), file: InputFile.fromBuffer(Buffer.from('probe'), 'probe.txt') }), [401, 403])}`;
  });
  await probe('perm.revoked-session-jwt-rejected', async () => {
    await users.deleteSessions({ userId: bob });
    return `Account.get with JWT of deleted session -> ${await expectError(new Account(userClient(bobJwt)).get(), [401])}`;
  });

  // --- Functions runtime availability ---
  await probe('functions.node22-runtime', async () => {
    // /functions/runtimes needs the "public" scope (guest), which server keys do not carry: query it directly.
    const res = await undici.fetch(`${endpoint}/functions/runtimes`, { headers: { 'x-appwrite-project': project }, dispatcher: direct });
    const body = await res.json();
    if (res.status !== 200) throw new Error(`runtimes ${res.status} ${body.type}: ${body.message}`);
    const node = body.runtimes.filter((r) => r.$id.startsWith('node-')).map((r) => r.$id);
    if (!node.includes('node-22')) throw new Error(`node-22 not offered; node runtimes: ${node.join(',')}`);
    const response = await fetch(`${endpoint}/functions`, { headers: { 'x-appwrite-project': project, 'x-appwrite-key': key } });
    const fns = await response.json();
    if (!response.ok || !Number.isSafeInteger(fns.total)) throw new Error(`functions list rejected or malformed (${response.status})`);
    return `node-22 offered (node runtimes: ${node.join(',')}); functions deployed in project: ${fns.total}`;
  });
} finally {
  const cleanup = [];
  for (const { tableId, rowId } of created.rows) {
    try {
      await db.deleteRow({ databaseId, tableId, rowId });
      cleanup.push('row');
    } catch (error) {
      if (error.code !== 404) cleanup.push(`row ${tableId} ${error.code}`);
    }
  }
  for (const userId of created.users) {
    try {
      await users.delete({ userId });
      cleanup.push('user');
    } catch (error) {
      cleanup.push(`user ${error.code}`);
    }
  }
  const leftover = await db.listRows({ databaseId, tableId: 'p_blocks', queries: [Query.limit(1)] }).then((r) => r.total).catch((e) => `err ${e.code}`);
  console.log(JSON.stringify({ project, at: now(), results, cleanup: { deletedRows: cleanup.filter((c) => c === 'row').length, deletedUsers: cleanup.filter((c) => c === 'user').length, errors: cleanup.filter((c) => !['row', 'user'].includes(c)), p_blocksRowsRemaining: leftover } }, null, 2));
  process.exitCode = results.every((r) => r.pass) ? 0 : 1;
}
