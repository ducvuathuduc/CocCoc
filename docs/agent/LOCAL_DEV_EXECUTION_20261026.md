# Stable local development implementation plan — 2026-10-26

**Goal:** run the approved Android application against local durable Auth/data, three owner services and workers; verify login, lessons, progress/reward idempotency and offline recovery before any hosting deployment.

**Checkpoint:** paused at the user's request on 2026-10-26 for commit/push to `main`. See the exact [local evidence and remaining acceptance](../devops/LOCAL_DURABLE_RUNTIME.md#pause-checkpoint). APK build and native offline acceptance remain unfinished.

**Architecture:** retain Flutter/Riverpod, Learning/Progress/AI on Node 22, Appwrite Auth/TablesDB/Storage, Drift and the approved RabbitMQ/Redis boundaries. Isolate this development environment and its generated credentials from existing cloud projects. Preserve the accepted UI.

**Spec:** [approved feature plan](REAL_FEATURES_SETUP_PLAN_20261025.md), [phase tasks](PHASE_BREAKDOWN_2_8.md), [runtime ADR](../architecture/adr/0018-container-event-cache-runtime.md), [SRS](../product/SRS.md).

## Execution constraints

- No hosting deployment, paid provider activation, cloud schema mutation or real-money billing.
- Keep keys and generated local account credentials outside Git and redact diagnostic output.
- Do not disguise in-memory/dev fixtures as durable authenticated acceptance.
- Preserve owner writes, verified JWT identity, transactional receipts/outbox and duplicate protection.
- Make missing runtime/provider/device prerequisites explicit; keep making independent implementation progress.
- The pasted old CI figures are historical: `bb36760` passed all five workflows, 1,525 Flutter tests and seven native Android tests. Recheck changed areas; retain those tests.

## Work packages

### 1. Reproducible local runtime

Files: `tools/scripts/local-*.mjs`, `tools/tests/local-*.test.mjs`, `infra/docker/`, root command aliases and local setup documentation.

- [x] Verify Windows/WSL, Docker Engine, ports, disk and pinned toolchains without printing secrets.
- [x] Install/reuse an isolated Linux container runtime; preserve existing distributions/data and never trigger a reboot automatically.
- [x] Add tested prerequisite/config validation and bounded start/health/stop commands; restarts preserve volumes.
- [x] Bootstrap an isolated local Appwrite project/schema/seed and SMTP capture using official documented APIs; never target existing cloud endpoints automatically.
- [x] Start the three real API entrypoints and their workers with local credentials and prove readiness plus restart recovery.

Review: absent Docker, service port conflicts, unsafe non-local endpoints, partial bootstrap/retry, environment or secret leakage.

### 2. Authenticated learning and offline acceptance

Files: existing Appwrite schema/seed/probe tools, owner runtime adapters, `apps/mobile/integration_test/` and existing real repositories.

- [x] Register two isolated local accounts, authenticate real JWTs and reject cross-account private access.
- [x] Publish/verify the existing authored curriculum and media; complete typed lessons through the real API and receive the same reward receipt across duplicate retries.
- [ ] Build the existing Android API flavor against the local endpoints and exercise account/session recovery.
- [ ] Persist journal state across offline/process kill/restart; reconnect and settle exactly once with the durable backend.

Review: uncertain commits, stale auth/session, account switches, outbox lag, unavailable media and retained rejected answers.

### 3. Event/cache and remaining feature closure

Files: approved Phase 2–8 task owners; OpenAPI/schema/shared interfaces have one owner at a time.

- [ ] Complete RabbitMQ application receipts/retry/dead-letter and Redis cache/invalidation with fault tests before cutover.
- [ ] Close remaining profile/economy/social/practice callers in verified thin slices, without replacing approved screens.
- [ ] Configure AI/speech adapters and provider-disabled states; real quality/quota/microphone acceptance requires actual provider/device evidence.
- [ ] Re-run changed-area tests and root gates, produce an API Android APK, and record the exact working local commands and remaining external requirements.

Physical Android/iOS signing and genuine external email/OAuth/paid AI acceptance remain separate from local SMTP capture or emulator tests.

## Initial machine evidence

On 2026-10-26 the checkout was clean at `bb36760`; Windows reports 16 GB RAM, approximately 40 GB free on C:, WSL 2.3.24 with no installed distribution, and no Docker Engine/Desktop. The current shell is not elevated. Existing `pnpm dev:services` explicitly uses ephemeral stores and rejects user business routes, so it cannot satisfy the requested real login/lesson workflow.
