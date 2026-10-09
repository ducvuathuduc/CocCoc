# Backend foundation

Read the nearest owner instructions, SRS, OpenAPI, data model and current task. Three independently packaged services remain Learning/Progress/AI; the shared module contains transport and verified auth only.

Run `pnpm backend:verify`, `pnpm backend:smoke`, `pnpm contracts:check` and `pnpm api:lint`. Use strict TypeScript and runtime DTO validation. Verify Appwrite JWT using Account.get; never accept caller user IDs or mobile XP. Cloud entrypoints deliberately return no business success until live persistence/auth gates exist.

Mock stores are acceptance fixtures, not durable storage. Their completion/reward workflow is local and never included in a cloud Function artifact. Transactions, retry leases, permissions, migrations, service HMAC and outbox recovery need admitted cloud tests before enablement. No live AI in CI.
