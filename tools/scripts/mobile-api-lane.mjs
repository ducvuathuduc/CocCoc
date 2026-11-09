// `node tools/scripts/mobile-api-lane.mjs [--port 4181] [-- <extra flutter test args>]`
// The Flutter API-mode lane. It starts the Learning test backend (api-lane-backend.mjs, fresh state,
// 127.0.0.1 only), runs apps/mobile/test_api with the build defines a real API build carries, and
// stops the backend whatever happens. The mock-mode suite (`pnpm verify`, test/) is unaffected:
// that stays the undeclared build. This lane never reads or edits config/real.public.json; release
// builds keep it (tools/tests/mobile-release-config.test.mjs pins that).
//
// Needs a Flutter SDK (FLUTTER_ROOT, PATH or .cache/flutter) with `flutter pub get` done. Without
// one it exits 2 with BLOCKED: that is not a pass.
import { spawn, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { findFlutterRoot } from './flutter-toolchain.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const mobile = path.join(root, 'apps', 'mobile');
const args = process.argv.slice(2);
const split = args.indexOf('--');
const own = split === -1 ? args : args.slice(0, split);
const extra = split === -1 ? [] : args.slice(split + 1);
const flag = (name, fallback) => {
  const index = own.indexOf(`--${name}`);
  return index === -1 ? fallback : own[index + 1];
};

const toolchain = findFlutterRoot(root);
if (!toolchain) {
  console.error(
    JSON.stringify({
      status: 'BLOCKED',
      reason: 'Flutter SDK not found or not initialised (FLUTTER_ROOT, PATH, .cache/flutter)',
    }),
  );
  process.exit(2);
}

const port = Number(flag('port', process.env.COC_API_LANE_PORT ?? 4181));
const stateFile = path.join(root, '.cache', 'api-lane', 'state.json');
fs.rmSync(stateFile, { force: true });

const backend = spawn(
  process.execPath,
  [
    path.join(root, 'tools', 'scripts', 'api-lane-backend.mjs'),
    '--port',
    String(port),
    '--state',
    stateFile,
  ],
  { cwd: root, stdio: ['ignore', 'pipe', 'inherit'] },
);
const stop = () => {
  if (!backend.killed) backend.kill();
};
process.on('exit', stop);
for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => {
    stop();
    process.exit(130);
  });
}

function waitForReady(timeoutMs) {
  return new Promise((resolve, reject) => {
    let buffered = '';
    const timer = setTimeout(
      () => reject(new Error('lane backend did not become ready')),
      timeoutMs,
    );
    backend.once('exit', (code) => reject(new Error(`lane backend exited early (${code})`)));
    backend.stdout.on('data', (chunk) => {
      buffered += chunk;
      for (const line of buffered.split('\n')) {
        try {
          const message = JSON.parse(line);
          if (message.status === 'READY') {
            clearTimeout(timer);
            resolve(message);
          }
        } catch {
          // not the ready line
        }
      }
    });
  });
}

let exitCode = 1;
try {
  const ready = await waitForReady(180_000);
  console.log(`> lane backend ${ready.url}`);
  const result = spawnSync(
    toolchain.dartExecutable,
    [
      toolchain.flutterSnapshot,
      'test',
      'test_api',
      '--no-pub',
      '--concurrency=1',
      '--dart-define=DATA_SOURCE=api',
      '--dart-define=USE_MOCK_AUTH=false',
      '--dart-define=ALLOW_INSECURE_LOCAL_ENDPOINTS=true',
      `--dart-define=LEARNING_API_URL=${ready.url}`,
      `--dart-define=API_LANE_STATE=${stateFile}`,
      ...extra,
    ],
    {
      cwd: mobile,
      env: { ...process.env, FLUTTER_ROOT: toolchain.flutterRoot },
      stdio: 'inherit',
    },
  );
  exitCode = result.status ?? 1;
  console.log(
    JSON.stringify({
      status: exitCode === 0 ? 'PASS' : 'FAIL',
      lane: 'flutter-api-mode',
      backend: ready.url,
      scope: 'Flutter runtime against the local Learning service; no cloud, no Appwrite, no device',
    }),
  );
} catch (error) {
  console.error(JSON.stringify({ status: 'FAIL', reason: String(error.message ?? error) }));
} finally {
  stop();
}
process.exit(exitCode);
