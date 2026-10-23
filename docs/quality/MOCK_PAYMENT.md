# Simulated subscription payment — 2026-10-21

Branch: `feat/payment`, base `origin/main` at `c407f46`. User authorization:
complete the existing simulated purchase design; keep all work local until push
is explicitly permitted. No deploy, schema apply, paid call or push is included.

## User flow

Open Super or Max, select an individual/family plan, proceed to the confirmation
sheet and choose a demo result. **CONFIRM DEMO PAYMENT** creates the order.
Success activates the selected mock plan; pending keeps premium ungranted (or
preserves the previous paid plan during an upgrade); declined leaves the prior
receipt unchanged. Settings → Manage Subscription shows the order, state, expiry
and renewal status. Restore rereads saved state. Cancel Subscription disables
renewal while keeping access until expiry.

Mock mode is runnable without a payment account. Receipts use the existing
shared_preferences dependency in a dedicated `billing.v1.demo.<user>` namespace;
API retry intent/receipt uses `billing.v1.api.<user>`. Storage failure is surfaced
before API checkout rather than silently losing its operation key. The demo
guest namespace is explicitly local simulation data. Provider responses from a
previous account are discarded when the repository changes.

In API mode a signed-in user calls Progress `verifyPurchase`, `getPurchase`,
`getEntitlement` and `cancelSubscription`. The API uses SIMULATION only; pending
orders settle through the existing maintainer-signed billing notification. Local
pending-demo settlement does not call this privileged route. New REST operations
and TypeScript/Dart client code are generated from the canonical OpenAPI.

## Requirement evidence

| Behavior | Exact regression evidence |
| --- | --- |
| Receipt persistence and restart | `mock purchase persists receipt and restores after repository recreation` |
| Pending/declined and existing access | `pending payment grants nothing until explicit simulated settlement once`; `pending upgrade preserves current paid plan after restart`; `declined payment never replaces a valid receipt` |
| Explicit checkout, readability | Three `checkout <outcome> requires explicit confirmation at text scale two` cases; `routed mock checkout dismiss preserves selection and confirms only explicitly` |
| Duplicate/lost response | `controller blocks duplicate checkout and applies verified result`; `lost response retains durable intent and retries same key after recreation`; `intent storage failure prevents a purchase request` |
| Restore/cancel/expiry | `restore checks owned receipt instead of creating a second purchase`; `cancel renewal preserves paid expiry through restore and expires at boundary`; `API cancel renewal uses server expiry and does not revoke paid access` |
| Account isolation | `repository/account change ignores late purchase result`; `owned receipt read redacts tokens and hides other accounts` |
| Server authority | `API submits SIMULATION with bearer and caller idempotency key`; `pending Max upgrade cannot grant Max while current entitlement is Super` |
| Event correctness | `cancel renewal keeps paid access and emits one event across retries`; `duplicate ACTIVE notifications do not extend paid expiry`; `newer ACTIVE notification cannot resurrect a refunded purchase` |

Initial backend RED: all four new regressions failed (missing owner receipt/cancel
routes; duplicate ACTIVE extended expiry; refund could be reactivated). After the
implementation, the billing/commerce group passes 15 tests. Focused Flutter,
existing Max navigation, generated-operation sync and DTO round-trip tests pass
155 cases after including settings restore/navigation. These tests use in-memory persistence and fake HTTP; they prove no
device, store or deployed-cloud behavior.

## Verification results

| Command | Result |
| --- | --- |
| `flutter test --no-pub test/billing_test.dart test/billing_api_test.dart test/max_flow_test.dart test/settings_shop_taps_test.dart test/core/api/api_operations_sync_test.dart test/api_contracts_round_trip_test.dart --dart-define=ENABLE_MASCOT_MOTION=false` (from mobile) | PASS 155 tests |
| `node --test services/progress/test/billing.test.mjs services/progress/test/commerce.test.mjs` | PASS 15 tests |
| `flutter analyze --no-pub` | PASS, no issues |
| `flutter build web --release --no-pub --dart-define=USE_MOCK_AUTH=true --dart-define=RIVE_NATIVE_WASM_HOST=rive/` | PASS, release web compilation in 121.4s. No Android/iOS device or store test is inferred |
| Full Flutter tests with motion disabled | 948 passed / 273 golden failures, no billing/payment group failure; 273 is also the previous baseline golden failure count |
| Full backend test list (`services/{progress,learning,ai,shared}/test/*.test.mjs`) | 168 passed / 1 failed / 12 skipped. The existing Learning content rebuild assertion receives empty stdout on Windows; no billing test failed |
| `node tools/scripts/backend-check.mjs` | TypeScript/artifact builds/ESLint pass; stops at repository Prettier baseline (156 files). All five changed backend files pass scoped Prettier and ESLint |
| `node tools/scripts/mobile-check.mjs --with-blueprint` | Blueprint passes; stops at 20 pre-existing formatting differences outside this change. No unrelated baseline file was formatted |
| `node tools/blueprint/validate-schemas.mjs` | PASS 154 schemas / 105 fixtures |
| `node tools/blueprint/generate-dart-contracts.mjs --check` | PASS, 154 schemas / 165 classes, generated source SHA matches the changed contract |
| Redocly lint | PASS, valid OpenAPI |
| `node tools/blueprint/validate.mjs`, `node tools/audit/validate.mjs` | PASS, 39 requirements / 62 tables / 90 operations and valid links/diagrams |
| `node tools/scripts/backend-smoke.mjs`, `node tools/scripts/dev-smoke.mjs` | PASS, local in-memory / real local HTTP and signed event delivery, no external provider calls |

The Flutter full run completed while final API restore and settings assertions
were being tightened; the final 155-case targeted run and clean analyzer cover
those final changes. The full run is broad regression evidence, not an all-green
release claim. Raw logs are retained under `.git/testagent/payment/` outside the
stageable source tree. Host Flutter/Dart remains 3.47.2/3.13.2 versus the pinned
3.47.0/3.13.0; no claim is made that this explains every golden difference.

The source-pairing helper could not run because tree-sitter-language-pack is not
installed; no test-coverage claim is based on that helper.

## Scope limits

All prices and payment outcomes are illustrative. Local demo receipts are not
proof of an entitlement in API mode. Family membership/invites and gift checkout
keep their existing separate implementation. Existing free-trial tour screens
are retained as previews; the new checkout explicitly states no real trial or
store renewal is created. Real payment integration and device/store sandbox
validation require their own configuration and acceptance work.
