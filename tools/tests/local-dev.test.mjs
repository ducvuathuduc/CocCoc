import test from 'node:test';
import assert from 'node:assert/strict';
import {
  composeInvocation,
  dockerCandidates,
  isolatedDockerEnv,
  parseLocalDevArgs,
  runLocalDev,
  validateLocalDevPaths,
} from '../scripts/local-dev-lib.mjs';

const root = 'C:\\Users\\ADMIN\\Desktop\\CocEnglish';
const regularFile = () => ({ isFile: () => true });
const keeperIdentity = {
  executablePath: 'C:\\Windows\\System32\\wsl.exe',
  commandLine: 'wsl.exe -d CocEnglishDev -u root --exec sleep infinity',
};

test('Windows fallback uses exact isolated WSL distribution and argument boundaries', () => {
  const candidates = dockerCandidates({ platform: 'win32', root });
  assert.deepEqual(candidates, [
    { command: 'docker', prefixArgs: [] },
    {
      command: 'wsl.exe',
      prefixArgs: [
        '-d',
        'CocEnglishDev',
        '-u',
        'root',
        '--cd',
        '/mnt/c/Users/ADMIN/Desktop/CocEnglish',
        '--exec',
        'docker',
      ],
    },
  ]);
  const invocation = composeInvocation(candidates[1], 'status', { root, platform: 'win32' });
  assert.equal(invocation.command, 'wsl.exe');
  assert.deepEqual(invocation.args, [
    ...candidates[1].prefixArgs,
    'compose',
    '--project-name',
    'cocenglish-dev',
    '--file',
    'infra/docker/compose.dev.yaml',
    '--env-file',
    '.secrets/local-dev/compose.env',
    'ps',
  ]);
  assert.equal(
    dockerCandidates({ platform: 'win32', root: 'C:\\Work Space\\CocEnglish' })[1].prefixArgs[5],
    '/mnt/c/Work Space/CocEnglish',
  );
});

test('rejects unknown commands, unsafe log services, control characters and escaping paths', () => {
  assert.throws(() => parseLocalDevArgs(['down']), /Unknown local-dev command/);
  assert.throws(() => parseLocalDevArgs(['logs']), /requires one service/);
  assert.throws(() => parseLocalDevArgs(['logs', 'learning;down']), /Unsafe service/);
  assert.throws(() => parseLocalDevArgs(['status\nup']), /control character/);
  assert.throws(
    () => validateLocalDevPaths({ root: 'C:\\repo\npoison', platform: 'win32' }),
    /control character/,
  );
  assert.throws(
    () =>
      validateLocalDevPaths({
        root,
        platform: 'win32',
        composeFile: '..\\outside.yaml',
      }),
    /inside repository root/,
  );
});

test('stop preserves containers and volumes by using compose stop only', () => {
  const invocation = composeInvocation({ command: 'docker', prefixArgs: [] }, 'stop', {
    root,
    platform: 'win32',
  });
  assert.equal(invocation.args.at(-1), 'stop');
  assert.equal(invocation.args.includes('down'), false);
  assert.equal(invocation.args.includes('--volumes'), false);
  assert.equal(invocation.args.includes('-v'), false);
});

test('Docker subprocess environment excludes inherited cloud and secret settings', () => {
  const env = isolatedDockerEnv({
    PATH: 'C:\\Windows\\System32',
    SystemRoot: 'C:\\Windows',
    TEMP: 'C:\\Temp',
    DOCKER_HOST: 'tcp://cloud.example:2376',
    COMPOSE_FILE: 'remote.yaml',
    APPWRITE_API_KEY: 'secret',
    GEMINI_API_KEY: 'secret',
    COC_REDIS_URL: 'rediss://default:secret@cache.example',
    NODE_OPTIONS: '--inspect',
  });
  assert.deepEqual(env, {
    PATH: 'C:\\Windows\\System32',
    SystemRoot: 'C:\\Windows',
    TEMP: 'C:\\Temp',
  });
});

test('up requires generated config before exact wait-bounded compose invocation', async () => {
  const calls = [];
  const base = {
    argv: ['up'],
    root,
    platform: 'win32',
    nodeVersion: '22.21.1',
    run: async (spec) => {
      calls.push(spec);
      return { status: 0, stdout: '28.5.2', stderr: '' };
    },
    checkPort: async () => true,
  };
  await assert.rejects(
    runLocalDev({
      ...base,
      statFile: () => {
        throw new Error('ENOENT');
      },
    }),
    /local setup configuration missing/,
  );
  assert.equal(calls.length, 0);

  await runLocalDev({ ...base, statFile: regularFile });
  const up = calls.at(-1);
  assert.deepEqual(up.args.slice(-4), ['--detach', '--wait', '--wait-timeout', '300']);
  assert.equal(up.timeoutMs, 330_000);
  assert.equal(up.args.includes('--env-file'), true);
  assert.equal(up.args.includes('cocenglish-dev'), true);
});

