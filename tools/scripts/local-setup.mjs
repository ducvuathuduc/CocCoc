import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { prepareLocalConfig, writeLocalMobileDefines } from './local-config.mjs';
import { runLocalDev } from './local-dev-lib.mjs';
import { disposableRuntimeEnv } from './runtime-test-env.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const dir = path.join(root, '.secrets/local-dev');
const logs = path.join(root, '.cache/local-dev');
const env = disposableRuntimeEnv();
function run(command, args, stage) {
  const log = path.join(logs, `${stage}.log`);
  const descriptor = fs.openSync(log, 'w');
  try {
    const child = spawnSync(command, args, {
      cwd: root,
      env,
      shell: false,
      windowsHide: true,
      stdio: ['ignore', descriptor, descriptor],
      timeout: 900_000,
    });
    if (child.error || child.status !== 0)
      throw new Error(`${stage} failed. Inspect ${log} (private local diagnostics).`);
  } finally {
    fs.closeSync(descriptor);
  }
  console.log(`${stage}: passed`);
}
try {
  if (Number(process.versions.node.split('.')[0]) !== 22) throw new Error('Node 22 required.');
  fs.mkdirSync(logs, { recursive: true });
  prepareLocalConfig(dir);
  if (process.platform === 'win32') {
    run(
      'wsl.exe',
      [
        '-d',
        'CocEnglishDev',
        '-u',
        'root',
        '--cd',
        root,
        '--exec',
        'bash',
        'tools/scripts/local-tls-bootstrap.sh',
      ],
      'local-tls',
    );
  } else run('bash', ['tools/scripts/local-tls-bootstrap.sh'], 'local-tls');
  writeLocalMobileDefines(dir);
  console.log('Starting isolated Docker stack (first image download/build takes several minutes).');
  await runLocalDev({ argv: ['up'], root });
  for (const action of ['bootstrap', 'schema', 'probe', 'publish', 'admit']) {
    run(process.execPath, ['tools/scripts/local-appwrite.mjs', action], `appwrite-${action}`);
  }
  await runLocalDev({ argv: ['up'], root });
  run(process.execPath, ['tools/scripts/local-learning-smoke.mjs'], 'learning-smoke');
  run(process.execPath, ['tools/scripts/local-auth-smoke.mjs'], 'auth-smoke');
  console.log('Durable local environment ready. Start/stop with pnpm local:up / pnpm local:stop.');
} catch (error) {
  console.error(error instanceof Error ? error.message : 'Local setup failed.');
  process.exitCode = 1;
}
