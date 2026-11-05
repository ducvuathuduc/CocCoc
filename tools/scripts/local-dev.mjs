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
