import fs from 'node:fs';
import path from 'node:path';
import { randomBytes } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { Client, Users } from 'node-appwrite';
import { disposableRuntimeEnv } from './runtime-test-env.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const privateDir = path.join(root, '.secrets/local-dev');
const evidenceFile = path.join(privateDir, 'auth-smoke.json');
const caFile = path.join(privateDir, 'tls/ca.crt');
const bootstrapFile = path.join(privateDir, 'bootstrap.json');
const appwriteEndpoint = 'https://127.0.0.1:8443/v1';
const project = 'cocenglish-local';
const mailpitEndpoint = 'http://127.0.0.1:8025';
const callbackOrigin = 'https://127.0.0.1:8443';
const childMarker = 'COC_LOCAL_AUTH_SMOKE_TLS';
const platform = {
  platformId: 'cocenglish-local-auth',
  name: 'CocEnglish Local Auth',
  hostname: '127.0.0.1',
};

function fileApi(value) {
  return value === 'win32' ? path.win32 : path.posix;
}

function defaultReadJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

export function checkLocalAuthSmoke({
  root: repositoryRoot,
  platform: operatingSystem = process.platform,
  statFile = fs.statSync,
  readJson = defaultReadJson,
}) {
  const api = fileApi(operatingSystem);
  const localDir = api.resolve(repositoryRoot, '.secrets', 'local-dev');
  const ca = api.resolve(localDir, 'tls', 'ca.crt');
  const bootstrap = api.resolve(localDir, 'bootstrap.json');
  try {
    if (!statFile(ca).isFile() || !statFile(bootstrap).isFile()) throw new Error('not file');
    const state = readJson(bootstrap);
    if (
      state?.endpoint !== appwriteEndpoint ||
      state?.project !== project ||
      typeof state?.keys?.setup !== 'string' ||
      state.keys.setup.length < 16
    ) {
      throw new Error('identity');
    }
  } catch {
    throw new Error('LOCAL_AUTH_SMOKE_CONFIGURATION_INVALID');
  }
  return { status: 'ready', project };
}

export function findRecipientMessage(messages, email, excludedIds) {
  return messages.find(
    (message) =>
      !excludedIds.has(message?.ID) &&
      Array.isArray(message?.To) &&
      message.To.some((recipient) => recipient?.Address === email),
  );
}

function messageBody(message) {
  return `${typeof message?.Text === 'string' ? message.Text : ''}\n${
    typeof message?.HTML === 'string' ? message.HTML : ''
  }`
    .replaceAll('&amp;', '&')
    .replaceAll('&#38;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#34;', '"');
}

export function parseCallbackParameters(message, expectedPath) {
  if (!['/auth/verify-email', '/auth/reset-password'].includes(expectedPath)) {
    throw new Error('AUTH_MESSAGE_CALLBACK_MISSING');
  }
  const body = messageBody(message);
  const escapedPath = expectedPath.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const match = body.match(new RegExp(`https://127\\.0\\.0\\.1:8443${escapedPath}\\?[^\\s"'<>]+`));
  if (!match) throw new Error('AUTH_MESSAGE_CALLBACK_MISSING');
  const callback = new URL(match[0]);
  const userId = callback.searchParams.get('userId');
  const secret = callback.searchParams.get('secret');
  if (!userId || !secret) throw new Error('AUTH_MESSAGE_CALLBACK_MISSING');
  return { userId, secret };
}

export function parseEmailOtp(message) {
  const text = typeof message?.Text === 'string' ? message.Text : '';
  const source =
    text.trim().length > 0
      ? text
      : messageBody({ HTML: message?.HTML })
          .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, ' ')
          .replace(/<[^>]+>/g, ' ');
  const matches = [...source.matchAll(/(?<!\d)\d{6}(?!\d)/g)].map((match) => match[0]);
  const unique = [...new Set(matches)];
  if (unique.length !== 1) throw new Error('AUTH_MESSAGE_OTP_INVALID');
  return unique[0];
}

export function publicAuthSummary(value) {
  const blocked = value.emailOtp === false && typeof value.emailOtpBlocker === 'string';
  return {
    status: blocked ? 'passed_with_provider_blocker' : 'passed',
    emailVerification: value.emailVerification === true,
    passwordRecovery: value.passwordRecovery === true,
    emailOtp: value.emailOtp === true,
    ...(blocked ? { emailOtpBlocker: value.emailOtpBlocker } : {}),
    callbackUiVerified: false,
    publicDeliverabilityVerified: false,
  };
}

function savePrivate(value) {
  const temporary = `${evidenceFile}.${process.pid}.tmp`;
  fs.writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
  fs.renameSync(temporary, evidenceFile);
}

