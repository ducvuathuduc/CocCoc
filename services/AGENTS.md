# Backend services

There are three independently bundled Appwrite Functions (Node 22, strict TypeScript). Each owns its tables. Read [SERVICE_CATALOG](../docs/architecture/SERVICE_CATALOG.md), [OpenAPI](../docs/api/openapi.yaml), [EVENTS_ERRORS](../docs/api/EVENTS_ERRORS.md), [DATA_MODEL](../docs/data/DATA_MODEL.md) and the service's own `AGENTS.md` before changing a handler.

| Service | Tables | Dev port | Notes |
|---|---|---|---|
| `learning/` | `l_*` | 4101 | course, sessions, grading, review, outbox. [AGENTS](learning/AGENTS.md) |
| `progress/` | `p_*` | 4102 | profile, XP ledger, streak, quests, leagues, social, inbox. [AGENTS](progress/AGENTS.md) |
| `ai/` | `a_*` | 4103 | voice sessions, provider adapters, assessment. [AGENTS](ai/AGENTS.md) |
| `shared/` | none | — | transport/router, error envelope, JWT auth port, service HMAC, internal client, owner-store ports. No business rules. |

## Layout of one service

```text
services/<svc>/
  package.json              build / test / dev scripts (delegate to tools/scripts)
  appwrite-function.json    disabled deploy descriptor (enabled:false, no scopes)
  src/index.ts              HOSTED entry -> dist/function.mjs; disabled adapter; no mock/memory imports
  src/dev.ts                LOCAL DEV entry; same wiring, in-memory adapter, mode 'local-dev'
  src/http/wiring.ts        routes + event consumer, shared by index.ts and dev.ts
  src/domain/               pure rules, no I/O              (progress: lesson-xp.ts)
  src/application/          use cases over persistence ports (progress: consume-events.ts)
  src/persistence/          port.ts (owned tables), disabled.ts (hosted), memory.ts (tests/dev only)
  src/testing/              fixtures for tests/backend:smoke only (never bundled into dist/)
  test/*.test.mjs           node:test; imports bundles from .cache/backend-fixtures
```

Domain and application modules implement each service's rules and use cases. Add a business route only for an operation that exists in OpenAPI, and register it in `src/http/wiring.ts`. Native `src/runtime/{http,worker}.ts` entrypoints reuse the hosted composition; they never select the dev stores.

## Run locally

```sh
pnpm install --frozen-lockfile
pnpm dev:services                 # all three; or: pnpm dev:services progress
curl http://127.0.0.1:4102/health # {"service":"progress","buildId":"local-dev","status":"degraded"}
pnpm dev:smoke                    # starts them, checks /health, /ready (503), signed Learning->Progress event
```

Dev mode is explicit. Stores are in memory and lost on exit, and `/ready` always returns 503 `SERVICE_NOT_CONFIGURED` because memory is never admitted. User routes fail closed unless `COC_DEV_AUTH=1`, which accepts only `Authorization: Bearer dev-<userId>` on the loopback dev servers; hosted bundles never include this adapter. Internal calls must carry `X-Service-*` HMAC headers. The dev keys come from `shared/src/testing/dev-keyring.ts` unless `COC_SERVICE_KEYS` is set. `COC_DEV_PORT_BASE` moves the ports, and the servers bind to 127.0.0.1 only. A `NODE_ENV=production` process refuses to start.

## Gates

`pnpm backend:verify` runs tsc, esbuild, ESLint, Prettier and every `services/*/test`. Also run `pnpm backend:smoke`, `pnpm dev:smoke`, `pnpm contracts:check` and `pnpm api:lint`. `shared/test/persistence.test.mjs` asserts that the hosted bundles contain no mock or memory code, so keep it passing. The live Appwrite probe test is skipped unless `COC_LIVE_APPWRITE_PROBE=1`.

## Rules

Verify the Appwrite JWT through `Account.get`. Never accept a caller-supplied user ID or a client's XP. Hosted entrypoints keep their disabled adapters until a durable Appwrite adapter passes the admitted cloud gate: transactions, conflict, permissions, migrations and outbox recovery. No live AI in CI. Cross-service effects travel only as signed events into the receiver's inbox. Never write another service's tables.
