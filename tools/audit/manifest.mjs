import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const git = (...args) => execFileSync('git', args, { cwd: root, encoding: 'utf8' }).trim().split(/\r?\n/).filter(Boolean);
const changed = [...new Set([...git('diff', '--name-only'), ...git('ls-files', '--others', '--exclude-standard')])].sort();
const owner = (file) => {
  if (file.startsWith('docs/audit/')) return 'Ground truth, evidence, disposition or verification';
  if (file.startsWith('docs/product/')) return 'Requirements, behaviors, content or future billing';
  if (file.startsWith('docs/ai/') || file.startsWith('tools/evals/')) return 'Capability candidates, evals and honest scoring';
  if (file.startsWith('docs/architecture/')) return 'Boundaries, authority or decision rationale';
  if (file.startsWith('docs/devops/') || file.startsWith('.github/')) return 'Setup, recovery, cost or deterministic CI';
  if (file.startsWith('docs/quality/')) return 'Readiness and professor demonstration';
  if (file.startsWith('services/')) return 'Independent owner scaffold, transport/auth or acceptance fixture';
  if (file.startsWith('appwrite/')) return 'Additive foundation schema/dry-run or typed seed';
  if (file.startsWith('packages/')) return 'OpenAPI-derived wire types only';
  if (file.startsWith('tools/')) return 'Reproducible local build/check/audit command';
  return 'Navigation, task state or enforced tool configuration';
};
const method = (file) => file.endsWith('.ts') ? 'strict TS/ESLint; generated wire schema for contracts' : /\.json$/.test(file) ? 'JSON parse + applicable schema/owner checks' : /\.ya?ml$/.test(file) ? 'YAML parse; CI not externally executed' : file.endsWith('.mjs') ? 'node syntax + applicable executed command' : file.endsWith('.md') ? 'internal links + Mermaid when present; evidence distinguished' : 'configuration/lock/diff inspection';
const rows = changed.map((file) => `| [${file}](../../${file}) | ${owner(file)} | ${method(file)} |`);
const mappings = [
  ['START_HERE and prior READ_ME_FIRST', 'docs/00_START_HERE.md', 'Current entry; historical reading order remains a redirecting map'],
  ['INPUT_INVENTORY / LEGACY_DOC_AUDIT / UI_IMPLEMENTATION_GAP / RESEARCH_EVIDENCE / OPEN_DECISIONS', 'docs/audit/INPUT_INVENTORY.md', 'Separate audit files + machine inventory and source-control index'],
  ['SRS / FEATURE_MATRIX / SCREEN_INVENTORY / SCREEN_BEHAVIOR_MAP / USER_FLOWS / STATE_MACHINES / EDGE_CASE_MATRIX / CONTENT_MODEL / MONETIZATION', 'docs/product/SRS.md', 'Existing owners retained; missing behavior/state/content/billing contracts added'],
  ['DESIGN / TOKENS / COMPONENT_STATES / MOTION_AUDIO / GUMMBLE_REFERENCE', 'docs/design/DESIGN.md', 'Tokens/motion/audio in DESIGN; states and Gummble provenance in existing sibling files; no pixel rewrite'],
  ['ARCHITECTURE / STACK / SERVICE_CATALOG / DATA_OWNERSHIP / NFR', 'docs/architecture/ARCHITECTURE.md', 'Architecture/stack/catalog/NFR retained; table/index/PII/retention/permissions in docs/data owners'],
  ['CONSISTENCY / EVENTS / OFFLINE_SYNC', 'docs/architecture/CONSISTENCY.md', 'Consistency added; event schema/retry in api/EVENTS_ERRORS; offline protocol in architecture/OFFLINE'],
  ['COST_AND_CREDITS / BILLING_ARCHITECTURE', 'docs/devops/COST_MODEL.md', 'One cost owner; product/MONETIZATION owns later store verification/entitlements'],
  ['Required ADR subjects 0001–0007', 'docs/architecture/adr/README.md', 'Preserve existing 17 ADR IDs; subject equivalents: 0001 Flutter,0004 Appwrite,0005 services,0002 Riverpod,0016 outbox,0011 voice,0012 assessment'],
  ['openapi / API_ENDPOINT_MATRIX / ERROR_CATALOG / WEBHOOKS_AND_EVENTS / examples', 'docs/api/openapi.yaml', 'Wire unchanged; derived endpoint matrix + synthetic event example; errors/events/auth own detailed behavior; billing webhooks in monetization until API added'],
  ['AI_ARCHITECTURE / PROVIDER_BENCHMARK / PRICING_AND_QUOTAS', 'docs/ai/PROVIDER_BENCHMARK.md', 'Current candidate/price/transport/account table; operational lifecycle in AI_ARCHITECTURE'],
  ['SPEAKING_SPEC / LISTENING_SPEC / PRONUNCIATION_SPEC / EVALUATIONS / PROMPT_REGISTRY', 'docs/ai/AI_ARCHITECTURE.md', 'Lifecycle/listening/assessment consolidated here; AI_EVALS + actual prompt/harness fixtures own evaluation/registry'],
  ['ENVIRONMENTS / LOCAL_SETUP_WINDOWS / APPWRITE_SETUP / CI_CD / SECRETS', 'docs/devops/LOCAL_SETUP_WINDOWS.md', 'Windows/Appwrite setup added; existing CI_CD owns environments/secrets/deploy/rollback; descriptors disabled'],
  ['NOTIFICATIONS / OBSERVABILITY / LOAD_FAILURE_TESTING / RUNBOOK', 'docs/devops/OPERATIONS.md', 'One operations owner; permission/device/push behavior also references SRS/state machine; no imaginary cluster'],
  ['ANDROID_RELEASE / IOS_CLOUD_BUILD', 'docs/devops/CI_CD.md', 'Existing pipeline/release procedure with explicit device/signing gates; local setup and release gate link it'],
  ['TEST_STRATEGY / TEST_MATRIX / CONTRACT_TESTS / PERFORMANCE_BUDGET / RELEASE_GATE / DEMO_PLAYBOOK', 'docs/quality/TEST_STRATEGY.md', 'Strategy + TRACEABILITY/NFR own detailed matrix/targets; real contract tooling and release/demo files added'],
  ['IMPLEMENTATION_PLAN / TASK_BOARD / TASK_PROTOCOL / PARALLEL_WORK_MATRIX / DECISION_LOG / CHANGE_CONTROL / TRACEABILITY', 'docs/agent/IMPLEMENTATION_PLAN.md', 'Existing task-status.json, TASK_PROTOCOL, DEPENDENCY_DAG, ADR index and quality/TRACEABILITY remain owners; refresh plan/evidence added'],
  ['Root/nested AGENTS / CLAUDE / useful skills/hooks / valid Codex config', 'AGENTS.md', 'Short root/nested guidance and existing four canonical skills/wrappers retained; config.example.toml only; no duplicated new prompt suite'],
  ['Scaffold / schema / seed / tests / local smoke', 'services/AGENTS.md', 'Three separate artifacts plus four-table initial schema and unavailable typed catalog seed; full cloud schema/curriculum remains phase-gated'],
];
const consolidation = mappings.map(([requested, file, note]) => `| ${requested} | [${file}](../../${file}) | ${note} |`);
fs.writeFileSync(path.join(root, 'docs/audit/DOCS_MANIFEST.md'), `# Actual changed files and content ownership\n\nFinal manifest generated from Git diff/untracked files on 2026-10-10. No generated cache/install/build directories are listed. Individual command results are in [validation](VALIDATION.md). A listed check method is not an assertion that cloud/device evidence exists.\n\n## Required-content consolidation\n\nThe directive explicitly permits consolidation. These mappings preserve required content in one substantive canonical owner instead of creating empty duplicate documents. Phase-gated integrations are named honestly.\n\n| Requested documents/content | Canonical owner | Content/implementation scope |\n|---|---|---|\n${consolidation.join('\n')}\n\n## Created/updated files\n\n| Actual path | Ownership | Validation method |\n|---|---|---|\n${rows.join('\n')}\n\n## Preserved baseline\n\nMobile source/assets/pubspec lock and original 17 ADR identities are preserved. The 101 legacy documentation rows are in [legacy audit](LEGACY_DOC_AUDIT.md). OpenAPI remains the original 42-operation/94-schema contract; generated DTOs and examples derive from it. Production readiness remains conditional.\n`);
const api = JSON.parse(fs.readFileSync(path.join(root, 'docs/api/openapi.yaml'), 'utf8'));
const endpoints = Object.entries(api.paths).flatMap(([route, item]) => Object.entries(item).filter(([method]) => ['get','post','patch','put','delete'].includes(method)).map(([method, operation]) => `| ${method.toUpperCase()} ${route} | ${operation.operationId} / ${operation['x-owner']} | ${(operation['x-requirements'] ?? []).join(', ') || 'health/internal'} | ${(operation['x-tables'] ?? []).join(', ') || 'none'} | ${operation.security?.length ? 'JWT or specified internal signature' : 'public health'} |`));
fs.writeFileSync(path.join(root, 'docs/api/API_ENDPOINT_MATRIX.md'), `# Derived endpoint ownership matrix\n\nGenerated from [OpenAPI](openapi.yaml); wire DTOs/headers/errors/idempotency/rate/version behavior remain there and in [auth](AUTH.md)/[events-errors](EVENTS_ERRORS.md). [Behavior map](../product/SCREEN_BEHAVIOR_MAP.md) identifies consuming mock seams; [traceability](../quality/TRACEABILITY.md) names acceptance tests. Hosted business handlers are not implemented by a generated matrix.\n\n| Route | Operation / owner | Requirements | Owned tables | Access |\n|---|---|---|---|---|\n${endpoints.join('\n')}\n\nHealth/ready shapes apply to all three independent service domains; Learning is the primary OpenAPI declaration owner. Internal events have receiver-specific allowlists, not cross-owned writes.\n`);
console.log(JSON.stringify({ changedFiles: changed.length, endpoints: endpoints.length, source: 'actual Git diff/untracked files and OpenAPI' }));
