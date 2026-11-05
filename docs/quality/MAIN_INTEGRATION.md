# Main integration — 2026-10-23

Scope: the owner authorized reviewing the remaining remote branches, integrating
the missing current code into `main`, pushing `main`, and starting a preview.
Cloud migrations, deployment, paid providers and real purchases are not part of
this integration.

## Branch decisions

- `feat/real-learning-stats` contains `feat/payment`,
  `feat/persistent-mistake-review`, `feat/personal-vocabulary-srs`,
  `feat/pronunciation-assessment`, `feat/real-learning-flow` and
  `feat/real-placement-test`. It was merged once, preserving their ancestry.
- `pb/notify` contains no remaining content change against the integrated tree.
  Its merge retains the newer router/session logic, microphone permission,
  asset provenance and locked `cupertino_ui` version already on `main`.
- `hark/master-i1-i2` contains the October 10 exercise implementation and old
  sprint checkpoints. Its merge deliberately retains the later October 11
  exercise implementation and subsequent wire-image/audio integration on
  `main`, rather than restoring the older alternate renderers and snapshots.
  This is a history reconciliation, not adoption of every historical UI variant.

After these merges, `git branch -r --no-merged HEAD` returns no branches.
No remote branch was deleted and no published history was rewritten.

## Integration repairs

- Regenerated Dart DTOs and client endpoints from the current OpenAPI owner;
  the imported generation headers referred to an older spec hash.
- The DTO generator marks its own exact output `dart format off`. Backend
  contract checks remain independent of a Flutter installation, and formatting
  the app no longer makes generator-owned output fail the drift check.
- Applied the pinned Dart formatter to the source/test files rejected by the
  existing format gate; no behavior assertions or tolerances were changed.
- Updated only the golden snapshots for the intentional vocabulary buttons,
  lesson-feedback bookmark action and billing management changes. The 22
  affected golden cases passed their update run; final no-update checks are
  recorded below. Unrelated legacy goldens were not regenerated.

## Validation

The toolchain is Node 22.23.3, pnpm 10.15.0, Flutter 3.47.0 and Dart 3.13.0.

| Command / check | Result |
|---|---|
| `pnpm install --frozen-lockfile` | PASS; lockfile unchanged |
| `flutter pub get --enforce-lockfile` (mobile directory) | PASS; lockfile unchanged |
| `pnpm backend:verify` | PASS; 169 passed, 0 failed, 12 gated cloud tests skipped |
| `pnpm backend:smoke` | PASS; duplicate event applied once; no cloud/provider calls |
| `pnpm dev:smoke` | PASS; real HTTP health and signed event checks |
| `pnpm contracts:check` | PASS; 156 schemas, 105 fixtures; exact generated Dart output current |
| `pnpm contracts:generate` | PASS; TypeScript output unchanged |
| `pnpm api:lint` | PASS |
| `pnpm schema:plan` | PASS; dry run only |
| `pnpm schema:test` | PASS; 24 tests |
| `pnpm seed:check` | PASS; no network writes |
| `pnpm blueprint:check` | PASS |
| `pnpm audit:check` | PASS |
| `node tools/evals/voice-harness.mjs` | PASS; fixture schema check, not a provider benchmark |
| `pnpm build:web` | PASS; actual release Flutter web build |
| `python3 tools/palette_check.py` | 85 existing unmatched colors; byte-identical output to the pre-merge baseline; lesson art 0 unmatched |

An additional scratch check exercised `GET /v1/me/learning-stats` through the
real Progress router and strict in-memory persistence: 28 empty days, asymmetric
8/13 accuracy, duplicate event delivery, review/placement exclusion, account
isolation, missing authentication and forged query rejection all passed.

### Flutter baseline and candidate

The untouched pre-merge `main` was checked out into an isolated temporary
worktree using the same pinned SDK, package configuration and Linux Rive
library. Its command was:

```sh
flutter test --no-pub --dart-define=ENABLE_MASCOT_MOTION=false
```

Baseline: **1,061 passed / 144 failed**. Before the scoped golden updates,
the integrated candidate had **1,175 passed / 149 failed**. All baseline failing
test names were also present in the candidate; the five additional failures
were golden comparisons in Words, Settings and lesson feedback, whose visual
content intentionally changed. Actual renders were inspected before updating
those affected snapshots. These results do not establish a fully green suite.

Final `pnpm verify`: format **544 files / 0 changes**, analyzer **0 issues**,
Flutter **1,193 passed / 131 failed**. All 22 affected golden cases passed
without `--update-goldens`; 18 image files changed. Comparing the full failure
name sets gives **0 newly failing tests**, with 13 baseline failures now passing.
The remaining 131 failures are still a failing gate, not a green-suite claim.
Golden tolerances and existing behavioral assertions were not relaxed.

Android `flutter build apk --debug --no-pub`: **PASS**, 307.1 seconds on the
resource-bounded retry. Output: `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`.
SHA-256: `702555a53c7e2cad715e166076e3024901fe228df97c7477f22bee5d044b86d4`.
The pinned plugins emit a warning about a future built-in-Kotlin migration;
this build succeeds without a plugin upgrade. This is build evidence, not
proof of execution on a phone.

## Runtime checks and limits

The release preview runs the existing mock configuration. Learning, Progress
and AI also run as supervised dev services. All three `/health` routes return
HTTP 200 with `status: degraded`, as expected for the in-memory dev mode;
this is not a durable production backend and `/ready` intentionally stays closed.

On Chromium at 390×844 / DPR 2, the actual app was exercised through demo login,
Home, Practice, Words, saving `woman`, My vocabulary, due-word review and
Settings. Entering `người phụ nữ` returned “Correct”, then “Review complete”
with no XP awarded. The visible notebook contains the saved word, meaning,
due date and review controls. Settings retains readable account rows and
explicit “Demo billing • No real charges” copy. Browser errors were empty.
Screenshots and a real-pointer interaction recording were inspected.

The first Android debug-build attempt was terminated with exit 137. The kernel
OOM log identifies Java/Dart build processes as victims. The successful retry used a smaller
orb-local Gradle heap, one worker and in-process Kotlin; application build files
and dependencies were not weakened to work around the resource limit.

No physical Android device, iOS simulator, live speech provider or cloud schema
was tested. The new statistics writer requires the additive M004 columns before
its separate cloud rollout; follow [the statistics rollout](REAL_LEARNING_STATS.md)
and [the migration owner](../data/MIGRATIONS.md). Merging this code does not apply
that migration or deploy the endpoint.
