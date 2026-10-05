import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '../..');
const ledgerPath = 'docs/design/qa/FLOW_COVERAGE.json';
const read = relative => JSON.parse(fs.readFileSync(path.join(root, relative), 'utf8'));
const index = read('docs/design/references/ORDERED_FLOW_INDEX.json');
const ledger = read(ledgerPath);
const statuses = new Set(['pending', 'analyzed', 'in_progress', 'verified_mock']);
const familyIds = new Set(ledger.families.map(family => family.id));
if (familyIds.size !== ledger.families.length) throw new Error('Duplicate family ID.');
const byId = new Map(ledger.flows.map(flow => [flow.flowId, flow]));
if (byId.size !== ledger.flows.length || byId.size !== index.flows.length) {
  throw new Error('Coverage must contain each scoped flow exactly once.');
}
let steps = 0;
for (const source of index.flows) {
  const entry = byId.get(source.flowId);
  if (!entry || entry.flowName !== source.flowName || !statuses.has(entry.status)) {
    throw new Error(`Unknown or changed flow: ${source.flowId}`);
  }
  if (JSON.stringify(entry.screens.map(screen => screen.screenId)) !==
      JSON.stringify(source.screens.map(screen => screen.id))) {
    throw new Error(`Ordered screen mismatch: ${source.flowId}`);
  }
  for (const screen of entry.screens) {
    steps++;
    if (!statuses.has(screen.status)) throw new Error(`Invalid status: ${screen.screenId}`);
    if (screen.status === 'verified_mock' && !screen.evidence.length) {
      throw new Error(`Missing completion evidence: ${screen.screenId}`);
    }
    for (const evidence of screen.evidence) {
      if (!fs.existsSync(path.join(root, evidence))) throw new Error(`Missing ${evidence}`);
    }
  }
  for (const family of entry.reuseFamilies) {
    if (!familyIds.has(family)) throw new Error(`Unknown reuse family: ${family}`);
  }
  if (entry.status === 'verified_mock' && entry.screens.some(screen => screen.status !== 'verified_mock')) {
    throw new Error(`Cannot close incomplete flow: ${source.flowId}`);
  }
}
for (const family of ledger.families) {
  if (!statuses.has(family.status)) throw new Error(`Invalid family status: ${family.id}`);
  for (const evidence of family.evidence) {
    if (!fs.existsSync(path.join(root, evidence))) throw new Error(`Missing ${evidence}`);
  }
}
const symbol = { pending: '⬜', analyzed: '🔎', in_progress: '🔄', verified_mock: '✅' };
const lines = [
  '# English UI flow checklist', '',
  `Updated ${ledger.updated}. ${byId.size} scoped flows / ${steps} ordered screen occurrences.`, '',
  'This is the persistent completion register. ✅ means the scoped native mock UI was implemented and verified; exact pixel/motion and production gates remain separate. Existing families below are reused. A pending source variant does not authorize rebuilding its shared controller or screen.', '',
  'Edit FLOW_COVERAGE.json after checking evidence, then run `node tools/scripts/flow-coverage.mjs --write`. Regeneration reads existing marks; it does not reset them.', '',
  '## Existing reusable families', '',
  '| State | Family | Evidence | Open limits |', '| --- | --- | --- | --- |',
  ...ledger.families.map(family => `| ${symbol[family.status]} | ${family.name} | [analysis](${path.relative('docs/design/qa', family.evidence[0]).replaceAll('\\', '/')}) | ${family.openLimits} |`),
  '', '## Ordered source flows', '',
  '| State | Flow | Verified screens | Reuse family |', '| --- | --- | --- | --- |',
  ...ledger.flows.map(flow => `| ${symbol[flow.status]} | [${flow.flowName}](${flow.gummbleUrl}) · ${flow.flowId} | ${flow.screens.filter(screen => screen.status === 'verified_mock').length}/${flow.screens.length} | ${flow.reuseFamilies.join(', ') || 'New slice'} |`),
  '', 'Per-screen IDs, status, evidence and differences are stored in [FLOW_COVERAGE.json](FLOW_COVERAGE.json).', '',
];
if (process.argv.includes('--write')) {
  fs.writeFileSync(path.join(root, 'docs/design/qa/FLOW_CHECKLIST.md'), lines.join('\n'));
}
console.log(`PASS ${byId.size} flow IDs / ${steps} ordered screens; completion evidence exists.`);
