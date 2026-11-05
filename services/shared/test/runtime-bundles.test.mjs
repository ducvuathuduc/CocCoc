import test from 'node:test';
import { disposableRuntimeEnv } from '../../../tools/scripts/runtime-test-env.mjs';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import fs from 'node:fs';
import net from 'node:net';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');

async function freePort() {
  const server = net.createServer();
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  await new Promise((resolve) => server.close(resolve));
  return port;
}

async function waitFor(url) {
  for (let attempt = 0; attempt < 80; attempt++) {
    try {
      const response = await fetch(url);
      if (response.status) return response;
    } catch {}
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  throw new Error('runtime did not listen');
}

for (const service of ['learning', 'progress', 'ai']) {
  test(`${service} native HTTP bundle is live and private routes fail closed`, async (t) => {
    const port = await freePort();
    const child = spawn(process.execPath, [`services/${service}/dist/http.mjs`], {
      cwd: root,
      env: disposableRuntimeEnv({
        HOST: '127.0.0.1',
        PORT: String(port),
        APPWRITE_FUNCTION_API_ENDPOINT: '',
        APPWRITE_FUNCTION_PROJECT_ID: '',
        APPWRITE_API_KEY: '',
      }),
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    t.after(async () => {
      if (child.exitCode === null) child.kill('SIGTERM');
      await Promise.race([
        once(child, 'exit'),
        new Promise((resolve) => setTimeout(resolve, 2000)),
      ]);
    });
    const health = await waitFor(`http://127.0.0.1:${port}/health`);
    assert.equal(health.status, 200);
    const privateResponse = await fetch(`http://127.0.0.1:${port}/v1/private`, {
      headers: {
        authorization: 'Bearer fake',
        'x-appwrite-key': 'forged',
        'x-appwrite-trigger': 'schedule',
      },
    });
    assert.equal(privateResponse.status, 503);
    assert.match(await privateResponse.text(), /SERVICE_NOT_CONFIGURED/);
  });

  test(`${service} native bundles contain no dev or memory adapter markers`, () => {
    for (const entry of ['http', 'worker']) {
      const bundle = fs.readFileSync(
        path.join(root, `services/${service}/dist/${entry}.mjs`),
        'utf8',
      );
      assert.doesNotMatch(bundle, /src\/dev|createMemory|LOCAL TEST ADAPTER|failNextCommit/);
    }
  });
}

test('standalone worker stays resident across a tick and exits cleanly on SIGTERM', async () => {
  const child = spawn(process.execPath, ['services/learning/dist/worker.mjs'], {
    cwd: root,
    env: disposableRuntimeEnv({ COC_WORKER_INTERVAL_MS: '1000' }),
    stdio: 'ignore',
  });
  await new Promise((resolve) => setTimeout(resolve, 1200));
  assert.equal(child.exitCode, null, 'worker exited after its disabled first tick');
  child.kill('SIGTERM');
  const [code, signal] = await Promise.race([
    once(child, 'exit'),
    new Promise((_, reject) => setTimeout(() => reject(new Error('worker did not stop')), 2000)),
  ]);
  assert.ok(
    (code === 0 && signal === null) || (code === null && signal === 'SIGTERM'),
    `unexpected worker exit: code=${code} signal=${signal}`,
  );
});
