import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '../..');
const app = path.join(root, 'apps/mobile');
const sdk = process.env.FLUTTER_ROOT ?? (process.platform === 'win32' ? 'C:/flutter' : null);
if (!sdk) throw new Error('Set FLUTTER_ROOT before building the preview.');
const receipt = JSON.parse(readFileSync(path.join(root, 'docs/design/qa/rive-web-runtime.json'), 'utf8'));
for (const record of receipt.records) {
  const bytes = readFileSync(path.join(app, 'web/rive', record.file));
  if (bytes.length !== record.bytes) throw new Error(`Missing or incomplete local Rive runtime ${record.file}`);
}
const dart = path.join(sdk, 'bin/cache/dart-sdk/bin', process.platform === 'win32' ? 'dart.exe' : 'dart');
const snapshot = path.join(sdk, 'bin/cache/flutter_tools.snapshot');
const result = spawnSync(dart, [snapshot, 'build', 'web', '--release', '--dart-define=RIVE_NATIVE_WASM_HOST=rive/'], { cwd: app, env: { ...process.env, FLUTTER_ROOT: sdk }, stdio: 'inherit' });
if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
