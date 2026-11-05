// Builds the shared transport/cache test kit once per test file (esbuild, no network).
import { buildSync } from 'esbuild';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

export const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');

export async function loadTransportKit(name) {
  const outfile = path.join(root, `.cache/shared-tests/${name}-${process.pid}.mjs`);
  buildSync({
    entryPoints: [path.join(root, 'services/shared/src/testing/transport-kit.ts')],
    outfile,
    bundle: true,
    platform: 'node',
    target: 'node22',
    format: 'esm',
    logLevel: 'error',
    banner: {
      js: "import { createRequire as __cocCreateRequire } from 'node:module';\nconst require = __cocCreateRequire(import.meta.url);",
    },
  });
  return import(pathToFileURL(outfile).href);
}
