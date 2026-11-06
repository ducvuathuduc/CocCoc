# ASP.NET Core migration

Read [ADR-0020](../docs/architecture/adr/0020-dotnet-service-migration.md), the [operation matrix](migration/operations.json), [OpenAPI](../docs/api/openapi.yaml), [data model](../docs/data/DATA_MODEL.md) and the corresponding Node service's application/domain/persistence code before porting behavior. All 91 operations plus internal handlers and workers remain in scope. Never replace a business implementation with a successful placeholder, a Node subprocess or a production memory store.

Use the pinned SDK and locked packages. Preserve controllers, sealed typed DTOs, wire names/nulls/status codes, the existing error envelope, UTC millisecond timestamps and cancellation. OpenAPI is canonical; generated route/error catalogs are checked with `node tools/generate-contracts.mjs --check` from this directory. Keep the Node implementation for differential tests and rollback.

Identity comes from verified Account.get only. Cross-service authority uses the existing HMAC contract. Use owner-scoped transactions, receipt/inbox/outbox conventions, original row IDs and server time. Never trust client XP or write another owner's tables. API keys must not appear in source, tests, logs or build contexts.

Add meaningful failing tests for each port; directly test application rules and verify the HTTP composition. Run the affected tests, then the solution tests. Test doubles prove local behavior only. Record durable Appwrite, mixed-runtime and native evidence separately. Readiness remains closed until the complete admission gate is satisfied. The unconfigured Docker foundation stack proves liveness and failure boundaries only.

Do not push, merge, deploy, apply cloud schema, reset learner data or enable paid providers without explicit authorization. At cutover, permit only one active writer and worker set per owner.
