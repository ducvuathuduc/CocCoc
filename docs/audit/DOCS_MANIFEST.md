# Actual changed files and content ownership

Final manifest generated from Git diff/untracked files on 2026-10-10. No generated cache/install/build directories are listed. Individual command results are in [validation](VALIDATION.md). A listed check method is not an assertion that cloud/device evidence exists.

## Required-content consolidation

The directive explicitly permits consolidation. These mappings preserve required content in one substantive canonical owner instead of creating empty duplicate documents. Phase-gated integrations are named honestly.

| Requested documents/content | Canonical owner | Content/implementation scope |
|---|---|---|
| START_HERE and prior READ_ME_FIRST | [docs/00_START_HERE.md](../../docs/00_START_HERE.md) | Current entry; historical reading order remains a redirecting map |
| INPUT_INVENTORY / LEGACY_DOC_AUDIT / UI_IMPLEMENTATION_GAP / RESEARCH_EVIDENCE / OPEN_DECISIONS | [docs/audit/INPUT_INVENTORY.md](../../docs/audit/INPUT_INVENTORY.md) | Separate audit files + machine inventory and source-control index |
| SRS / FEATURE_MATRIX / SCREEN_INVENTORY / SCREEN_BEHAVIOR_MAP / USER_FLOWS / STATE_MACHINES / EDGE_CASE_MATRIX / CONTENT_MODEL / MONETIZATION | [docs/product/SRS.md](../../docs/product/SRS.md) | Existing owners retained; missing behavior/state/content/billing contracts added |
| DESIGN / TOKENS / COMPONENT_STATES / MOTION_AUDIO / GUMMBLE_REFERENCE | [docs/design/DESIGN.md](../../docs/design/DESIGN.md) | Tokens/motion/audio in DESIGN; states and Gummble provenance in existing sibling files; no pixel rewrite |
| ARCHITECTURE / STACK / SERVICE_CATALOG / DATA_OWNERSHIP / NFR | [docs/architecture/ARCHITECTURE.md](../../docs/architecture/ARCHITECTURE.md) | Architecture/stack/catalog/NFR retained; table/index/PII/retention/permissions in docs/data owners |
| CONSISTENCY / EVENTS / OFFLINE_SYNC | [docs/architecture/CONSISTENCY.md](../../docs/architecture/CONSISTENCY.md) | Consistency added; event schema/retry in api/EVENTS_ERRORS; offline protocol in architecture/OFFLINE |
| COST_AND_CREDITS / BILLING_ARCHITECTURE | [docs/devops/COST_MODEL.md](../../docs/devops/COST_MODEL.md) | One cost owner; product/MONETIZATION owns later store verification/entitlements |
| Required ADR subjects 0001–0007 | [docs/architecture/adr/README.md](../../docs/architecture/adr/README.md) | Preserve existing 17 ADR IDs; subject equivalents: 0001 Flutter,0004 Appwrite,0005 services,0002 Riverpod,0016 outbox,0011 voice,0012 assessment |
| openapi / API_ENDPOINT_MATRIX / ERROR_CATALOG / WEBHOOKS_AND_EVENTS / examples | [docs/api/openapi.yaml](../../docs/api/openapi.yaml) | Wire unchanged; derived endpoint matrix + synthetic event example; errors/events/auth own detailed behavior; billing webhooks in monetization until API added |
| AI_ARCHITECTURE / PROVIDER_BENCHMARK / PRICING_AND_QUOTAS | [docs/ai/PROVIDER_BENCHMARK.md](../../docs/ai/PROVIDER_BENCHMARK.md) | Current candidate/price/transport/account table; operational lifecycle in AI_ARCHITECTURE |
| SPEAKING_SPEC / LISTENING_SPEC / PRONUNCIATION_SPEC / EVALUATIONS / PROMPT_REGISTRY | [docs/ai/AI_ARCHITECTURE.md](../../docs/ai/AI_ARCHITECTURE.md) | Lifecycle/listening/assessment consolidated here; AI_EVALS + actual prompt/harness fixtures own evaluation/registry |
| ENVIRONMENTS / LOCAL_SETUP_WINDOWS / APPWRITE_SETUP / CI_CD / SECRETS | [docs/devops/LOCAL_SETUP_WINDOWS.md](../../docs/devops/LOCAL_SETUP_WINDOWS.md) | Windows/Appwrite setup added; existing CI_CD owns environments/secrets/deploy/rollback; descriptors disabled |
| NOTIFICATIONS / OBSERVABILITY / LOAD_FAILURE_TESTING / RUNBOOK | [docs/devops/OPERATIONS.md](../../docs/devops/OPERATIONS.md) | One operations owner; permission/device/push behavior also references SRS/state machine; no imaginary cluster |
| ANDROID_RELEASE / IOS_CLOUD_BUILD | [docs/devops/CI_CD.md](../../docs/devops/CI_CD.md) | Existing pipeline/release procedure with explicit device/signing gates; local setup and release gate link it |
| TEST_STRATEGY / TEST_MATRIX / CONTRACT_TESTS / PERFORMANCE_BUDGET / RELEASE_GATE / DEMO_PLAYBOOK | [docs/quality/TEST_STRATEGY.md](../../docs/quality/TEST_STRATEGY.md) | Strategy + TRACEABILITY/NFR own detailed matrix/targets; real contract tooling and release/demo files added |
| IMPLEMENTATION_PLAN / TASK_BOARD / TASK_PROTOCOL / PARALLEL_WORK_MATRIX / DECISION_LOG / CHANGE_CONTROL / TRACEABILITY | [docs/agent/IMPLEMENTATION_PLAN.md](../../docs/agent/IMPLEMENTATION_PLAN.md) | Existing task-status.json, TASK_PROTOCOL, DEPENDENCY_DAG, ADR index and quality/TRACEABILITY remain owners; refresh plan/evidence added |
| Root/nested AGENTS / CLAUDE / useful skills/hooks / valid Codex config | [AGENTS.md](../../AGENTS.md) | Short root/nested guidance and existing four canonical skills/wrappers retained; config.example.toml only; no duplicated new prompt suite |
| Scaffold / schema / seed / tests / local smoke | [services/AGENTS.md](../../services/AGENTS.md) | Three separate artifacts plus four-table initial schema and unavailable typed catalog seed; full cloud schema/curriculum remains phase-gated |

