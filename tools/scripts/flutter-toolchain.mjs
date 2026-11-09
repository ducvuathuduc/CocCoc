// Locates an initialised Flutter SDK without needing `flutter` on PATH: FLUTTER_ROOT, FLUTTER_HOME,
// then PATH, then the repository-local `.cache/flutter` (git-ignored) so a lane can run from a
// checkout that pinned its own SDK. Mirrors tools/scripts/mobile-check.mjs.
import { existsSync, realpathSync } from 'node:fs';
import path from 'node:path';

const isWindows = process.platform === 'win32';

export function findFlutterRoot(repositoryRoot, env = process.env) {
  const candidates = [];
  for (const variable of ['FLUTTER_ROOT', 'FLUTTER_HOME']) {
    if (env[variable]) candidates.push(path.resolve(env[variable]));
  }
  const wrapperNames = isWindows ? ['flutter.exe', 'flutter.bat'] : ['flutter'];
  for (const entry of (env.PATH ?? env.Path ?? '').split(path.delimiter).filter(Boolean)) {
    for (const wrapperName of wrapperNames) {
      const wrapper = path.join(entry, wrapperName);
      if (existsSync(wrapper)) {
        candidates.push(path.dirname(path.dirname(realpathSync(wrapper))));
      }
    }
  }
  candidates.push(path.join(repositoryRoot, '.cache', 'flutter'));

  for (const candidate of candidates) {
    const dartExecutable = path.join(
      candidate,
      'bin',
      'cache',
      'dart-sdk',
      'bin',
      isWindows ? 'dart.exe' : 'dart',
    );
    const flutterSnapshot = path.join(candidate, 'bin', 'cache', 'flutter_tools.snapshot');
    if (existsSync(dartExecutable) && existsSync(flutterSnapshot)) {
      return { dartExecutable, flutterRoot: candidate, flutterSnapshot };
    }
  }
  return null;
}
