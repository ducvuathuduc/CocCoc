// Per-service Appwrite operations: functions (one per microservice), variables/secrets, auth, platforms,
// function domains, schedules. Declarations: appwrite/appwrite.config.json (Appwrite CLI functions) and
// appwrite/ops/project.json. Modes:
//   (default)      offline plan: validate declarations, print plan + SHA-256. No network.
//   --apply        idempotent create/update on the reviewed TEST project (guarded).
//   --check-live   read-only drift check (exit 1 on missing/drift/extra).
//   --deploy       build bundles, push code with the Appwrite CLI, wait for ready, verify /health.
//   --health       execute GET /health on every function and require 200 + matching service/buildId.
//   --probe        live trust probes over the public function domains with a synthetic user
//                  (ALLOW_LIVE_PROBE=reviewed-test-project); the user is deleted afterwards.
// Options: --service learning,progress (deploy/health subset), --rotate-service-keys (apply),
//          --no-build (deploy). Secrets are never printed or written to disk.
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  SERVICES,
  activeSchedule,
  diffAuthMethods,
  diffOAuthProviders,
  diffFunction,
  diffPlatforms,
  diffPolicies,
  diffVariables,
  functionByService,
  generateKeyrings,
  providerSecretFromEnv,
  sha256,
  validateOps,
} from './ops-lib.mjs';

// Node's fetch ignores HTTPS_PROXY unless NODE_USE_ENV_PROXY=1; re-exec once so a proxied shell works.
if (
  (process.env.HTTPS_PROXY || process.env.https_proxy) &&
  process.env.NODE_USE_ENV_PROXY !== '1'
) {
  const child = spawnSync(process.execPath, process.argv.slice(1), {
    stdio: 'inherit',
    env: { ...process.env, NODE_USE_ENV_PROXY: '1' },
  });
  process.exit(child.status ?? 1);
}

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');
const configText = read('appwrite/appwrite.config.json');
const opsText = read('appwrite/ops/project.json');
const config = JSON.parse(configText);
const ops = JSON.parse(opsText);
const args = process.argv.slice(2);
const flag = (name) => args.includes(name);
const option = (name) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
};

function mobileIds() {
  const ids = {};
  const gradle = read('apps/mobile/android/app/build.gradle.kts').match(
    /applicationId\s*=\s*"([^"]+)"/,
  );
  if (gradle) ids.android = gradle[1];
  const pbx = [
    ...read('apps/mobile/ios/Runner.xcodeproj/project.pbxproj').matchAll(
      /PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);/g,
    ),
  ]
    .map((m) => m[1].trim())
    .filter((id) => !id.endsWith('Tests'));
  if (pbx.length) ids.apple = pbx[0];
  return ids;
}
const descriptors = Object.fromEntries(
  SERVICES.map((s) => [s, JSON.parse(read(`services/${s}/appwrite-function.json`))]),
);
const problems = validateOps(config, ops, { descriptors, mobileIds: mobileIds() });
if (problems.length) {
  console.error(JSON.stringify({ status: 'FAIL', mode: 'VALIDATION', problems }, null, 2));
  process.exit(1);
}
const declarationSha256 = sha256(configText + '\n' + opsText);
const fns = functionByService(config);
const selected = (option('--service') ?? SERVICES.join(',')).split(',').map((s) => s.trim());
for (const s of selected) if (!SERVICES.includes(s)) throw new Error(`unknown service ${s}`);

const mode = flag('--apply')
  ? 'apply'
  : flag('--check-live')
    ? 'check-live'
    : flag('--deploy')
      ? 'deploy'
      : flag('--health')
        ? 'health'
        : flag('--probe')
          ? 'probe'
          : 'plan';

