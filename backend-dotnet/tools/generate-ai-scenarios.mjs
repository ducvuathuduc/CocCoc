import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { SCENARIOS } from '../../services/ai/src/domain/scenarios.ts';

const target = fileURLToPath(new URL('../src/CocEnglish.AI/scenarios.json', import.meta.url));
const generated = JSON.stringify(SCENARIOS);

if (process.argv.includes('--check')) {
  const current = await readFile(target, 'utf8');
  if (current !== generated) {
    console.error('AI scenario catalog is stale; run node --experimental-strip-types backend-dotnet/tools/generate-ai-scenarios.mjs');
    process.exitCode = 1;
  } else {
    console.log(JSON.stringify({ status: 'PASS', scenarios: SCENARIOS.length, mode: 'check' }));
  }
} else {
  await writeFile(target, generated, 'utf8');
  console.log(JSON.stringify({ status: 'PASS', scenarios: SCENARIOS.length, mode: 'write' }));
}
