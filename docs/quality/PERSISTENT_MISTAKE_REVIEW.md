# Persistent mistake review

Local feature branch: `feat/persistent-mistake-review`, 2026-10-21.
Requirements: [FR-PRACTICE-001/002, FR-SYNC-001 and reward rules](../product/SRS.md).

## User flow

1. Finish a lesson with an incorrect original answer. Correcting it during the same lesson's retries does not erase the original mistake.
2. Open Practice → Mistakes. Loading, empty, failed and cached-offline states are distinct. REFRESH fetches the latest history.
3. REVIEW MISTAKES opens up to 20 questions. Only a correct, unassisted first answer in a completed review resolves a saved mistake. Wrong or hinted attempts leave it available for another review.
4. API mode uses the existing private `REVIEW` bundle, which prioritizes unresolved mistakes and includes due vocabulary/padding. With an empty mistakes list, OPEN OR RESUME REVIEW still recovers a saved server session or opens a due-word review.
5. The history refreshes after completion and on return from the review route. Another account cannot see the previous account's data or active lesson state.

## Persistence and authority

- Demo: completed-lesson first-attempt evidence and authored exercises are stored in a versioned SharedPreferencesAsync snapshot per account/course/mode. The 100 most recent mistakes are retained; commands serialize and completion identities deduplicate retries. Correct regular lessons do not resolve old mistakes. Demo reviews award zero XP and do not unlock path nodes.
- API: Learning already owns `l_mistakes`, capture/resolution and bounded rewards. The screen now reads `/v1/mistakes` independently of the words catalogue. It caches only the last successful response; cached data is explicitly marked offline. Authentication/configuration failures are not presented as a successful empty list. API results are never resolved optimistically by the client.
- Review starts persist their request identity before POST. Submitted answers retain their original expected revision, body and idempotency key. Reopening restores original/retry queue position from journal/server history. Lost completion responses retry the same identity. Other active lesson journals are protected from replacement.
- Private review snapshots never enter the ordinary offline-completion endpoint. Losing the network retains answers and the active journal; reconnect to submit/finish. Demo history remains available offline, but an interrupted demo review restarts from its retained mistakes.
- Unsupported hosts without a preferences plugin use temporary memory and show that limitation. Actual disk errors surface. Corrupt demo storage is not overwritten silently. Physical-device persistence is not inferred from repository restart tests.
- No backend route, OpenAPI schema, cloud configuration, migration or paid provider was changed. Existing server replay/review reward caps remain authoritative. This branch does not integrate the other payment/pronunciation/vocabulary branches.

## Requirement coverage

| Requirement | Exact tests |
|---|---|
| Persistent demo history / duplicate completion | `demo history survives a new repository; duplicate completion counts once` |
| First-attempt semantics across retries | `completed lesson saves original mistake even after a correct retry; review resolves with zero XP` |
| Hint forwarding and resolution | `hint evidence is sent to the server and journal`; `hint evidence reaches authoritative grading and cannot resolve demo history`; `only unassisted first correct review resolves; lesson and hint do not` |
| API history, offline cache, resolved rows | `API reads only mistakes, restores offline cache and removes resolved server rows` |
| Offline without cache / expired auth | `API offline without cache and expired auth are errors, not empty history` |
| Cap, concurrent writes and corruption | `history caps at 100 and concurrent writes preserve both sessions`; `failed storage never reports saved; corrupt history is not overwritten` |
| Authored exercise snapshot | `exercise codec preserves every authored exercise type and media fields` |
| Account isolation | `account switch hides history and discards the previous lesson state` |
| Correct REVIEW request | `mistake review requests private REVIEW bundle instead of a path lesson` |
| Lost start/answer/completion | `lost start survives restart with identical request and key`; `lost review answer replays same body and key on retry`; `lost completion survives restart and replays the exact completion identity` |
| Restart navigation / bounded retry queues | `restart restores the next unanswered original instead of resubmitting the first`; `partial originals restore first-attempt counters and pending mistakes`; `partial retry and exhausted second retry restore bounded queues` |
| Offline private-review safety | `offline review completion keeps journal and never queues a public offline lesson` |
| No local path advance / fabricated XP | `review completion cannot advance local path or grant invented XP` |
| Empty review pool recovery | `empty review pool does not leave a pending intent that blocks lessons` |
| Widget states and text scale 2 | `persisted questions open a capped demo review at text scale two`; `loading is distinct from empty and storage errors offer retry`; `empty history offers learning and offline data stays clearly marked` |

## Validation

From `apps/mobile`:

```sh
flutter test --no-pub test/mistake_review_api_test.dart test/mistake_review_resume_test.dart test/mistake_history_test.dart test/mistake_review_controller_test.dart test/mistake_history_ui_test.dart test/features/learning/api_learning_repository_test.dart test/practice_flow_test.dart --dart-define=ENABLE_MASCOT_MOTION=false
flutter analyze --no-pub
flutter test --no-pub --dart-define=ENABLE_MASCOT_MOTION=false --reporter json
flutter build web --release --no-pub --dart-define=USE_MOCK_AUTH=true --dart-define=RIVE_NATIVE_WASM_HOST=rive/
```

Focused suite: **41 PASS**. From root, existing authoritative backend suites:

```sh
node --test services/learning/test/review.test.mjs services/learning/test/practice.test.mjs services/progress/test/rewards.test.mjs
```

Backend: **18 PASS**, covering capture/resolution, private review, inbox/ledger deduplication and reward caps. Remaining gate results are recorded below at handoff. Raw logs and golden diffs are kept under local Git metadata (`testagent/mistakes`). No physical device, real cloud account, Android/iOS build or deployment is claimed.

Final gate results:

- `flutter analyze --no-pub`: **PASS**, no issues, 102.6s.
- Full Flutter suite: **958 PASS / 273 golden failures**, 215.9s. All error events correspond to golden comparison output; no non-golden functional error was found in the JSON report. This is not an all-green release gate. No golden baseline was rewritten.
- Release web build: **PASS**, 213.1s (including Wasm dry-run compilation). Runtime Wasm, device and cloud behavior are not inferred from compilation.
- `pnpm blueprint:check`: **PASS**, 39 requirements / 48 tasks / 88 operations.
- `pnpm audit:check`: syntax/link checks pass (960 local links); the generated endpoint-matrix check fails as stale. This branch changes neither OpenAPI nor the endpoint matrix.
- `git diff --check`: **PASS**.

No push is authorized for this branch.