test('up requires every env and TLS input to be a regular file before Docker', async () => {
  const required = [
    'compose.env',
    'appwrite.env',
    'learning.env',
    'progress.env',
    'ai.env',
    'tls\\ca.crt',
    'tls\\server.crt',
    'tls\\server.key',
  ];
  for (const invalidSuffix of ['tls\\ca.crt', 'tls\\server.key']) {
    let dockerCalls = 0;
    await assert.rejects(
      runLocalDev({
        argv: ['up'],
        root,
        platform: 'win32',
        statFile: (file) => {
          if (file.endsWith(invalidSuffix)) {
            if (invalidSuffix.endsWith('ca.crt')) throw new Error('ENOENT');
            return { isFile: () => false };
          }
          return regularFile();
        },
        run: async () => {
          dockerCalls++;
          return { status: 0, stdout: 'unexpected', stderr: '' };
        },
      }),
      /local setup configuration missing/,
    );
    assert.equal(dockerCalls, 0);
  }

  const checked = [];
  await runLocalDev({
    argv: ['up'],
    root,
    platform: 'win32',
    statFile: (file) => {
      checked.push(file);
      return regularFile();
    },
    run: async () => ({ status: 0, stdout: 'ok', stderr: '' }),
  });
  assert.deepEqual(
    checked.map((file) => file.slice(file.indexOf('.secrets\\local-dev\\') + 19)),
    required,
  );
});

test('WSL-backed up starts one hidden detached keeper before Compose and persists its PID', async () => {
  const events = [];
  const writes = [];
  await runLocalDev({
    argv: ['up'],
    root,
    platform: 'win32',
    statFile: regularFile,
    exists: (file) => !file.endsWith('wsl-keeper.pid'),
    run: async (spec) => {
      if (spec.command === 'docker') return { status: 1, stdout: '', stderr: 'missing' };
      events.push(spec.args.includes('compose') ? 'compose' : 'probe');
      return { status: 0, stdout: '28.5.2', stderr: '' };
    },
    spawnKeeper: (spec) => {
      events.push('keeper');
      assert.deepEqual(spec, {
        command: 'wsl.exe',
        args: ['-d', 'CocEnglishDev', '-u', 'root', '--exec', 'sleep', 'infinity'],
        cwd: root,
        env: {},
        detached: true,
        windowsHide: true,
        stdio: 'ignore',
        shell: false,
      });
      return 4321;
    },
    writeText: (file, value) => writes.push([file, value]),
    sourceEnv: {},
  });

  assert.deepEqual(events, ['probe', 'keeper', 'compose']);
  assert.deepEqual(writes, [
    ['C:\\Users\\ADMIN\\Desktop\\CocEnglish\\.secrets\\local-dev\\wsl-keeper.pid', '4321\n'],
  ]);
});

test('WSL-backed up reuses a live persisted keeper without spawning another', async () => {
  let spawnCount = 0;
  let checkedPid;
  await runLocalDev({
    argv: ['up'],
    root,
    platform: 'win32',
    statFile: regularFile,
    exists: () => true,
    readText: () => '7654\n',
    pidAlive: (pid) => {
      checkedPid = pid;
      return true;
    },
    processIdentity: () => keeperIdentity,
    spawnKeeper: () => {
      spawnCount++;
      return 9999;
    },
    writeText: () => assert.fail('live keeper PID must not be replaced'),
    run: async (spec) =>
      spec.command === 'docker'
        ? { status: 1, stdout: '', stderr: 'missing' }
        : { status: 0, stdout: 'ok', stderr: '' },
  });

  assert.equal(checkedPid, 7654);
  assert.equal(spawnCount, 0);
});

test('live unrelated PID is never trusted as keeper and starts a replacement without killing it', async () => {
  let spawned = 0;
  await runLocalDev({
    argv: ['up'],
    root,
    platform: 'win32',
    statFile: regularFile,
    exists: () => true,
    readText: () => '7654\n',
    pidAlive: () => true,
    processIdentity: () => ({
      executablePath: 'C:\\Windows\\System32\\notepad.exe',
      commandLine: 'notepad.exe',
    }),
    spawnKeeper: () => {
      spawned++;
      return 8765;
    },
    writeText: () => undefined,
    run: async (spec) =>
      spec.command === 'docker'
        ? { status: 1, stdout: '', stderr: 'missing' }
        : { status: 0, stdout: 'ok', stderr: '' },
  });
  assert.equal(spawned, 1);
});

test('failed process identity query fails closed and starts a replacement keeper', async () => {
  let spawned = 0;
  await runLocalDev({
    argv: ['up'],
    root,
    platform: 'win32',
    statFile: regularFile,
    exists: () => true,
    readText: () => '7654\n',
    pidAlive: () => true,
    processIdentity: () => {
      throw new Error('CIM unavailable');
    },
    spawnKeeper: () => ++spawned + 9000,
    writeText: () => undefined,
    run: async (spec) =>
      spec.command === 'docker'
        ? { status: 1, stdout: '', stderr: 'missing' }
        : { status: 0, stdout: 'ok', stderr: '' },
  });
  assert.equal(spawned, 1);
});

