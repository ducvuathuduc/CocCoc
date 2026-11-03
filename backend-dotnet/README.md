# ASP.NET Core migration — in progress

This directory contains the replacement runtime approved in [ADR-0020](../docs/architecture/adr/0020-dotnet-service-migration.md). Node remains the active baseline. This is not a complete replacement or a deployment-ready backend yet.

## Build and verify

Run from this directory with the SDK pinned in `global.json`:

```powershell
dotnet restore CocEnglish.sln --locked-mode
dotnet build CocEnglish.sln --no-restore
dotnet test CocEnglish.sln --no-restore
node tools/generate-contracts.mjs --check
```

The solution has three independent API hosts, a shared security/persistence library, contracts and three test projects. The canonical OpenAPI and storage declarations are embedded directly; the generator checks all 91 declared operations and 52 error codes without modifying Flutter contracts.

## Current verified scope

The shared implementation includes Account.get JWT verification, HMAC canonicalization and key rotation, owner-scoped TablesDB REST transactions, receipts, inbox deduplication, error envelopes and request boundaries. Tests currently use controlled HTTP handlers and row drivers, not a real Appwrite deployment.

Progress implements `getMe`, `getRewards`, `getLearningStats`, `listQuests`, `getPreferences`, `updatePreferences`, `sendFeedback`, `initializeProfile`, `updateMe` and the `deleteAccount` request. Quest reads preserve local daily/monthly periods, UTC Monday friend weeks and the existing offset cursor. Writes preserve revision checks and atomic receipts. Initialization credits 20 gems only once, including across different operation keys. Profile updates preserve nickname normalization and deferred/rate-limited timezone changes. Deletion writes its tombstone and owner event atomically and returns 202; purge/ack workers are still pending.

Latest Windows checkpoint (2026-11-03): `dotnet test CocEnglish.sln --no-restore --configuration Release --logger "trx;LogFileName=dotnet-foundation-checkpoint.trx"` passed 69 shared, 32 Progress and 62 HTTP integration cases (163 total). All 163 cases also passed Release tests inside the pinned Linux SDK image. Generated-contract validation passed. These results prove only the implemented local scope.

The [operation matrix](migration/operations.json) records local evidence and remaining acceptance. `implemented-local-tests` does not mean service acceptance. Other business operations, internal consumers, workers, differential tests, durable Appwrite acceptance and Flutter end-to-end acceptance remain outstanding. Readiness deliberately returns 503 while migration is incomplete; unported operations fail closed. A separate .NET CI workflow is defined; it has not been run on GitHub yet.

## Local container foundation

From this directory:

```powershell
docker compose -f docker/compose.foundation.yaml up --build --wait --wait-timeout 120
node tools/smoke-hosts.mjs
docker compose -f docker/compose.foundation.yaml down --remove-orphans
```

All three API images have been built and their real HTTP liveness/fail-closed smoke passed on loopback ports 5101–5103. Images run as non-root with read-only filesystems, bounded memory/processes and no added capabilities. `--probe` checks only the process's own `/health`; container health must not be interpreted as durable readiness. This isolated stack has no Appwrite credentials or workers and does not change the existing Node stack.

To execute the current tests inside Linux, run from the repository root:

```powershell
docker build --target test -f backend-dotnet/docker/Dockerfile -t cocenglish-dotnet-foundation-tests .
```

## Migration constraints

Keep Flutter, Appwrite identity/data/storage, wire contracts, deterministic IDs and service-owned writes. Never run Node and .NET writers/workers concurrently for the same owner during cutover. Preserve Node for rollback. Do not reset learner data, introduce shadow writes, enable paid providers, apply cloud schema, deploy or push as an implicit consequence of local migration work.

Next: complete Progress writes with receipt-backed concurrency tests, then its consumers/jobs, Learning and AI. Test mixed runtimes and all-.NET Docker against isolated durable data before any cutover.
