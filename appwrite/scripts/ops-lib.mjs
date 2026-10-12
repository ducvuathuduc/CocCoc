// Pure (no network) helpers for the per-service Appwrite operations declaration:
// appwrite/appwrite.config.json (Appwrite CLI functions) + appwrite/ops/project.json (auth, platforms,
// variables, domains, schedules). Used by appwrite/scripts/ops.mjs and appwrite/test/ops.test.mjs.
import { createHash, randomBytes } from 'node:crypto';

export const SERVICES = ['learning', 'progress', 'ai'];

/**
 * Dynamic-key scope ceiling per service (docs/data/PERMISSIONS.md: "row read/write and file operations
 * only as needed; user administration solely Progress deletion path"). Appwrite scopes are capability
 * classes, not per-table grants, so table ownership stays enforced by each adapter's prefix allowlist.
 */
export const SCOPE_CEILING = {
  learning: ['rows.read', 'rows.write', 'files.read', 'files.write'],
  progress: ['rows.read', 'rows.write', 'users.read', 'users.write'],
  ai: ['rows.read', 'rows.write', 'files.read', 'files.write'],
};
export const TABLE_PREFIX = { learning: 'l_', progress: 'p_', ai: 'a_' };
export const KEYRING_SENDERS = {
  // receiver -> senders whose HMAC it must verify (EVENT_ALLOWLIST in services/shared/src/transport.ts),
  // plus itself so it can sign its own outgoing calls.
  learning: ['learning', 'progress'],
  progress: ['progress', 'learning', 'ai'],
  ai: ['ai', 'progress'],
};
export const MANAGED_RUNTIME_VARS = ['BUILD_ID'];
const SECRETISH = /(KEY|SECRET|TOKEN|PASSWORD|PRIVATE)/;
const PUBLIC_KEY_VARS = ['COC_CONTENT_PUBLIC_KEYS'];
const CRON_FIELD = /^(\*|\d+|\d+-\d+|\*\/\d+|\d+(,\d+)+)$/;

export function functionByService(config) {
  const map = {};
  for (const fn of config.functions ?? []) map[fn.$id.replace(/^coc-/, '')] = fn;
  return map;
}

export function isCron(value) {
  const parts = String(value).trim().split(/\s+/);
  return parts.length === 5 && parts.every((part) => CRON_FIELD.test(part));
}

/** Live schedule a function must carry: the single active schedule, else ''. */
export function activeSchedule(ops, functionId) {
  const active = (ops.schedules ?? []).filter(
    (s) => s.functionId === functionId && s.status === 'active',
  );
  return active.length ? active[0].cron : '';
}

/**
 * Validate the two declaration files against each other, the service descriptors and the mobile app ids.
 * Returns a list of problems (empty = valid). `context` carries file contents read by the caller.
 */
