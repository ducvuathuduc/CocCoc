import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
function files(directory) {
  return fs.readdirSync(path.join(root, directory), { withFileTypes: true }).flatMap((entry) => entry.isDirectory() ? files(path.posix.join(directory, entry.name)) : entry.name.endsWith('.dart') ? [path.posix.join(directory, entry.name)] : []);
}
const controls = [];
for (const file of files('apps/mobile/lib')) {
  const lines = fs.readFileSync(path.join(root, file), 'utf8').split(/\r?\n/);
  lines.forEach((line, index) => {
    const match = line.match(/\b(onPressed|onTap|onChanged|onSubmitted|onSelected|onLongPress):/);
    if (!match) return;
    const snippet = lines.slice(index, index + 7).join('\n').trim();
    controls.push({ id: `CTRL-${String(controls.length + 1).padStart(4, '0')}`, file, line: index + 1, callback: match[1], sourceSnippet: snippet, commandsObserved: [...snippet.matchAll(/\b(controller|vm|notifier|context)\.(\w+)/g)].map((value) => `${value[1]}.${value[2]}`), bindingState: 'SOURCE_DECLARATION; reusable wrapper/multiple runtime states possible', contract: 'docs/product/SCREEN_BEHAVIOR_MAP.md', productionAcceptance: 'gated by owning FR and phase; inventory is not UI/device completion proof' });
  });
}
fs.writeFileSync(path.join(root, 'docs/audit/SCREEN_CONTROLS.json'), `${JSON.stringify({ date: '2026-10-09', scope: 'Exhaustive callback declaration inventory, not automatic semantic traceability proof', controls }, null, 2)}\n`);
console.log(JSON.stringify({ status: 'PASS', callbackDeclarations: controls.length, files: new Set(controls.map((control) => control.file)).size }));
