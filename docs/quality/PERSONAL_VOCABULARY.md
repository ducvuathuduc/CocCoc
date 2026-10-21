# Personal vocabulary notebook

Local implementation on `feat/personal-vocabulary-srs`, 2026-10-21.
Requirement owner: [FR-PRACTICE-002 and review heuristic](../product/SRS.md).

## Try it

1. Practice → Words → MY VOCABULARY. Add a word/phrase, Vietnamese meaning and optional example.
2. Alternatively bookmark a Words row, or answer a lesson and choose SAVE TO MY VOCABULARY on the feedback panel. Check/edit prefilled fields before saving; missing translations must be supplied by the learner.
3. REVIEW DUE WORDS asks for the saved meaning. Whitespace/case are ignored; Vietnamese accents matter. HINT reveals the first character and marks the answer assisted. Feedback shows the full meaning/example after submission.
4. Correct unassisted answers advance the canonical schedule; wrong/assisted answers reset it. NEXT cannot schedule a second time. Sessions contain at most 20 due cards, oldest due first, then stable word identity.
5. Refresh to recalculate due counts after a UTC day boundary. Remove words with their delete buttons.

## Scope

Strict SharedPreferencesAsync storage uses one versioned JSON snapshot per account, course and demo/API mode. Guest identity differs from an account named guest. Writes serialize per scope, errors surface and corrupt storage is not silently replaced. Duplicate normalized terms preserve the original entry/schedule. Limit: 1000 cards. Commands report success after the storage write completes.

The notebook is device-local in both demo and API mode. It does not alter server review queues or wallet/XP. **Zero XP** is awarded, so replaying, deleting/re-adding cards or changing the device clock cannot farm rewards. No backend contract/schema/deployment changed. API course resolution follows the existing ActiveCourse abstraction. No cloud synchronization or notification scheduler is claimed. Clearing application data removes the notebook. Account-switch tests prove app-level isolation, not device encryption.

## Requirement coverage

| Requirement | Exact test evidence |
|---|---|
| Lesson entry and saved phrase | `lesson exposes save after feedback and prefills authored phrase` |
| Empty/add/validation/remove, text scale 2 | `empty notebook, validate add, persist and remove at text scale 2` |
| Restart and duplicate save | `save deduplicates normalized terms and survives restart` |
| Interval progression/cap/reset | `correct advances through capped intervals; wrong and hint reset` |
| Correct and incorrect typed answers | `review correct advances without a hint`; `review wrong resets without a hint` |
| Assisted answer and example | `hinted correct review resets stage, saves once and shows example` |
| Due boundary, accents, validation | `due boundary and meaning match preserve accents` |
| Duplicate/early review | `early and duplicate review cannot advance schedule` |
| Concurrent writes/storage errors | `concurrent saves are serialized without losing cards`; `write failures surface and corrupt data is never overwritten` |
| Identity scope/account transitions | `scope keys isolate accounts, guest, mode and course without collisions`; `account switch hides old cards and returning restores only owned cards` |
| Lifecycle | `disposing while a durable write completes causes no late state mutation` |
| Load failure | `load error offers retry without exposing empty success state` |

## Checks

From `apps/mobile`:

```sh
flutter test --no-pub test/vocabulary_test.dart test/vocabulary_ui_test.dart test/vocabulary_account_test.dart test/practice_flow_test.dart --dart-define=ENABLE_MASCOT_MOTION=false
flutter analyze --no-pub
flutter build web --release --no-pub --dart-define=USE_MOCK_AUTH=true --dart-define=RIVE_NATIVE_WASM_HOST=rive/
```

- Focused tests: **20 pass**, including five existing practice regression tests.
- Analyzer: **PASS, no issues**, final rerun in 20.3s.
- Release web build: **PASS**, 169.7s, with mock authentication. This is compilation evidence, not a physical-device or cloud receipt.
- Extra lesson screenshot regression: **6 pass / 11 golden mismatches**. Golden baselines were not updated. Feedback visuals intentionally changed; this run does not prove every mismatch predates this feature. Diffs retained locally in Git metadata under `testagent/vocabulary/golden-diffs`.
- Full repository suite, physical-device restart, Android/iOS builds and real Appwrite flows were not run for this slice.

No push or merge is authorized for this branch.
