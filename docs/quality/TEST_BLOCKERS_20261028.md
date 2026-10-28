# Test blockers — 2026-10-28

This receipt supplements the existing [operation evidence](OPERATION_EVIDENCE_20261028.md).
It distinguishes reproduced failures from environment assumptions. No golden image,
reference asset or test tolerance was replaced or relaxed.

## Reproduced and fixed

- Direct Windows animation tests failed to load the Rive native runtime even though
  the release DLL already existed. The test bootstrap now preloads that DLL by full
  path through a native-only conditional export. No machine PATH, package cache or
  product animation changed. The six avatar/character motion tests pass directly.
- The generated Postman session capture exited before creating an answer plan, so
  every answer request was skipped. It now captures the session and derives answers
  for all 12 authored exercise types. Unsupported data fails visibly.
- The abandon conflict scenario could send the original revision again, making it
  an ordinary replay. The generated changed body now uses an actually different revision.
- The bodyless voice-close operation was rejected before its handler despite having
  no OpenAPI request body. Its service-local scope accepts the empty request and
  the handler rejects unknown fields. A regression test covers both.
- Lesson abandonment previously swallowed failures and closed the lesson anyway.
  The controller now waits, preserves the lesson/error state on failure and retries.
  The journal stores the exact abandon key/revision across repository reopening;
  a known revision conflict gets a fresh command identity. Existing lesson error
  presentation is reused.
- Real Year in Review could expose and share the historical demo before an API
  response or after a failure. API mode now has loading/error/retry states and no
  demo snapshot. The approved loaded demo layout remains unchanged. Unprovided
  percentile/score/duration fields are unavailable instead of fabricated zeroes.
- Sharing a real review with fewer than 1,000 XP threw a RangeError; grouping now
  supports small and large totals. Summary year/date come from the snapshot.

## Executed evidence

| Check | Result and scope |
|---|---|
| Backend verification, portable Node 22.23.3 | 277 tests: 265 passed, 0 failed, 12 live-gated skips; TypeScript, bundles, lint and format pass |
| Postman generated-artifact gate | 91 operations, 144 planned requests, deterministic regeneration, environment secrets empty, HMAC vectors pass |
| Repository-specific collection runner | Actual loopback HTTP: 137 requests, all 91 baseline operations executed, 408 assertions pass, 0 failed assertions or script errors; seven extra answer slots skipped |
| Collection runner/generator regression tests | 5 passed; response assertion failures, skip accounting, redirect/deadline policy, external/unsupported API rejection and authored answer capture covered |
| Abandon regression tests | 9 passed, including failure visibility, durable retry identity and revision conflict |
| Year-review state/economy scoped batch | 17 passed; API unavailable state/retry, sharing and economy integration covered |
| Combined lesson/journal/year-review regression | 43 passed; analyzer has no issues and Dart formatting is clean |
| Full Windows suite after native-runtime bootstrap, before later abandon/review changes | 1,348 passed, 273 failed; every failed test contained a golden pixel-diff assertion; no nonvisual failure found in the JSON test events |

The lightweight collection runner executes only the trusted generated collection's
current synchronous `pm` API subset. It refuses external origins/redirects and unknown
script APIs. It is not a general Postman/Newman sandbox. Baseline responses with
documented negative statuses remain contract smoke tests, not business-success proof.
The runner starts disposable in-memory services and never uses production credentials.

## Remaining acceptance

Strict visual comparison remains on the pinned Linux CI host; the Windows golden
differences must not be erased by regenerating baselines. The final candidate still
needs that canonical run. All live-gated skips still require admitted Appwrite
credentials, permissions/transactions and recovery evidence. Provider, device,
production broker/cache cutover, schema apply and deployment remain separate work.
