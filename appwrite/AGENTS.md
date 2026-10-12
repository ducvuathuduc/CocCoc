# Appwrite schema and scripts

`appwrite/` is the only home for Appwrite resources. There is no `infrastructure/` folder.

```text
appwrite/
  schema/foundation.json     declared TablesDB tables/columns/indexes/permissions + buckets (generated)
  scripts/schema-lib.mjs     derivation from docs + CANONICAL_TABLE_COUNT
  scripts/schema-declare.mjs regenerate foundation.json from docs/data/DATA_MODEL.md + PERMISSIONS.md
  scripts/schema.mjs         dry-run plan (default) | --apply | --check-live
  scripts/seed.mjs           typed catalog seed validation against OpenAPI
  scripts/live-probe.mjs     gated live permission/transaction probes
  seeds/catalog.json
  test/schema.test.mjs
```

## Changing a table

1. Edit [DATA_MODEL](../docs/data/DATA_MODEL.md) and [PERMISSIONS](../docs/data/PERMISSIONS.md), the owner docs.
2. Update `CANONICAL_TABLE_COUNT` in `scripts/schema-lib.mjs` if the table count changes.
3. Run `pnpm schema:declare`, then `pnpm schema:plan && pnpm schema:test && pnpm seed:check`.
4. Commit the docs, the declaration and the tests together. `schema/` is an exclusive change area.

## Live commands (never in CI, never without an explicit request)

Run `pnpm schema:apply`, `pnpm schema:check-live` or `pnpm appwrite:probe` only against the reviewed **test** project. They require these environment variables:

- `APPWRITE_PROJECT_ENV=test`
- `ALLOW_SCHEMA_APPLY=reviewed-test-project` (for apply) or `ALLOW_LIVE_PROBE=reviewed-test-project` (for probe)
- `APPWRITE_ENDPOINT`, `APPWRITE_PROJECT_ID` and `APPWRITE_API_KEY` in the process environment, never in files

Apply is idempotent and additive. Never run a destructive reset.
