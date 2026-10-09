import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { build } from 'esbuild';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
process.chdir(root);
const names = ['learning', 'progress', 'ai'];
const buildOnly = process.argv.includes('--build');
const selected = process.argv.filter((value) => names.includes(value));
function run(file, args) {
  const result = spawnSync(process.execPath, [file, ...args], { stdio: 'inherit', cwd: root });
  if (result.error || result.status !== 0) {
    console.error(result.error?.message ?? `Command failed (${result.status}).`);
    process.exit(result.status || 1);
  }
}
run('node_modules/typescript/bin/tsc', ['-p', 'tsconfig.backend.json']);
for (const name of selected.length ? selected : names) {
  fs.mkdirSync(`services/${name}/dist`, { recursive: true });
  await build({
    entryPoints: [`services/${name}/src/index.ts`],
    outfile: `services/${name}/dist/function.mjs`,
    bundle: true,
    platform: 'node',
    target: 'node22',
    format: 'esm',
    sourcemap: true,
  });
}
await build({
  entryPoints: {
    'mock-completion': 'services/learning/src/mock-completion.ts',
    'mock-rewards': 'services/progress/src/mock-rewards.ts',
  },
  outdir: '.cache/backend-fixtures',
  bundle: true,
  platform: 'node',
  target: 'node22',
  format: 'esm',
  outExtension: { '.js': '.mjs' },
});
if (!buildOnly) {
  run('node_modules/eslint/bin/eslint.js', ['services/*/src/**/*.ts']);
  run('node_modules/prettier/bin/prettier.cjs', [
    '--check',
    'services/*/src/**/*.ts',
    'services/*/test/*.mjs',
    'tools/scripts/backend*.mjs',
    'tools/scripts/service-local.mjs',
    'tsconfig.backend.json',
    'eslint.config.mjs',
  ]);
  const tests = names.flatMap((name) =>
    fs.existsSync(`services/${name}/test`)
      ? fs
          .readdirSync(`services/${name}/test`)
          .filter((file) => file.endsWith('.test.mjs'))
          .map((file) => `services/${name}/test/${file}`)
      : [],
  );
  const result = spawnSync(process.execPath, ['--test', ...tests], { stdio: 'inherit', cwd: root });
  if (result.status !== 0) process.exit(result.status || 1);
}
console.log(
  JSON.stringify({
    status: 'PASS',
    scope: 'local scaffold and fixtures; no cloud/provider/device proof',
    services: selected.length ? selected : names,
  }),
);
