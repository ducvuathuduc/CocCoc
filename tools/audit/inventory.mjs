import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const skip = new Set(['.git', 'node_modules', '.dart_tool', 'build', '.gradle', 'Pods', '.cache', '.pnpm-store', 'dist', '.secrets', '.screenshots']);
const textExtensions = new Set(['.md', '.dart', '.ts', '.js', '.mjs', '.json', '.yaml', '.yml', '.toml', '.xml', '.gradle', '.kts', '.plist', '.swift', '.kt', '.ps1', '.properties', '.lock', '.html', '.css', '.txt', '.xcconfig', '.pbxproj']);
function walk(directory = '') {
  return fs.readdirSync(path.join(root, directory), { withFileTypes: true }).flatMap((entry) => {
    if (skip.has(entry.name) || entry.name === '.env' || (entry.name.startsWith('.env.') && !entry.name.endsWith('.example')) || entry.name === 'local.properties') return [];
    const relative = path.posix.join(directory, entry.name);
    return entry.isDirectory() ? walk(relative) : entry.isSymbolicLink() ? [] : [relative];
  });
}
const git = (...args) => execFileSync('git', args, { cwd: root, encoding: 'utf8' }).trim();
const baseline = git('rev-parse', 'HEAD');
const records = walk().filter((file) => !file.startsWith('docs/audit/')).sort().map((file) => {
  const bytes = fs.readFileSync(path.join(root, file));
  const isText = textExtensions.has(path.extname(file)) || ['AGENTS.md', 'CLAUDE.md', '.gitignore', '.editorconfig'].includes(path.basename(file));
  const text = isText ? bytes.toString('utf8') : '';
  return {
    path: file,
    bytes: bytes.length,
    sha256: crypto.createHash('sha256').update(bytes).digest('hex'),
    type: path.extname(file).slice(1) || 'configuration',
    inspection: isText ? 'AUTOMATED_FULL_TEXT; focused human-model review where referenced' : 'HASH_AND_METADATA_ONLY; visual sample separately recorded',
    headings: file.endsWith('.md') ? [...text.matchAll(/^#{1,3} (.+)$/gm)].map((match) => match[1].trim()) : undefined,
    routes: file.endsWith('.dart') ? [...text.matchAll(/path:\s*'([^']+)'/g)].map((match) => match[1]) : undefined,
    classes: file.endsWith('.dart') ? [...text.matchAll(/^(?:abstract |sealed |final |base )?class (\w+)/gm)].map((match) => match[1]) : undefined,
    tests: file.endsWith('_test.dart') ? [...text.matchAll(/(?:test|testWidgets)\(\s*['"]([^'"\n]+)['"]/g)].map((match) => match[1]) : undefined,
  };
});
const docs = records.filter((record) => record.path.startsWith('docs/') && record.type === 'md');
const mobile = records.filter((record) => record.path.startsWith('apps/mobile/lib/'));
const counts = Object.fromEntries([...new Set(records.map((record) => record.type))].map((type) => [type, records.filter((record) => record.type === type).length]));
const result = {
  date: '2026-10-09',
  project: root,
  baselineCommit: baseline,
  commitDate: git('show', '-s', '--format=%cI', 'HEAD'),
  branch: git('branch', '--show-current'),
  exclusions: [...skip, 'private environment files and local.properties', 'symlinks'],
  sourceAvailability: { currentDirective: 'user attachment read in session; not copied into repository', earlierMasterDirectives: 'MISSING SOURCE — USER ACTION NEEDED', courseworkRubric: 'MISSING SOURCE — USER ACTION NEEDED', legacyDocsArchive: 'MISSING SOURCE — USER ACTION NEEDED; existing docs inspected instead' },
  counts, records,
};
fs.mkdirSync(path.join(root, 'docs/audit'), { recursive: true });
fs.writeFileSync(path.join(root, 'docs/audit/INPUT_INVENTORY.json'), `${JSON.stringify(result, null, 2)}\n`);
const rows = docs.map((record) => {
  const isHistoric = /\/design\/(flows|qa)\//.test(record.path) || /REPOSITORY_CLEANUP|GITHUB_SNAPSHOT|REPOSITORY_HANDOFF_PLAN/.test(record.path);
  const update = /00_READ_ME_FIRST|ARCHITECTURE_BLUEPRINT|FREEZE_REVIEW|ASSUMPTIONS|RESEARCH_EVIDENCE|AI_EVIDENCE|STACK|AI_ARCHITECTURE|COST_MODEL|CI_CD|OPERATIONS|IMPLEMENTATION_PLAN|DEVELOPER_HANDOFF|REPOSITORY_TREE|FEATURE_MATRIX|SCREEN_INVENTORY|SRS|USER_FLOWS|EDGE_CASE_MATRIX/.test(record.path);
  const disposition = isHistoric ? 'KEEP — historical evidence' : update ? 'MODIFY' : 'KEEP';
  const action = isHistoric ? 'Preserve receipt/date; never infer current device or production proof.' : update ? 'Link current refresh; reconcile implementation/status/vendor claims. Preserve IDs and contracts.' : 'Retain canonical contract; link refresh where relevant. No duplicate owner.';
  return `| [${record.path.replaceAll('docs/', '')}](../${record.path.slice(5)}) | ${disposition} | ${record.sha256.slice(0, 12)}; ${record.headings[0] ?? 'document'} | ${action} |`;
});
fs.writeFileSync(path.join(root, 'docs/audit/LEGACY_DOC_AUDIT.md'), `# Legacy document audit\n\nSnapshot 2026-10-09, baseline ${baseline}. Every row corresponds to a real document read by the inventory scanner; focused review is recorded in the current audit. No legacy files were deleted. The supplied current directive overrides contradictory historical assumptions. Binary screenshots receive metadata/hash inspection, not a claim that every image was visually examined.\n\n| Document | Disposition | Evidence / original content | Migration action |\n|---|---|---|---|\n${rows.join('\n')}\n\nMissing prior master directives, archived docs outside this checkout and assignment rubric are **MISSING SOURCE — USER ACTION NEEDED**. No named missing source was represented as inspected. Current operational contradictions and corrections are in [changelog](CHANGELOG.md).\n`);
console.log(JSON.stringify({ baseline, files: records.length, documents: docs.length, mobileSourceFiles: mobile.length, counts, routes: mobile.flatMap((record) => record.routes ?? []), sourceModules: [...new Set(mobile.map((record) => record.path.split('/').slice(0, 5).join('/')))], screenClasses: mobile.flatMap((record) => record.classes ?? []).filter((name) => /Screen|Flow|Shell|Path/.test(name)) }, null, 2));
