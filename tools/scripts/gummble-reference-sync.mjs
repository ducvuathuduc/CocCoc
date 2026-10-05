import { readFile, writeFile, mkdir, access } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import path from 'node:path';

// Explicit, read-only research command. No credentials, HTML scraping or app writes.
const root = path.resolve(import.meta.dirname, '../..');
const directory = path.join(root, 'docs/design/references/catalog-cache');
const index = JSON.parse(await readFile(path.join(root, 'docs/design/references/ORDERED_FLOW_INDEX.json'), 'utf8'));
await mkdir(directory, { recursive: true });
const screens = [...new Map(index.flows.flatMap(flow => flow.screens).map(screen => [screen.id, screen])).values()];
let cursor = 0;
let completed = 0;
const failures = [];
const records = [];
await Promise.all(Array.from({ length: 6 }, async () => {
  while (cursor < screens.length) {
    const screen = screens[cursor++];
    const file = `${screen.id}.png`;
    const target = path.join(directory, file);
    try {
      try { await access(target); } catch {
        const url = new URL(screen.screenUrl);
        if (url.protocol !== 'https:' || url.hostname !== 'storage.gummble.com') throw new Error('Unexpected source host');
        let bytes;
        for (let attempt = 0; attempt < 3; attempt++) {
          try {
            const response = await fetch(url, { signal: AbortSignal.timeout(30000) });
            if (!response.ok) throw new Error(`HTTP ${response.status}`);
            bytes = Buffer.from(await response.arrayBuffer());
            break;
          } catch (error) { if (attempt === 2) throw error; }
        }
        if (bytes.toString('hex', 0, 8) !== '89504e470d0a1a0a') throw new Error('Source is not a PNG');
        await writeFile(target, bytes);
      }
      const bytes = await readFile(target);
      const width = bytes.readUInt32BE(16), height = bytes.readUInt32BE(20);
      if (width !== screen.width || height !== screen.height) throw new Error('Source dimensions mismatch');
      records.push({ id: screen.id, file, width, height, sha256: createHash('sha256').update(bytes).digest('hex'), url: screen.screenUrl });
      completed++;
      if (completed % 50 === 0) process.stdout.write(`${completed}/${screens.length} source PNGs verified\n`);
    } catch (error) { failures.push({ id: screen.id, error: String(error) }); }
  }
}));
records.sort((a, b) => a.id.localeCompare(b.id));
await writeFile(path.join(directory, 'manifest.json'), JSON.stringify({ captured: '2026-10-04', flows: index.flows.length, orderedSteps: index.orderedScreens, uniqueScreens: screens.length, verified: records.length, records, failures }, null, 2) + '\n');
process.stdout.write(JSON.stringify({ flows: index.flows.length, orderedSteps: index.orderedScreens, uniqueScreens: screens.length, verified: records.length, failures: failures.length }) + '\n');
if (failures.length) process.exitCode = 1;