## Created/updated files

| Actual path | Ownership | Validation method |
|---|---|---|
| [.editorconfig](../../.editorconfig) | Navigation, task state or enforced tool configuration | configuration/lock/diff inspection |
| [.env.example](../../.env.example) | Navigation, task state or enforced tool configuration | configuration/lock/diff inspection |
| [.github/workflows/backend.yml](../../.github/workflows/backend.yml) | Setup, recovery, cost or deterministic CI | YAML parse; CI not externally executed |
| [.gitignore](../../.gitignore) | Navigation, task state or enforced tool configuration | configuration/lock/diff inspection |
| [.prettierrc.json](../../.prettierrc.json) | Navigation, task state or enforced tool configuration | JSON parse + applicable schema/owner checks |
| [AGENTS.md](../../AGENTS.md) | Navigation, task state or enforced tool configuration | internal links + Mermaid when present; evidence distinguished |
| [README.md](../../README.md) | Navigation, task state or enforced tool configuration | internal links + Mermaid when present; evidence distinguished |
| [appwrite/schema/foundation.json](../../appwrite/schema/foundation.json) | Additive foundation schema/dry-run or typed seed | JSON parse + applicable schema/owner checks |
| [appwrite/scripts/schema.mjs](../../appwrite/scripts/schema.mjs) | Additive foundation schema/dry-run or typed seed | node syntax + applicable executed command |
| [appwrite/scripts/seed.mjs](../../appwrite/scripts/seed.mjs) | Additive foundation schema/dry-run or typed seed | node syntax + applicable executed command |
| [appwrite/seeds/catalog.json](../../appwrite/seeds/catalog.json) | Additive foundation schema/dry-run or typed seed | JSON parse + applicable schema/owner checks |
| [docs/00_READ_ME_FIRST.md](../../docs/00_READ_ME_FIRST.md) | Navigation, task state or enforced tool configuration | internal links + Mermaid when present; evidence distinguished |
| [docs/00_START_HERE.md](../../docs/00_START_HERE.md) | Navigation, task state or enforced tool configuration | internal links + Mermaid when present; evidence distinguished |
| [docs/ARCHITECTURE_BLUEPRINT_V1.md](../../docs/ARCHITECTURE_BLUEPRINT_V1.md) | Navigation, task state or enforced tool configuration | internal links + Mermaid when present; evidence distinguished |
| [docs/ARCHITECTURE_FREEZE_REPORT.md](../../docs/ARCHITECTURE_FREEZE_REPORT.md) | Navigation, task state or enforced tool configuration | internal links + Mermaid when present; evidence distinguished |
| [docs/ASSUMPTIONS.md](../../docs/ASSUMPTIONS.md) | Navigation, task state or enforced tool configuration | internal links + Mermaid when present; evidence distinguished |
| [docs/FREEZE_REVIEW.md](../../docs/FREEZE_REVIEW.md) | Navigation, task state or enforced tool configuration | internal links + Mermaid when present; evidence distinguished |
| [docs/agent/DEVELOPER_HANDOFF.md](../../docs/agent/DEVELOPER_HANDOFF.md) | Navigation, task state or enforced tool configuration | internal links + Mermaid when present; evidence distinguished |
| [docs/agent/IMPLEMENTATION_PLAN.md](../../docs/agent/IMPLEMENTATION_PLAN.md) | Navigation, task state or enforced tool configuration | internal links + Mermaid when present; evidence distinguished |
| [docs/agent/REPOSITORY_TREE.md](../../docs/agent/REPOSITORY_TREE.md) | Navigation, task state or enforced tool configuration | internal links + Mermaid when present; evidence distinguished |
| [docs/agent/RESEARCH_REFRESH_PLAN.md](../../docs/agent/RESEARCH_REFRESH_PLAN.md) | Navigation, task state or enforced tool configuration | internal links + Mermaid when present; evidence distinguished |
| [docs/agent/task-status.json](../../docs/agent/task-status.json) | Navigation, task state or enforced tool configuration | JSON parse + applicable schema/owner checks |
| [docs/ai/AI_ARCHITECTURE.md](../../docs/ai/AI_ARCHITECTURE.md) | Capability candidates, evals and honest scoring | internal links + Mermaid when present; evidence distinguished |
| [docs/ai/AI_EVALS.md](../../docs/ai/AI_EVALS.md) | Capability candidates, evals and honest scoring | internal links + Mermaid when present; evidence distinguished |
| [docs/ai/PROVIDER_BENCHMARK.md](../../docs/ai/PROVIDER_BENCHMARK.md) | Capability candidates, evals and honest scoring | internal links + Mermaid when present; evidence distinguished |
| [docs/api/API_ENDPOINT_MATRIX.md](../../docs/api/API_ENDPOINT_MATRIX.md) | Navigation, task state or enforced tool configuration | internal links + Mermaid when present; evidence distinguished |
| [docs/api/examples/lesson-completed.v1.json](../../docs/api/examples/lesson-completed.v1.json) | Navigation, task state or enforced tool configuration | JSON parse + applicable schema/owner checks |
| [docs/architecture/ARCHITECTURE.md](../../docs/architecture/ARCHITECTURE.md) | Boundaries, authority or decision rationale | internal links + Mermaid when present; evidence distinguished |
| [docs/architecture/CONSISTENCY.md](../../docs/architecture/CONSISTENCY.md) | Boundaries, authority or decision rationale | internal links + Mermaid when present; evidence distinguished |
| [docs/architecture/STACK.md](../../docs/architecture/STACK.md) | Boundaries, authority or decision rationale | internal links + Mermaid when present; evidence distinguished |
| [docs/architecture/adr/0010-provider-capability-adapters.md](../../docs/architecture/adr/0010-provider-capability-adapters.md) | Boundaries, authority or decision rationale | internal links + Mermaid when present; evidence distinguished |
| [docs/architecture/adr/0011-bounded-direct-native-voice.md](../../docs/architecture/adr/0011-bounded-direct-native-voice.md) | Boundaries, authority or decision rationale | internal links + Mermaid when present; evidence distinguished |
| [docs/audit/BUILD_ARTIFACTS.json](../../docs/audit/BUILD_ARTIFACTS.json) | Ground truth, evidence, disposition or verification | JSON parse + applicable schema/owner checks |
| [docs/audit/CHANGELOG.md](../../docs/audit/CHANGELOG.md) | Ground truth, evidence, disposition or verification | internal links + Mermaid when present; evidence distinguished |
| [docs/audit/DOCS_MANIFEST.md](../../docs/audit/DOCS_MANIFEST.md) | Ground truth, evidence, disposition or verification | internal links + Mermaid when present; evidence distinguished |
| [docs/audit/INPUT_INVENTORY.json](../../docs/audit/INPUT_INVENTORY.json) | Ground truth, evidence, disposition or verification | JSON parse + applicable schema/owner checks |
| [docs/audit/INPUT_INVENTORY.md](../../docs/audit/INPUT_INVENTORY.md) | Ground truth, evidence, disposition or verification | internal links + Mermaid when present; evidence distinguished |
| [docs/audit/LEGACY_DOC_AUDIT.md](../../docs/audit/LEGACY_DOC_AUDIT.md) | Ground truth, evidence, disposition or verification | internal links + Mermaid when present; evidence distinguished |
| [docs/audit/OPEN_DECISIONS.md](../../docs/audit/OPEN_DECISIONS.md) | Ground truth, evidence, disposition or verification | internal links + Mermaid when present; evidence distinguished |
| [docs/audit/REPO_TREE.md](../../docs/audit/REPO_TREE.md) | Ground truth, evidence, disposition or verification | internal links + Mermaid when present; evidence distinguished |
| [docs/audit/RESEARCH_EVIDENCE.md](../../docs/audit/RESEARCH_EVIDENCE.md) | Ground truth, evidence, disposition or verification | internal links + Mermaid when present; evidence distinguished |
| [docs/audit/SCREEN_CONTROLS.json](../../docs/audit/SCREEN_CONTROLS.json) | Ground truth, evidence, disposition or verification | JSON parse + applicable schema/owner checks |
| [docs/audit/UI_IMPLEMENTATION_GAP.md](../../docs/audit/UI_IMPLEMENTATION_GAP.md) | Ground truth, evidence, disposition or verification | internal links + Mermaid when present; evidence distinguished |
| [docs/audit/VALIDATION.md](../../docs/audit/VALIDATION.md) | Ground truth, evidence, disposition or verification | internal links + Mermaid when present; evidence distinguished |
| [docs/design/DESIGN.md](../../docs/design/DESIGN.md) | Navigation, task state or enforced tool configuration | internal links + Mermaid when present; evidence distinguished |
| [docs/design/GUMMBLE_RESEARCH.md](../../docs/design/GUMMBLE_RESEARCH.md) | Navigation, task state or enforced tool configuration | internal links + Mermaid when present; evidence distinguished |
| [docs/devops/APPWRITE_SETUP.md](../../docs/devops/APPWRITE_SETUP.md) | Setup, recovery, cost or deterministic CI | internal links + Mermaid when present; evidence distinguished |
| [docs/devops/CI_CD.md](../../docs/devops/CI_CD.md) | Setup, recovery, cost or deterministic CI | internal links + Mermaid when present; evidence distinguished |
| [docs/devops/COST_MODEL.md](../../docs/devops/COST_MODEL.md) | Setup, recovery, cost or deterministic CI | internal links + Mermaid when present; evidence distinguished |
| [docs/devops/LOCAL_SETUP_WINDOWS.md](../../docs/devops/LOCAL_SETUP_WINDOWS.md) | Setup, recovery, cost or deterministic CI | internal links + Mermaid when present; evidence distinguished |
| [docs/devops/OPERATIONS.md](../../docs/devops/OPERATIONS.md) | Setup, recovery, cost or deterministic CI | internal links + Mermaid when present; evidence distinguished |
| [docs/product/CONTENT_MODEL.md](../../docs/product/CONTENT_MODEL.md) | Requirements, behaviors, content or future billing | internal links + Mermaid when present; evidence distinguished |
| [docs/product/FEATURE_MATRIX.md](../../docs/product/FEATURE_MATRIX.md) | Requirements, behaviors, content or future billing | internal links + Mermaid when present; evidence distinguished |
| [docs/product/MONETIZATION.md](../../docs/product/MONETIZATION.md) | Requirements, behaviors, content or future billing | internal links + Mermaid when present; evidence distinguished |
| [docs/product/SCREEN_BEHAVIOR_MAP.md](../../docs/product/SCREEN_BEHAVIOR_MAP.md) | Requirements, behaviors, content or future billing | internal links + Mermaid when present; evidence distinguished |
| [docs/product/SCREEN_INVENTORY.md](../../docs/product/SCREEN_INVENTORY.md) | Requirements, behaviors, content or future billing | internal links + Mermaid when present; evidence distinguished |
| [docs/product/SRS.md](../../docs/product/SRS.md) | Requirements, behaviors, content or future billing | internal links + Mermaid when present; evidence distinguished |
| [docs/product/STATE_MACHINES.md](../../docs/product/STATE_MACHINES.md) | Requirements, behaviors, content or future billing | internal links + Mermaid when present; evidence distinguished |
| [docs/quality/DEMO_PLAYBOOK.md](../../docs/quality/DEMO_PLAYBOOK.md) | Readiness and professor demonstration | internal links + Mermaid when present; evidence distinguished |
| [docs/quality/RELEASE_GATE.md](../../docs/quality/RELEASE_GATE.md) | Readiness and professor demonstration | internal links + Mermaid when present; evidence distinguished |
| [docs/research/AI_EVIDENCE.md](../../docs/research/AI_EVIDENCE.md) | Navigation, task state or enforced tool configuration | internal links + Mermaid when present; evidence distinguished |
| [docs/research/RESEARCH_EVIDENCE.md](../../docs/research/RESEARCH_EVIDENCE.md) | Navigation, task state or enforced tool configuration | internal links + Mermaid when present; evidence distinguished |
| [eslint.config.mjs](../../eslint.config.mjs) | Navigation, task state or enforced tool configuration | node syntax + applicable executed command |
| [infrastructure/toolchain.json](../../infrastructure/toolchain.json) | Navigation, task state or enforced tool configuration | JSON parse + applicable schema/owner checks |
| [package.json](../../package.json) | Navigation, task state or enforced tool configuration | JSON parse + applicable schema/owner checks |
| [packages/api_contracts/generated.ts](../../packages/api_contracts/generated.ts) | OpenAPI-derived wire types only | strict TS/ESLint; generated wire schema for contracts |
| [packages/api_contracts/package.json](../../packages/api_contracts/package.json) | OpenAPI-derived wire types only | JSON parse + applicable schema/owner checks |
| [pnpm-lock.yaml](../../pnpm-lock.yaml) | Navigation, task state or enforced tool configuration | YAML parse; CI not externally executed |
| [services/AGENTS.md](../../services/AGENTS.md) | Independent owner scaffold, transport/auth or acceptance fixture | internal links + Mermaid when present; evidence distinguished |
| [services/ai/appwrite-function.json](../../services/ai/appwrite-function.json) | Independent owner scaffold, transport/auth or acceptance fixture | JSON parse + applicable schema/owner checks |
| [services/ai/package.json](../../services/ai/package.json) | Independent owner scaffold, transport/auth or acceptance fixture | JSON parse + applicable schema/owner checks |
| [services/ai/src/index.ts](../../services/ai/src/index.ts) | Independent owner scaffold, transport/auth or acceptance fixture | strict TS/ESLint; generated wire schema for contracts |
| [services/ai/test/disabled.test.mjs](../../services/ai/test/disabled.test.mjs) | Independent owner scaffold, transport/auth or acceptance fixture | node syntax + applicable executed command |
| [services/learning/appwrite-function.json](../../services/learning/appwrite-function.json) | Independent owner scaffold, transport/auth or acceptance fixture | JSON parse + applicable schema/owner checks |
| [services/learning/package.json](../../services/learning/package.json) | Independent owner scaffold, transport/auth or acceptance fixture | JSON parse + applicable schema/owner checks |
| [services/learning/src/index.ts](../../services/learning/src/index.ts) | Independent owner scaffold, transport/auth or acceptance fixture | strict TS/ESLint; generated wire schema for contracts |
| [services/learning/src/mock-completion.ts](../../services/learning/src/mock-completion.ts) | Independent owner scaffold, transport/auth or acceptance fixture | strict TS/ESLint; generated wire schema for contracts |
| [services/learning/test/completion.test.mjs](../../services/learning/test/completion.test.mjs) | Independent owner scaffold, transport/auth or acceptance fixture | node syntax + applicable executed command |
| [services/progress/appwrite-function.json](../../services/progress/appwrite-function.json) | Independent owner scaffold, transport/auth or acceptance fixture | JSON parse + applicable schema/owner checks |
| [services/progress/package.json](../../services/progress/package.json) | Independent owner scaffold, transport/auth or acceptance fixture | JSON parse + applicable schema/owner checks |
| [services/progress/src/index.ts](../../services/progress/src/index.ts) | Independent owner scaffold, transport/auth or acceptance fixture | strict TS/ESLint; generated wire schema for contracts |
| [services/progress/src/mock-rewards.ts](../../services/progress/src/mock-rewards.ts) | Independent owner scaffold, transport/auth or acceptance fixture | strict TS/ESLint; generated wire schema for contracts |
| [services/progress/test/events.test.mjs](../../services/progress/test/events.test.mjs) | Independent owner scaffold, transport/auth or acceptance fixture | node syntax + applicable executed command |
| [services/shared/src/transport.ts](../../services/shared/src/transport.ts) | Independent owner scaffold, transport/auth or acceptance fixture | strict TS/ESLint; generated wire schema for contracts |
| [services/shared/src/verify-jwt.ts](../../services/shared/src/verify-jwt.ts) | Independent owner scaffold, transport/auth or acceptance fixture | strict TS/ESLint; generated wire schema for contracts |
| [tools/audit/controls.mjs](../../tools/audit/controls.mjs) | Reproducible local build/check/audit command | node syntax + applicable executed command |
| [tools/audit/inventory.mjs](../../tools/audit/inventory.mjs) | Reproducible local build/check/audit command | node syntax + applicable executed command |
| [tools/audit/manifest.mjs](../../tools/audit/manifest.mjs) | Reproducible local build/check/audit command | node syntax + applicable executed command |
| [tools/audit/secret-check.mjs](../../tools/audit/secret-check.mjs) | Reproducible local build/check/audit command | node syntax + applicable executed command |
| [tools/audit/tree.mjs](../../tools/audit/tree.mjs) | Reproducible local build/check/audit command | node syntax + applicable executed command |
| [tools/audit/validate.mjs](../../tools/audit/validate.mjs) | Reproducible local build/check/audit command | node syntax + applicable executed command |
| [tools/blueprint/validate.mjs](../../tools/blueprint/validate.mjs) | Reproducible local build/check/audit command | node syntax + applicable executed command |
| [tools/evals/prompts.json](../../tools/evals/prompts.json) | Capability candidates, evals and honest scoring | JSON parse + applicable schema/owner checks |
| [tools/evals/voice-harness.mjs](../../tools/evals/voice-harness.mjs) | Capability candidates, evals and honest scoring | node syntax + applicable executed command |
| [tools/scripts/backend-check.mjs](../../tools/scripts/backend-check.mjs) | Reproducible local build/check/audit command | node syntax + applicable executed command |
| [tools/scripts/backend-smoke.mjs](../../tools/scripts/backend-smoke.mjs) | Reproducible local build/check/audit command | node syntax + applicable executed command |
| [tools/scripts/service-local.mjs](../../tools/scripts/service-local.mjs) | Reproducible local build/check/audit command | node syntax + applicable executed command |
| [tsconfig.backend.json](../../tsconfig.backend.json) | Navigation, task state or enforced tool configuration | JSON parse + applicable schema/owner checks |

## Preserved baseline

Mobile source/assets/pubspec lock and original 17 ADR identities are preserved. The 101 legacy documentation rows are in [legacy audit](LEGACY_DOC_AUDIT.md). OpenAPI remains the original 42-operation/94-schema contract; generated DTOs and examples derive from it. Production readiness remains conditional.
