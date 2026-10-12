// Builds the Learning test kit (services/learning/src/testing/learning-testkit.ts) with esbuild and
// imports it. Each test file gets its own output so parallel `node --test` processes never race.
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { build } from 'esbuild';

export const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../..');

export async function loadKit(name) {
  const outfile = path.join(root, `.cache/learning-tests/${name}-${process.pid}.mjs`);
  await build({
    entryPoints: [path.join(root, 'services/learning/src/testing/learning-testkit.ts')],
    outfile,
    bundle: true,
    platform: 'node',
    target: 'node22',
    format: 'esm',
    logLevel: 'warning',
    banner: {
      js: "import { createRequire as __cocCreateRequire } from 'node:module';\nconst require = __cocCreateRequire(import.meta.url);",
    },
  });
  return import(pathToFileURL(outfile).href);
}