if (mode === 'plan') {
  console.log(
    JSON.stringify(
      {
        status: 'PASS',
        mode: 'DRY_RUN_NO_NETWORK',
        declarationSha256,
        projectId: ops.projectId,
        functions: config.functions.map((f) => ({
          id: f.$id,
          runtime: f.runtime,
          bundle: ops.functions[f.$id].bundle,
          entrypoint: `${f.entrypoint} (appwrite/runtime adapter)`,
          execute: f.execute,
          scopes: f.scopes,
          timeout: f.timeout,
          schedule: f.schedule || null,
          domain: ops.functions[f.$id].functionDomain,
          variables: Object.keys(ops.functions[f.$id].variables),
          secrets: ops.functions[f.$id].secrets,
        })),
        auth: ops.auth.methods,
        oauth2: ops.auth.oauth2 ?? {},
        policies: Object.keys(ops.auth.policies),
        platforms: ops.platforms.map((p) => `${p.type}:${p.applicationId ?? p.bundleIdentifier}`),
        schedules: ops.schedules.map((s) => ({
          id: s.id,
          functionId: s.functionId,
          cron: s.cron,
          status: s.status,
        })),
      },
      null,
      2,
    ),
  );
  process.exit(0);
}

// ---------- live modes ----------
if (process.env.APPWRITE_PROJECT_ENV !== 'test')
  throw new Error('Live ops only against APPWRITE_PROJECT_ENV=test.');
if (mode === 'probe' && process.env.ALLOW_LIVE_PROBE !== 'reviewed-test-project') {
  throw new Error(
    'Set ALLOW_LIVE_PROBE=reviewed-test-project to run live probes (creates and deletes a synthetic user).',
  );
}
if (
  (mode === 'apply' || mode === 'deploy') &&
  process.env.ALLOW_APPWRITE_APPLY !== 'reviewed-test-project'
) {
  throw new Error(
    'Set ALLOW_APPWRITE_APPLY=reviewed-test-project to change the reviewed test project.',
  );
}
const endpoint = process.env.APPWRITE_ENDPOINT ?? config.endpoint;
const projectId = process.env.APPWRITE_PROJECT_ID ?? config.projectId;
const apiKey = process.env.APPWRITE_API_KEY;
if (projectId !== ops.projectId)
  throw new Error('APPWRITE_PROJECT_ID is not the declared test project.');
if (!apiKey)
  throw new Error('APPWRITE_API_KEY must be set in the process environment (never in files).');

