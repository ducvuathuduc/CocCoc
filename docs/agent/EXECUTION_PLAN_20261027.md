# Execution plan — language-learning product

This execution checklist supplements [IMPLEMENTATION_PLAN](IMPLEMENTATION_PLAN.md)
and [PHASE_BREAKDOWN_2_8](PHASE_BREAKDOWN_2_8.md). Those documents and the linked
SRS, OpenAPI, data model and ADRs remain the owners of requirements and contracts.
Status means evidence in this checkout, not a production or live-provider claim.

## Constraints

- Preserve the approved UI, routes, layout, assets, motion and golden baselines.
- Keep Learning, Progress and AI as the owners of their own data and writes.
- Implement provider-independent behavior and test it with deterministic local
  adapters. Never report simulated data as a successful real operation.
- Use Flutter Web for interactive work on this machine; do not install Android
  Studio, the Android SDK or an emulator. Reuse the pinned SDK and dependencies.
- Do not deploy, apply a schema, publish, push or enable paid resources as a
  side effect of local implementation. Live acceptance requires an admitted
  environment, credentials and explicit authorization for those operations.

## Work order and completion criteria

1. **Baseline and CI:** diagnose the current failing job; preserve visual
   snapshots; run format, analyzer and targeted tests; record actual GitHub run
   status separately. Analyzer lint fixed locally; GitHub rerun remains pending.
2. **Learning loop:** complete enrollment, course switching, session start,
   answer, pause, abandon, completion, retry and offline recovery. Maintain
   session revisions, account isolation, durable command identities and exactly
   one receipt/effect. The report menu is wired locally to Learning; live and
   restart-retry acceptance remain open.
3. **Practice and content:** connect existing story, listening, review, mistakes,
   vocabulary and other language-learning activities to real progress and
   authored content. Add contract and schema changes before new session modes;
   verify resume, duplicate completion and monotonic progress.
4. **Progress and economy:** connect server-owned XP, streak, inventory, quests,
   badges and course progress. Verify time-zone boundaries, retries, settlement,
   caps and no client-authoritative awards. Preserve the existing restriction on
   real-money billing and paid ad integrations.
5. **Profile and social:** connect existing profile, friends, feed, leagues and
   learning-related collaboration through Progress. Test authorization, privacy,
   pagination, blocks, account switching and duplicate operations.
6. **API and resilience:** validate inputs and ownership at service boundaries;
   bound request bodies, queues, timeouts and retries; verify event outbox/inbox,
   application receipts, AMQP failure paths, Redis isolation and primary-store
   fallback against [ADR-0018](../architecture/adr/0018-container-event-cache-runtime.md).
   Admit caching and event transport only after their correctness gates pass.
7. **Performance and operations:** add reproducible bounded local load tests for
   read pagination, common learning requests and duplicate/retry behavior; report
   measured throughput, latency, errors and resource use with test conditions.
   Evaluate load balancing and lazy loading against actual bottlenecks and
   statelessness; do not invent capacity or deploy a new platform without evidence.
   A first loopback-only in-memory Learning catalog smoke is available via
   `node tools/scripts/local-load.mjs`; 200 requests at concurrency 10 yielded
   200 successes and p95 10.0 ms on Node 24.22.1 in this checkout. This single
   local run excludes Appwrite, network, persistence and production behavior.
   A second short run with `--requests=1000 --concurrency=50` had 1,000
   successes and p95 36.7 ms. These are smoke measurements, not capacity claims.
8. **Security and CI/CD:** retain pinned dependencies/actions and least privilege;
   verify authentication, cross-account denial, secret handling, dependency and
   source scanning. Run backend, contract, schema and mobile gates; retain test
   artifacts and do not disable failures or rewrite golden baselines to go green.
9. **Provider-dependent and release acceptance:** prepare safe disabled adapters
   and documented configuration for email/OAuth, AI and speech; verify real
   services and physical-device behavior only when the owner supplies access and
   explicitly authorizes the relevant environment operations.

## Evidence per slice

Each change includes a behavior-focused test, targeted checks and an explicit
statement of what is local versus live. Contract, schema, shared ports, router
and lockfiles each have one owner at a time. Acceptance includes negative paths,
retry/duplicate behavior and account boundaries where applicable. A passing local
test does not prove production readiness or a particular concurrent-user capacity.

## Local implementation receipts — 2026-10-27

| Slice | Evidence | Remaining gate |
|---|---|---|
| HTTP backpressure | `services/shared/test/runtime.test.mjs` verifies a timed-out handler keeps its slot, overload returns retryable 429 and capacity recovers when it finishes. | No production load, proxy, health-check or multi-instance acceptance. |
| Cache robustness | `services/shared/test/redis-cache.test.mjs` and `event-cache-ports.test.mjs` cover oversized SCAN pages, bounded invalidation and malformed/unavailable cache fallback. | Redis is not admitted or wired into production traffic; TTL remains the fallback if invalidation reaches its limit. |
| AMQP fault handling | `services/shared/test/amqp-transport.test.mjs` covers independent fan-out returns, server-side consumer cancellation, close during connect and reconnection after blocked state. | Fake broker only; real RabbitMQ fault matrix, application receipts and cutover remain gated. |
| Contract reproducibility | `tools/tests/dart-contract-line-endings.test.mjs` checks CRLF equivalence and detects real generated-code changes; `.gitattributes` pins LF in fresh checkouts. | Existing checkout files retain their current line endings until refreshed; CI result for this candidate is pending. |
| Local load smoke | `tools/tests/local-load.test.mjs` verifies safety limits and failure accounting; `node tools/scripts/local-load.mjs` runs only an in-memory Learning service on loopback. | Not a durable-storage, cloud, provider, long-duration or production-capacity test. |
| Learning session integrity | `services/learning/test/sessions.test.mjs` covers reset/removal races, slot ownership and chronological answer replay; `offline.test.mjs` covers concurrent duplicate completion and changed payload rejection. | Memory persistence tests do not prove Appwrite transaction isolation or device recovery. |
| Learning vocabulary | `services/learning/test/practice.test.mjs` verifies failed content reads are retried, concurrent requests share one build, and bundle reads use batches of at most eight. | First build still reads the complete manifest; no cloud latency or quota claim. |
| Progress league ordering | `services/progress/test/league.test.mjs` covers late XP events and equal instants with different timezone offsets; reward/delivery tests pass locally. | Durable multi-worker and real settlement acceptance remain open. |
| Backend CI coverage | `tools/tests/backend-workflow-paths.test.mjs` checks triggers for content, contracts and workspace inputs; the workflow includes the bounded local load smoke. | The changed workflow has not run on GitHub. |
