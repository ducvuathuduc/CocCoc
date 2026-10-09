# CocEnglish — current engineering entry

Updated 2026-10-10. Product: English language learning for Vietnamese-speaking university learners, Android first, Flutter iOS from the same codebase. Application identifiers remain `com.cocenglish.cocenglish`. Existing source and reference assets are preserved.

## What is implemented and what is designed

The actual Flutter app has onboarding/authentication UI, a learning path, deterministic mock lessons, practice, progress, social/settings and subscription preview flows. Most features use local fixtures. An Appwrite Auth adapter exists but account setup, cloud identity/permissions and device proof are not established by its presence. Lesson drafts are in memory; the planned Drift journal is not implemented. Native live voice, assessed pronunciation, server-authoritative rewards, billing and cloud asynchronous delivery remain gated.

The local backend foundation now supplies three separate Function artifacts, strict TypeScript, verified-account adapter code and deterministic async workflow fixtures. Hosted entrypoints fail closed for business routes; fixture stores are never cloud persistence. This is an executable design and a local scaffold, not a production-ready integration.

## Read by purpose

| Purpose | Canonical owner |
|---|---|
| Current verdict, risks and validation | [freeze report](ARCHITECTURE_FREEZE_REPORT.md) |
| Actual inputs / previous docs / existing UI gaps | [input inventory](audit/INPUT_INVENTORY.md), [legacy audit](audit/LEGACY_DOC_AUDIT.md), [UI gap](audit/UI_IMPLEMENTATION_GAP.md) |
| Current external claims / blockers / changes | [evidence](audit/RESEARCH_EVIDENCE.md), [open decisions](audit/OPEN_DECISIONS.md), [changelog](audit/CHANGELOG.md) |
| Requirements and feature priority | [SRS](product/SRS.md), [feature matrix](product/FEATURE_MATRIX.md) |
| Screens, controls, transitions and content | [screen inventory](product/SCREEN_INVENTORY.md), [behavior map](product/SCREEN_BEHAVIOR_MAP.md), [state machines](product/STATE_MACHINES.md), [content model](product/CONTENT_MODEL.md) |
| Architecture, boundaries and authority | [architecture](architecture/ARCHITECTURE.md), [service catalog](architecture/SERVICE_CATALOG.md), [consistency](architecture/CONSISTENCY.md), [data model](data/DATA_MODEL.md) |
| REST / events / auth / schemas | [OpenAPI](api/openapi.yaml), [events/errors](api/EVENTS_ERRORS.md), [authentication](api/AUTH.md) |
| UI tokens, media and reference provenance | [design](design/DESIGN.md), [component states](design/COMPONENT_STATES.md), [Gummble research](design/GUMMBLE_RESEARCH.md) |
| AI candidates, prices, scoring and evaluation | [provider benchmark](ai/PROVIDER_BENCHMARK.md), [AI architecture](ai/AI_ARCHITECTURE.md), [evaluations](ai/AI_EVALS.md) |
| Windows setup, Appwrite integration, cost and recovery | [local setup](devops/LOCAL_SETUP_WINDOWS.md), [Appwrite setup](devops/APPWRITE_SETUP.md), [cost model](devops/COST_MODEL.md), [operations](devops/OPERATIONS.md) |
| Commercialization design | [monetization](product/MONETIZATION.md) |
| Phases and assigned work | [phase plan](agent/IMPLEMENTATION_PLAN.md), [refresh task](agent/RESEARCH_REFRESH_PLAN.md), [task protocol](agent/TASK_PROTOCOL.md) |
| Release/demo evidence | [release gate](quality/RELEASE_GATE.md), [demo playbook](quality/DEMO_PLAYBOOK.md), [validation receipt](audit/VALIDATION.md) |
| Requested-document consolidation and actual files | [manifest](audit/DOCS_MANIFEST.md), [actual repository tree](audit/REPO_TREE.md) |

Run `pnpm install --frozen-lockfile`, then `pnpm backend:verify`, `pnpm backend:smoke`, `pnpm contracts:check`, `pnpm api:lint`, `pnpm audit:check` and `pnpm verify`. See local setup for mobile dependency restoration and build commands. Cloud deploy, signing and publishing require their own authorized task and credentials.
