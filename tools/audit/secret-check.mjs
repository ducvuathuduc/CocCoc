import fs from 'node:fs';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const git = (...args) => execFileSync('git', args, { cwd: root, encoding: 'utf8' }).trim().split(/\r?\n/).filter(Boolean);
const files = [...new Set([...git('diff', '--name-only'), ...git('ls-files', '--others', '--exclude-standard')])];
const scanRoot = path.join(root, '.cache', 'secret-audit');
fs.mkdirSync(scanRoot, { recursive: true });
let count = 0;
for (const file of files) {
  if (!/\.(md|json|ts|mjs|ya?ml|toml|example)$/.test(file) && !['AGENTS.md','README.md','.gitignore','.editorconfig'].includes(file)) continue;
  const destination = path.resolve(scanRoot, file);
  if (path.relative(scanRoot, destination).startsWith('..')) throw new Error('Unsafe scan path.');
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.copyFileSync(path.join(root, file), destination); count++;
}
const result = spawnSync('gitleaks', ['dir', scanRoot, '--no-banner', '--redact=100', '--exit-code=1'], { cwd: root, encoding: 'utf8' });
const output = `${result.stdout ?? ''}\n${result.stderr ?? ''}`;
if (result.error || result.status !== 0 || /\b(?:ERR|FATAL)\b/.test(output)) { console.error(output.trim()); throw new Error('Secret scanner did not prove success.'); }
console.log(JSON.stringify({ status: 'PASS', changedTextFilesScanned: count, scanner: 'gitleaks dir with full redaction', scope: 'changed repository text only; no private environment copied' }));