test('stop never starts or kills a WSL keeper', async () => {
  let keeperTouched = false;
  await runLocalDev({
    argv: ['stop'],
    root,
    platform: 'win32',
    exists: () => true,
    readText: () => {
      keeperTouched = true;
      return '1234';
    },
    pidAlive: () => {
      keeperTouched = true;
      return true;
    },
    spawnKeeper: () => {
      keeperTouched = true;
      return 9999;
    },
    writeText: () => {
      keeperTouched = true;
    },
    run: async (spec) =>
      spec.command === 'docker'
        ? { status: 1, stdout: '', stderr: 'missing' }
        : { status: 0, stdout: 'ok', stderr: '' },
  });

  assert.equal(keeperTouched, false);
});

test('doctor is read-only and checks Node 22, Docker Compose, ports and config', async () => {
  const calls = [];
  const checkedPorts = [];
  const result = await runLocalDev({
    argv: ['doctor'],
    root,
    platform: 'win32',
    nodeVersion: '22.21.1',
    exists: () => true,
    statFile: regularFile,
    checkPort: async (port) => {
      checkedPorts.push(port);
      return true;
    },
    run: async (spec) => {
      calls.push(spec);
      if (spec.args.at(-1) === 'json') return { status: 0, stdout: '[]', stderr: '' };
      return {
        status: 0,
        stdout: spec.args.includes('compose') ? '2.39.1' : '28.5.2',
        stderr: '',
      };
    },
  });
  assert.deepEqual(checkedPorts, [8443, 4101, 4102, 4103, 8025]);
  assert.equal(result.command, 'doctor');
  assert.equal(result.ok, true);
  assert.equal(
    calls.every((call) => call.args.includes('version') || call.args.includes('ps')),
    true,
  );
  assert.equal(
    calls.some((call) => call.args.slice(-3).join(' ') === 'ps --format json'),
    true,
  );
  assert.equal(JSON.stringify(result).includes('rediss://'), false);

  await assert.rejects(
    runLocalDev({
      argv: ['doctor'],
      root: '/repo',
      platform: 'linux',
      nodeVersion: '24.0.0',
      exists: () => true,
      statFile: regularFile,
      checkPort: async () => true,
      run: async () => ({ status: 0, stdout: 'ok', stderr: '' }),
    }),
    /Node 22 required/,
  );
});

test('doctor admits busy ports only when running Compose publishers own exact loopback ports', async () => {
  const records = [
    {
      State: 'running',
      Publishers: [8443, 4101, 4102, 4103].map((PublishedPort) => ({
        URL: '127.0.0.1',
        PublishedPort,
      })),
    },
    {
      State: 'running',
      Publishers: [{ URL: '127.0.0.1', PublishedPort: 8025 }],
    },
  ];
  const result = await runLocalDev({
    argv: ['doctor'],
    root,
    platform: 'win32',
    nodeVersion: '22.21.1',
    statFile: regularFile,
    checkPort: async () => false,
    run: async (spec) => {
      if (spec.args.at(-1) === 'json') {
        return {
          status: 0,
          stdout: records.map((row) => JSON.stringify(row)).join('\n'),
          stderr: '',
        };
      }
      return { status: 0, stdout: 'ok', stderr: '' };
    },
  });
  assert.equal(result.ok, true);
  assert.equal(
    result.ports.every((entry) => !entry.available && entry.ownedByStack),
    true,
  );
});

test('doctor rejects foreign busy port and malformed Compose JSON', async () => {
  for (const [psOutput, allAvailable] of [
    [
      JSON.stringify([
        {
          State: 'running',
          Publishers: [{ URL: '0.0.0.0', PublishedPort: 4101 }],
        },
      ]),
      false,
    ],
    ['not-json', true],
  ]) {
    const result = await runLocalDev({
      argv: ['doctor'],
      root,
      platform: 'win32',
      nodeVersion: '22.21.1',
      statFile: regularFile,
      checkPort: async (port) => allAvailable || port !== 4101,
      run: async (spec) =>
        spec.args.at(-1) === 'json'
          ? { status: 0, stdout: psOutput, stderr: '' }
          : { status: 0, stdout: 'ok', stderr: '' },
    });
    assert.equal(result.ok, false);
  }
});

test('logs accepts only explicit allowlist and always bounds output to 100 lines', () => {
  for (const service of [
    'appwrite',
    'learning',
    'progress',
    'ai',
    'redis',
    'rabbitmq',
    'mailpit',
  ]) {
    assert.deepEqual(parseLocalDevArgs(['logs', service]), { command: 'logs', service });
  }
  const invocation = composeInvocation({ command: 'docker', prefixArgs: [] }, 'logs', {
    root,
    platform: 'win32',
    service: 'rabbitmq',
  });
  assert.deepEqual(invocation.args.slice(-4), ['logs', '--tail', '100', 'rabbitmq']);
});
