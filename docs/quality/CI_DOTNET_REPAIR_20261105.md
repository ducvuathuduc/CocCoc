# .NET migration CI repair — 2026-11-05

Scope: repair the existing migration branch under [ADR-0020](../architecture/adr/0020-dotnet-service-migration.md); no runtime cutover or deployment.

The [failed workflow](https://github.com/ducvuathuduc/CocCoc/actions/runs/42006231305) stopped with CS1501/CS1061 because `OutboxBacklogMetricsService` called session query methods on `OwnerStore`. The metric refresh now opens an owner session through `TransactAsync`, reads the three status counts and oldest active event, and publishes only the completed result. It stages no writes.

Regression tests cover all three owner tables, exact status filters, oldest-event ordering, count/age metric values, and cancellation on service shutdown. The test driver rejects every write. The targeted command reproduced the two compiler errors before the fix and passed 3/3 afterward.

Local commands from `backend-dotnet/`, pinned .NET SDK 10.0.401:

- `dotnet test tests/CocEnglish.Shared.Tests/CocEnglish.Shared.Tests.csproj --configuration Release --filter FullyQualifiedName~OutboxBacklogMetricsTests`: PASS, 3 tests.
- `dotnet restore CocEnglish.sln --locked-mode`: PASS.
- `dotnet build CocEnglish.sln --no-restore --configuration Release`: PASS, zero warnings/errors.
- `dotnet test CocEnglish.sln --no-build --no-restore --configuration Release --logger 'trx;LogFileName=dotnet-migration.trx'`: PASS, 750 passed, 7 gated live tests skipped, zero failures.
- `node tools/generate-contracts.mjs --check`, all ten parity fixture generator checks, and `node tools/check-operation-parity.mjs`: PASS, 91/91 operations covered.

Docker and GitHub execution evidence is recorded after the workflow finishes. Deterministic tests do not establish cloud durability, native device behavior, or runtime admission.
