import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { createHash, createHmac, randomBytes, randomUUID } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { Client, Users } from 'node-appwrite';
import { correctAnswer } from '../../services/learning/test/helpers/answers.mjs';
import { disposableRuntimeEnv } from './runtime-test-env.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const privateDir = path.join(root, '.secrets/local-dev');
const evidenceFile = path.join(privateDir, 'learning-smoke.json');
const caFile = path.join(privateDir, 'tls/ca.crt');
const bootstrapFile = path.join(privateDir, 'bootstrap.json');
const appwriteEndpoint = 'https://127.0.0.1:8443/v1';
const project = 'cocenglish-local';
const services = {
  learning: 'https://127.0.0.1:4101',
  progress: 'https://127.0.0.1:4102',
  ai: 'https://127.0.0.1:4103',
};
const localHost = '127.0.0.1';
const childMarker = 'COC_LOCAL_LEARNING_SMOKE_TLS';

function fileApi(platform) {
  return platform === 'win32' ? path.win32 : path.posix;
}

function defaultReadJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

export function checkLocalLearningSmoke({
  root: repositoryRoot,
  platform = process.platform,
  statFile = fs.statSync,
  readJson = defaultReadJson,
}) {
  const api = fileApi(platform);
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
    throw new Error('LOCAL_SMOKE_CONFIGURATION_INVALID');
  }
  return { status: 'ready', project };
}

export function rewardSnapshot(value) {
  const fields = [
    'completionId',
    'status',
    'studyXp',
    'leagueXp',
    'gems',
    'freezeSlots',
    'currentStreak',
    'awardXp',
    'revision',
  ];
  return Object.fromEntries(fields.map((field) => [field, value[field]]));
}

export function validateRestartEvidence(value) {
  const validUser = (user) =>
    typeof user?.id === 'string' &&
    /^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$/.test(user.id) &&
    typeof user.email === 'string' &&
    user.email.endsWith('@cocenglish.local') &&
    typeof user.password === 'string' &&
    user.password.length >= 12;
  if (
    value?.version !== 1 ||
    value.endpoint !== appwriteEndpoint ||
    value.project !== project ||
    typeof value.runId !== 'string' ||
    !Array.isArray(value.users) ||
    value.users.length !== 2 ||
    !value.users.every(validUser) ||
    typeof value.sessionId !== 'string' ||
    value.sessionId.length === 0 ||
    typeof value.lessonId !== 'string' ||
    value.lessonId.length === 0 ||
    value.completionId !== value.sessionId ||
    typeof value.rewards !== 'object' ||
    value.rewards?.completionId !== value.completionId
  ) {
    throw new Error('Restart evidence invalid.');
  }
  return value;
}

export function publicSummary(value) {
  return {
    status: 'passed',
    rewardIdentity: value.completionId,
    rewardStatus: value.rewards.status,
    awardXp: value.rewards.awardXp,
    studyXp: value.rewards.studyXp,
    revision: value.rewards.revision,
  };
}

function savePrivate(value) {
  const temporary = `${evidenceFile}.${process.pid}.tmp`;
  fs.writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
  fs.renameSync(temporary, evidenceFile);
}

async function appwriteJwt(email, password) {
  const headers = { 'content-type': 'application/json', 'x-appwrite-project': project };
  const session = await fetch(`${appwriteEndpoint}/account/sessions/email`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ email, password }),
    redirect: 'error',
    signal: AbortSignal.timeout(30_000),
  });
  if (session.status !== 201) throw new Error(`APPWRITE_SESSION_FAILED:${session.status}`);
  const cookies = session.headers
    .getSetCookie()
    .map((cookie) => cookie.split(';')[0])
    .filter((cookie) => cookie.startsWith('a_session_'));
  if (cookies.length === 0) throw new Error('APPWRITE_SESSION_COOKIE_MISSING');
  const response = await fetch(`${appwriteEndpoint}/account/jwts`, {
    method: 'POST',
    headers: { ...headers, cookie: cookies.join('; ') },
    redirect: 'error',
    signal: AbortSignal.timeout(30_000),
  });
  if (response.status !== 201) throw new Error(`APPWRITE_JWT_FAILED:${response.status}`);
  const value = await response.json();
  if (typeof value.jwt !== 'string' || value.jwt.length < 20)
    throw new Error('APPWRITE_JWT_MISSING');
  return value.jwt;
}

