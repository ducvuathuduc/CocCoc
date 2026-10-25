# ADR-0018: Container runtime, RabbitMQ event transport and Redis read cache

## Status and authorization

**Status: ACCEPTED FOR IMPLEMENTATION. approvalStatus: APPROVED_BY_HUMAN. Date: 2026-10-25.**

The human explicitly approved the preceding real-feature setup plan on 2026-10-25. This accepts the container/event/cache design for implementation while preserving approved UI and the three business owners. It supersedes only the no-broker/no-cache runtime restrictions in [ADR-0005](0005-three-domain-services.md) and [ADR-0016](0016-transactional-outbox-and-inbox.md), under [TASK_PROTOCOL](../../agent/TASK_PROTOCOL.md). Runtime admission, successful installation, deployment, paid infrastructure and schema apply are separate gates; none is inferred from approval. The subsequent [Descope evaluation](draft-0019-descope-identity.md) was closed without adoption: the human chose to retain Appwrite Auth and its existing OTP/recovery integration.

## Context

The three existing services have durable Appwrite adapters and signed direct HTTP outbox/inbox delivery. Most UI is already approved; runtime integration remains uneven. The requested broker requires a long-lived worker host, explicit operational ownership and preserved consumer-effect acknowledgement. Redis can reduce repeated safe reads, but no measured bottleneck or capacity claim is established. Docker/Compose definitions are absent in the inspected checkout; Docker CLI is not found in PATH.

## Alternatives

| Alternative | Benefit | Cost / limitation |
|---|---|---|
| Existing Appwrite Functions plus signed direct relay and bounded local caches | Fewest runtime changes; existing implementation and rollback path | Does not deliver the requested RabbitMQ/distributed-cache setup; scheduling/account gates remain |
| **Selected:** three service container images, owner workers, RabbitMQ, Redis; managed Appwrite retained | Long-lived consumers, explicit independent API/worker lifecycle, requested event/cache infrastructure | Additional host, secrets, monitoring, storage, patching and restore work; not automatically free or highly available |
| New broker/cache/gateway business services or Kubernetes/Kafka platform | More infrastructure options | No verified need; increases operational scope without solving current feature wiring |

## Decision

1. Retain Flutter manual Riverpod MVVM, REST/OpenAPI and the Learning/Progress/AI business boundaries and table owners. Each service image can run `api` or `worker`; a worker is part of its owner service, not a fourth business service. Share only transport/auth/ports, never domain rules.
2. Add real Node HTTP/worker composition roots that reuse owner handlers and admitted Appwrite adapters. Do not package `src/dev.ts`, test fixtures or in-memory persistence into the real runtime. Do not pretend Appwrite Function schedule/context headers authenticate a container scheduler.
3. Appwrite Auth/TablesDB/Storage stay authoritative. Container server credentials are environment-injected and allowlisted; Appwrite Function dynamic keys must not be assumed to exist outside Functions. Current one-project credentials provide logical, not hard per-table security isolation.
4. RabbitMQ is the asynchronous transport over the existing transactional owner outbox/inbox. Redis is a disposable derived read cache. Neither replaces durable owner transactions, idempotency, ledger rows, deletion acknowledgements or quota reservations.
5. Compose is a local/disposable integration topology. A production host and broker/cache failure domains require their own admitted runbook and budget. One local broker node, even with a quorum queue, provides no multi-host availability proof.

## Rationale

Separate runtime transport from business ownership so feature integration can reuse the approved UI and existing domain handlers. Implement durable container composition first with direct signed delivery; admit AMQP/cache only after their correctness and operational gates pass. Human acceptance advances the explicit architecture validation baseline from 17 to 18 accepted records. The gate remains exact; further unaccepted proposals retain draft filenames.

## Event bus protocol requirements

The existing [event owner](../../api/EVENTS_ERRORS.md) remains canonical. Its direct signed HTTP transport stays operational during the compatible migration. Before AMQP adoption, update that owner, OpenAPI where needed, storage declarations and tests in one exclusively owned contract slice.

