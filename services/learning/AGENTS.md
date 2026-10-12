# Learning module

Own l_ tables and published/draft l_ assets. Course frontier, session grading, review and outbox belong here. Never write p_/a_ tables or award XP directly. Complete session/frontier/receipt/outbox in one transaction. Published bundle immutable; receipts reconstruct immutable large bundle. PLACEMENT earns no reward/activity; offline server regrades and has no league eligibility. Read DATA_MODEL, SRS and EVENTS_ERRORS before handler changes.

## Layout and switches

`domain/` grading (NFC, authored flags, token-ID classes, pairs), lesson queue/retry passes, frontier, review heuristic. `application/` use cases (content/publish, enrollment/path, sessions, review, outbox dispatcher + watermark, relay). `http/` routes for the OpenAPI learning operations; `scope.ts` resolves `{param}` templates and exposes `Idempotency-Key` without touching shared. `persistence/` engine + Appwrite TablesDB adapter (+ memory for tests/dev). `content/` integrity, validation, verified repository; course files live in `content/` at the repo root.

Hosted env: `COC_LEARNING_PERSISTENCE=appwrite` + `APPWRITE_API_KEY` selects the durable adapter (otherwise disabled); business routes also need `COC_LEARNING_ADMITTED=reviewed-cloud-gate`. `COC_CONTENT_PUBLIC_KEYS` (trusted content keys), `COC_MAINTAINER_USER_IDS` (publishers), `COC_PROGRESS_URL` + a `learning` key in `COC_SERVICE_KEYS` (immediate signed event relay). Dev: `COC_DEV_AUTH=1` accepts `Bearer dev-<userId>`; `COC_DEV_RELAY=0` disables delivery to the Progress dev server. Live tests: `COC_LIVE_LEARNING_APPWRITE=1` (TEST project only; rows cleaned up).
