// [VI] Điều khiển stack local bền: `up`, `stop`, `status`, `logs`, `doctor`.
// `stop` giữ nguyên volume/dữ liệu; không có lệnh reset xóa DB. Logic compose/WSL nằm trong
// local-dev-lib.mjs để test được mà không cần Docker thật.
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { runLocalDev } from './local-dev-lib.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

try {
  const result = await runLocalDev({ argv: process.argv.slice(2), root });
  if (result.command === 'doctor') {
    process.stdout.write(`${JSON.stringify(result)}\n`);
    if (!result.ok) process.exitCode = 1;
  } else if (result.output) {
    process.stdout.write(result.output.endsWith('\n') ? result.output : `${result.output}\n`);
  }
} catch (error) {
  process.stderr.write(
    `${error instanceof Error ? error.message : 'Local Docker command failed.'}\n`,
  );
  process.exitCode = 1;
}
