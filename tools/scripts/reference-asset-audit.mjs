import { createHash } from 'node:crypto';
import { readFile, readdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const referenceRoot = path.join(root, 'docs/design/references');
const bundleRoot = path.join(root, 'apps/mobile/assets/reference_art');
const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');
const sources = new Map();
const families = [];
for (const entry of await readdir(referenceRoot, { withFileTypes: true })) {
  if (!entry.isDirectory()) continue;
  const manifest = JSON.parse(await readFile(path.join(referenceRoot, entry.name, 'manifest.json'), 'utf8'));
  let available = 0;
  const entries = manifest.records ?? manifest.screens ?? (manifest.flows ?? []).flatMap(flow => flow.screens.map((screen, index) => ({ ...screen, file: `${flow.flowId}/${String(index + 1).padStart(2, '0')}.png` })));
  for (const screen of entries) {
    const file = `${entry.name}/${screen.file}`;
    const bytes = await readFile(path.join(referenceRoot, file));
    if (bytes.readUInt32BE(16) !== screen.width || bytes.readUInt32BE(20) !== screen.height) {
      throw new Error(`Source dimensions differ from MCP metadata: ${file}`);
    }
    const hash = sha256(bytes);
    sources.set(hash, [...(sources.get(hash) ?? []), file]);
    available++;
  }
  families.push({ family: entry.name, manifestScreens: entries.length, available });
}
const assets = [];
for (const file of await readdir(bundleRoot)) {
  if (!file.endsWith('.png')) continue;
  const hash = sha256(await readFile(path.join(bundleRoot, file)));
  const references = sources.get(hash);
  if (!references) throw new Error(`Bundled illustration source is not byte-identical to a saved MCP reference: ${file}`);
  assets.push({ file, sha256: hash, references });
}
const receipt = { date: new Date().toLocaleDateString('sv-SE', { timeZone: 'Asia/Ho_Chi_Minh' }), families, sourceScreens: families.reduce((sum, f) => sum + f.available, 0), bundledPngs: assets.length, assets,
  scope: 'Local byte/dimension audit of saved MCP references and bundled illustration sources; not independent remote integrity or pixel/motion equivalence.' };
await writeFile(path.join(root, 'docs/design/qa/reference-assets.json'), `${JSON.stringify(receipt, null, 2)}\n`);
console.log(`PASS: ${receipt.sourceScreens} ordered source PNGs in ${families.length} families; ${assets.length} bundled PNGs match saved source bytes.`);
