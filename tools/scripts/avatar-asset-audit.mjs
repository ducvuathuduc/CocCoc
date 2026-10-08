import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const inventory=JSON.parse(await readFile(path.join(root,
  'docs/design/references/AVATAR_ASSETS.json'),'utf8'));
for (const item of inventory.assets) {
  const resolved=path.resolve(root,item.file);
  if (!resolved.startsWith(`${root}${path.sep}`)) throw Error('Invalid asset path');
  const bytes=await readFile(resolved);
  const digest=createHash('sha256').update(bytes).digest('hex');
  if (bytes.length!==item.bytes || digest!==item.sha256) throw Error(`Asset differs: ${item.file}`);
}
const config=JSON.parse(await readFile(path.join(root,
  'apps/mobile/assets/avatar/avatar_builder_config.json'),'utf8')).avatarBuilderConfig;
const choices=config.stateChooserTabs.reduce((n,t)=>n+t.sections.reduce((m,s)=>
  m+s.imageButtons.length+s.featureButtons.length,0),0);
console.log(`PASS: ${inventory.assets.length} avatar assets, ${config.stateChooserTabs.length} categories, ${choices} configured choices; byte hashes intact.`);
