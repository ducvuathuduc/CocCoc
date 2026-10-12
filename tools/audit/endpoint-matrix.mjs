// Regenerates docs/api/API_ENDPOINT_MATRIX.md from docs/api/openapi.yaml.
// Writes only that file; the hand-maintained "## Proposed endpoints" tail is preserved.
// `--check` exits 1 when the committed matrix is stale (used by audit:check).
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const api = JSON.parse(fs.readFileSync(path.join(root, 'docs/api/openapi.yaml'), 'utf8'));
const endpoints = Object.entries(api.paths).flatMap(([route, item]) => Object.entries(item).filter(([method]) => ['get','post','patch','put','delete'].includes(method)).map(([method, operation]) => `| ${method.toUpperCase()} ${route} | ${operation.operationId} / ${operation['x-owner']} | ${(operation['x-requirements'] ?? []).join(', ') || 'health/internal'} | ${(operation['x-tables'] ?? []).join(', ') || 'none'} | ${operation.security?.length ? 'JWT or specified internal signature' : 'public health'} |`));
const matrixFile = path.join(root, 'docs/api/API_ENDPOINT_MATRIX.md');
const previousMatrix = fs.existsSync(matrixFile) ? fs.readFileSync(matrixFile, 'utf8') : '';
const proposedAt = previousMatrix.indexOf('\n## Proposed endpoints');
const proposed = proposedAt >= 0 ? previousMatrix.slice(proposedAt) : '';
const next = `# Derived endpoint ownership matrix\n\nGenerated from [OpenAPI](openapi.yaml); wire DTOs/headers/errors/idempotency/rate/version behavior remain there and in [auth](AUTH.md)/[events-errors](EVENTS_ERRORS.md). [Behavior map](../product/SCREEN_BEHAVIOR_MAP.md) identifies consuming mock seams; [traceability](../quality/TRACEABILITY.md) names acceptance tests. Hosted business handlers are not implemented by a generated matrix.\n\n| Route | Operation / owner | Requirements | Owned tables | Access |\n|---|---|---|---|---|\n${endpoints.join('\n')}\n\nHealth/ready shapes apply to all three independent service domains; Learning is the primary OpenAPI declaration owner. Internal events have receiver-specific allowlists, not cross-owned writes.\n${proposed}`;
if (process.argv.includes('--check')) {
  if (next !== previousMatrix) {
    console.error('docs/api/API_ENDPOINT_MATRIX.md is stale: run `pnpm docs:endpoints`.');
    process.exit(1);
  }
} else {
  fs.writeFileSync(matrixFile, next);
}
console.log(JSON.stringify({ endpoints: endpoints.length, output: 'docs/api/API_ENDPOINT_MATRIX.md', mode: process.argv.includes('--check') ? 'check' : 'write' }));
