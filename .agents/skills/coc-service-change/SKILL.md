---
name: coc-service-change
description: Implement a CocEnglish Learning, Progress or AI API change with owner-safe Appwrite transactions and idempotency.
---

Trigger: assigned server command/event/schema task.
Inputs: task, owner, operation/event IDs and exclusive migration claim if needed.
Read: nearest AGENTS; OpenAPI; DATA_MODEL/PERMISSIONS; EVENTS_ERRORS; relevant SRS and ADR.
Procedure: inspect owner handler and adapter; verify subject and allowlist; failing tests for normal path plus duplicate/uncertain commit/foreign user; implement atomic domain effects and receipt/outbox; retry only bounded fresh re-stage; generate/validate contract fixtures; run targeted unit/contract then admitted integration checks.
Output: scoped diff and evidence linking command, table and requirement.
Validation: no cross-owner writes, deterministic receipt/body hash, event replay harmless, secrets/log redaction, transaction operations within probed budget.
Prohibited: inventing TablesDB APIs/columns/scopes; broad client table grants; direct client XP/clock; broker/new service without approved ADR; destructive migration or deployment without task authorization.
