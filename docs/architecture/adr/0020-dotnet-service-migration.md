# ADR-0020 — ASP.NET Core service migration

Date: 2026-11-03. approvalStatus: ACCEPTED by the human's migration-plan choices and explicit implementation request.

## Context

The human requested a complete backend runtime migration. The current Node implementation has three service owners, 91 declared operations and additional internal/background handlers. Flutter, Appwrite identity/data/storage and existing learner data must remain compatible throughout the migration.

## Decision

Introduce .NET 10 ASP.NET Core implementations of all three owner services under `backend-dotnet/`. Keep Appwrite Auth/TablesDB/Storage, Flutter, the canonical OpenAPI and all owner boundaries. The migration is complete only after all 91 declared operations, service-specific internal handlers and background jobs have parity and local durable/native acceptance.

Use controllers and the existing error envelope/status codes, not framework-default ProblemDetails. Use typed REST clients for Appwrite, verified Account.get identity, original HMAC canonicalization and atomic receipt/inbox/outbox persistence. Native lesson journals remain unchanged. No new broker/cache cutover, real billing or generative AI capability is implied.

## Alternatives

Retaining Node avoids rewrite risk but does not satisfy the requested runtime change. Simultaneously replacing identity/database or consolidating services increases migration scope and was declined by the human.

## Rationale

Changing the runtime independently preserves the existing wire, authority and ownership boundaries, making each service independently comparable and reversible. The approved migration adds one accepted decision to the previous 18-record baseline; the exact architecture gate therefore advances to 19 accepted records. The closed ADR-0019 evaluation remains a draft and is not counted.

## Consequences

.NET introduces a separate locked SDK, CI and container runtime. Every operation and worker needs behavioral parity and durable/native evidence before cutover. Existing Node tools remain valid for schema/content/Postman and rollback. Local scaffolding, green unit tests and container liveness do not admit the service.

## Migration and rollback

Baseline: `12b1222554c9ae248e47f865e3ecb1f1f2a02633`. Sequence: shared contracts/authority/persistence, Progress, Learning, AI, workers, mixed-runtime and all-.NET acceptance. A service has exactly one active writer and worker set at cutover. Compare independent seeded test projects; never shadow-write live data. Preserve row IDs, revisions, schemas and event identities. Stop .NET before restoring Node; do not reset learner data. Default local runtime changes only after acceptance. Cloud deploy/schema apply/push remain separately authorized.

Canonical references: [architecture](../ARCHITECTURE.md), [contracts](../../api/openapi.yaml), [data](../../data/DATA_MODEL.md), [task protocol](../../agent/TASK_PROTOCOL.md).

## Status

Implementation in progress. Node remains the active baseline; no service has been accepted or cut over yet. This ADR supersedes ADR-0003 only for the approved migration target, not the current deployed runtime.

## Revisit triggers

Revisit through the task protocol if Appwrite's REST transactions or permissions cannot preserve an existing invariant, if native acceptance exposes an incompatible contract, or if measured hosting constraints require another runtime topology. Do not silently replace identity/storage, relax admission or introduce a second live writer to bypass a failed gate.
