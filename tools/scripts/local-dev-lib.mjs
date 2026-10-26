import fs from 'node:fs';
import net from 'node:net';
import path from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import { disposableRuntimeEnv } from './runtime-test-env.mjs';

export const COMPOSE_PROJECT = 'cocenglish-dev';
export const COMPOSE_FILE = 'infra/docker/compose.dev.yaml';
export const COMPOSE_ENV = '.secrets/local-dev/compose.env';
export const LOG_SERVICES = [
  'appwrite',
  'learning',
  'progress',
  'ai',
  'redis',
  'rabbitmq',
  'mailpit',
];
export const LOCAL_PORTS = [8443, 4101, 4102, 4103, 8025];
const COMMANDS = ['doctor', 'up', 'status', 'stop', 'logs'];
const CONTROL = /[\u0000-\u001f\u007f]/;
const PROCESS_TIMEOUT_MS = 30_000;
const UP_PROCESS_TIMEOUT_MS = 330_000;
const KEEPER_QUERY_TIMEOUT_MS = 5_000;
const REQUIRED_LOCAL_FILES = [
  'compose.env',
  'appwrite.env',
  'learning.env',
  'progress.env',
  'ai.env',
  'tls/ca.crt',
  'tls/server.crt',
  'tls/server.key',
];

function assertSafeText(value, label) {
  if (typeof value !== 'string' || value === '' || CONTROL.test(value)) {
    throw new Error(`${label} contains a control character or is empty.`);
  }
}

function pathApi(platform) {
  return platform === 'win32' ? path.win32 : path.posix;
}

function relativeInside(root, candidate, platform) {
  const api = pathApi(platform);
  const absolute = api.resolve(root, candidate);
  const relative = api.relative(api.resolve(root), absolute);
  if (relative === '..' || relative.startsWith(`..${api.sep}`) || api.isAbsolute(relative)) {
    throw new Error('Local Docker paths must stay inside repository root.');
  }
  return relative.split(api.sep).join('/');
}

export function validateLocalDevPaths({
  root,
  platform = process.platform,
  composeFile = COMPOSE_FILE,
  envFile = COMPOSE_ENV,
}) {
  assertSafeText(root, 'Repository root');
  assertSafeText(composeFile, 'Compose path');
  assertSafeText(envFile, 'Environment path');
  const api = pathApi(platform);
  if (!api.isAbsolute(root)) throw new Error('Repository root must be absolute.');
  return {
    root: api.resolve(root),
    composeFile: relativeInside(root, composeFile, platform),
    envFile: relativeInside(root, envFile, platform),
  };
}

function windowsPathForWsl(root) {
  const match = /^([A-Za-z]):\\(.*)$/.exec(root);
  if (!match) throw new Error('WSL fallback requires an absolute Windows drive path.');
  const drive = match[1].toLowerCase();
  const rest = match[2].split('\\').join('/');
  return `/mnt/${drive}/${rest}`;
}

export function dockerCandidates({ platform = process.platform, root }) {
  const paths = validateLocalDevPaths({ root, platform });
  const candidates = [{ command: 'docker', prefixArgs: [] }];
  if (platform === 'win32') {
    candidates.push({
      command: 'wsl.exe',
      prefixArgs: [
        '-d',
        'CocEnglishDev',
        '-u',
        'root',
        '--cd',
        windowsPathForWsl(paths.root),
        '--exec',
        'docker',
      ],
    });
  }
  return candidates;
}

export function parseLocalDevArgs(argv) {
  for (const value of argv) assertSafeText(value, 'Argument');
  const [command, ...rest] = argv;
  if (!COMMANDS.includes(command)) {
    throw new Error(`Unknown local-dev command. Choose ${COMMANDS.join('|')}.`);
  }
  if (command === 'logs') {
    if (rest.length !== 1) throw new Error('logs requires one service.');
    if (!LOG_SERVICES.includes(rest[0]))
      throw new Error('Unsafe service. Use the local log allowlist.');
    return { command, service: rest[0] };
  }
  if (rest.length !== 0) throw new Error(`${command} does not accept arguments.`);
  return { command };
}

export function composeInvocation(
  docker,
  command,
  { root, platform = process.platform, service, composeFile = COMPOSE_FILE, envFile = COMPOSE_ENV },
) {
  const paths = validateLocalDevPaths({ root, platform, composeFile, envFile });
  if (!COMMANDS.includes(command) || command === 'doctor')
    throw new Error('Unsafe compose command.');
  let action;
  if (command === 'up') action = ['up', '--detach', '--wait', '--wait-timeout', '300'];
  else if (command === 'status') action = ['ps'];
  else if (command === 'stop') action = ['stop'];
  else {
    if (!LOG_SERVICES.includes(service))
      throw new Error('Unsafe service. Use the local log allowlist.');
    action = ['logs', '--tail', '100', service];
  }
  return {
    command: docker.command,
    args: [
      ...docker.prefixArgs,
      'compose',
      '--project-name',
      COMPOSE_PROJECT,
      '--file',
      paths.composeFile,
      '--env-file',
      paths.envFile,
      ...action,
    ],
    cwd: paths.root,
  };
}