async function request(
  base,
  method,
  route,
  { jwt, body, key, headers = {}, allowed = [200] } = {},
) {
  const baseUrl = new URL(base);
  if (
    baseUrl.protocol !== 'https:' ||
    baseUrl.hostname !== localHost ||
    !route.startsWith('/') ||
    route.startsWith('//') ||
    route.includes('://')
  ) {
    throw new Error('UNSAFE_LOCAL_REQUEST');
  }
  const response = await fetch(`${base}${route}`, {
    method,
    redirect: 'error',
    signal: AbortSignal.timeout(30_000),
    headers: {
      'content-type': 'application/json',
      'x-request-id': randomUUID(),
      ...(jwt ? { authorization: `Bearer ${jwt}` } : {}),
      ...(key ? { 'idempotency-key': key } : {}),
      ...headers,
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const value = await response.json().catch(() => ({}));
  if (!allowed.includes(response.status)) {
    const code = typeof value?.error?.code === 'string' ? value.error.code : 'UPSTREAM_ERROR';
    throw new Error(`LOCAL_REQUEST_FAILED:${response.status}:${code}`);
  }
  return { status: response.status, body: value };
}

function readinessHeaders(key) {
  if (
    key?.sender !== 'maintainer' ||
    typeof key.keyId !== 'string' ||
    typeof key.secretHex !== 'string' ||
    !/^[0-9a-f]{64,}$/i.test(key.secretHex)
  ) {
    throw new Error('LOCAL_MAINTAINER_KEY_INVALID');
  }
  const timestamp = String(Math.floor(Date.now() / 1000));
  const bodyHash = createHash('sha256').update('').digest('hex');
  const signed = `${timestamp}\nGET\n/ready\n${bodyHash}`;
  return {
    'X-Service-Key-Id': key.keyId,
    'X-Service-Timestamp': timestamp,
    'X-Service-Signature': createHmac('sha256', Buffer.from(key.secretHex, 'hex'))
      .update(signed, 'utf8')
      .digest('hex'),
  };
}

async function verifyServices(serviceKey) {
  for (const [name, base] of Object.entries(services)) {
    const health = await request(base, 'GET', '/health');
    if (health.body.service !== name) throw new Error('HEALTH_IDENTITY_MISMATCH');
    await request(base, 'GET', '/ready', { headers: readinessHeaders(serviceKey) });
  }
}

async function initializeProgress(jwt) {
  await request(services.progress, 'POST', '/v1/me/initialize', {
    jwt,
    key: randomUUID(),
    body: {},
  });
}

async function rewards(jwt, completionId) {
  const suffix = completionId ? `?completionId=${encodeURIComponent(completionId)}` : '';
  return (await request(services.progress, 'GET', `/v1/me/rewards${suffix}`, { jwt })).body;
}

async function assertPrivate(jwt, sessionId) {
  const result = await request(services.learning, 'GET', `/v1/sessions/${sessionId}`, {
    jwt,
    allowed: [403, 404],
  });
  if (JSON.stringify(result.body).includes('acceptedAnswer'))
    throw new Error('PRIVATE_ANSWER_EXPOSED');
}

async function pollReward(jwt, completionId) {
  const deadline = Date.now() + 90_000;
  while (Date.now() < deadline) {
    const value = await rewards(jwt, completionId);
    if (value.completionId === completionId && ['credited', 'capped'].includes(value.status)) {
      return value;
    }
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }
  throw new Error('REWARD_SETTLEMENT_TIMEOUT');
}

async function createSyntheticUsers(setupKey, runId) {
  const users = new Users(
    new Client().setEndpoint(appwriteEndpoint).setProject(project).setKey(setupKey),
  );
  const records = ['a', 'b'].map((suffix) => {
    const id = `ls${runId}${suffix}`;
    return {
      id,
      email: `${id}@cocenglish.local`,
      password: `L-${randomBytes(18).toString('base64url')}`,
    };
  });
  for (const record of records) {
    try {
      const created = await users.create({
        userId: record.id,
        email: record.email,
        password: record.password,
        name: 'CocEnglish local acceptance',
      });
      if (created.$id !== record.id) throw new Error('identity');
    } catch {
      throw new Error('SYNTHETIC_ACCOUNT_CREATE_FAILED');
    }
  }
  return records;
}

async function runFresh() {
  const bootstrap = defaultReadJson(bootstrapFile);
  const runId = randomBytes(8).toString('hex');
  const users = await createSyntheticUsers(bootstrap.keys.setup, runId);
  const runningEvidence = {
    version: 1,
    endpoint: appwriteEndpoint,
    project,
    runId,
    createdAt: new Date().toISOString(),
    status: 'running',
    users,
  };
  savePrivate(runningEvidence);
  const [aliceJwt, bobJwt] = await Promise.all(
    users.map((user) => appwriteJwt(user.email, user.password)),
  );
  await verifyServices(bootstrap.serviceKeys?.find((key) => key.sender === 'maintainer'));
  await initializeProgress(aliceJwt);
  await initializeProgress(bobJwt);
  const before = await rewards(aliceJwt);
  const enrollment = (
    await request(services.learning, 'POST', '/v1/enrollments', {
      jwt: aliceJwt,
      key: randomUUID(),
      body: { courseId: 'vi_en', startPoint: 'beginner' },
    })
  ).body;
  const coursePath = (
    await request(services.learning, 'GET', '/v1/courses/vi_en/path', { jwt: aliceJwt })
  ).body;
  const node = coursePath.nodes.find(
    (candidate) =>
      ['available', 'current'].includes(candidate.state) && candidate.lessonIds?.length > 0,
  );
  if (!node) throw new Error('NO_AVAILABLE_LOCAL_LESSON');
  const lessonId = node.lessonIds[0];
  const session = (
    await request(services.learning, 'POST', '/v1/sessions', {
      jwt: aliceJwt,
      key: randomUUID(),
      body: {
        courseId: 'vi_en',
        lessonId,
        mode: 'LESSON',
        expectedEnrollmentRevision: enrollment.revision,
      },
    })
  ).body;
  let revision = session.revision;
  for (const [index, exercise] of session.bundle.exercises.entries()) {
    const key = randomUUID();
    const body = {
      exerciseId: exercise.id,
      attemptOrdinal: 0,
      answer: correctAnswer(exercise),
      assisted: false,
      substituted: false,
      expectedRevision: revision,
    };
    const answered = await request(
      services.learning,
      'POST',
      `/v1/sessions/${session.sessionId}/answers`,
      { jwt: aliceJwt, key, body },
    );
    if (!answered.body.correct) throw new Error('AUTHORED_ANSWER_REJECTED');
    if (index === 0) {
      const replay = await request(
        services.learning,
        'POST',
        `/v1/sessions/${session.sessionId}/answers`,
        { jwt: aliceJwt, key, body },
      );
      assert.deepEqual(replay.body, answered.body);
    }
    revision = answered.body.sessionRevision;
  }
  await assertPrivate(bobJwt, session.sessionId);
  const completionBody = { expectedRevision: revision };
  const completionKey = randomUUID();
  const completion = await request(
    services.learning,
    'POST',
    `/v1/sessions/${session.sessionId}/complete`,
    { jwt: aliceJwt, key: completionKey, body: completionBody },
  );
  const sameKey = await request(
    services.learning,
    'POST',
    `/v1/sessions/${session.sessionId}/complete`,
    { jwt: aliceJwt, key: completionKey, body: completionBody },
  );
  const newKey = await request(
    services.learning,
    'POST',
    `/v1/sessions/${session.sessionId}/complete`,
    { jwt: aliceJwt, key: randomUUID(), body: completionBody },
  );
  assert.deepEqual(sameKey.body, completion.body);
  assert.deepEqual(newKey.body, completion.body);
  if (completion.body.completionId !== session.sessionId) throw new Error('COMPLETION_ID_MISMATCH');
  const settled = await pollReward(aliceJwt, completion.body.completionId);
  if (
    settled.awardXp === null ||
    settled.awardXp <= 0 ||
    settled.studyXp - before.studyXp !== settled.awardXp
  ) {
    throw new Error('REWARD_DUPLICATE_OR_MISSING');
  }
  const finalSession = (
    await request(services.learning, 'GET', `/v1/sessions/${session.sessionId}`, { jwt: aliceJwt })
  ).body;
  if (finalSession.status !== 'COMPLETED') throw new Error('SESSION_NOT_DURABLE');
  const finalPath = (
    await request(services.learning, 'GET', '/v1/courses/vi_en/path', { jwt: aliceJwt })
  ).body;
  if (!finalPath.enrollment.completedLessonIds.includes(lessonId)) {
    throw new Error('PATH_NOT_ADVANCED');
  }
  const evidence = {
    ...runningEvidence,
    status: 'passed',
    completedAt: new Date().toISOString(),
    sessionId: session.sessionId,
    lessonId,
    completionId: completion.body.completionId,
    completion: completion.body,
    rewards: rewardSnapshot(settled),
  };
  savePrivate(evidence);
  return evidence;
}

async function runRestartVerification() {
  const evidence = validateRestartEvidence(defaultReadJson(evidenceFile));
  const bootstrap = defaultReadJson(bootstrapFile);
  const [aliceJwt, bobJwt] = await Promise.all(
    evidence.users.map((user) => appwriteJwt(user.email, user.password)),
  );
  await verifyServices(bootstrap.serviceKeys?.find((key) => key.sender === 'maintainer'));
  const session = (
    await request(services.learning, 'GET', `/v1/sessions/${evidence.sessionId}`, { jwt: aliceJwt })
  ).body;
  if (session.status !== 'COMPLETED' || session.lessonId !== evidence.lessonId) {
    throw new Error('RESTART_SESSION_MISMATCH');
  }
  await assertPrivate(bobJwt, evidence.sessionId);
  const current = rewardSnapshot(await rewards(aliceJwt, evidence.completionId));
  assert.deepEqual(current, evidence.rewards);
  await new Promise((resolve) => setTimeout(resolve, 1200));
  assert.deepEqual(
    rewardSnapshot(await rewards(aliceJwt, evidence.completionId)),
    evidence.rewards,
  );
  return evidence;
}

async function execute() {
  const action = process.argv[2] ?? 'run';
  if (!['run', '--check', '--verify-restart'].includes(action)) {
    throw new Error('UNKNOWN_LOCAL_LEARNING_SMOKE_ACTION');
  }
  const checked = checkLocalLearningSmoke({ root });
  if (action === '--check') {
    process.stdout.write(`${JSON.stringify(checked)}\n`);
    return;
  }
  if (process.env[childMarker] !== '1') {
    const args = [fileURLToPath(import.meta.url), ...(action === 'run' ? [] : [action])];
    const child = spawnSync(process.execPath, args, {
      cwd: root,
      stdio: 'inherit',
      timeout: 900_000,
      env: disposableRuntimeEnv({ NODE_EXTRA_CA_CERTS: caFile, [childMarker]: '1' }),
    });
    if (child.error || child.status !== 0) throw new Error('LOCAL_LEARNING_SMOKE_CHILD_FAILED');
    return;
  }
  const evidence =
    action === '--verify-restart' ? await runRestartVerification() : await runFresh();
  process.stdout.write(`${JSON.stringify(publicSummary(evidence))}\n`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  execute().catch((error) => {
    const safe =
      error instanceof Error && /^[A-Z0-9_:.-]+$/.test(error.message)
        ? error.message
        : 'LOCAL_LEARNING_SMOKE_FAILED';
    process.stderr.write(`${safe}\n`);
    process.exitCode = 1;
  });
}
