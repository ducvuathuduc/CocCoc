import { createHash, createHmac } from 'node:crypto';
import { spawn, spawnSync } from 'node:child_process';
import { once } from 'node:events';
import net from 'node:net';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { disposableRuntimeEnv } from './runtime-test-env.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const services = ['learning', 'progress', 'ai'];
const children = [];
const secretHex = '17'.repeat(32);
const keyring = JSON.stringify([{ keyId: 'runtime-check', sender: 'maintainer', secretHex }]);

function runBuild() {
  const result = spawnSync(process.execPath, ['tools/scripts/backend-check.mjs', '--build'], {
    cwd: root,
    stdio: 'inherit',
  });
  if (result.error || result.status !== 0) process.exit(result.status || 1);
}

async function freePort() {
  const server = net.createServer();
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  const { port } = server.address();
  await new Promise((resolve) => server.close(resolve));
  return port;
}

function signedReadyHeaders() {
  const timestamp = String(Math.floor(Date.now() / 1000));
  const bodyHash = createHash('sha256').update('').digest('hex');
  const message = `${timestamp}\nGET\n/ready\n${bodyHash}`;
  const signature = createHmac('sha256', Buffer.from(secretHex, 'hex'))
    .update(message, 'utf8')
    .digest('hex');
  return {
    'X-Service-Key-Id': 'runtime-check',
    'X-Service-Timestamp': timestamp,
    'X-Service-Signature': signature,
  };
}

async function fetchReady(url) {
  for (let attempt = 0; attempt < 100; attempt++) {
    try {
      return await fetch(url, { signal: AbortSignal.timeout(1000) });
    } catch {}
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  throw new Error('RUNTIME_START_TIMEOUT');
}

async function stopChildren() {
  await Promise.all(
    children.map(async (child) => {
      if (child.exitCode === null) child.kill('SIGTERM');
      await Promise.race([
        once(child, 'exit'),
        new Promise((resolve) => setTimeout(resolve, 2000)),
      ]);
      if (child.exitCode === null) child.kill('SIGKILL');
    }),
  );
}

if (!process.argv.includes('--skip-build')) runBuild();

try {
  const ports = await Promise.all(services.map(() => freePort()));
  for (const [index, service] of services.entries()) {
    const child = spawn(process.execPath, [`services/${service}/dist/http.mjs`], {
      cwd: root,
      env: disposableRuntimeEnv({
        HOST: '127.0.0.1',
        PORT: String(ports[index]),
        COC_SERVICE_KEYS: keyring,
        APPWRITE_FUNCTION_API_ENDPOINT: '',
        APPWRITE_FUNCTION_PROJECT_ID: '',
        APPWRITE_API_KEY: '',
      }),
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    children.push(child);
  }

  for (const [index, service] of services.entries()) {
    const base = `http://127.0.0.1:${ports[index]}`;
    const health = await fetchReady(`${base}/health`);
    if (health.status !== 200) throw new Error(`${service.toUpperCase()}_HEALTH_FAILED`);
    const ready = await fetch(`${base}/ready`, { headers: signedReadyHeaders() });
    if (ready.status !== 503) throw new Error(`${service.toUpperCase()}_READY_NOT_CLOSED`);
    const privateResponse = await fetch(`${base}/v1/private`, {
      headers: {
        authorization: 'Bearer fake',
        'x-appwrite-key': 'forged',
        'x-appwrite-trigger': 'schedule',
      },
    });
    if (privateResponse.status !== 503)
      throw new Error(`${service.toUpperCase()}_PRIVATE_NOT_CLOSED`);
  }
  process.stdout.write(
    `${JSON.stringify({ status: 'PASS', scope: 'local native runtime; no cloud admission' })}\n`,
  );
} finally {
  await stopChildren();
}
