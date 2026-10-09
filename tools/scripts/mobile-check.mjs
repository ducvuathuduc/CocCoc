import { spawnSync } from 'node:child_process';
import { existsSync, realpathSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(scriptDirectory, '..', '..');
const mobileDirectory = path.join(repositoryRoot, 'apps', 'mobile');
const isWindows = process.platform === 'win32';

const flags = new Set(process.argv.slice(2));
const supportedFlags = new Set(['--build-android', '--help', '--with-blueprint']);
const unknownFlags = [...flags].filter((flag) => !supportedFlags.has(flag));

if (unknownFlags.length > 0) {
  console.error(`Unknown option: ${unknownFlags.join(', ')}`);
  process.exit(2);
}

if (flags.has('--help')) {
  console.log(
    'Usage: node tools/scripts/mobile-check.mjs [--with-blueprint] [--build-android]',
  );
  process.exit(0);
}

function run(label, executable, arguments_, options = {}) {
  console.log(`\n> ${label}`);
  const result = spawnSync(executable, arguments_, {
    cwd: options.cwd ?? repositoryRoot,
    env: options.env ?? process.env,
    shell: false,
    stdio: 'inherit',
  });

  if (result.error) {
    console.error(`${label} could not start: ${result.error.message}`);
    process.exit(1);
  }

  if (result.status !== 0) {
    console.error(`${label} failed with exit code ${result.status ?? 'unknown'}.`);
    process.exit(result.status ?? 1);
  }
}

function findFlutterRoot() {
  const candidates = [];

  for (const variable of ['FLUTTER_ROOT', 'FLUTTER_HOME']) {
    if (process.env[variable]) {
      candidates.push(path.resolve(process.env[variable]));
    }
  }

  const pathEntries = (process.env.PATH ?? '').split(path.delimiter).filter(Boolean);
  const wrapperNames = isWindows ? ['flutter.exe', 'flutter.bat'] : ['flutter'];

  for (const entry of pathEntries) {
    for (const wrapperName of wrapperNames) {
      const wrapper = path.join(entry, wrapperName);
      if (existsSync(wrapper)) {
        const resolvedWrapper = realpathSync(wrapper);
        candidates.push(path.dirname(path.dirname(resolvedWrapper)));
      }
    }
  }

  for (const candidate of candidates) {
    const dartExecutable = path.join(
      candidate,
      'bin',
      'cache',
      'dart-sdk',
      'bin',
      isWindows ? 'dart.exe' : 'dart',
    );
    const flutterSnapshot = path.join(
      candidate,
      'bin',
      'cache',
      'flutter_tools.snapshot',
    );

    if (existsSync(dartExecutable) && existsSync(flutterSnapshot)) {
      return { dartExecutable, flutterRoot: candidate, flutterSnapshot };
    }
  }

  throw new Error(
    'Flutter SDK not found or its cache is not initialized. Set FLUTTER_ROOT or add Flutter bin to PATH, then run flutter --version once.',
  );
}

if (flags.has('--with-blueprint')) {
  run('Blueprint validation', process.execPath, [
    path.join(repositoryRoot, 'tools', 'blueprint', 'validate.mjs'),
  ]);
}

if (!existsSync(path.join(mobileDirectory, 'pubspec.yaml'))) {
  console.error(`Flutter app is missing: ${path.join(mobileDirectory, 'pubspec.yaml')}`);
  process.exit(1);
}

let toolchain;
try {
  toolchain = findFlutterRoot();
} catch (error) {
  console.error(error.message);
  process.exit(1);
}

const flutterEnvironment = {
  ...process.env,
  FLUTTER_ROOT: toolchain.flutterRoot,
};
const runFlutter = (label, arguments_) =>
  run(label, toolchain.dartExecutable, [toolchain.flutterSnapshot, ...arguments_], {
    cwd: mobileDirectory,
    env: flutterEnvironment,
  });

run(
  'Dart format check',
  toolchain.dartExecutable,
  ['format', '--output=none', '--set-exit-if-changed', 'lib', 'test', 'integration_test', 'test_driver'],
  { cwd: mobileDirectory, env: flutterEnvironment },
);
runFlutter('Flutter analyze', ['analyze', '--fatal-infos']);
// Rive's official setup downloads the host test runtime. Windows debug DLLs
// require the Visual C++ debug CRT; the release DLL works on normal developer PCs.
const riveHost = { win32: 'windows', linux: 'linux', darwin: 'macos' }[process.platform];
if (riveHost) {
  // Flutter clean removes the app copy but leaves Rive's Pub-cache marker.
  // Official setup needs --clean to restore that missing prebuilt runtime.
  const missingWindowsRuntime = isWindows && !existsSync(path.join(mobileDirectory, 'build/rive_native/native/build/windows/bin/lib/release/rive_native.dll'));
  run('Rive host test runtime', toolchain.dartExecutable, ['run', 'rive_native:setup', '--platform', riveHost, ...(missingWindowsRuntime ? ['--clean'] : [])], { cwd: mobileDirectory, env: flutterEnvironment });
}
if (isWindows) {
  const pathKey = Object.keys(flutterEnvironment).find((key) => key.toLowerCase() === 'path') ?? 'PATH';
  flutterEnvironment[pathKey] = path.join(mobileDirectory, 'build/rive_native/native/build/windows/bin/lib/release') + path.delimiter + (flutterEnvironment[pathKey] ?? '');
}
runFlutter('Flutter test', ['test', '--dart-define=ENABLE_MASCOT_MOTION=false']);

if (flags.has('--build-android')) {
  runFlutter('Flutter Android debug build', ['build', 'apk', '--debug']);
}