export function isolatedDockerEnv(source = process.env) {
  return disposableRuntimeEnv({}, source);
}

function runProcess(spec) {
  const result = spawnSync(spec.command, spec.args, {
    cwd: spec.cwd,
    env: spec.env,
    encoding: 'utf8',
    shell: false,
    timeout: spec.timeoutMs,
    maxBuffer: 2_000_000,
    windowsHide: true,
  });
  return {
    status: result.status,
    stdout: result.stdout ?? '',
    stderr: result.stderr ?? result.error?.message ?? '',
  };
}

function readTextFile(file) {
  return fs.readFileSync(file, 'utf8');
}

function writeTextFile(file, value) {
  const temporary = `${file}.${process.pid}.tmp`;
  fs.writeFileSync(temporary, value, { encoding: 'utf8', mode: 0o600 });
  fs.renameSync(temporary, file);
}

function processIsAlive(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

function queryWindowsProcess(pid, env) {
  if (!Number.isSafeInteger(pid) || pid <= 0) throw new Error('Invalid keeper PID.');
  const script =
    `$process = Get-CimInstance -ClassName Win32_Process -Filter 'ProcessId = ${pid}' ` +
    '-ErrorAction Stop; if ($null -eq $process) { exit 3 }; ' +
    '$process | Select-Object ExecutablePath,CommandLine | ConvertTo-Json -Compress';
  const result = spawnSync(
    'powershell.exe',
    ['-NoProfile', '-NonInteractive', '-Command', script],
    {
      encoding: 'utf8',
      env,
      shell: false,
      timeout: KEEPER_QUERY_TIMEOUT_MS,
      windowsHide: true,
    },
  );
  if (result.status !== 0 || !result.stdout?.trim()) return undefined;
  const parsed = JSON.parse(result.stdout);
  return {
    executablePath: parsed.ExecutablePath,
    commandLine: parsed.CommandLine,
  };
}

function isKeeperProcess(identity) {
  if (
    typeof identity?.executablePath !== 'string' ||
    path.win32.basename(identity.executablePath).toLowerCase() !== 'wsl.exe' ||
    typeof identity.commandLine !== 'string'
  ) {
    return false;
  }
  const command = identity.commandLine.trim();
  const match = /^(?:"[^"]*\\wsl\.exe"|(?:[^\s"]*\\)?wsl\.exe)\s+(.+)$/.exec(command);
  return match?.[1] === '-d CocEnglishDev -u root --exec sleep infinity';
}

function spawnDetachedKeeper(spec) {
  const child = spawn(spec.command, spec.args, {
    cwd: spec.cwd,
    env: spec.env,
    detached: spec.detached,
    windowsHide: spec.windowsHide,
    stdio: spec.stdio,
    shell: spec.shell,
  });
  if (!child.pid) throw new Error('Unable to start CocEnglishDev WSL keeper.');
  child.unref();
  return child.pid;
}

function portAvailable(port) {
  return new Promise((resolve) => {
    const server = net.createServer();
    server.unref();
    server.once('error', () => resolve(false));
    server.listen(port, '127.0.0.1', () => server.close(() => resolve(true)));
  });
}

function redact(text) {
  return String(text)
    .replace(/([a-z][a-z0-9+.-]*:\/\/)[^\s/@:]+:[^\s/@]+@/gi, '$1[redacted]@')
    .replace(/\b(password|secret|token|api[_-]?key)=([^\s]+)/gi, '$1=[redacted]');
}

async function resolveDocker({ root, platform, run, env }) {
  for (const candidate of dockerCandidates({ root, platform })) {
    const result = await run({
      command: candidate.command,
      args: [...candidate.prefixArgs, 'version', '--format', '{{.Server.Version}}'],
      cwd: root,
      env,
      timeoutMs: PROCESS_TIMEOUT_MS,
    });
    if (result.status === 0 && result.stdout.trim() !== '') return candidate;
  }
  throw new Error('Docker server unavailable. Run local setup doctor.');
}

function ensureWslKeeper({
  root,
  platform,
  env,
  exists,
  readText,
  writeText,
  pidAlive,
  processIdentity,
  spawnKeeper,
}) {
  const api = pathApi(platform);
  const pidFile = api.resolve(root, '.secrets', 'local-dev', 'wsl-keeper.pid');
  if (exists(pidFile)) {
    try {
      const raw = readText(pidFile);
      if (/^[1-9]\d*\s*$/.test(raw)) {
        const pid = Number(raw.trim());
        if (
          Number.isSafeInteger(pid) &&
          pidAlive(pid) &&
          isKeeperProcess(processIdentity(pid, env))
        ) {
          return pid;
        }
      }
    } catch {
      // Missing, malformed, or stale state starts a new keeper. Never kill the recorded PID.
    }
  }
  const pid = spawnKeeper({
    command: 'wsl.exe',
    args: ['-d', 'CocEnglishDev', '-u', 'root', '--exec', 'sleep', 'infinity'],
    cwd: root,
    env,
    detached: true,
    windowsHide: true,
    stdio: 'ignore',
    shell: false,
  });
  if (!Number.isSafeInteger(pid) || pid <= 0) {
    throw new Error('Unable to start CocEnglishDev WSL keeper.');
  }
  writeText(pidFile, `${pid}\n`);
  return pid;
}

