// Builds the AI test bundle once per test process (esbuild, no network) and re-exports it.
import { buildSync } from 'esbuild';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const outfile = path.join(root, `.cache/ai-test/kit-${process.pid}.mjs`);
buildSync({
  entryPoints: [path.join(root, 'services/ai/src/testing/testkit.ts')],
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
export const kit = await import(pathToFileURL(outfile).href);
export const repoRoot = root;
