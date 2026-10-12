// Shared helpers for content tools: bundle the TypeScript integrity/validation code once.
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { build } from 'esbuild';

export const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

export async function loadContentTools() {
  const outfile = path.join(root, '.cache/content-tools/content-tools.mjs');
  await build({
    entryPoints: [path.join(root, 'services/learning/src/testing/content-tools.ts')],
    outfile,
    bundle: true,
    platform: 'node',
    target: 'node22',
    format: 'esm',
    logLevel: 'warning',
  });
  return import(`${pathToFileURL(outfile).href}?t=${Date.now()}`);
}