- Publish the unchanged versioned `BusinessEvent` only after its owner's state/outbox transaction commits. Use durable queues, persistent messages, publisher confirms and explicit handling of unroutable/returned messages. An ambiguous publish retries the **same** event ID and payload hash.
- Separate **published** from **applied by every required consumer**. A broker confirm must never advance the learning settlement watermark as though Progress credited a reward. Queue depth zero is not a consumer-effect watermark.
- Proposed application receipt path: the target consumer validates producer/version/allowlist and commits inbox plus domain effects atomically; then sends a freshly authenticated, idempotent receipt to the producing owner; only after that source records the target acknowledgement does the consumer acknowledge the AMQP delivery. Crash/retry at any boundary repeats the same identity. A receipt endpoint/schema and per-target durable acknowledgement representation are contract-first deliverables, not existing APIs.
- The receipt contains source event ID/hash, producer, consumer and applied/replayed outcome. A consumer cannot acknowledge another target. Progress fan-out to Learning and AI requires both durable target acknowledgements. Receipt loss/source outage must cause retry, not fake success; already committed effects remain idempotent.
- Preserve current conflict handling: same event ID with a different payload is a security failure. Consumers reject unrecognized producers/types/versions and out-of-range data before mutation. Do not trust AMQP headers alone as producer identity.
- AMQP producer authentication/signatures require a reviewed envelope and key-rotation policy. Do not reuse the direct HTTP 300-second freshness rule against the original creation time of a queued event: valid delivery can be delayed much longer. Fresh HTTP receipt requests retain HTTP freshness checks; event replay protection remains the durable inbox/hash. No mobile client can publish or consume broker messages.
- Use bounded prefetch, owner leases, retry backoff/jitter, maximum attempts and a retained dead-letter path. Pin an explicit version-tested broker delivery limit as well as the application retry limit, and verify their interaction; never rely on a default that can discard a message. Do not create a tight `nack(requeue=true)` loop. Existing domain order/revision guards still apply; queue ordering is not a global ordering guarantee.
- Proposed quorum dead-letter policy must explicitly select at-least-once transfer and `overflow=reject-publish`, configure its dead-letter exchange and verify a routable durable target. Check the selected version's required feature flags, including `stream_queue` when applicable. Do not rely on default at-most-once dead-letter transfer. If the selected RabbitMQ version cannot satisfy the tested policy, keep the event in the owner's durable retry/dead-letter store.
- Retain producer audit/replay data for at least the admitted recovery window. Unknown publish/ack outcomes and dead letters remain visible to settlement; a retention expiry cannot silently discard committed pending work. Deletion tombstones and entitlement revisions must defeat stale delayed events.

Acceptance: crash before/after each database commit, publish confirm, application receipt and AMQP ack; unroutable message, lost connection, duplicate with equal/different hash, reordered revisions, producer/consumer outage, broker disk pressure, unavailable DLX target, delayed delivery beyond 300 seconds and two-target fan-out. Run the NFR's 100 duplicate/reorder trials. Assert no lost committed outbox, ledger equality, one reward effect, and no league settlement while a required application receipt is missing.

