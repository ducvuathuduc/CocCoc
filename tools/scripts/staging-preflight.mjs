// `node tools/scripts/staging-preflight.mjs [--ops appwrite/ops/project.staging.json]
//                                          [--mobile apps/mobile/config/staging.public.json]`
// Offline check that a STAGING profile is independent of the shared TEST project before anyone
// applies it: no network, no credentials, nothing is created or changed. It merges the overlay over
// appwrite/ops/project.json (the TEST declaration) and fails on anything that would make staging
// share a project, a function domain, a signing key or an OAuth client with TEST, on a placeholder
// left in, on a secret written into a file, and on a mobile profile that does not point at the same
// staging project. A pass is not staging runtime evidence: it only says the files are safe to use.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const HEX64 = /^[0-9a-f]{64}$/i;
const SECRET_KEY = /(api_?key|secret|seed|password|private)/i;
const SERVICES = { 'coc-learning': 'learning', 'coc-progress': 'progress', 'coc-ai': 'ai' };

const isObject = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);

function merge(base, overlay) {
  if (!isObject(base) || !isObject(overlay)) return overlay;
  const out = { ...base };
  for (const [key, value] of Object.entries(overlay)) {
    if (key.startsWith('$')) continue;
    out[key] = key in base ? merge(base[key], value) : value;
  }
  return out;
}

function* strings(value, where = '') {
  if (typeof value === 'string') yield [where, value];
  else if (Array.isArray(value))
    for (const [i, v] of value.entries()) yield* strings(v, `${where}[${i}]`);
  else if (isObject(value))
    for (const [k, v] of Object.entries(value)) {
      if (!k.startsWith('$')) yield* strings(v, where ? `${where}.${k}` : k);
    }
}

const hostOf = (value) => {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' ? url.hostname : null;
  } catch {
    return null;
  }
};