export function validateOps(config, ops, context = {}) {
  const problems = [];
  const fail = (msg) => problems.push(msg);
  if (config.projectId !== ops.projectId)
    fail('projectId differs between appwrite.config.json and ops/project.json');
  if (ops.projectEnv !== 'test') fail('ops/project.json must target the test project');
  const fns = functionByService(config);
  const ids = (config.functions ?? []).map((f) => f.$id).sort();
  if (JSON.stringify(ids) !== JSON.stringify(SERVICES.map((s) => `coc-${s}`).sort())) {
    fail(
      `functions must be exactly one per service (coc-learning, coc-progress, coc-ai); got ${ids.join(',')}`,
    );
  }
  for (const service of SERVICES) {
    const fn = fns[service];
    if (!fn) continue;
    const id = fn.$id;
    const descriptor = context.descriptors?.[service];
    if (descriptor) {
      if (descriptor.functionId !== id)
        fail(
          `${id}: services/${service}/appwrite-function.json functionId ${descriptor.functionId}`,
        );
      if (descriptor.runtime !== fn.runtime) fail(`${id}: runtime differs from service descriptor`);
      if (`services/${service}/${descriptor.entrypoint}` !== ops.functions?.[id]?.bundle)
        fail(`${id}: bundle differs from service descriptor entrypoint`);
    }
    if (fn.runtime !== 'node-22') fail(`${id}: runtime must be node-22`);
    if (fn.path !== `.build/${service}`)
      fail(`${id}: path must be .build/${service} (staged by ops.mjs --deploy)`);
    if (fn.entrypoint !== 'main.mjs')
      fail(`${id}: entrypoint must be main.mjs (appwrite/runtime adapter over the hosted bundle)`);
    if (fn.commands !== '') fail(`${id}: bundle is prebuilt; commands must be empty`);
    if (!Array.isArray(fn.ignore) || !fn.ignore.includes('*.map'))
      fail(`${id}: ignore must exclude source maps`);
    // PERMISSIONS.md: "Function execute access / public domains: Any needed for direct HTTP; authenticate
    // every protected route; /health only public". Appwrite function domains refuse every request unless
    // execute includes "any" (live probe 2026-10-12: users-only -> 403 router_unauthorized_execution even
    // with a valid session cookie or JWT), and the mobile client calls the REST API over the domains with
    // Authorization: Bearer <jwt> (docs/api/AUTH.md). Identity is enforced in the service (Account.get).
    if (JSON.stringify(fn.execute) !== '["any"]')
      fail(
        `${id}: execute must be ["any"] (direct HTTP; services authenticate every route but /health)`,
      );
    if ((fn.events ?? []).length)
      fail(`${id}: platform events are not used (cross-service effects are signed outbox events)`);
    const extra = (fn.scopes ?? []).filter((s) => !SCOPE_CEILING[service].includes(s));
    if (extra.length) fail(`${id}: scopes beyond ${service} ceiling: ${extra.join(',')}`);
    if (!Number.isInteger(fn.timeout) || fn.timeout < 15 || fn.timeout > 900)
      fail(`${id}: timeout out of range`);
    if (fn.enabled !== true || fn.logging !== true) fail(`${id}: enabled and logging must be true`);
    if (fn.schedule !== activeSchedule(ops, id))
      fail(`${id}: schedule must equal its active ops schedule ('${activeSchedule(ops, id)}')`);

    const decl = ops.functions?.[id];
    if (!decl) {
      fail(`${id}: missing in ops/project.json functions`);
      continue;
    }
    if (decl.service !== service) fail(`${id}: service mismatch`);
    if (decl.bundle !== `services/${service}/dist/function.mjs`)
      fail(`${id}: bundle must be services/${service}/dist/function.mjs`);
    for (const [key, value] of Object.entries(decl.variables ?? {})) {
      // Ed25519 content-verification PUBLIC keys (Learning trust anchor) are not secrets.
      if (PUBLIC_KEY_VARS.includes(key)) continue;
      if (SECRETISH.test(key))
        fail(`${id}: variable ${key} looks secret; declare it under secrets`);
      if (/[0-9a-f]{40,}/i.test(String(value)))
        fail(`${id}: variable ${key} value looks like key material`);
      if (MANAGED_RUNTIME_VARS.includes(key)) fail(`${id}: ${key} is managed by deploy`);
    }
    if (decl.variables?.COC_SERVICE_ID !== service)
      fail(`${id}: COC_SERVICE_ID must be ${service}`);
    if (decl.variables?.APPWRITE_PROJECT_ID !== ops.projectId)
      fail(`${id}: APPWRITE_PROJECT_ID mismatch`);
    if (decl.variables?.APPWRITE_ENDPOINT !== config.endpoint)
      fail(`${id}: APPWRITE_ENDPOINT mismatch`);
    if (JSON.stringify(decl.secrets) !== '["COC_SERVICE_KEYS"]')
      fail(`${id}: secrets must be exactly COC_SERVICE_KEYS`);
    if (JSON.stringify(decl.keyringSenders) !== JSON.stringify(KEYRING_SENDERS[service])) {
      fail(`${id}: keyringSenders must be ${KEYRING_SENDERS[service].join(',')}`);
    }
    if (service === 'ai' && decl.variables?.COC_GEMINI_ENABLED !== 'false')
      fail('coc-ai: Gemini must stay disabled');
  }
  for (const schedule of ops.schedules ?? []) {
    if (!isCron(schedule.cron)) fail(`schedule ${schedule.id}: invalid cron ${schedule.cron}`);
    if (!ids.includes(schedule.functionId)) fail(`schedule ${schedule.id}: unknown function`);
    if (!['active', 'pending-service-worker'].includes(schedule.status))
      fail(`schedule ${schedule.id}: bad status`);
  }
  for (const id of ids) {
    if (
      (ops.schedules ?? []).filter((s) => s.functionId === id && s.status === 'active').length > 1
    ) {
      fail(`${id}: at most one active schedule per function`);
    }
  }
  const auth = ops.auth ?? {};
  if (auth.methods?.['email-password'] !== true)
    fail('auth: email-password must be enabled (FR-AUTH-001)');
  if (auth.methods?.jwt !== true) fail('auth: jwt must be enabled (services verify user JWTs)');
  if (auth.methods?.anonymous !== false)
    fail('auth: anonymous must be off (guest is a local demo)');
  if (!(auth.policies?.['password-strength']?.min >= 12))
    fail('auth: password-strength.min must be >= 12 (FR-AUTH-001)');
  for (const platform of ops.platforms ?? []) {
    const want = context.mobileIds?.[platform.type];
    const got = platform.applicationId ?? platform.bundleIdentifier;
    if (want && want !== got)
      fail(`platform ${platform.platformId}: ${got} differs from apps/mobile (${want})`);
  }
  return problems;
}