async function api(method, route, body, { allow404 = false } = {}) {
  const headers = { 'X-Appwrite-Project': projectId, 'X-Appwrite-Key': apiKey };
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  for (let attempt = 1; ; attempt += 1) {
    const response = await fetch(`${endpoint}${route}`, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await response.text();
    const json = text ? JSON.parse(text) : {};
    if (response.ok) return json;
    if (allow404 && response.status === 404) return null;
    if ((response.status >= 500 || response.status === 429) && attempt < 3) {
      await new Promise((r) => setTimeout(r, 500 * attempt));
      continue;
    }
    throw new Error(
      `${method} ${route} -> ${response.status} ${json.type ?? ''} ${json.message ?? ''}`,
    );
  }
}

function cli(cliArgs, { capture = false } = {}) {
  const result = spawnSync('appwrite', cliArgs, {
    cwd: path.join(root, 'appwrite'),
    stdio: capture ? ['ignore', 'pipe', 'pipe'] : ['ignore', 'inherit', 'inherit'],
    encoding: 'utf8',
    timeout: 600000,
  });
  if (result.error) throw new Error(`appwrite CLI unavailable: ${result.error.message}`);
  if (result.status !== 0) throw new Error(`appwrite ${cliArgs.join(' ')} exited ${result.status}`);
  return result.stdout;
}

const listVars = async (id) => (await api('GET', `/functions/${id}/variables`)).variables ?? [];

async function upsertVar(id, existing, key, value, secret) {
  if (existing) {
    await api('PUT', `/functions/${id}/variables/${existing.$id}`, { key, value, secret });
  } else {
    await api('POST', `/functions/${id}/variables`, { variableId: 'unique()', key, value, secret });
  }
}

async function liveFunctions() {
  const out = {};
  for (const fn of config.functions)
    out[fn.$id] = await api('GET', `/functions/${fn.$id}`, undefined, { allow404: true });
  return out;
}

async function apply() {
  const created = { functions: 0, variables: 0, secrets: 0, platforms: 0, domains: 0 };
  const updated = { functions: 0, variables: 0, authMethods: 0, policies: 0, platforms: 0 };
  const before = await liveFunctions();
  // 1. Functions (settings only; code is pushed by --deploy) through the Appwrite CLI.
  for (const fn of config.functions) {
    const live = before[fn.$id];
    const drift = live ? diffFunction(fn, live) : null;
    if (!live || drift.length) {
      cli(['push', 'functions', '--function-id', fn.$id, '--force', '--no-code']);
      if (live) updated.functions += 1;
      else created.functions += 1;
    }
  }
  const after = await liveFunctions();
  for (const fn of config.functions) {
    const drift = after[fn.$id]
      ? diffFunction(fn, after[fn.$id])
      : [{ field: 'function', live: 'absent' }];
    if (drift.length)
      throw new Error(`${fn.$id}: still drifted after CLI push: ${JSON.stringify(drift)}`);
  }
  // 2. Plain variables.
  const varsById = {};
  for (const fn of config.functions) {
    const decl = ops.functions[fn.$id];
    const liveVars = await listVars(fn.$id);
    varsById[fn.$id] = liveVars;
    for (const [key, value] of Object.entries(decl.variables)) {
      const existing = liveVars.find((v) => v.key === key);
      if (existing && !existing.secret && existing.value === value) continue;
      await upsertVar(fn.$id, existing, key, value, false);
      if (existing) updated.variables += 1;
      else created.variables += 1;
    }
  }
  // 3. Secrets: COC_SERVICE_KEYS keyrings, generated here and stored only as secret variables.
  //    Secret values are write-only, so a keyring is (re)generated for ALL functions together:
  //    on first apply, or with --rotate-service-keys. A partial set is an error (would split the ring).
  const has = config.functions.map((fn) =>
    varsById[fn.$id].some((v) => v.key === 'COC_SERVICE_KEYS'),
  );
  const rotate = flag('--rotate-service-keys');
  if (rotate || has.every((h) => !h)) {
    const rings = generateKeyrings(ops);
    for (const fn of config.functions) {
      const existing = varsById[fn.$id].find((v) => v.key === 'COC_SERVICE_KEYS');
      await upsertVar(fn.$id, existing, 'COC_SERVICE_KEYS', rings[fn.$id], true);
      created.secrets += 1;
    }
  } else if (!has.every(Boolean)) {
    throw new Error(
      'COC_SERVICE_KEYS exists on only some functions; rerun with --rotate-service-keys to regenerate the whole ring.',
    );
  }
  // 3b. Provider secrets (third-party keys): set from the operator env when it holds a real value;
  //     otherwise an existing secret is kept and a missing one is reported (set it out-of-band).
  const providerSecretsMissing = [];
  for (const fn of config.functions) {
    for (const key of ops.functions[fn.$id].providerSecrets ?? []) {
      const existing = varsById[fn.$id].find((v) => v.key === key);
      const value = providerSecretFromEnv(process.env, key);
      if (value) {
        await upsertVar(fn.$id, existing, key, value, true);
        created.secrets += 1;
      } else if (!existing) {
        providerSecretsMissing.push(`${fn.$id}:${key}`);
      }
    }
  }
  // 4. Auth methods and policies.
  const project = await api('GET', `/projects/${projectId}`);
  for (const d of diffAuthMethods(ops.auth.methods, project.authMethods ?? [])) {
    await api('PATCH', `/project/auth-methods/${d.method}`, { enabled: d.declared });
    updated.authMethods += 1;
  }
  const policies = (await api('GET', '/project/policies')).policies ?? [];
  const policyDrift = new Set(diffPolicies(ops.auth.policies, policies).map((d) => d.policy));
  for (const id of policyDrift) {
    await api('PATCH', `/project/policies/${id}`, ops.auth.policies[id]);
    updated.policies += 1;
  }
  // 5. Platforms.
  const platforms = (await api('GET', '/project/platforms')).platforms ?? [];
  const pd = diffPlatforms(ops.platforms, platforms);
  for (const p of ops.platforms) {
    const idField = p.type === 'android' ? 'applicationId' : 'bundleIdentifier';
    const body = { name: p.name, [idField]: p[idField] };
    if (pd.missing.includes(p.platformId)) {
      await api('POST', `/project/platforms/${p.type}`, { platformId: p.platformId, ...body });
      created.platforms += 1;
    } else if (pd.drift.some((d) => d.platform === p.platformId)) {
      await api('PUT', `/project/platforms/${p.type}/${p.platformId}`, body);
      updated.platforms += 1;
    }
  }
  // 6. Function domains.
  const rules = (await api('GET', '/proxy/rules')).rules ?? [];
  for (const fn of config.functions) {
    const domain = ops.functions[fn.$id].functionDomain;
    if (!rules.some((r) => r.domain === domain)) {
      await api('POST', '/proxy/rules/function', { domain, functionId: fn.$id });
      created.domains += 1;
    }
  }
  const changed = Object.values(created).some(Boolean) || Object.values(updated).some(Boolean);
  console.log(
    JSON.stringify(
      {
        status: changed ? 'APPLIED' : 'NO_CHANGES',
        declarationSha256,
        created,
        updated,
        providerSecretsMissing: providerSecretsMissing.length ? providerSecretsMissing : undefined,
        note:
          changed && (created.variables || updated.variables || created.secrets)
            ? 'Variable changes take effect on the next deployment: run pnpm appwrite:deploy.'
            : undefined,
      },
      null,
      2,
    ),
  );
}

async function checkLive() {
  const report = {
    functions: {},
    auth: {},
    platforms: {},
    domains: {},
    messaging: {},
    schedules: [],
  };
  let ok = true;
  const live = await liveFunctions();
  for (const fn of config.functions) {
    const entry = {};
    const l = live[fn.$id];
    if (!l) {
      report.functions[fn.$id] = { missing: true };
      ok = false;
      continue;
    }
    entry.drift = diffFunction(fn, l);
    entry.variables = diffVariables(ops.functions[fn.$id], await listVars(fn.$id));
    entry.activeDeployment = l.deploymentId || null;
    if (l.deploymentId) {
      const dep = await api('GET', `/functions/${fn.$id}/deployments/${l.deploymentId}`);
      entry.deploymentStatus = dep.status;
      if (dep.status !== 'ready') ok = false;
    } else ok = false;
    if (
      entry.drift.length ||
      entry.variables.missing.length ||
      entry.variables.drift.length ||
      entry.variables.extra.length
    )
      ok = false;
    report.functions[fn.$id] = entry;
  }
  const project = await api('GET', `/projects/${projectId}`);
  report.auth.methods = diffAuthMethods(ops.auth.methods, project.authMethods ?? []);
  report.auth.policies = diffPolicies(
    ops.auth.policies,
    (await api('GET', '/project/policies')).policies ?? [],
  );
  report.auth.oauth2 = diffOAuthProviders(
    ops.auth.oauth2,
    (await api('GET', '/project/oauth2')).providers ?? [],
  );
  if (report.auth.methods.length || report.auth.policies.length || report.auth.oauth2.length)
    ok = false;
  report.platforms = diffPlatforms(
    ops.platforms,
    (await api('GET', '/project/platforms')).platforms ?? [],
  );
  if (
    report.platforms.missing.length ||
    report.platforms.drift.length ||
    report.platforms.extra.length
  )
    ok = false;
  const rules = (await api('GET', '/proxy/rules')).rules ?? [];
  for (const fn of config.functions) {
    const domain = ops.functions[fn.$id].functionDomain;
    const rule = rules.find((r) => r.domain === domain);
    report.domains[domain] = rule
      ? { functionId: rule.deploymentResourceId, status: rule.status }
      : 'missing';
    if (!rule || rule.deploymentResourceId !== fn.$id) ok = false;
  }
  const providers = (await api('GET', '/messaging/providers')).total;
  const topics = (await api('GET', '/messaging/topics')).total;
  report.messaging = { providers, topics };
  if (providers !== ops.messaging.providers.length || topics !== ops.messaging.topics.length)
    ok = false;
  for (const s of ops.schedules) {
    const liveCron = live[s.functionId]?.schedule ?? null;
    const want = activeSchedule(ops, s.functionId);
    report.schedules.push({
      id: s.id,
      status: s.status,
      declaredCron: s.cron,
      liveFunctionSchedule: liveCron || '',
    });
    if ((liveCron ?? '') !== want) ok = false;
  }
  console.log(
    JSON.stringify(
      { status: ok ? 'PASS' : 'FAIL', mode: 'CHECK_LIVE', declarationSha256, ...report },
      null,
      2,
    ),
  );
  process.exitCode = ok ? 0 : 1;
}

function buildId() {
  const git = spawnSync('git', ['rev-parse', '--short=12', 'HEAD'], {
    cwd: root,
    encoding: 'utf8',
  });
  const dirty = spawnSync('git', ['status', '--porcelain', '--', 'services'], {
    cwd: root,
    encoding: 'utf8',
  });
  const sha = git.status === 0 ? git.stdout.trim() : 'unknown';
  return `${sha}${dirty.stdout.trim() ? '-dirty' : ''}`.slice(0, 64);
}

async function health(services, expectBuildId) {
  const results = [];
  for (const service of services) {
    const id = fns[service].$id;
    const exec = await api('POST', `/functions/${id}/executions`, {
      path: '/health',
      method: 'GET',
      async: false,
    });
    let body = null;
    try {
      body = JSON.parse(exec.responseBody);
    } catch {
      body = null;
    }
    const pass =
      exec.responseStatusCode === 200 &&
      body?.service === service &&
      (!expectBuildId || body?.buildId === expectBuildId);
    results.push({
      functionId: id,
      executionId: exec.$id,
      status: exec.status,
      http: exec.responseStatusCode,
      durationS: exec.duration,
      body,
      pass,
    });
  }
  return results;
}

async function waitReady(id, deploymentId) {
  for (let i = 0; i < 120; i += 1) {
    const dep = await api('GET', `/functions/${id}/deployments/${deploymentId}`);
    if (dep.status === 'ready') return dep;
    if (dep.status === 'failed' || dep.status === 'canceled')
      throw new Error(`${id}: deployment ${deploymentId} ${dep.status}`);
    await new Promise((r) => setTimeout(r, 3000));
  }
  throw new Error(`${id}: deployment ${deploymentId} not ready in time`);
}

async function deploy() {
  if (!flag('--no-build')) {
    const build = spawnSync(
      process.execPath,
      ['tools/scripts/backend-check.mjs', '--build', ...selected],
      { cwd: root, stdio: 'inherit' },
    );
    if (build.status !== 0)
      throw new Error('bundle build failed (pnpm backend:build); not deploying');
  }
  const id = buildId();
  const deployments = [];
  for (const service of selected) {
    const fn = fns[service];
    const bundle = path.join(root, ops.functions[fn.$id].bundle);
    if (!fs.existsSync(bundle)) throw new Error(`${bundle} missing; run pnpm backend:build`);
    // Stage: unchanged hosted bundle + the runtime adapter as the Appwrite entrypoint.
    const stage = path.join(root, 'appwrite', fn.path);
    fs.rmSync(stage, { recursive: true, force: true });
    fs.mkdirSync(stage, { recursive: true });
    fs.copyFileSync(bundle, path.join(stage, 'function.mjs'));
    fs.copyFileSync(path.join(root, 'appwrite/runtime/main.mjs'), path.join(stage, fn.entrypoint));
    const vars = await listVars(fn.$id);
    await upsertVar(
      fn.$id,
      vars.find((v) => v.key === 'BUILD_ID'),
      'BUILD_ID',
      id,
      false,
    );
    const previous = (await api('GET', `/functions/${fn.$id}`)).deploymentId;
    cli(['push', 'functions', '--function-id', fn.$id, '--force', '--activate', '--no-logs']);
    const current = await api('GET', `/functions/${fn.$id}`);
    const latest = current.latestDeploymentId || current.deploymentId;
    const dep = await waitReady(fn.$id, latest);
    let active = (await api('GET', `/functions/${fn.$id}`)).deploymentId;
    if (active !== latest) {
      await api('PATCH', `/functions/${fn.$id}/deployment`, { deploymentId: latest });
      active = latest;
    }
    deployments.push({
      functionId: fn.$id,
      previous: previous || null,
      deploymentId: active,
      status: dep.status,
      sizeBytes: dep.sourceSize,
      bundleSha256: sha256(fs.readFileSync(bundle)),
    });
  }
  const checks = await health(selected, id);
  const ok = checks.every((c) => c.pass);
  console.log(
    JSON.stringify(
      { status: ok ? 'DEPLOYED' : 'FAIL', buildId: id, deployments, health: checks },
      null,
      2,
    ),
  );
  process.exitCode = ok ? 0 : 1;
}

/** Probe one public domain request; returns [httpStatus, errorCode|status]. No credential is printed. */
async function domainCall(domain, method, route, headers = {}) {
  const response = await fetch(`https://${domain}${route}`, {
    method,
    headers: {
      'User-Agent': 'coc-ops-probe/1',
      ...(method === 'POST' ? { 'Content-Type': 'application/json' } : {}),
      ...headers,
    },
    body: method === 'POST' ? '{}' : undefined,
  });
  const text = await response.text();
  let json = {};
  try {
    json = JSON.parse(text);
  } catch {
    json = {};
  }
  return [response.status, json.error?.code ?? json.status ?? json.type ?? null];
}

async function probe() {
  const userRoute = { learning: '/v1/courses', progress: '/v1/me', ai: '/v1/ai/capabilities' };
  const expectations = [];
  const userId = `opsprobe${Date.now().toString(36)}`;
  const password = `Pr0be-${(await import('node:crypto')).randomBytes(12).toString('hex')}`;
  const results = {};
  const expect = (name, got, wantStatus, wantCode) => {
    const pass = got[0] === wantStatus && (wantCode === undefined || got[1] === wantCode);
    expectations.push({
      name,
      status: got[0],
      code: got[1],
      want: wantCode ? `${wantStatus} ${wantCode}` : String(wantStatus),
      pass,
    });
  };
  // Password policy: an 11-character password must be refused (password-strength.min=12).
  try {
    await api('POST', '/users', {
      userId: `${userId}s`,
      email: `${userId}s@cocenglish-ops.dev`,
      password: 'Abcdefgh-11',
    });
    expectations.push({ name: 'password policy rejects 11 chars', pass: false });
    await api('DELETE', `/users/${userId}s`, undefined, { allow404: true });
  } catch (error) {
    expectations.push({
      name: 'password policy rejects 11 chars',
      detail: String(error.message).slice(0, 80),
      pass: true,
    });
  }
  await api('POST', '/users', { userId, email: `${userId}@cocenglish-ops.dev`, password });
  try {
    const session = await api('POST', `/users/${userId}/sessions`, {});
    const { jwt } = await api('POST', `/users/${userId}/jwts`, {
      sessionId: session.$id,
      duration: 900,
    });
    const tampered = `${jwt.slice(0, -6)}AAAAAA`;
    for (const service of selected) {
      const domain = ops.functions[fns[service].$id].functionDomain;
      const route = userRoute[service];
      expect(
        `${service} /health anonymous`,
        await domainCall(domain, 'GET', '/health'),
        200,
        'degraded',
      );
      expect(
        `${service} /ready without HMAC`,
        await domainCall(domain, 'GET', '/ready'),
        401,
        'AUTH_REQUIRED',
      );
      expect(
        `${service} /internal/events unsigned`,
        await domainCall(domain, 'POST', '/internal/events'),
        401,
        'AUTH_REQUIRED',
      );
      expect(
        `${service} ${route} no JWT`,
        await domainCall(domain, 'GET', route),
        401,
        'AUTH_REQUIRED',
      );
      expect(
        `${service} ${route} forged x-appwrite-user-id`,
        await domainCall(domain, 'GET', route, { 'x-appwrite-user-id': userId }),
        401,
        'AUTH_REQUIRED',
      );
      expect(
        `${service} ${route} forged x-appwrite-user-jwt (router strips)`,
        await domainCall(domain, 'GET', route, { 'x-appwrite-user-jwt': jwt }),
        401,
        'AUTH_REQUIRED',
      );
      expect(
        `${service} ${route} forged schedule trigger`,
        await domainCall(domain, 'GET', route, { 'x-appwrite-trigger': 'schedule' }),
        401,
        'AUTH_REQUIRED',
      );
      expect(
        `${service} ${route} tampered JWT`,
        await domainCall(domain, 'GET', route, { Authorization: `Bearer ${tampered}` }),
        401,
      );
      // A valid JWT passes Account.get; with persistence disabled the route then fails closed,
      // with persistence enabled (COC_<SERVICE>_PERSISTENCE=appwrite) it answers 200.
      const persistent =
        ops.functions[fns[service].$id].variables?.[`COC_${service.toUpperCase()}_PERSISTENCE`] ===
        'appwrite';
      if (persistent && service === 'ai') {
        expect(
          `${service} ${route} valid JWT -> verified, persistence enabled`,
          await domainCall(domain, 'GET', route, { Authorization: `Bearer ${jwt}` }),
          200,
        );
      } else if (!persistent) {
        expect(
          `${service} ${route} valid JWT -> verified, persistence fails closed`,
          await domainCall(domain, 'GET', route, { Authorization: `Bearer ${jwt}` }),
          503,
          'SERVICE_NOT_CONFIGURED',
        );
      }
    }
    await api('DELETE', `/users/${userId}/sessions/${session.$id}`);
    for (const service of selected) {
      const domain = ops.functions[fns[service].$id].functionDomain;
      expect(
        `${service} JWT of deleted session`,
        await domainCall(domain, 'GET', userRoute[service], { Authorization: `Bearer ${jwt}` }),
        401,
      );
    }
  } finally {
    await api('DELETE', `/users/${userId}`, undefined, { allow404: true });
    results.syntheticUserDeleted =
      (await api('GET', `/users/${userId}`, undefined, { allow404: true })) === null;
  }
  const ok = expectations.every((e) => e.pass) && results.syntheticUserDeleted;
  console.log(
    JSON.stringify(
      { status: ok ? 'PASS' : 'FAIL', mode: 'PROBE', ...results, expectations },
      null,
      2,
    ),
  );
  process.exitCode = ok ? 0 : 1;
}

if (mode === 'apply') await apply();
else if (mode === 'probe') await probe();
else if (mode === 'check-live') await checkLive();
else if (mode === 'deploy') await deploy();
else {
  const checks = await health(selected);
  console.log(
    JSON.stringify(
      { status: checks.every((c) => c.pass) ? 'PASS' : 'FAIL', mode: 'HEALTH', health: checks },
      null,
      2,
    ),
  );
  process.exitCode = checks.every((c) => c.pass) ? 0 : 1;
}
