# Teammate entry point — 2026-10-09

Read [project instructions](../../AGENTS.md) and
[canonical reading order](../00_READ_ME_FIRST.md) before editing.

## What exists

- Runnable Flutter frontend in `apps/mobile`: feature-first manual Riverpod
  MVVM, English lessons and local mock repositories. Latest recorded frontend
  checks: [English lesson report](../design/qa/ENGLISH_LESSON_REPORT.md).
- Backend design contracts exist. `services/learning`, `services/progress` and
  `services/ai` currently contain ownership instructions, not runnable handlers.
  There is no backend package lock, Appwrite schema migration or backend CI gate
  proving a production implementation. Frontend mock results are not server
  authority or production authentication.

## Backend documentation map

| Topic | Canonical owner |
| --- | --- |
| Product rules and edge cases | [SRS](../product/SRS.md), [edge cases](../product/EDGE_CASE_MATRIX.md) |
| Architecture and pinned target stack | [architecture](../architecture/ARCHITECTURE.md), [stack](../architecture/STACK.md), [toolchain](../../infrastructure/toolchain.json) |
| Three service responsibilities | [service catalog](../architecture/SERVICE_CATALOG.md), [Learning](../../services/learning/AGENTS.md), [Progress](../../services/progress/AGENTS.md), [AI](../../services/ai/AGENTS.md) |
| REST payloads and operations | [OpenAPI](../api/openapi.yaml) |
| JWT and route authorization | [authentication](../api/AUTH.md) |
| Errors, idempotency and internal events | [events/errors](../api/EVENTS_ERRORS.md) |
| Tables, indexes, transactions and storage | [data model](../data/DATA_MODEL.md), [permissions](../data/PERMISSIONS.md) |
| Migrations, seeds and rollback | [migration procedure](../data/MIGRATIONS.md) |
| Offline replay and journal | [offline protocol](../architecture/OFFLINE.md) |
| Speech/AI providers and capability limits | [AI architecture](../ai/AI_ARCHITECTURE.md), [evaluations](../ai/AI_EVALS.md) |
| Tests and contract verification | [test strategy](../quality/TEST_STRATEGY.md) |
| CI, environments, recovery and costs | [CI/CD](../devops/CI_CD.md), [operations](../devops/OPERATIONS.md), [cost model](../devops/COST_MODEL.md) |
| Implementation sequence and task ownership | [implementation plan](IMPLEMENTATION_PLAN.md), [task protocol](TASK_PROTOCOL.md) |

The design is detailed enough to start implementation. The production runtime,
Cloud permissions, transactions, schema/seed scripts, restore drills and backend
CI still need implementation and measured acceptance evidence.

Begin by checking the remaining `P1-FOUND-001` gate; do not recreate completed
Flutter screens. Then implement `P1-FOUND-002` (three handlers and shared backend
adapters), `P1-CONTRACT-001` (wire types/DTO fixtures) and `P1-OPS-001` (schema,
migrations, configuration probes and CI) in the canonical dependency order.

Two contract details need explicit treatment in that foundation:
`/health` and `/ready` are modeled once with Learning ownership, although the
service catalog requires them on every service; document/test the per-service
mapping before handlers are added. `/internal/events` has Progress as primary
owner and additional Learning/AI receivers; implement receiver-specific event
allowlists and ownership tests. Do not infer cross-service write permission.

## Run the frontend after a clean clone

Use the pinned Flutter/Dart baseline and pnpm from the toolchain manifest.
Node 22 is the frozen CI/backend target; the recorded local frontend toolchain
used Node 24.16.0. Service package versions and backend locks remain a P1 task.

From the repository root:

```sh
cd apps/mobile
flutter pub get
cd ../..
pnpm verify
pnpm build:web
pnpm preview:web
```

Open `http://127.0.0.1:4173/preview.html`. To use a connected Android emulator or
device, run `flutter run` from `apps/mobile`. Set `FLUTTER_ROOT` if Flutter is not
on PATH. iOS requires macOS/Xcode. Mock settings and credentials are documented
in the [mobile README](../../apps/mobile/README.md).

`node tools/blueprint/validate.mjs` checks document links/ownership and structure.
`node tools/scripts/reference-asset-audit.mjs` verifies original bundled assets.
`node tools/scripts/flow-coverage.mjs` validates completion evidence. These checks
do not prove a runnable backend. Schema fixtures use the isolated verifier
procedure in the test strategy until P1 pins its dependencies.

## Repository hygiene and collaboration

Build output, Dart/Gradle state, temporary scripts and captures in `.cache` are
regenerable and ignored. Source, lockfiles, platform build scripts, original
reference PNG/Rive/fonts and linked QA receipts belong to this project.
`docs/design/references` is the source archive; `docs/design/qa` preserves verified
states. They are not temporary files and should not be reinterpreted as new
product-flow counts or deleted to make the checkout smaller.

The cleanup [plan](REPOSITORY_HANDOFF_PLAN.md) and
[receipt](REPOSITORY_CLEANUP.json) record what was removed. Before sharing a zip,
include tracked project files; exclude `.git`, cache/build output and private
local configuration. A fresh Git clone already excludes ignored files.

Use small feature branches and the [PR template](../../.github/pull_request_template.md).
Keep contracts, routing, dependency locks and migrations under one owner at a
time. Follow the [service-change skill](../../.agents/skills/coc-service-change/SKILL.md)
for backend work. Never put provider/admin keys into Flutter or committed files.