/** @returns {{status: 'PASS'|'FAIL', problems: {code: string, where: string}[]}} */
export function checkStaging({ test, overlay, realProfile, mobile }) {
  const problems = [];
  const fail = (code, where) => problems.push({ code, where });
  const staging = merge(test, overlay);

  for (const [where, value] of strings({ overlay, mobile })) {
    if (/REPLACE/.test(value)) fail('PLACEHOLDER_LEFT_IN', where);
  }
  // Keys written into a file, by name (values here are public identifiers or empty).
  const walk = (node, where) => {
    if (Array.isArray(node)) return node.forEach((v, i) => walk(v, `${where}[${i}]`));
    if (!isObject(node)) return;
    for (const [key, value] of Object.entries(node)) {
      const at = where ? `${where}.${key}` : key;
      if (typeof value === 'string' && value && SECRET_KEY.test(key) && !key.startsWith('$'))
        fail('SECRET_IN_FILE', at);
      walk(value, at);
    }
  };
  walk(overlay, 'overlay');
  walk(mobile, 'mobile');
  for (const [where, value] of strings(overlay)) {
    if (/^standard_[0-9a-f]{32,}/i.test(value)) fail('SECRET_IN_FILE', where);
  }

  if (staging.projectEnv !== 'staging') fail('ENV_NOT_STAGING', 'projectEnv');
  if (!staging.projectId || staging.projectId === test.projectId)
    fail('SAME_PROJECT_AS_TEST', 'projectId');
  if (!hostOf(staging.endpoint ?? '')) fail('ENDPOINT_NOT_HTTPS', 'endpoint');
  if (
    staging.auth?.oauth2?.google?.enabled &&
    staging.auth.oauth2.google.clientId === test.auth?.oauth2?.google?.clientId
  )
    fail('OAUTH_CLIENT_SHARED_WITH_TEST', 'auth.oauth2.google.clientId');

  const testDomains = new Set(Object.values(test.functions).map((f) => f.functionDomain));
  const domainOf = (name) => staging.functions?.[name]?.functionDomain;
  for (const [name, fn] of Object.entries(staging.functions ?? {})) {
    const where = `functions.${name}`;
    if (testDomains.has(fn.functionDomain))
      fail('DOMAIN_SHARED_WITH_TEST', `${where}.functionDomain`);
    if (fn.variables?.APPWRITE_PROJECT_ID !== staging.projectId)
      fail('FUNCTION_POINTS_AT_OTHER_PROJECT', `${where}.variables.APPWRITE_PROJECT_ID`);
    if (fn.variables?.APPWRITE_ENDPOINT !== staging.endpoint)
      fail('FUNCTION_POINTS_AT_OTHER_ENDPOINT', `${where}.variables.APPWRITE_ENDPOINT`);
    for (const [variable, target] of [
      ['COC_PROGRESS_URL', 'coc-progress'],
      ['COC_LEARNING_URL', 'coc-learning'],
      ['COC_AI_URL', 'coc-ai'],
    ]) {
      const value = fn.variables?.[variable];
      if (value !== undefined && value !== `https://${domainOf(target)}`)
        fail('PEER_URL_NOT_STAGING', `${where}.variables.${variable}`);
    }
    if (fn.variables?.COC_SERVICE_KEYS)
      fail('SECRET_IN_FILE', `${where}.variables.COC_SERVICE_KEYS`);
  }

  const learning = staging.functions?.['coc-learning']?.variables ?? {};
  let keys = [];
  try {
    keys = JSON.parse(learning.COC_CONTENT_PUBLIC_KEYS ?? '[]');
  } catch {
    fail('CONTENT_KEYS_NOT_JSON', 'functions.coc-learning.variables.COC_CONTENT_PUBLIC_KEYS');
  }
  const testKeys = JSON.parse(test.functions['coc-learning'].variables.COC_CONTENT_PUBLIC_KEYS);
  const devHex = new Set(testKeys.map((k) => k.publicKeyHex.toLowerCase()));
  const devIds = new Set(testKeys.map((k) => k.keyId));
  if (!keys.length) fail('CONTENT_KEY_MISSING', 'COC_CONTENT_PUBLIC_KEYS');
  for (const key of keys) {
    if (devIds.has(key.keyId) || devHex.has(String(key.publicKeyHex).toLowerCase()))
      fail('DEV_CONTENT_KEY', `COC_CONTENT_PUBLIC_KEYS.${key.keyId}`);
    if (!HEX64.test(String(key.publicKeyHex)))
      fail('CONTENT_KEY_NOT_HEX', `COC_CONTENT_PUBLIC_KEYS.${key.keyId}`);
  }
  if (
    !String(learning.COC_MAINTAINER_USER_IDS ?? '')
      .split(',')
      .some((id) => id.trim())
  )
    fail('MAINTAINERS_MISSING', 'functions.coc-learning.variables.COC_MAINTAINER_USER_IDS');
  if (learning.COC_LEARNING_ADMITTED !== 'reviewed-cloud-gate')
    fail('ADMISSION_GATE_CHANGED', 'functions.coc-learning.variables.COC_LEARNING_ADMITTED');

  if (mobile) {
    const at = (key) => `mobile.${key}`;
    if (mobile.DATA_SOURCE !== 'api') fail('MOBILE_NOT_API', at('DATA_SOURCE'));
    if (mobile.USE_MOCK_AUTH !== 'false') fail('MOBILE_MOCK_AUTH', at('USE_MOCK_AUTH'));
    if (mobile.ALLOW_INSECURE_LOCAL_ENDPOINTS === 'true')
      fail('MOBILE_INSECURE_ENDPOINTS', at('ALLOW_INSECURE_LOCAL_ENDPOINTS'));
    if (mobile.APPWRITE_PROJECT_ID !== staging.projectId)
      fail('MOBILE_PROJECT_MISMATCH', at('APPWRITE_PROJECT_ID'));
    if (mobile.APPWRITE_ENDPOINT !== staging.endpoint)
      fail('MOBILE_ENDPOINT_MISMATCH', at('APPWRITE_ENDPOINT'));
    for (const [key, name] of [
      ['LEARNING_API_URL', 'coc-learning'],
      ['PROGRESS_API_URL', 'coc-progress'],
      ['AI_API_URL', 'coc-ai'],
    ]) {
      if (mobile[key] !== `https://${domainOf(name)}`) fail('MOBILE_URL_NOT_STAGING', at(key));
      if (realProfile && mobile[key] === realProfile[key])
        fail('MOBILE_URL_SHARED_WITH_REAL', at(key));
    }
  }
  return { status: problems.length ? 'FAIL' : 'PASS', problems };
}

export { merge as mergeProfile, SERVICES };

const invoked = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (invoked) {
  const arg = (name, fallback) => {
    const index = process.argv.indexOf(`--${name}`);
    return index === -1 ? fallback : process.argv[index + 1];
  };
  const read = (file) => JSON.parse(fs.readFileSync(path.resolve(root, file), 'utf8'));
  const opsFile = arg('ops', 'appwrite/ops/project.staging.json');
  const mobileFile = arg('mobile', 'apps/mobile/config/staging.public.json');
  const missing = [opsFile, mobileFile].filter((f) => !fs.existsSync(path.resolve(root, f)));
  if (missing.length) {
    console.log(
      JSON.stringify({ status: 'BLOCKED', reason: 'staging profile files do not exist', missing }),
    );
    process.exit(2);
  }
  const result = checkStaging({
    test: read('appwrite/ops/project.json'),
    overlay: read(opsFile),
    realProfile: read('apps/mobile/config/real.public.json'),
    mobile: read(mobileFile),
  });
  console.log(
    JSON.stringify({ ...result, scope: 'offline file checks; not staging runtime evidence' }),
  );
  process.exit(result.status === 'PASS' ? 0 : 1);
}
