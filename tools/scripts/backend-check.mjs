// [VI] Gate backend chính (`pnpm backend:verify` / `backend:build`):
// chạy tsc strict → esbuild đóng gói 3 bundle độc lập (function/http/worker) → ESLint +
// Prettier → toàn bộ test node của services. `--build` chỉ build, dùng cho deploy/container.
// Esbuild thêm banner createRequire vì node-appwrite kéo dependency CommonJS dùng require()
// cho built-in của Node; bundle ESM vẫn phải load được trong Appwrite Function.
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { build } from 'esbuild';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
process.chdir(root);
const names = ['learning', 'progress', 'ai'];
const buildOnly = process.argv.includes('--build');
// node-appwrite pulls CommonJS dependencies that call require() for Node built-ins; ESM
// bundles need a real require so the self-contained Function artifact loads.
const banner = {
  js: "import { createRequire as __cocCreateRequire } from 'node:module';\nconst require = __cocCreateRequire(import.meta.url);",
};
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
    entryPoints: {
      function: `services/${name}/src/index.ts`,
      http: `services/${name}/src/runtime/http.ts`,
      worker: `services/${name}/src/runtime/worker.ts`,
    },
    outdir: `services/${name}/dist`,
    bundle: true,
    platform: 'node',
    target: 'node22',
    format: 'esm',
    outExtension: { '.js': '.mjs' },
    sourcemap: true,
    banner,
  });
}
await build({
  entryPoints: {
    'mock-completion': 'services/learning/src/testing/mock-completion.ts',
    'mock-rewards': 'services/progress/src/testing/mock-rewards.ts',
    'foundation-testkit': 'services/shared/src/testing/testkit.ts',
    'runtime-http': 'services/shared/src/runtime-http.ts',
    'runtime-worker': 'services/shared/src/runtime-worker.ts',
  },
  outdir: '.cache/backend-fixtures',
  bundle: true,
  platform: 'node',
  target: 'node22',
  format: 'esm',
  outExtension: { '.js': '.mjs' },
  banner,
});
if (!buildOnly) {
  run('node_modules/eslint/bin/eslint.js', ['services/*/src/**/*.ts']);
  run('node_modules/prettier/bin/prettier.cjs', [
    '--check',
    'services/*/src/**/*.ts',
    'services/*/test/*.mjs',
    'tools/scripts/backend*.mjs',
    'tools/scripts/dev-*.mjs',
    'tsconfig.backend.json',
    'eslint.config.mjs',
  ]);
  const tests = [...names, 'shared'].flatMap((name) =>
    fs.existsSync(`services/${name}/test`)
      ? fs
          .readdirSync(`services/${name}/test`)
          .filter((file) => file.endsWith('.test.mjs'))
          .map((file) => `services/${name}/test/${file}`)
      : [],
  );
  const testConcurrency =
    process.env.BACKEND_TEST_CONCURRENCY ?? (process.platform === 'win32' ? '1' : '4');
  const result = spawnSync(
    process.execPath,
    ['--test', `--test-concurrency=${testConcurrency}`, ...tests],
    { stdio: 'inherit', cwd: root },
  );
  if (result.status !== 0) process.exit(result.status || 1);
}
console.log(
  JSON.stringify({
    status: 'PASS',
    scope: 'local scaffold and fixtures; no cloud/provider/device proof',
    services: selected.length ? selected : names,
  }),
);
