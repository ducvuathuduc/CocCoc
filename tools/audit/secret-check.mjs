import fs from 'node:fs';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const all = process.argv.slice(2).includes('--all');
if (process.argv.slice(2).some((flag) => flag !== '--all')) {
  console.error('Usage: node tools/audit/secret-check.mjs [--all]');
  process.exit(2);
}
const git = (...args) =>
  execFileSync('git', args, { cwd: root, encoding: 'utf8' }).split('\0').filter(Boolean);
const files = [
  ...new Set([
    ...(all
      ? git('ls-files', '-z')
      : git('diff', '--name-only', '-z', '--diff-filter=ACMR', 'HEAD')),
    ...git('ls-files', '-z', '--others', '--exclude-standard'),
  ]),
];
const scanParent = path.join(root, '.cache', 'secret-audit');
fs.mkdirSync(scanParent, { recursive: true });
const scanRoot = fs.mkdtempSync(path.join(scanParent, 'scan-'));
let count = 0;
for (const file of files) {
  if (
    !/\.(md|json|ts|mjs|js|dart|kt|kts|java|gradle|xml|plist|entitlements|properties|ya?ml|toml|example|lock|py|sh|ps1|bat|txt|sql|svg)$/.test(
      file,
    ) &&
    !['AGENTS.md', 'README.md', '.gitignore', '.editorconfig', 'Dockerfile.service'].includes(
      path.basename(file),
    )
  )
    continue;
  const destination = path.resolve(scanRoot, file);
  if (path.relative(scanRoot, destination).startsWith('..')) throw new Error('Unsafe scan path.');
  const source = path.resolve(root, file);
  if (path.relative(root, source).startsWith('..') || fs.lstatSync(source).isSymbolicLink())
    throw new Error('Unsafe source path.');
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.copyFileSync(path.join(root, file), destination);
  count++;
}
// The generated OpenAPI SHA is public integrity metadata, not a credential.
// Keep the exception to this exact computed digest, match and generated path;
// every other Dart/native value still goes through the default secret rules.
const contractHash = createHash('sha256')
  .update(fs.readFileSync(path.join(root, 'docs/api/openapi.yaml')))
  .digest('hex');
const configPath = path.join(root, '.cache', 'secret-audit-gitleaks.toml');
fs.writeFileSync(
  configPath,
  `[extend]
useDefault = true
[[rules]]
id = "generic-api-key"
[[rules.allowlists]]
description = "Verified public OpenAPI source digest only"
condition = "AND"
regexTarget = "match"
regexes = [ '''^apiContractSourceSha256 = '${contractHash}'$''' ]
paths = [ '''apps[/\\\\]mobile[/\\\\]lib[/\\\\]core[/\\\\]api[/\\\\]generated[/\\\\]api_schemas\\.g\\.dart$''' ]
[[rules.allowlists]]
description = "Public SharedPreferences storage namespaces, never credentials"
condition = "AND"
regexTarget = "match"
regexes = [ '''^key = 'billing\\.simulation\\.v1'$''', '''^receiptKey = 'billing\\.api\\.receipt\\.v1'$''' ]
paths = [ '''apps[/\\\\]mobile[/\\\\]lib[/\\\\]features[/\\\\]billing[/\\\\]data[/\\\\]billing_repository\\.dart$''' ]
[[rules.allowlists]]
description = "UUID receipt identity in the persistence protocol test"
condition = "AND"
regexTarget = "match"
regexes = [ '''^key: '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'$''' ]
paths = [ '''services[/\\\\]shared[/\\\\]test[/\\\\]persistence\\.test\\.mjs$''' ]
`,
);
const result = spawnSync(
  'gitleaks',
  ['dir', scanRoot, '--config', configPath, '--no-banner', '--redact=100', '--exit-code=1'],
  { cwd: root, encoding: 'utf8' },
);
const output = `${result.stdout ?? ''}\n${result.stderr ?? ''}`;
if (result.error || result.status !== 0 || /\b(?:ERR|FATAL)\b/.test(output)) {
  console.error(output.trim());
  throw new Error('Secret scanner did not prove success.');
}
console.log(
  JSON.stringify({
    status: 'PASS',
    textFilesScanned: count,
    scanner: 'gitleaks dir with full redaction',
    scope: `${all ? 'all tracked and unignored' : 'changed'} repository text only; no private environment copied`,
  }),
);
