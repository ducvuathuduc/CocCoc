import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { parse as parseYaml } from 'yaml';
import { JSDOM } from 'jsdom';
import Ajv from 'ajv/dist/2020.js';
import formats from 'ajv-formats';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const excluded = new Set(['.git', 'node_modules', 'build', 'dist', '.dart_tool', '.gradle', '.kotlin', '.cache', 'Pods']);
function files(directory = '') {
  return fs.readdirSync(path.join(root, directory), { withFileTypes: true }).flatMap((entry) => {
    if (excluded.has(entry.name) || entry.isSymbolicLink()) return [];
    const file = path.posix.join(directory, entry.name);
    return entry.isDirectory() ? files(file) : [file];
  });
}
const inventory = files();
const required = ['docs/00_START_HERE.md', 'docs/ARCHITECTURE_FREEZE_REPORT.md', 'docs/audit/DOCS_MANIFEST.md', 'docs/audit/INPUT_INVENTORY.json', 'docs/audit/SCREEN_CONTROLS.json', 'docs/product/STATE_MACHINES.md', 'docs/product/CONTENT_MODEL.md', 'docs/product/MONETIZATION.md', 'docs/ai/PROVIDER_BENCHMARK.md', 'pnpm-lock.yaml'];
for (const file of required) if (!inventory.includes(file)) throw new Error(`Missing refresh deliverable: ${file}`);
let json = 0, yaml = 0, links = 0, diagrams = 0;
const dom = new JSDOM('<!doctype html><html><body></body></html>');
globalThis.window = dom.window; globalThis.document = dom.window.document;
const { default: mermaid } = await import('mermaid');
mermaid.initialize({ startOnLoad: false, securityLevel: 'strict' });
for (const file of inventory) {
  if (file.endsWith('.json')) { JSON.parse(fs.readFileSync(path.join(root, file), 'utf8')); json++; }
  if ((file.startsWith('.github/') || file === 'pnpm-workspace.yaml' || file === 'pnpm-lock.yaml') && /\.ya?ml$/.test(file)) { parseYaml(fs.readFileSync(path.join(root, file), 'utf8')); yaml++; }
  if (!file.endsWith('.md')) continue;
  const body = fs.readFileSync(path.join(root, file), 'utf8');
  for (const match of body.matchAll(/!?\[[^\]\n]*\]\(([^)\n]+)\)/g)) {
    const target = match[1].replace(/^<|>$/g, '').split('#')[0];
    if (!target || /^(https?:|mailto:|codex:|app:)/.test(target)) continue;
    const full = path.resolve(root, path.dirname(file), decodeURIComponent(target));
    if (path.relative(root, full).startsWith('..') || !fs.existsSync(full)) throw new Error(`${file}: broken/outside link ${target}`);
    links++;
  }
  for (const match of body.matchAll(/(?:```|~~~)mermaid\s*\n([\s\S]*?)(?:```|~~~)/g)) {
    try { await mermaid.parse(match[1]); diagrams++; } catch (error) { throw new Error(`${file}: Mermaid parse failed: ${error.message}`); }
  }
}
const api = JSON.parse(fs.readFileSync(path.join(root, 'docs/api/openapi.yaml'), 'utf8'));
const ajv = new Ajv({ strict: false });
formats(ajv);
ajv.addSchema({ $id: 'https://cocenglish.example.invalid/schema', components: api.components });
const validateEvent = ajv.compile({ $ref: 'https://cocenglish.example.invalid/schema#/components/schemas/BusinessEvent' });
const eventExample = JSON.parse(fs.readFileSync(path.join(root, 'docs/api/examples/lesson-completed.v1.json'), 'utf8'));
if (!validateEvent(eventExample)) throw new Error(`Event example violates OpenAPI: ${JSON.stringify(validateEvent.errors)}`);
const generated = fs.readFileSync(path.join(root, 'packages/api_contracts/generated.ts'), 'utf8');
for (const operations of Object.values(api.paths)) for (const operation of Object.values(operations)) if (operation.operationId && !generated.includes(operation.operationId)) throw new Error(`Generated type missing operation ${operation.operationId}`);
for (const name of ['learning', 'progress', 'ai']) {
  const descriptor = JSON.parse(fs.readFileSync(path.join(root, `services/${name}/appwrite-function.json`), 'utf8'));
  if (descriptor.runtime !== 'node-22' || descriptor.enabled !== false || descriptor.scopes.length || descriptor.execute.length) throw new Error(`${name}: unexpected enabled/privileged scaffold`);
  const source = fs.readFileSync(path.join(root, `services/${name}/src/index.ts`), 'utf8');
  if (/mock-|fixture/.test(source)) throw new Error(`${name}: fixture import in hosted entrypoint`);
}
dom.window.close();
console.log(JSON.stringify({ status: 'PASS', json, yaml, localLinks: links, mermaidDiagrams: diagrams, eventExamples: 1, generatedSha256: crypto.createHash('sha256').update(generated).digest('hex'), scope: 'syntax/integrity and disabled-adapter checks; no cloud/device proof' }, null, 2));
