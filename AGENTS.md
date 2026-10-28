# CocEnglish — agent instructions

Start at [docs/00_START_HERE.md](docs/00_START_HERE.md). Then read the assigned task in [docs/agent/IMPLEMENTATION_PLAN.md](docs/agent/IMPLEMENTATION_PLAN.md) and the nearest nested `AGENTS.md` before changing code.

## Layout (full map: [docs/agent/REPOSITORY_TREE.md](docs/agent/REPOSITORY_TREE.md))

| Path | Owns | Instructions |
|---|---|---|
| `apps/mobile/` | Flutter Android/iOS app (all product UI) | [apps/mobile/AGENTS.md](apps/mobile/AGENTS.md) |
| `services/{learning,progress,ai}/` | Three independently bundled Node 22 services; `services/shared/` holds transport/auth/HMAC only | [services/AGENTS.md](services/AGENTS.md) |
| `appwrite/` | Appwrite TablesDB schema declaration, apply/drift/probe scripts, seeds | [appwrite/AGENTS.md](appwrite/AGENTS.md) |
| `packages/api_contracts/` | TypeScript wire types generated from OpenAPI + shared schema fixtures | generated: `pnpm contracts:generate` |
| `docs/` | Specifications, decisions, evidence, task state | [docs/AGENTS.md](docs/AGENTS.md) |
| `tools/` | Every checked command: `blueprint/`, `audit/`, `scripts/`, `evals/`, `agent/` hooks, `palette_check.py`, `toolchain.json` pins | — |
| `.agents/skills/`, `.claude/` | Agent skills and reviewer definitions (`.claude/skills` points to `.agents/skills`) | [CLAUDE.md](CLAUDE.md) |

## Frozen architecture

The architecture is frozen as follows. Flutter Android/iOS uses feature-first manual Riverpod MVVM. The backend is TypeScript on Node 22 with three services: Learning, Progress and AI. Appwrite provides Auth, TablesDB and Storage. The API is REST described by OpenAPI, and each service owns its writes. The local journal is Drift. The human-approved [ADR-0018](docs/architecture/adr/0018-container-event-cache-runtime.md) permits Docker container API/worker entrypoints, RabbitMQ transport and Redis derived read cache, subject to its admission gates. Other architecture changes use [TASK_PROTOCOL](docs/agent/TASK_PROTOCOL.md); no unapproved cluster, gateway or Python service. The human chose to retain Appwrite Auth after the [closed Descope evaluation](docs/architecture/adr/draft-0019-descope-identity.md); do not introduce an auth-provider migration in this scope.

Canonical owners:

- Requirements: `docs/product/SRS.md`.
- Wire format: `docs/api/openapi.yaml`. The file is JSON, which is valid YAML 1.2; every tool reads it as JSON.
- Storage: `docs/data/DATA_MODEL.md`.
- Design: `docs/design/DESIGN.md`.
- Phases: `docs/agent/IMPLEMENTATION_PLAN.md`.

Link to these owners; never duplicate them.

## Rules

- Identity comes only from a verified Appwrite JWT. Never trust a client's XP, clock or pronunciation score. Keys stay server-side, logs are redacted, and no paid adapter auto-enables.
- Hosted entrypoints use disabled adapters and fail closed. In-memory stores exist only in `src/testing/`, `src/dev.ts` and tests.
- Exclusive change areas: OpenAPI, the root router, `pubspec.lock`/`pnpm-lock.yaml`, `appwrite/schema` and migrations, and the `services/shared` interfaces. One owner at a time.
- For a behavior change, write a meaningful failing test first. Then implement, run the area's targeted checks, then the gates. Report exact commands and evidence. Never claim a device or cloud result from a document check.
- No deploy, publish, `schema:apply`, merge to `main`, reset/delete, force-push or paid plan without an explicit request.

## Gates (run from root after `pnpm install --frozen-lockfile`)

```sh
pnpm backend:verify   # tsc + esbuild bundles + eslint + prettier + node tests
pnpm backend:smoke    # in-process outbox->inbox fixture
pnpm dev:smoke        # real HTTP: 3 dev services, /health, signed cross-service event
pnpm contracts:check  # schema fixtures + Dart DTOs in sync with OpenAPI
pnpm postman:check    # Postman collection covers every OpenAPI operation, secrets empty
pnpm api:lint         # redocly
pnpm schema:plan && pnpm schema:test && pnpm seed:check
pnpm blueprint:check && pnpm audit:check   # traceability, links, Mermaid, endpoint matrix
pnpm verify           # Flutter format/analyze/test + blueprint (see apps/mobile/AGENTS.md)
python3 tools/palette_check.py              # informational: known baseline of unmatched colors
```

Run locally: `pnpm dev:services`. Learning runs on :4101, Progress on :4102 and AI on :4103, all with in-memory dev adapters. See [services/AGENTS.md](services/AGENTS.md).
