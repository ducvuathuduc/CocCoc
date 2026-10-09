# Research refresh and executable foundation — 2026-10-09

Goal: reconcile the attached current engineering directive with the actual Flutter mock app and V1 contracts; supply runnable local backend foundations without asserting cloud or production readiness.

Architecture: retain Flutter/Riverpod and three independently packaged TypeScript Learning/Progress/AI services. Progress retains profile ownership. Appwrite remains managed infrastructure; a dispatcher is an execution role within Learning. Existing UI, application IDs, contracts and production phase gates are preserved.

Spec: the user attachment dated 2026-10-09; [canonical entry](../00_READ_ME_FIRST.md), [SRS](../product/SRS.md), [OpenAPI](../api/openapi.yaml), [task protocol](TASK_PROTOCOL.md).

## Constraints and review focus

- Windows native development; no Docker, broker, gateway, new paid signup or cloud deployment.
- One isolated official voice research context; main thread owns all repository changes.
- Existing mobile code and dependency lock remain intact. A mock build proves compilation only.
- Never award production XP from fixture data; test fixture user isolation, duplicate/changed commands and async redelivery. Account.get JWT verification is supplied but live identity and owner permissions remain P1 gates.
- Model availability, Education expiry, native microphone, transaction conflicts, cross-account permissions and iOS signing require separate evidence.
- No secrets or raw private account metadata in inventory or logs.

## Tasks and acceptance

| ID | Owner / paths | Inputs / dependencies | Acceptance / exit gate | Lane / status |
|---|---|---|---|---|
| AUDIT-20261009 | root; tools/audit, docs/audit | clean baseline HEAD and attached directive | recursive file metadata + bounded text inspection, missing artifacts, per-document disposition, source/code distinction | exclusive audit; PASSED |
| RESEARCH-20261009 | root + isolated evidence reader; docs/audit, docs/ai | official current documentation | source URLs/date/classification; model shutdown and Education enforcement; no fabricated quota/latency | research; PASSED |
| SPEC-20261009 | root; existing owners + consolidated additions | audit + research | explicit scope/state/action/content/payment/ops contracts and required-content map | exclusive canonical docs; PASSED |
| FOUNDATION-20261009 | root; services, package tooling, tests, CI | fixed three-service boundary and OpenAPI | red-first meaningful behavior tests; strict TS; injected fake ports; local asynchronous completion/reward workflow; separate deploy descriptors; no enabled live adapter | exclusive root contracts/tooling; PASSED |
| VERIFY-20261009 | root; docs/audit, freeze report | preceding tasks | blueprint, JSON Schema, OpenAPI lint, links, Mermaid, source formatting/type/tests, Flutter analyze/tests/build when tooling available; exact receipts | verification; PASSED local; cloud/device/full phase gates pending |

## Execution steps

- [x] Inventory non-generated files; inspect text and record hashes/commit identity; compare actual routes/controllers/tests with historical screen IDs.
- [x] Read key official sources; classify public support separately from account access and benchmark proof.
- [x] Add substantive missing specifications and map consolidated requested documents to canonical owners; record V1 changes and unresolved gates.
- [x] Add failing backend acceptance tests before implementing fixture adapters and handlers; run local smoke with no network/provider spend.
- [x] Resolve and pin tools; run required validators, Flutter checks, and review the final diff; save audit and task evidence.

First five downstream implementation tasks remain P1-FOUND-001, P1-FOUND-002, P1-CONTRACT-001, P1-OPS-001 and P2-DES-001 in the [canonical phase plan](IMPLEMENTATION_PLAN.md). This refresh does not pass their external/device gates.

Evidence: [fresh validation](../audit/VALIDATION.md), [actual manifest](../audit/DOCS_MANIFEST.md), [conditional freeze](../ARCHITECTURE_FREEZE_REPORT.md). PASSED denotes the scoped local research/document/scaffold outcome; it does not close P1 or later cloud/device gates.
