import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { writeLocalMobileDefines } from './local-config.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const mobile = path.join(root, 'apps/mobile');
try {
  if (process.argv.length !== 2)
    throw new Error('local-mobile builds only the debug local API APK; no options accepted');
  const flutter = process.env.FLUTTER_ROOT ?? (process.platform === 'win32' ? 'C:/flutter' : '');
  if (!flutter) throw new Error('Set FLUTTER_ROOT to the installed pinned Flutter SDK');
  const dart = path.join(
    flutter,
    'bin/cache/dart-sdk/bin',
    process.platform === 'win32' ? 'dart.exe' : 'dart',
  );
  const snapshot = path.join(flutter, 'bin/cache/flutter_tools.snapshot');
  if (!fs.statSync(dart).isFile() || !fs.statSync(snapshot).isFile())
    throw new Error('Initialize the pinned Flutter SDK first');
  const dir = path.join(root, '.secrets/local-dev');
  writeLocalMobileDefines(dir);
  // A dedicated cache keeps the 8 GB template heap from exhausting this 16 GB dev machine.
  const gradle = path.join(root, '.cache/gradle-android-refresh');
  fs.mkdirSync(gradle, { recursive: true });
  const properties = path.join(gradle, 'gradle.properties');
  const previous = fs.existsSync(properties)
    ? fs
        .readFileSync(properties, 'utf8')
        .split(/\r?\n/)
        .filter((line) => !/^org\.gradle\.(?:jvmargs|workers\.max)=/.test(line))
        .join('\n')
        .trimEnd()
    : '';
  fs.writeFileSync(
    path.join(gradle, 'gradle.properties'),
    `${previous}\norg.gradle.jvmargs=-Xmx1536m -XX:MaxMetaspaceSize=768m -XX:ReservedCodeCacheSize=256m\norg.gradle.workers.max=2\n`,
  );
  const result = spawnSync(
    dart,
    [
      snapshot,
      'build',
      'apk',
      '--debug',
      '--no-pub',
      `--dart-define-from-file=${path.join(dir, 'mobile-defines.json')}`,
    ],
    {
      cwd: mobile,
      env: { ...process.env, FLUTTER_ROOT: flutter, GRADLE_USER_HOME: gradle },
      stdio: 'inherit',
      shell: false,
      windowsHide: true,
    },
  );
  if (result.error || result.status !== 0) throw new Error('Local API debug APK build failed');
} catch (error) {
  console.error(error instanceof Error ? error.message : 'Local mobile build failed');
  process.exitCode = 1;
}
