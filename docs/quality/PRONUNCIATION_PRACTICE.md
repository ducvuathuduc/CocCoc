# Recorded pronunciation practice — 2026-10-15

Branch: `feat/pronunciation-assessment`, based on `origin/main` at `d8632b0`.
Fetch on 2026-10-15 found no newer main commit. Existing commits `b5edb59`,
`7097db8` and `69f7ef3` already implement the Azure provider, mobile recorder,
lesson assessment and voice-turn audio. This change connects the remaining
Practice recording screen to those interfaces.

Scope: [FR-SPEECH-001/003](../product/SRS.md), using the existing
[AI score rules](../ai/AI_ARCHITECTURE.md) and REST contract. No API/schema,
provider configuration or architecture change. The recording/upload format was
cross-checked against Microsoft's [short-audio REST reference](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/rest-speech-to-text-short).

## Behavior

- Three reference sentences, explicit microphone action, automatic stop/submit
  at 15 seconds, no simultaneous start or duplicate stop submission.
- Existing API assessor uploads WAV, SHA-256, reference and Appwrite JWT. The
  client retries with the same job/body/key. Practice feedback never awards XP.
- Dedicated scorer metrics, word errors and expandable phoneme scores are
  preserved. Optional metrics stay absent. Failed/expired/unfinished or
  low-confidence results cannot pass as a scored verdict. Transcription-only
  results explicitly say pronunciation was not assessed.
- Permission denial, empty recording and network failure permit retry/typed
  practice. Background/exit/disposal cancels microphone capture and invalidates
  asynchronous results. The iOS permission prompt's inactive lifecycle does not
  cancel a permission request; background/hidden still cancels it.
- Android RECORD_AUDIO and optional microphone hardware declaration, plus iOS
  microphone purpose text. No recording until the learner taps the button.
- Mock mode shows unavailable/typed practice instead of fabricated recording
  completion. The legacy typed call demo remains a separate flow.

## Validation

Initial RED: the two new widget acceptance cases failed against the old screen
(missing reference sentence and microphone-denial result). Then the implementation
passed the scoped command below. All requests in these tests use doubles; no
microphone, provider key, paid call or cloud deploy is involved.

From `apps/mobile`:

```sh
flutter test --no-pub test/pronunciation_practice_test.dart test/speech_assessment_test.dart test/practice_flow_test.dart test/english_spoken_lesson_test.dart --dart-define=ENABLE_MASCOT_MOTION=false
flutter analyze --no-pub
```

| Requirement | Direct evidence |
| --- | --- |
| Capture/upload/reference/word+phoneme feedback | `records real audio and submits the displayed reference once`; `uploads WAV with reference, SHA256, bearer auth and stable retry key`; `keeps dedicated scorer metrics and drops inserted words` |
| Permission and no fake success | `permission denied never sends audio and offers typed practice`; `mock mode offers typed practice without a fabricated recording`; `denied speech uses an assisted guest text substitution` |
| Bounds, errors and retry | `double tap cannot open two microphone sessions`; `recording stops automatically at 15 seconds`; `empty recording is retryable and never sent`; `network failure preserves sentence and permits explicit retry`; `assessment timeout becomes retryable without a second submission` |
| Lifecycle/stale work | `background cancels capture and never submits it`; `late assessment after interruption cannot replace a newer result`; `leaving during microphone permission cancels late capture`; `iOS permission inactive state still allows recording after approval` |
| Honest nullable scoring | `transcript-only result never displays numeric pronunciation`; score-state/status parameter cases and the two threshold boundaries in `speech_assessment_test.dart`; generated contract rejects stale numbers/missing score provenance |

| Check | Result |
| --- | --- |
| Scoped Flutter command above | PASS, 42 tests, including 320px/text-scale-2 scored feedback and phoneme expansion |
| `node --test services/ai/test/speech.test.mjs` | PASS, 7 tests with fake provider HTTP, including Azure scoring, fallbacks, cap and provider failures |
| `flutter analyze --no-pub` | PASS, no issues |
| Full `flutter test --no-pub --dart-define=ENABLE_MASCOT_MOTION=false --reporter json` | 960 passed / 273 failed; golden image comparison diagnostics, same failure count observed on the original checkout; no pronunciation-feature failure |
| `node tools/scripts/mobile-check.mjs --with-blueprint` | Blueprint PASS; stops at 21 pre-existing format differences outside this change |
| `node tools/blueprint/validate-schemas.mjs` | PASS, 154 schemas / 105 fixture cases |
| `node tools/blueprint/generate-dart-contracts.mjs --check` | FAIL from checkout CRLF differences. In-memory LF-normalized diagnostic PASS, 154 schemas / 165 classes; generated source files unchanged |
| `node tools/blueprint/validate.mjs`, `node tools/audit/validate.mjs` | PASS; 39 requirements, 62 tables, 88 operations; audit links/Mermaid valid |
| Native XML parsing / `git diff --check` | PASS |

Host SDK is Flutter 3.47.2/Dart 3.13.2; repository pins 3.47.0/3.13.0. The exact
cause of every golden difference is not established by this run. No unrelated
goldens or formatting baselines were rewritten. Raw logs and generated golden
diffs are retained under `.git/testagent/` as non-stageable local evidence.
An earlier full run while feature files were changing is discarded; the counts
above come from the final source state (`mobile-final-tests.jsonl`).

Repository-wide gates retain these baseline failures; no full P8 or release
sign-off follows from focused tests. Android build result is recorded separately
when Gradle finishes.

## Device and provider acceptance still required

This Windows session has no attached Android phone or iOS runtime. The existing
emulator is not evidence of pronunciation quality. Use the configured API build
with a consenting speaker; check actual mic permission denial/approval, pause,
speaker/headset routing, silence/noise, correct/mispronounced/omitted reference
words, service quota failure, and non-retention of captured bytes on navigation.
Only a dedicated valid scorer may expose numbers. No provider/cost/quality
benchmark or iOS compilation is claimed here.
