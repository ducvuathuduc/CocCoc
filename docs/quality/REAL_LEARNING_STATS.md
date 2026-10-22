# Real learning statistics — 2026-10-22

Branch: `feat/real-learning-stats`.

## Use

In native API mode, open **Profile → Learning statistics**. Switch between the last 7 and 28 learning days. The screen includes daily XP bars, completed lesson/review counts, active days and first-attempt accuracy for tracked lesson originals. Pull down to refresh; loading, empty and retry states are explicit. Day labels come from the server calendar rather than the device clock.

History is a daily summary, not individual lesson titles or sessions. XP includes all credited study XP; lesson counts include replays. Accuracy is weighted by the number of originals, excludes reviews and placement, and includes replays of ordinary lessons. Older rows without the new counters are excluded from accuracy, not treated as incorrect answers.

## Authority and data isolation

`GET /v1/me/learning-stats` uses the verified JWT subject and rejects query parameters. Reads are bounded to 28 rows plus one most-recent-day lookup. Missing dates are filled with zero. The endpoint uses the effective server learning zone and preserves the latest credited day across backwards timezone travel. It returns no other user's activity. Mobile state is disposed on leaving the page and reloaded on account changes; loading never displays a previous account's retained result.

The new counters are written inside the existing idempotent lesson reward transaction. AI practice preserves them. Duplicate completion events return before changing counters. Capped XP still records practice; placement does not create daily activity. Accuracy is not inferred from earned XP or a fixed lesson length.

## Rollout

1. Review and apply the additive [M004 declaration](../data/MIGRATIONS.md) on the authorized test project before deploying Progress. Two nullable integer columns are added to `p_day_activity`; no backfill or destructive operation is required.
2. Deploy the updated Progress service, then the mobile client. Deploying the new writer against a database without the columns can reject lesson reward transactions.
3. Validate with a test account: empty history, a completed lesson and replay, duplicate event delivery, review, placement exclusion, reconnect/retry, account switch, zone transition and large text.

Cloud schema apply, deploy and device/account checks were not performed by this task. The new endpoint will not exist on the hosted service until deployment. Existing legacy answers cannot acquire a reliable denominator retroactively.

## Local evidence

- Progress bundle: `node tools/scripts/backend-check.mjs --build progress` passed.
- TypeScript: `node node_modules/typescript/bin/tsc -p tsconfig.backend.json` passed.
- Flutter: `flutter analyze --no-pub` passed on final sources (12.1 seconds).
- OpenAPI: `pnpm api:lint` passed.
- Traceability: `pnpm blueprint:check` passed after updating the operation trace.
- Schema declaration regenerated from canonical docs; `pnpm schema:plan` passed with no network access.
- Generated TypeScript/Dart contracts and Dart API endpoints were regenerated from OpenAPI.
- Functional and regression tests were not added or run for this request. Runtime and regression correctness remain unverified.

Canonical owners: [SRS](../product/SRS.md), [wire contract](../api/openapi.yaml), [data model](../data/DATA_MODEL.md), [permissions](../data/PERMISSIONS.md).
