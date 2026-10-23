# Real learning flow — local implementation

Branch: `feat/real-learning-flow`, from local `int/real-learning-features` combining
payment, pronunciation practice, vocabulary and persistent mistake review.
Neither new branch is pushed; main is unchanged. The user selected code completion
first and the existing `coccoc-test` project for later live acceptance.

## Native launch

From `apps/mobile`:

```sh
flutter run --dart-define-from-file=config/real.public.json
```

[Public configuration](../../apps/mobile/config/real.public.json) selects real
Appwrite Account auth and the three existing cloud function domains. No password,
API key or server secret ships in it. Default builds still use fixtures. The REST
transport supports native platforms; browser preview is not a cloud acceptance target.

## Implemented

- Restore identity and guard protected routes. Prepare missing server profile and
  enrollment, and fetch all path pages before admitting learning. Retain command
  keys across preparation retries; preserve existing profile choices.
- Registration publishes the authenticated identity before API clients are used.
  Preparation uses the fresh client and bypasses simulated verification. This
  does not claim that email is verified.
- Dispose account-scoped JWT caches, including late token mints. A second 401
  after refresh expires UI identity. Failed remote logout can be retried.
- Resolve lessons by server section/unit/node. Later units do not inject guest
  fixtures. Local placement/demo and skip checks cannot advance the real path.
- Journal starts before sending. Restore ordinary and retry queues, including
  provisional ordinary offline answers. Reuse exact command keys on replay;
  expired attempts get fresh start keys. Mistake review keeps its own snapshot.
- Server reads own XP, streak and path. A receipt cannot mint local API progress.
  Completion/app resume refresh snapshots and sync queued ordinary completions.
  Pending rewards are labelled and have a check-sync action.

Behavior owners: [SRS](../product/SRS.md), [OpenAPI](../api/openapi.yaml),
[release gate](RELEASE_GATE.md).

## Limits and later acceptance

No deployment, schema application, cloud account creation or authenticated
end-to-end run was performed. Public health reads returned 200 from all three
existing domains. The shared transport hardcodes `degraded`; it proves neither
persistence readiness nor authenticated business behavior. Hosted builds predate
this integration. Review schema, signed content, persistence admission and relay/
worker configuration through the gated deployment procedure before cloud acceptance.

Cold-start admission requires an online session/profile/path read. Cached lesson
evidence survives disconnection; fully offline cold-start admission is not included.
The existing per-user journal uses preferences; a planned Drift migration is separate.

Configure an allowed HTTPS `APPWRITE_RECOVERY_URL` and platform links before device
recovery acceptance; no recovery domain is invented in the public config. OAuth
flags remain off. Billing stays simulated and vocabulary stays local per account.
Speech still needs device, privacy, quality and cost acceptance before paid enablement.
Other preview journeys do not become real merely by selecting API mode.
No physical-device, iOS, email-delivery or cross-device acceptance claim is made.

Later, with explicit deployment authorization and native test login: verify one
profile/enrollment; complete and replay a lesson for exactly one reward/frontier
update; kill/reopen during answers and completion; reconnect offline completions;
resolve a saved mistake; switch accounts without data leakage; exercise logout
failure, expiry and the configured recovery link. Keep credentials out of chat,
source, screenshots and logs.

## Verification

Regressions reproduced before fixes: late JWT mint, later-unit lesson selection,
ordinary restart cursor, provisional offline restart and repeated 401 retaining
stale UI identity. Fixtures do not contact Appwrite. Final results follow below.

### Final local receipt (2026-10-21)

| Check | Result |
| --- | --- |
| Three new test files | 15 passed |
| Related regressions (command below) | 92 passed |
| Full Flutter suite, concurrency 2, mascot motion disabled | 1032 passed; 273 golden/UI baseline failures; no failures outside that group |
| `flutter analyze --no-pub` | PASS, no issues |
| `dart format --output=none --set-exit-if-changed` on changed Dart files | PASS |
| `flutter build apk --debug --no-pub --dart-define-from-file=config/real.public.json` | PASS, native compile only |
| `pnpm backend:verify` | tsc, bundles and ESLint pass; stops at Prettier issues in 161 existing files |
| Separate `node --test` over service test files | 168 pass, 1 content check failure, 12 live tests skipped |
| `pnpm contracts:check` | 154 schemas / 105 fixture cases pass; raw generated-byte check fails on CRLF; read-only LF-normalized generation matches |
| Audit syntax/links and blueprint validators | PASS; raw endpoint matrix check remains stale |

The backend content failure is in deterministic content tooling, including a
Windows entry-point comparison and the committed build-report check. Backend
source and generated course content were not changed by this implementation.
Golden files were not regenerated. Full-suite failure images and raw receipts
are retained locally under `.git/testagent/real-learning/`.

Final scoped command (from `apps/mobile`):

```sh
flutter test --no-pub --dart-define=ENABLE_MASCOT_MOTION=false test/real_account_session_test.dart test/real_learning_flow_test.dart test/real_session_token_test.dart test/auth_controller_test.dart test/features/learning test/features/api_snapshot_repositories_test.dart test/features/api_feature_repositories_test.dart
```

Debug APK: `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`, 232894475 bytes.
SHA-256: `e099ce614444cd4c89792cfcc43328e62a60ff144b2be7006b7483b3dc6bbdad`.
This artifact is a local compile receipt; it does not prove authenticated cloud
persistence, email recovery, provider quality or physical-device behavior.
