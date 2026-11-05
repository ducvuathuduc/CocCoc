# Real integration checkpoint — 2026-10-25

Local implementation continues on `codex/real-features-integration`. Appwrite Auth is retained. The human requested local preparation and key injection later; no VPS is available. Later instruction prioritizes working features and accepts minor visual differences while preserving the approved layout. Full integration, production and release acceptance remain open.

## Preserved UI

[Baseline](ui-baseline.json) records the original dirty candidate, HEAD and preview artifacts. [Integrity](baseline-integrity.json) confirms 1,583 art/reference files, the original web bundle and preview APK unchanged. Android testing restored the approved APK and relaunched it. A separate API debug APK is retained locally; it does not replace the approved browser preview.

[Runtime register](runtime-register.json) combines contract/route/provider/callback discovery with concrete [runtime findings](runtime-findings.json). Lexical discovery is not exhaustive semantic acceptance. Unsupported actions remain explicitly listed; no live status is inferred from an adapter class.

## Implemented behavior

- Validated real profiles fail closed before SDK/private HTTP construction. Release requires HTTPS; the explicit Android emulator profile uses `10.0.2.2`.
- Real shell/account/cache composition rejects fixture balances, fake deletion receipts and late cross-account responses. Same-state shell comparisons pass at widths 320/430, text scales 1/2 and light/dark.
- Native Drift journal transactionally stages completion, isolates accounts, bounds the queue, preserves operation IDs and migrates legacy preferences while retaining corrupt input/backup. Schema v2 atomically retains permanently rejected answer payloads for review, excludes them from replay and includes them in storage budgets. A v1 file upgrade preserves queued answer bytes. Actual Android emulator close/reopen, isolation, conflict and migration tests pass.
- Sync and connection recovery use actual journal state plus fresh owner API reads; cold/error/pending/rejected states cannot claim progress is current. A malformed success receipt stays retryable with its original operation key. Accepted synchronization invalidates path/Progress read snapshots. Full cross-service settlement is still a separate backend gate.
- Shop reads server wallet/catalog/inventory and freezes retry bodies/keys. Unsupported free offers stay unavailable.
- Nickname edits use `expectedRevision`; own-profile header uses verified identity and same-account Progress data. Unsupported social/score/joined fields display unavailable values. Standalone profile tab and lower social/achievement sections still require integration.
- Sound/privacy preferences use accepted server state and retained retry identities. Actual lesson effects read the accepted sound preference.
- Email verification reads Appwrite Account, sends and consumes links through the SDK, checks account ownership and reads verification back. Continue cannot mark an email verified locally. Configure `APPWRITE_VERIFICATION_URL` and platform association later; actual delivery/app-link acceptance remains pending.
- Notification channels, smart scheduling and reminder time wait for server acceptance. Failed saves retain old values and exact retry identity. Revision conflicts require refresh rather than automatic overwrite. Practice reminders use those accepted settings; denied native permission cannot save enabled, duplicate taps cannot repeat the OS request, and late account responses are ignored.
- Voice turns require captured audio, retain the exact request on retry and stop on lifecycle/account changes. Hosted speech stays disabled unless an actual engine is admitted; no scripted hosted success. Physical microphone/provider acceptance is pending.
- Hosted monetary simulation/ad/gift writers fail closed; explicit local dev/test simulation remains separate. Real money payments are excluded.
- Three owner HTTP/worker compositions enforce trusted identity, bounded requests, redacted failures and durable-adapter admission. Docker/CI definitions are prepared, resource-bounded and pinned. Compose configuration validates with CLI 2.39.1; Docker Engine is unavailable. RabbitMQ/Redis cutover remains unimplemented behind ADR gates.

## Executed evidence

| Check | Actual result |
| --- | --- |
| `pnpm backend:verify` on Node 22.23.3 | PASS: 212 tests, 200 passed, 12 gated skips, 0 failed; TypeScript, bundles, ESLint and Prettier pass |
| `pnpm backend:smoke`, `pnpm dev:smoke`, `pnpm runtime:check` | PASS, local fixtures/native HTTP only |
| `reward-delivery-trials.test.mjs` | PASS: 100 independent duplicate/reorder/commit-failure trials against the Progress consumer; ledger/XP equality and account isolation |
| `flutter test integration_test/real_journal_native_test.dart -d emulator-5554 --no-pub --dart-define=ENABLE_MASCOT_MOTION=false` | PASS: 3 tests on Android API 34 x86_64; actual native plugins/storage, not a physical device |
| Sync/journal/learning/account batch | PASS: 45 tests including sync/recovery, journal upgrade, learning flow, settings navigation and dark-surface regressions |
| Final combined scoped Flutter batch | PASS: 145 tests across 19 files; latest analyzer and format check pass |
| Latest Android API debug APK | PASS; separate artifact/hash in local result manifest, approved preview restored |
| Auth/Shop verification batch | PASS: 29 tests |
| Notification/repository/reminder batch | PASS: 39 tests, followed by additional denied-permission acceptance in the final combined batch |
| Existing notification functional groups | PASS: hub 3, reminders 5; no golden rewriting |
| Latest full `pnpm verify` before the later Auth/notification additions | 1,207 passed / 273 failed; exact failing-name set equals the previous baseline; format and analyzer passed at that checkpoint |
| `pnpm contracts:check`, `pnpm api:lint` | PASS; 157 schemas/105 fixtures, generated DTOs in sync |
| `pnpm schema:plan`, `pnpm schema:test`, `pnpm seed:check` | PASS: dry-run only, 24 schema tests; no schema apply |
| Content/media check | PASS: 512 lessons, 6,384 path exercises, 1,760 bundled assets; no new cloud publish |
| `python -X utf8 tools/palette_check.py` | 84 legacy unmatched colors, same baseline; informational and unresolved |
| Compose 2.39.1 `config --quiet` | PASS; no engine/container execution inferred |
| Secret scanner `--all` | PASS: 1,902 tracked/unignored text files with full redaction; no history/cloud inspection |

The 273 Windows failures were triaged: 272 visual golden cases and one Shop fixture missing its Max entitlement. An isolated Profile rerun reproduced a 3.83% pixel mismatch. The Shop fixture now explicitly supplies the entitlement represented by its reference; its historical image comparison still needs review. No proof establishes that every visual difference is a Windows-only issue. No golden baseline was replaced, no failing tests were disabled, and the full suite is not reported green. Minor pixel work is deprioritized under the latest human instruction; large visual regressions still require investigation.

Raw local logs are in `.cache/real-features-20261025/`. Targeted final results and latest APK identity are recorded in [the final local result manifest](local-results.json).

## Remaining acceptance

[Read-only hosted health](hosted-health-readonly.json) establishes liveness only: all three services reported degraded. It does not confirm production keys, schema/permissions, actual email delivery, providers or successful private functionality.

Remaining implementation includes AMQP application receipts/adapters/topology and Redis cache, supported phone-link and sensitive identity changes, avatar configuration/native icons, remaining social/profile flows and actual AI generation/provider integration. Full offline process-kill/reconnect with an admitted backend, physical Android audio/notification/motion acceptance, container execution, GitHub CI, recovery/security and deployment receipts remain open. No paid adapter, deployment, publish, schema apply, push or full phase advancement occurred.
