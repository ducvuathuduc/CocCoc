import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFileSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';

// Run once before integration edits. Never reads ignored/private configuration.
const git = (...args) => execFileSync('git', args, { maxBuffer: 64 * 1024 * 1024 });
const sha = (bytes) => createHash('sha256').update(bytes).digest('hex');
const paths = git('ls-files', '-z', '--cached', '--others', '--exclude-standard')
  .toString()
  .split('\0')
  .filter(Boolean);
const files = [...new Set(paths)].filter(
  (path) =>
    /^(apps\/mobile\/(lib|assets|test|integration_test|config)|docs\/design\/references)\//.test(
      path,
    ) &&
    !/(\/failures\/|\.private\.|\.env)/.test(path) &&
    existsSync(path),
);
const artifacts = [
  'apps/mobile/build/web/main.dart.js',
  'apps/mobile/build/app/outputs/flutter-apk/app-debug.apk',
].map((path) => ({
  path,
  exists: existsSync(path),
  ...(existsSync(path) ? { sha256: sha(readFileSync(path)) } : {}),
}));
const receipt = {
  capturedAt: new Date().toISOString(),
  head: git('rev-parse', 'HEAD').toString().trim(),
  branch: git('branch', '--show-current').toString().trim(),
  trackedDiffSha256: sha(git('diff', 'HEAD', '--binary')),
  dirtyPaths: git('status', '--porcelain', '-z').toString().split('\0').filter(Boolean),
  sourceFiles: files.sort().map((path) => ({ path, sha256: sha(readFileSync(path)) })),
  artifacts,
  referenceReceipt: 'docs/design/qa/ANDROID_NONPAYMENT_COMPLETION_20261024.md',
  comparisonConditions: {
    viewports: [
      { width: 390, height: 844 },
      { width: 320, height: 640 },
    ],
    themes: ['light', 'dark'],
    textScales: [1, 2],
    fonts: 'bundled reference fonts',
    motion: 'ENABLE_MASCOT_MOTION=false',
    status: 'planned comparisons; capture does not prove visual acceptance',
  },
};
const folder = 'docs/quality/real-features-20261025';
mkdirSync(folder, { recursive: true });
const output = `${folder}/ui-baseline.json`;
if (existsSync(output)) throw new Error('Baseline already exists; preserve the original capture.');
writeFileSync(output, `${JSON.stringify(receipt, null, 2)}\n`);
process.stdout.write(
  `Captured ${files.length} source/reference hashes and ${artifacts.length} artifact checks.\n`,
);