Publisher confirms and consumer acknowledgements cover different boundaries; duplicate delivery is expected. This is an application design preserving idempotent effects, not a claim of exactly-once broker delivery. [RabbitMQ confirms](https://www.rabbitmq.com/docs/confirms), [reliability](https://www.rabbitmq.com/docs/reliability), [quorum/DLX configuration](https://www.rabbitmq.com/docs/quorum-queues).

## Cache policy

| Data | Proposed policy | Safety boundary |
|---|---|---|
| Immutable public bundle/manifest by content version and hash | Bounded content/media cache; Redis only for demonstrated repeated metadata reads | Integrity checked; publish pointer refetched under its defined policy; no cache key based only on lesson ID |
| Catalog and owner-safe public projections | Cache-aside, owner/version namespace; initial TTL cap 60 seconds, then measured tuning | Invalidate after owner commit; stale presentation cannot authorize a write |
| Private profile/projection snapshots | Default bypass distributed cache until privacy/invalidation tests; if admitted, namespace by environment, user, schema and revision, TTL cap 15 seconds | No cross-account/cohort leakage; block/privacy/deletion revoke eligibility and purge; authorization before cache lookup |
| Gems/XP ledger, receipt, entitlement, inventory debit, quota reservation, course frontier, inbox/outbox | Primary owner transaction for every decision/mutation | A display snapshot never grants rights, spends funds, grades answers or settles a league |

Use a short bounded cache timeout, explicit memory/eviction limits, request coalescing and a breaker. Redis failure falls back to authorized primary reads within their rate limits; overload returns a typed retryable error, never fixture success or an unbounded database stampede. Do not store JWTs/provider secrets/audio in Redis. Local caches/journals remain user-scoped. TTLs above are proposed application bounds, not measured optimizations or vendor consistency guarantees.

Cache-aside requires an invalidation/staleness policy; it does not make Redis the source of truth. [Redis cache-aside](https://redis.io/docs/latest/develop/use-cases/cache-aside/).

## Docker and CI/CD requirements

Pin supported Node 22/service dependencies and image digests; non-root runtime, minimal build context, no baked secrets, bounded resource use, graceful SIGTERM and bounded connection pools. API liveness and readiness are distinct. Broker/cache loss must not make a healthy Learning API discard a committed lesson: a durable outbox permits pending rewards. Report worker/broker health separately; Appwrite/auth loss fails closed for operations requiring them.

Compose `depends_on: condition: service_healthy` can gate local startup; applications still reconnect/back off at runtime. It is not ongoing failover or production readiness proof. [Docker startup order](https://docs.docker.com/compose/how-tos/startup-order/).

Extend existing CI. Pin third-party actions by verified full SHA, use least privilege, avoid untrusted-code secret exposure, and protect deployment environments. OIDC is conditional on actual host federation support and a constrained trust policy; it is not assumed for Appwrite. Promote the reviewed immutable artifact, migration plan and contract identity. [GitHub secure use](https://docs.github.com/en/actions/reference/security/secure-use), [OIDC](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-cloud-providers), [environments](https://docs.github.com/en/actions/concepts/workflows-and-actions/deployment-environments).

## Migration and rollback

1. Capture existing visual/runtime candidate and direct-relay acceptance. Record active deployments/config/schema; do not infer cloud state from local code.
2. Admit the container composition roots against a disposable durable environment, without changing domain behavior or mobile routes. Keep hosted Function entrypoints buildable.
3. Land compatible event-receipt contracts/storage, transport authentication and tests. Prove old clients/direct relay still work. Pin/test broker/cache versions before image adoption.
4. Run shadow validation in an isolated environment. No second business mutation sink on the same live traffic. Verify producer and all required consumer ownership paths.
5. Cut over one producer/consumer route at a time through environment configuration; direct relay is primary until the matching AMQP acceptance passes. Preserve event IDs, hashes and target acknowledgements. Leased/in-flight direct deliveries may duplicate safely; do not generate a new event to migrate transport.
6. Roll back by stopping new AMQP publishing/consumption in a controlled drain, inspecting in-flight work and restoring direct dispatch of unacknowledged owner records. Consumer inboxes make duplicate reconciliation safe. Do not delete queue volumes, reset the database or drop additive schema to roll back.
7. Redis can be bypassed/flushed within its own namespace after owner privacy checks; no durable learner progress depends on it. Record restore/replay and observed recovery timings.

## Consequences, open gates and affected owners

Additional patching, broker credentials/vhosts/permissions, Redis ACL/network isolation, storage/backup, dead-letter operations and monitoring are required. No automatic free hosting or scale claim. The producer application-receipt path adds an explicit interface and must be tested for source outages and fan-out.

Before runtime admission, record: concrete host/network and TLS; supported pinned versions; local vs multi-host durability; broker retention/storage and restore; Appwrite transaction/permissions/drift proof; account/provider budget and acceptance receipts. Design approval is already recorded above and must not be requested again.

Affected canonical owners on adoption: ARCHITECTURE, STACK, SERVICE_CATALOG, CONSISTENCY, OFFLINE, EVENTS_ERRORS, OpenAPI/generated contracts if receipts are added, DATA_MODEL/migrations, CI_CD, OPERATIONS, COST_MODEL, root/nearest runtime guidance and IMPLEMENTATION_PLAN/task records. Keep historical ADRs as history and mark precise superseded portions; do not silently edit accepted decisions into a different architecture.

## Revisit triggers

Revisit the concrete topology when measured outbox lag, admitted traffic, unavailable worker hosting, broker/cache operating cost or a privacy/restore failure invalidates its acceptance assumptions. Retain direct delivery/cache bypass until the replacement demonstrates equivalent owner effects, settlement and recovery. A higher user-count target alone is not proof the proposed topology meets that capacity.

Execution map: [real feature setup plan](../../agent/REAL_FEATURES_SETUP_PLAN_20261025.md).