function validateUpFiles(root, platform, statFile) {
  const api = pathApi(platform);
  for (const relative of REQUIRED_LOCAL_FILES) {
    const file = api.resolve(root, '.secrets', 'local-dev', ...relative.split('/'));
    try {
      if (!statFile(file).isFile()) throw new Error('Not a regular file.');
    } catch {
      throw new Error('local setup configuration missing or invalid. Run local setup again.');
    }
  }
}

function parseComposePs(output) {
  const text = output.trim();
  if (text === '') return [];
  const parsed = text.startsWith('[')
    ? JSON.parse(text)
    : text
        .split(/\r?\n/)
        .filter(Boolean)
        .map((line) => JSON.parse(line));
  if (!Array.isArray(parsed) || parsed.some((entry) => !entry || typeof entry !== 'object')) {
    throw new Error('Invalid Compose status.');
  }
  return parsed;
}

function composeOwnsPort(records, port) {
  return records.some(
    (record) =>
      record.State === 'running' &&
      Array.isArray(record.Publishers) &&
      record.Publishers.some(
        (publisher) => publisher?.URL === '127.0.0.1' && publisher?.PublishedPort === port,
      ),
  );
}

export async function runLocalDev({
  argv,
  root,
  platform = process.platform,
  nodeVersion = process.versions.node,
  sourceEnv = process.env,
  exists = fs.existsSync,
  statFile = fs.statSync,
  checkPort = portAvailable,
  run = runProcess,
  readText = readTextFile,
  writeText = writeTextFile,
  pidAlive = processIsAlive,
  processIdentity = queryWindowsProcess,
  spawnKeeper = spawnDetachedKeeper,
}) {
  const parsed = parseLocalDevArgs(argv);
  const paths = validateLocalDevPaths({ root, platform });
  const api = pathApi(platform);
  const configPath = api.resolve(paths.root, paths.envFile.split('/').join(api.sep));
  const env = isolatedDockerEnv(sourceEnv);

  if (parsed.command === 'up') validateUpFiles(paths.root, platform, statFile);
  if (parsed.command === 'doctor') {
    if (Number(nodeVersion.split('.')[0]) !== 22) throw new Error('Node 22 required.');
    const docker = await resolveDocker({ root: paths.root, platform, run, env });
    const compose = await run({
      command: docker.command,
      args: [...docker.prefixArgs, 'compose', 'version', '--short'],
      cwd: paths.root,
      env,
      timeoutMs: PROCESS_TIMEOUT_MS,
    });
    if (compose.status !== 0) throw new Error('Docker Compose unavailable.');
    const psInvocation = composeInvocation(docker, 'status', {
      root: paths.root,
      platform,
    });
    const ps = await run({
      ...psInvocation,
      args: [...psInvocation.args, '--format', 'json'],
      env,
      timeoutMs: PROCESS_TIMEOUT_MS,
    });
    let composePsValid = ps.status === 0;
    let records = [];
    if (composePsValid) {
      try {
        records = parseComposePs(ps.stdout);
      } catch {
        composePsValid = false;
      }
    }
    const ports = [];
    for (const port of LOCAL_PORTS) {
      const available = await checkPort(port);
      ports.push({
        port,
        available,
        ownedByStack: !available && composePsValid && composeOwnsPort(records, port),
      });
    }
    let configRegular = false;
    try {
      configRegular = statFile(configPath).isFile();
    } catch {
      configRegular = false;
    }
    return {
      command: 'doctor',
      ok:
        configRegular &&
        composePsValid &&
        ports.every((entry) => entry.available || entry.ownedByStack),
      node: 22,
      docker: 'available',
      compose: 'available',
      config: configRegular ? 'present' : 'missing',
      ports,
    };
  }

  const docker = await resolveDocker({ root: paths.root, platform, run, env });
  if (parsed.command === 'up' && docker.command === 'wsl.exe') {
    ensureWslKeeper({
      root: paths.root,
      platform,
      env,
      exists,
      readText,
      writeText,
      pidAlive,
      processIdentity,
      spawnKeeper,
    });
  }
  const invocation = composeInvocation(docker, parsed.command, {
    root: paths.root,
    platform,
    ...(parsed.service ? { service: parsed.service } : {}),
  });
  const result = await run({
    ...invocation,
    env,
    timeoutMs: parsed.command === 'up' ? UP_PROCESS_TIMEOUT_MS : PROCESS_TIMEOUT_MS,
  });
  if (result.status !== 0)
    throw new Error(redact(result.stderr || result.stdout || 'Docker command failed.'));
  return { command: parsed.command, ok: true, output: redact(result.stdout) };
}
