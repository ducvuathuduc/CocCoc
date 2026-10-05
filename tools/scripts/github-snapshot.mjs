import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, statSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '../..');
const inventoryPath = 'docs/design/qa/github-upload-manifest.json';
const artifactPath = 'docs/design/qa/english-current-artifacts.json';
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const describe = relative => {
  const bytes = readFileSync(path.join(root, relative));
  return { path: relative, bytes: bytes.length, sha256: hash(bytes) };
};
const git = spawnSync('git', ['ls-files', '--cached', '--others', '--exclude-standard', '-z'], {
  cwd: root, encoding: 'utf8', shell: false,
});
if (git.error || git.status !== 0) throw new Error('Cannot inventory Git project files.');
const paths = [...new Set(git.stdout.split('\0').filter(Boolean))]
  .filter(relative => relative !== inventoryPath && statSync(path.join(root, relative)).isFile())
  .sort();

if (process.argv.includes('--write')) {
  const artifactFiles = [
    'apps/mobile/build/web/main.dart.js',
    ...['armeabi-v7a', 'arm64-v8a', 'x86_64'].map(abi =>
      `apps/mobile/build/app/outputs/flutter-apk/app-${abi}-release.apk`),
  ];
  writeFileSync(path.join(root, artifactPath), JSON.stringify({
    date: '2026-10-05',
    scope: 'User-authorized mock frontend. Release compilation and artifact integrity; no physical-device, iOS or production capability sign-off.',
    testCount: 239,
    extendedCaptures: { static: 124, actualClashRive: 4, browser: 2 },
    bundledReferencePngs: 201,
    records: artifactFiles.map(describe),
  }, null, 2) + '\n');
  const files = paths.map(describe);
  writeFileSync(path.join(root, inventoryPath), JSON.stringify({
    date: '2026-10-05',
    repository: 'https://github.com/ducvuathuduc/CocCoc',
    scope: 'All non-ignored project files; the inventory itself is excluded from its recursive checksum list but committed in Git.',
    releaseTag: 'mock-preview-2026-10-05',
    fileCount: files.length,
    totalBytes: files.reduce((sum, record) => sum + record.bytes, 0),
    files,
  }, null, 2) + '\n');
  console.log(`Wrote ${files.length} project file hashes and ${artifactFiles.length} build hashes.`);
} else {
  const inventory = JSON.parse(readFileSync(path.join(root, inventoryPath), 'utf8'));
  if (JSON.stringify(paths) !== JSON.stringify(inventory.files.map(file => file.path))) {
    throw new Error('Project file set changed after snapshot; regenerate the manifest.');
  }
  for (const record of inventory.files) {
    const actual = describe(record.path);
    if (actual.bytes !== record.bytes || actual.sha256 !== record.sha256) {
      throw new Error(`Snapshot mismatch: ${record.path}`);
    }
  }
  console.log(`PASS ${inventory.fileCount} project files match the snapshot.`);
}