async function jsonRequest(url, { method = 'GET', headers = {}, body, allowed = [200] } = {}) {
  const response = await fetch(url, {
    method,
    redirect: 'error',
    signal: AbortSignal.timeout(30_000),
    headers: { ...(body === undefined ? {} : { 'content-type': 'application/json' }), ...headers },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const value = await response.json().catch(() => ({}));
  if (!allowed.includes(response.status)) {
    const error = new Error(`LOCAL_AUTH_REQUEST_FAILED:${response.status}`);
    error.status = response.status;
    error.type = typeof value?.type === 'string' ? value.type : undefined;
    throw error;
  }
  return { response, value };
}

function accountHeaders(cookie) {
  return {
    'x-appwrite-project': project,
    ...(cookie ? { cookie } : {}),
  };
}

async function accountRequest(method, route, { cookie, body, allowed } = {}) {
  if (!route.startsWith('/account/') || route.includes('://') || route.startsWith('//')) {
    throw new Error('UNSAFE_LOCAL_AUTH_ROUTE');
  }
  return jsonRequest(`${appwriteEndpoint}${route}`, {
    method,
    headers: accountHeaders(cookie),
    body,
    allowed,
  });
}

function sessionCookie(response) {
  const cookies = response.headers
    .getSetCookie()
    .map((value) => value.split(';')[0])
    .filter((value) => value.startsWith('a_session_'));
  if (cookies.length === 0) throw new Error('APPWRITE_SESSION_COOKIE_MISSING');
  return cookies.join('; ');
}

async function passwordSession(email, password, allowed = [201]) {
  const result = await accountRequest('POST', '/account/sessions/email', {
    body: { email, password },
    allowed,
  });
  return result.response.status === 201 ? sessionCookie(result.response) : undefined;
}

async function currentAccount(cookie) {
  const { value } = await jsonRequest(`${appwriteEndpoint}/account`, {
    headers: accountHeaders(cookie),
  });
  return value;
}

async function ensureLocalWebPlatform(setupKey) {
  const headers = {
    'x-appwrite-project': project,
    'x-appwrite-key': setupKey,
  };
  const route = `${appwriteEndpoint}/projects/${project}/platforms`;
  const listed = await jsonRequest(route, { headers });
  if (
    Array.isArray(listed.value?.platforms) &&
    listed.value.platforms.some(
      (candidate) => candidate?.type === 'web' && candidate.hostname === platform.hostname,
    )
  ) {
    return;
  }
  await jsonRequest(route, { method: 'POST', headers, body: platform, allowed: [201] });
}

async function mailpitMessages() {
  const { value } = await jsonRequest(`${mailpitEndpoint}/api/v1/messages?limit=50`);
  if (!Array.isArray(value?.messages)) throw new Error('MAILPIT_RESPONSE_INVALID');
  return value.messages;
}

async function mailpitMessage(id) {
  if (typeof id !== 'string' || !/^[A-Za-z0-9_-]+$/.test(id)) {
    throw new Error('MAILPIT_MESSAGE_ID_INVALID');
  }
  return (await jsonRequest(`${mailpitEndpoint}/api/v1/message/${id}`)).value;
}

async function baselineMessageIds() {
  return new Set((await mailpitMessages()).map((message) => message.ID));
}

async function waitForMail(email, excludedIds, extract) {
  const deadline = Date.now() + 60_000;
  while (Date.now() < deadline) {
    const candidates = await mailpitMessages();
    let candidate = findRecipientMessage(candidates, email, excludedIds);
    while (candidate) {
      excludedIds.add(candidate.ID);
      const message = await mailpitMessage(candidate.ID);
      try {
        return { messageId: candidate.ID, value: extract(message) };
      } catch (error) {
        if (!String(error?.message).startsWith('AUTH_MESSAGE_')) throw error;
      }
      candidate = findRecipientMessage(candidates, email, excludedIds);
    }
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  throw new Error('MAILPIT_AUTH_MESSAGE_TIMEOUT');
}

async function createSyntheticUser(setupKey, runId) {
  const record = {
    id: `as${runId}`,
    email: `as${runId}@cocenglish.local`,
    password: `A-${randomBytes(18).toString('base64url')}`,
  };
  const users = new Users(
    new Client().setEndpoint(appwriteEndpoint).setProject(project).setKey(setupKey),
  );
  const created = await users.create({
    userId: record.id,
    email: record.email,
    password: record.password,
    name: 'CocEnglish local auth acceptance',
  });
  if (created.$id !== record.id) throw new Error('SYNTHETIC_AUTH_ACCOUNT_CREATE_FAILED');
  return record;
}

function isEmailOtpProviderBlock(error) {
  return (
    [404, 501].includes(error?.status) ||
    ['general_route_not_found', 'general_not_implemented', 'user_auth_method_unsupported'].includes(
      error?.type,
    )
  );
}

async function runFresh() {
  const bootstrap = defaultReadJson(bootstrapFile);
  await ensureLocalWebPlatform(bootstrap.keys.setup);
  const runId = randomBytes(8).toString('hex');
  const user = await createSyntheticUser(bootstrap.keys.setup, runId);
  const evidence = {
    version: 1,
    endpoint: appwriteEndpoint,
    project,
    runId,
    createdAt: new Date().toISOString(),
    status: 'running',
    user,
    messages: {},
    emailVerification: false,
    passwordRecovery: false,
    emailOtp: false,
  };
  savePrivate(evidence);

  let cookie = await passwordSession(user.email, user.password);
  let baseline = await baselineMessageIds();
  await accountRequest('POST', '/account/verification', {
    cookie,
    body: { url: `${callbackOrigin}/auth/verify-email` },
    allowed: [201],
  });
  const verification = await waitForMail(user.email, baseline, (message) =>
    parseCallbackParameters(message, '/auth/verify-email'),
  );
  evidence.messages.verification = verification.messageId;
  await accountRequest('PUT', '/account/verification', {
    cookie,
    body: verification.value,
  });
  if ((await currentAccount(cookie)).emailVerification !== true) {
    throw new Error('EMAIL_VERIFICATION_NOT_APPLIED');
  }
  evidence.emailVerification = true;
  savePrivate(evidence);

  baseline = await baselineMessageIds();
  await accountRequest('POST', '/account/recovery', {
    body: { email: user.email, url: `${callbackOrigin}/auth/reset-password` },
    allowed: [201],
  });
  const recovery = await waitForMail(user.email, baseline, (message) =>
    parseCallbackParameters(message, '/auth/reset-password'),
  );
  evidence.messages.recovery = recovery.messageId;
  const newPassword = `R-${randomBytes(18).toString('base64url')}`;
  await accountRequest('PUT', '/account/recovery', {
    body: { ...recovery.value, password: newPassword },
  });
  await passwordSession(user.email, user.password, [401]);
  cookie = await passwordSession(user.email, newPassword);
  if ((await currentAccount(cookie)).$id !== user.id) throw new Error('RECOVERY_SESSION_MISMATCH');
  user.password = newPassword;
  evidence.passwordRecovery = true;
  savePrivate(evidence);

  try {
    baseline = await baselineMessageIds();
    const token = await accountRequest('POST', '/account/tokens/email', {
      body: { userId: user.id, email: user.email },
      allowed: [201],
    });
    const otp = await waitForMail(user.email, baseline, parseEmailOtp);
    evidence.messages.emailOtp = otp.messageId;
    const otpSession = await accountRequest('POST', '/account/sessions/token', {
      body: { userId: token.value.userId, secret: otp.value },
      allowed: [201],
    });
    const otpCookie = sessionCookie(otpSession.response);
    if ((await currentAccount(otpCookie)).$id !== user.id) {
      throw new Error('EMAIL_OTP_SESSION_MISMATCH');
    }
    evidence.emailOtp = true;
  } catch (error) {
    if (!isEmailOtpProviderBlock(error)) throw error;
    evidence.emailOtpBlocker = 'provider_disabled';
  }

  evidence.status = evidence.emailOtp ? 'passed' : 'passed_with_provider_blocker';
  evidence.completedAt = new Date().toISOString();
  savePrivate(evidence);
  return evidence;
}

async function execute() {
  const action = process.argv[2] ?? 'run';
  if (!['run', '--check'].includes(action)) throw new Error('UNKNOWN_LOCAL_AUTH_SMOKE_ACTION');
  const checked = checkLocalAuthSmoke({ root });
  if (action === '--check') {
    process.stdout.write(`${JSON.stringify(checked)}\n`);
    return;
  }
  if (process.env[childMarker] !== '1') {
    const child = spawnSync(process.execPath, [fileURLToPath(import.meta.url)], {
      cwd: root,
      stdio: 'inherit',
      timeout: 900_000,
      env: disposableRuntimeEnv({ NODE_EXTRA_CA_CERTS: caFile, [childMarker]: '1' }),
    });
    if (child.error || child.status !== 0) throw new Error('LOCAL_AUTH_SMOKE_CHILD_FAILED');
    return;
  }
  process.stdout.write(`${JSON.stringify(publicAuthSummary(await runFresh()))}\n`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  execute().catch((error) => {
    const safe =
      error instanceof Error && /^[A-Z0-9_:.-]+$/.test(error.message)
        ? error.message
        : 'LOCAL_AUTH_SMOKE_FAILED';
    process.stderr.write(`${safe}\n`);
    process.exitCode = 1;
  });
}
