# Windows main and payment check — 2026-10-23

User scope: fetch current remote code, check payment and remote branches,
integrate into main, run checks, and show the web preview.

## Source and branches

`git fetch --all --prune` and `git pull --ff-only origin main` advanced local
main from `57fbc062` to `fa665708` (111 commits). All 14 remote topic branches,
including `origin/feat/payment`, are ancestors of this main. Every topic branch
has zero branch-only commits; `git branch -r --no-merged HEAD` is empty.
No additional merge is needed. See the earlier
[integration receipt](../../quality/MAIN_INTEGRATION.md) for those merges.

The pre-existing local frontend audit and remaining-plan edits were preserved
byte-for-byte and excluded from this change.

## Payment review and repairs

- Same-state billing notifications previously failed to advance their ordering
  watermark. A later-delivered older notification could then revoke or restore
  access incorrectly. The fix advances receipt metadata while preserving
  entitlement expiry, verification time, and outbox count for unchanged states.
- Invalid notification timestamps now fail validation before any inbox write.
  Three regression tests failed before the fix and passed afterward.
- The existing deterministic content-rebuild test exposed a Windows CLI entry
  check that silently skipped the builder. `fileURLToPath(import.meta.url)` now
  handles the Windows drive path correctly; all five content tests pass.
- An isolated read-only review found no new issue in these repairs.

Open payment issue: API restore of a historical receipt combines its product
with the account's current entitlement. If another device has changed to a
different product of the same tier, the client can display the historical plan
variant. The entitlement response lacks the current purchase/product identity
needed to correlate them. This remains unresolved; payment is not fully accepted.

Billing is internal simulation only. The web build selects mock data and mock
authentication; API billing also uses `SIMULATION`. The app has no StoreKit,
Google Play Billing, or payment-gateway SDK integration. No store sandbox or
real charge was tested. See [mock-payment scope](../../quality/MOCK_PAYMENT.md).

## Fresh verification on Windows

Toolchain: Node 22.23.3, pnpm 10.15.0, Flutter 3.47.0, Dart 3.13.0.
Logs are retained locally in `.cache/integration-20261023/`.

| Check | Result |
|---|---|
| `pnpm install --frozen-lockfile` | PASS; lock unchanged |
| `flutter pub get --enforce-lockfile` | PASS; lock unchanged |
| `pnpm backend:verify` | PASS; 172 passed, 0 failed, 12 skipped |
| Billing and commerce Node tests | PASS; 18 tests |
| Flutter payment, Max, settings/shop, API sync and DTO round-trip group | PASS; 155 tests |
| `pnpm backend:smoke`, `pnpm dev:smoke` | PASS; local only, zero provider calls |
| `pnpm contracts:check`, `pnpm api:lint`, `pnpm audit:check` | PASS |
| `pnpm schema:plan`, `pnpm schema:test`, `pnpm seed:check` | PASS; no cloud writes |
| `pnpm verify` | FAIL; format 544 files / 0 changes, analyzer 0 issues, Flutter 1051 passed / 273 failed |
| `pnpm build:web` | PASS; actual release build |
| `git diff --check` | PASS |

At least 255 failing Flutter case names explicitly identify golden comparisons;
the log also contains Rive native library-load failures. No golden baseline,
tolerance, or existing assertion was changed. The full Flutter gate remains
failing; no production or device acceptance is claimed.

## Web preview

`pnpm preview:web` serves `http://127.0.0.1:4173/preview.html` on loopback.
Preview HTML and JavaScript return HTTP 200 with `Cache-Control: no-store`.
The served JavaScript matches the new build byte-for-byte:
`373934b286e5d7393a5fcb096a13083f46507f2ab535c126668e31ff38eb456e` (SHA-256).
The visible Home screen was inspected and captured in
`.cache/integration-20261023/web-home.png`; the browser tab remains open.
