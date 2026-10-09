# CocEnglish project instructions

Read docs/00_START_HERE.md, the assigned task in docs/agent/IMPLEMENTATION_PLAN.md, and nearest nested AGENTS.md before changing code. Current authorized architecture audit/research/scaffold task: docs/agent/RESEARCH_REFRESH_PLAN.md. Existing frontend work in docs/agent/FRONTEND_FLOW_PLAN.md is preserved. Full cloud/device/production phase gates remain pending.

Frozen: Flutter Android/iOS; feature-first Riverpod MVVM; TypeScript/Node22; three services Learning/Progress/AI; Appwrite Auth/TablesDB/Storage; REST/OpenAPI; service-owned writes; Drift journal. Change architecture only through docs/agent/TASK_PROTOCOL.md ADR procedure. Do not default to Python or add broker/cluster/cache/gateway products.

Canonical owners: requirements docs/product/SRS.md; wire docs/api/openapi.yaml; storage docs/data/DATA_MODEL.md; design docs/design/DESIGN.md; phases docs/agent/IMPLEMENTATION_PLAN.md. Link, do not duplicate.

Claim one task/change area; inspect targeted symbols with rg/AST tools, not whole-repo dumps. Parallel work stays within current passed phase. Root contracts, routing, dependency locks and migrations are exclusive change areas. Native forks share subscription quota; use at most one child and only for a useful isolated context.

Preserve input on failures. User identity from verified Appwrite JWT; keys server-side. Never trust client XP/clock/pronunciation score. No live AI in deterministic CI. Secrets/logs redacted; no paid adapter auto-enables.

For behavior changes, write a meaningful failing test, implement, run targeted checks, then required gate. For major screens use gummble-ui-research skill and project tokens/state fixtures. Report exact commands/evidence and capability limitations; never claim app build/device success from document checks.

No deploy, publish, merge, reset/delete, force-push or new paid plan without explicit request. Research/scaffold permission does not authorize those actions.

Checks: pnpm backend:verify; pnpm backend:smoke; pnpm contracts:check; pnpm api:lint; pnpm audit:check; pnpm verify. See docs/devops/LOCAL_SETUP_WINDOWS.md. Mock stores never power cloud entrypoints; readiness fails closed until actual adapters are admitted. Before ending, update only assigned task evidence and canonical docs affected by actual decisions.