export function sha256(text) {
  return createHash('sha256').update(text).digest('hex');
}

/** Fresh HMAC keyrings: one 32-byte secret per sender, each function receives only the senders it needs. */
export function generateKeyrings(ops, now = new Date(), random = randomBytes) {
  const stamp = now.toISOString().slice(0, 10).replace(/-/g, '');
  const keys = {};
  for (const sender of SERVICES) {
    keys[sender] = {
      keyId: `${sender}-${stamp}-${random(3).toString('hex')}`,
      sender,
      secretHex: random(32).toString('hex'),
    };
  }
  const result = {};
  for (const [functionId, decl] of Object.entries(ops.functions)) {
    result[functionId] = JSON.stringify(decl.keyringSenders.map((sender) => keys[sender]));
  }
  return result;
}

const FUNCTION_FIELDS = [
  'runtime',
  'execute',
  'events',
  'scopes',
  'schedule',
  'timeout',
  'enabled',
  'logging',
  'entrypoint',
  'commands',
  'buildSpecification',
  'runtimeSpecification',
  'deploymentRetention',
];

/** Compare one live function object with its declaration. */
export function diffFunction(declared, live) {
  const drift = [];
  for (const field of FUNCTION_FIELDS) {
    if (declared[field] === undefined) continue;
    const a = Array.isArray(declared[field])
      ? JSON.stringify([...declared[field]].sort())
      : JSON.stringify(declared[field]);
    const b = Array.isArray(live[field])
      ? JSON.stringify([...(live[field] ?? [])].sort())
      : JSON.stringify(live[field]);
    if (a !== b) drift.push({ field, declared: declared[field], live: live[field] });
  }
  return drift;
}

/** Compare live variables (list response) with the declaration; secret values are never compared or printed. */
export function diffVariables(decl, liveVars) {
  const byKey = new Map(liveVars.map((v) => [v.key, v]));
  const missing = [];
  const drift = [];
  for (const [key, value] of Object.entries(decl.variables ?? {})) {
    const live = byKey.get(key);
    if (!live) missing.push(key);
    else if (live.secret || live.value !== value)
      drift.push({ key, declared: value, live: live.secret ? '<secret>' : live.value });
  }
  for (const key of decl.secrets ?? []) {
    const live = byKey.get(key);
    if (!live) missing.push(key);
    else if (!live.secret) drift.push({ key, declared: '<secret>', live: 'NOT SECRET' });
  }
  const known = new Set([
    ...Object.keys(decl.variables ?? {}),
    ...(decl.secrets ?? []),
    ...MANAGED_RUNTIME_VARS,
  ]);
  const extra = liveVars.filter((v) => !known.has(v.key)).map((v) => v.key);
  return { missing, drift, extra };
}

export function diffPolicies(declared, livePolicies) {
  const byId = new Map(livePolicies.map((p) => [p.$id, p]));
  const drift = [];
  for (const [id, want] of Object.entries(declared)) {
    const live = byId.get(id);
    if (!live) {
      drift.push({ policy: id, live: 'absent' });
      continue;
    }
    for (const [key, value] of Object.entries(want)) {
      if (live[key] !== value) drift.push({ policy: id, key, declared: value, live: live[key] });
    }
  }
  return drift;
}

export function diffAuthMethods(declared, liveMethods) {
  const byId = new Map(liveMethods.map((m) => [m.$id, m.enabled]));
  return Object.entries(declared)
    .filter(([id, enabled]) => byId.get(id) !== enabled)
    .map(([id, enabled]) => ({ method: id, declared: enabled, live: byId.get(id) }));
}

export function diffPlatforms(declared, livePlatforms) {
  const byId = new Map(livePlatforms.map((p) => [p.$id, p]));
  const missing = [];
  const drift = [];
  for (const platform of declared) {
    const live = byId.get(platform.platformId);
    if (!live) {
      missing.push(platform.platformId);
      continue;
    }
    const want = platform.applicationId ?? platform.bundleIdentifier;
    const got = live.applicationId ?? live.bundleIdentifier ?? live.key ?? live.identifier;
    if (live.name !== platform.name || (got !== undefined && got !== want)) {
      drift.push({
        platform: platform.platformId,
        declared: { name: platform.name, id: want },
        live: { name: live.name, id: got },
      });
    }
  }
  const extra = livePlatforms
    .filter((p) => !declared.some((d) => d.platformId === p.$id))
    .map((p) => p.$id);
  return { missing, drift, extra };
}
