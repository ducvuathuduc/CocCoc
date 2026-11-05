// Bootstrap ONLY the new loopback project. Never reads the caller's Appwrite/cloud environment.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { randomBytes, createHash } from 'node:crypto';
import { disposableRuntimeEnv } from './runtime-test-env.mjs';
import { Client, Storage } from 'node-appwrite';
import { assertLocalKeys, validLocalReceipt, ensureLocalKey } from './local-appwrite-lib.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const dir = path.join(root, '.secrets/local-dev');
const endpoint = 'https://127.0.0.1:8443/v1';
const project = 'cocenglish-local';
const adminScopes = [
  'project.read',
  'platforms.read',
  'platforms.write',
  'users.read',
  'users.write',
  'functions.read',
  'databases.read',
  'databases.write',
  'tables.read',
  'tables.write',
  'columns.read',
  'columns.write',
  'indexes.read',
  'indexes.write',
  'rows.read',
  'rows.write',
  'buckets.read',
  'buckets.write',
  'files.read',
  'files.write',
];

async function main() {
  const action = process.argv[2] ?? 'bootstrap';
  if (!['bootstrap', 'schema', 'probe', 'publish', 'admit'].includes(action))
    throw new Error('Unknown local Appwrite action');
  const ca = path.join(dir, 'tls/ca.crt');
  // Node reads additional trust roots only at process startup. Relaunch with an isolated env.
  if (process.env.COC_LOCAL_TLS_PROCESS !== '1') {
    if (!fs.existsSync(ca)) throw new Error('Local TLS missing; run local TLS setup first');
    const child = spawnSync(process.execPath, [fileURLToPath(import.meta.url), action], {
      cwd: root,
      stdio: 'inherit',
      timeout: 900_000,
      env: disposableRuntimeEnv({ NODE_EXTRA_CA_CERTS: ca, COC_LOCAL_TLS_PROCESS: '1' }),
    });
    if (child.error) throw new Error('Local Appwrite child process failed');
    process.exitCode = child.status ?? 1;
    return;
  }
  let cookie = '';
  const request = async (method, route, body, headers = {}, allowed = []) => {
    if (!route.startsWith('/') || route.startsWith('//') || route.includes('://'))
      throw new Error('Unsafe local route');
    const response = await fetch(endpoint + route, {
      method,
      redirect: 'error',
      signal: AbortSignal.timeout(30_000),
      headers: {
        'content-type': 'application/json',
        'x-appwrite-project': 'console',
        ...(cookie ? { cookie } : {}),
        ...headers,
      },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    const data = await response.json().catch(() => ({ type: 'non_json_upstream_response' }));
    if (!response.ok && !allowed.includes(response.status)) {
      throw new Error(
        `Local Appwrite ${method} ${route}: ${response.status} ${typeof data.type === 'string' ? data.type : 'error'}`,
      );
    }
    return { response, data };
  };
  const stateFile = path.join(dir, 'bootstrap.json');
  const fingerprint = createHash('sha256')
    .update(
      [
        'appwrite/schema/foundation.json',
        'appwrite/scripts/live-probe.mjs',
        'tools/scripts/local-appwrite-lib.mjs',
      ]
        .map((file) => fs.readFileSync(path.join(root, file)))
        .join('\n'),
    )
    .digest('hex');
  let state = fs.existsSync(stateFile) ? JSON.parse(fs.readFileSync(stateFile, 'utf8')) : undefined;
  if (state && (state.endpoint !== endpoint || state.project !== project))
    throw new Error('LOCAL_PROJECT_MISMATCH');
  if (action === 'bootstrap') {
    const credentials = JSON.parse(fs.readFileSync(path.join(dir, 'console.json'), 'utf8'));
    await request(
      'POST',
      '/account',
      { userId: 'coc-local-admin', ...credentials, name: 'CocEnglish Local' },
      {},
      [409, 403, 501],
    );
    const session = await request('POST', '/account/sessions/email', credentials);
    cookie = session.response.headers
      .getSetCookie()
      .map((value) => value.split(';')[0])
      .filter((value) => value.startsWith('a_session_'))
      .join('; ');
    if (!cookie) throw new Error('Console session cookie missing');
    const team = await request('GET', '/teams/cocenglish-local', undefined, {}, [404]);
    if (team.response.status === 404)
      await request('POST', '/teams', { teamId: 'cocenglish-local', name: 'CocEnglish Local' });
    const orgHeaders = { 'x-appwrite-organization': 'cocenglish-local' };
    const existingProject = await request(
      'GET',
      `/organization/projects/${project}`,
      undefined,
      orgHeaders,
      [404],
    );
    if (existingProject.response.status === 404)
      await request(
        'POST',
        '/organization/projects',
        { projectId: project, name: 'CocEnglish Local' },
        orgHeaders,
      );
    state ??= { endpoint, project, keys: {} };
    const save = () => {
      const temporary = `${stateFile}.${process.pid}.tmp`;
      fs.writeFileSync(temporary, JSON.stringify(state, null, 2) + '\n', { mode: 0o600 });
      fs.renameSync(temporary, stateFile);
    };
    save();
    for (const owner of ['setup', 'learning', 'progress', 'ai']) {
      const scopes =
        owner === 'setup'
          ? adminScopes
          : [
              'rows.read',
              'rows.write',
              ...(owner === 'learning' || owner === 'ai' ? ['files.read'] : []),
            ];
      state.keys[owner] = await ensureLocalKey({
        request,
        project,
        owner,
        scopes,
        headers: orgHeaders,
      });
      save();
    }
    const platformHeaders = { 'x-appwrite-project': project, 'x-appwrite-key': state.keys.setup };
    const platforms = [
      ['android', 'local-android', { applicationId: 'com.cocenglish.cocenglish' }],
      ...['127.0.0.1', 'localhost', '10.0.2.2'].map((hostname, i) => [
        'web',
        `local-web-${i}`,
        { hostname },
      ]),
    ];
    for (const [kind, platformId, attributes] of platforms) {
      const existing = await request(
        'GET',
        `/project/platforms/${platformId}`,
        undefined,
        platformHeaders,
        [404],
      );
      if (existing.response.status === 404)
        await request(
          'POST',
          `/project/platforms/${kind}`,
          { platformId, name: `CocEnglish ${platformId}`, ...attributes },
          platformHeaders,
        );
    }
    console.log('Local Appwrite project and four scoped server keys ready (credentials withheld).');
    return;
  }
  if (!state?.keys?.setup) throw new Error('Run local Appwrite bootstrap first');
  const env = disposableRuntimeEnv({
    NODE_EXTRA_CA_CERTS: ca,
    APPWRITE_ENDPOINT: endpoint,
    APPWRITE_PROJECT_ID: project,
    APPWRITE_API_KEY: state.keys.setup,
    APPWRITE_PROJECT_ENV: 'test',
    ALLOW_SCHEMA_APPLY: 'reviewed-test-project',
    ALLOW_LIVE_PROBE: 'reviewed-test-project',
    COC_DATABASE_ID: 'cocenglish',
  });
  if (action === 'admit') {
    assertLocalKeys(state.keys);
    const receiptFile = path.join(dir, 'probe-receipt.json');
    const receipt = fs.existsSync(receiptFile)
      ? JSON.parse(fs.readFileSync(receiptFile))
      : undefined;
    if (!validLocalReceipt(receipt, { endpoint, project, fingerprint })) {
      throw new Error(
        'Fresh successful local permission/transaction probe required before admission',
      );
    }
    state.serviceKeys ??= ['learning', 'progress', 'ai', 'maintainer', 'scheduler'].map(
      (sender) => ({
        keyId: `local-${sender}`,
        sender,
        secretHex: randomBytes(32).toString('hex'),
      }),
    );
    fs.writeFileSync(stateFile, JSON.stringify(state, null, 2) + '\n', { mode: 0o600 });
    const ops = JSON.parse(fs.readFileSync(path.join(root, 'appwrite/ops/project.json')));
    const contentKeys = ops.functions['coc-learning'].variables.COC_CONTENT_PUBLIC_KEYS;
    for (const owner of ['learning', 'progress', 'ai']) {
      const file = path.join(dir, `${owner}.env`);
      const prefix = `COC_${owner.toUpperCase()}`;
      let text = fs
        .readFileSync(file, 'utf8')
        .replace(`${prefix}_PERSISTENCE=disabled`, `${prefix}_PERSISTENCE=appwrite`);
      text = text
        .split('\n')
        .filter(
          (line) =>
            !line.startsWith(`${prefix}_APPWRITE_KEY=`) &&
            !line.startsWith(`${prefix}_ADMITTED=`) &&
            !line.startsWith('COC_SERVICE_KEYS=') &&
            !line.startsWith('COC_PROGRESS_CODE_SECRET=') &&
            !line.startsWith('COC_CONTENT_PUBLIC_KEYS='),
        )
        .join('\n')
        .trimEnd();
      text += `\n${prefix}_APPWRITE_KEY=${state.keys[owner]}\n${prefix}_ADMITTED=reviewed-cloud-gate\nCOC_SERVICE_KEYS='${JSON.stringify(state.serviceKeys)}'\n`;
      if (owner === 'progress') {
        state.codeSecret ??= randomBytes(32).toString('hex');
        text += `COC_PROGRESS_CODE_SECRET=${state.codeSecret}\n`;
      }
      if (owner === 'learning') text += `COC_CONTENT_PUBLIC_KEYS='${contentKeys}'\n`;
      fs.writeFileSync(file, text, { mode: 0o600 });
    }
    fs.writeFileSync(stateFile, JSON.stringify(state, null, 2) + '\n', { mode: 0o600 });
    console.log(
      'Local durable adapters admitted after permission/transaction probes; restart API/worker containers.',
    );
    return;
  }
  const args =
    action === 'schema'
      ? ['appwrite/scripts/schema.mjs', '--apply']
      : action === 'probe'
        ? ['appwrite/scripts/live-probe.mjs']
        : ['tools/content/publish-appwrite.mjs', '--course', 'vi_en', '--version', 'v2'];
  if (action === 'probe')
    fs.writeFileSync(
      path.join(dir, 'probe-receipt.json'),
      JSON.stringify({ endpoint, project, at: 0, status: 'running' }),
      { mode: 0o600 },
    );
  const child = spawnSync(process.execPath, args, {
    cwd: root,
    env,
    stdio: 'inherit',
    timeout: 900_000,
  });
  if (child.status !== 0 || child.error)
    throw new Error(`Local ${action} failed; adapters remain unadmitted`);
  if (action === 'schema') {
    const storage = new Storage(
      new Client().setEndpoint(endpoint).setProject(project).setKey(state.keys.setup),
    );
    const bucket = await storage.getBucket({ bucketId: 'learning-assets' });
    // Recover only the newly-created local bucket's zero default, never alter a cloud policy.
    if (bucket.maximumFileSize === 0)
      await storage.updateBucket({
        bucketId: bucket.$id,
        name: bucket.name,
        permissions: bucket.$permissions,
        fileSecurity: bucket.fileSecurity,
        enabled: bucket.enabled,
        maximumFileSize: 30_000_000,
      });
  }
  if (action === 'probe')
    fs.writeFileSync(
      path.join(dir, 'probe-receipt.json'),
      JSON.stringify({ endpoint, project, fingerprint, at: Date.now(), status: 'passed' }),
      { mode: 0o600 },
    );
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : 'Local Appwrite setup failed');
  process.exitCode = 1;
});
