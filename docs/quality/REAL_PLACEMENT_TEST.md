# Real placement test — local implementation receipt

Date: 2026-10-22. Branch: `feat/real-placement-test`, based on `f2ffe88` from
`feat/real-learning-flow`. This branch is local; merge ownership remains with
the user's teammate. No deployment, schema application or push was performed.

## Use the feature

From `apps/mobile`:

```sh
flutter run --dart-define-from-file=config/real.public.json
```

Sign in with an account that has no enrollment in the available English course.
After profile preparation, choose **CHECK MY LEVEL** or **START FROM THE
BEGINNING**. Accounts with an existing learning path keep that path. A saved
unfinished placement can still resume if an earlier enrollment response was lost.
The default mock preview keeps its separate local placement journey.

The test uses the published manifest's placement bundle and ten original
questions. The server owns grading and first-attempt accuracy. Continue after the
tenth answer completes the test, then enrolls using the completed session ID.
The server's existing rule chooses unit 2 at 8/10 or higher, otherwise the first
node. This is a course starting-point check, not a certified CEFR assessment.
Placement creates no XP, streak/activity or lesson reward event.

The path opens its server-designated current unit after enrollment and on cold
start. Browsing another unlocked unit remains a learner choice.

## Implementation and recovery

- Removed eager beginner enrollment during session preparation. Beginner is now
  an explicit command with a retained idempotency key and duplicate-tap guard.
- Added native entry/result screens, authenticated placement routes and a pending
  placement redirect. An unfinished journal blocks a conflicting beginner choice.
- Starts use `SessionRequest(mode: PLACEMENT)` with the published bundle ID.
  Start intent is stored before POST. Lost starts replay the same request and
  read current session state. Expired attempts get fresh start keys.
- Answers use authoritative API grading. A disconnected answer stays journaled;
  retry sends its original body/key/revision. Placement never falls through to
  provisional offline grading or ordinary offline-completion sync.
- Original questions are presented once, without lesson retry passes. Resuming
  the final answered question retains original-only placement state.
- Completion and enrollment are two replay-safe commands. The journal is cleared
  only after enrollment succeeds. If enrollment committed but its response was
  lost, startup still offers resume; replay returns the saved server result and
  existing frontier. Completed results use server accuracy, and placement
  receipts are always non-rewarding.
- Identity-scoped journal/provider behavior is inherited from the real-learning
  branch. No generated contracts, database schemas, service handlers, dependencies
  or paid adapters were changed.

Canonical rules: [SRS FR-COURSE-002](../product/SRS.md),
[OpenAPI](../api/openapi.yaml), [release gate](RELEASE_GATE.md).
The earlier [real learning receipt](REAL_LEARNING_FLOW.md) remains a historical
receipt; its eager-enrollment behavior is superseded by this branch.

## Requirement coverage

| Requirement | Exact test evidence |
| --- | --- |
| Published placement bundle, no early enrollment | `placement starts the published server bundle before enrollment` |
| Server score, zero XP, enroll completed session | `placement completes with zero XP and enrolls using server session identity` |
| Lost start and expired attempt | `lost placement start response replays the durable original request`; `expired placement attempts get a new start identity` |
| Offline answer and completion | `offline placement answer stays pending and retries with the exact key`; `offline placement completion never queues an ordinary lesson` |
| Lost enrollment response | `failed enrollment preserves completed placement and replays both keys`; `bootstrap retains pending placement even after server enrollment committed`; `saved placement can resume when enrollment already exists` |
| No conflicting attempt or retake | `placement cannot overwrite a different saved lesson`; `existing enrollment cannot be retested through placement entry`; `beginner choice cannot bypass an unfinished placement journal` |
| Exactly ten originals | `placement ends after ten original answers without retry passes or XP` |
| Correct path and authenticated routes | `cold path opens the server frontier unit and retains manual selection`; `placement routes require identity but not prior enrollment` |
| Explicit beginner choice and retry | `beginner choice is explicit and duplicate taps enroll once`; `failed beginner enrollment retries the same command identity` |
| Large text | `starting point choice is readable at text scale two`; `placement entry explains no XP and resume at text scale two` |
| Server boundary and monotonicity | Existing backend tests `placement 8/10 -> unit 2; no reward event; cannot repeat`; `placement 7/10 -> node 1; no reward event; cannot repeat` |

Final verification results are recorded below after all checks finish.

## Acceptance limits

Local fake transport and backend fixture evidence only. No real cloud account,
physical-device, iOS, email, provider or production readiness claim is made.
`coccoc-test` is selected in the existing public config; its hosted content,
persistence and permissions still need authenticated acceptance. No credentials
are needed for the committed tests. Cold restore/resume requires connectivity;
disconnected placement pauses with its saved evidence. Per-user journal storage
remains the existing preferences implementation; a Drift migration is separate.
Billing remains simulated. This task does not merge into main or publish code.

## Final local verification (2026-10-22)

| Check | Result |
| --- | --- |
| Feature repository/controller/UI cases | 19 passed |
| Scoped Flutter regression command below | 76 passed |
| Existing backend placement boundary tests | 3 passed (7/10, 8/10 and placement constant) |
| Full Flutter suite on final source | 1051 passed; 273 existing golden/UI baseline failures; no failures outside that group |
| `flutter analyze --no-pub` | PASS, no issues |
| Changed Dart formatting | PASS |
| Native debug APK using `config/real.public.json` | PASS; compile receipt only |
| Documentation integrity and blueprint validators | PASS |

From `apps/mobile`:

```sh
flutter test --no-pub --dart-define=ENABLE_MASCOT_MOTION=false test/real_placement_test.dart test/real_placement_ui_test.dart test/real_learning_flow_test.dart test/real_account_session_test.dart test/features/learning test/learning_controller_test.dart
flutter analyze --no-pub
flutter build apk --debug --no-pub --dart-define-from-file=config/real.public.json
```

Backend fixtures (from root):

```sh
node --test --test-name-pattern=placement services/learning/test/sessions.test.mjs services/learning/test/domain.test.mjs
```

The scoped regression exposed an existing widget fixture's dependency on native
preferences once boot started reading the journal. Its journal is now explicitly
in-memory in that fixture; the product still reads durable per-user storage.
A missing enrollment command was reproduced before adding completion-to-enrollment
sequencing. Golden baselines were not rewritten. Raw logs and comparison images
remain local under `.git/testagent/placement/`.

Debug APK: `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`, 273944762 bytes.
SHA-256: `aa627e74431d4e75404aa2b9ebfe38f1c8bef96b8ae70471ffaace4fdd02b18d`.
No authenticated cloud or physical-device acceptance was run.
