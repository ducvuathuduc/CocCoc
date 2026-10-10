# I2 implementation worker — resumed Phase A

Task IDs: P2-FE-001 / SC17, UI-FIDELITY-001, UI-CATALOG-008, UI-EXTENDED-QA-010; artifacts support P2-QA-001/UI-QA-014.
Read root/mobile AGENTS, both project skills, canonical docs and PM brief 12-exercises-I2.md before edits. I1 is committed d438218; execute I2 only, then stop for lead review/QA. One child, no descendants. Root owns docs, shared design, router and commits. Preserve existing shared design WIP and protected league/quests/shop/profile. No dependency changes/build artifacts/lock edits.

## Exact allowlist
- apps/mobile/lib/features/learning/presentation/word_bank.dart (new)
- apps/mobile/lib/features/learning/presentation/listening_exercise.dart (new)
- apps/mobile/lib/features/learning/presentation/lesson_screen.dart (wordBank/sentenceOrder/dictation branches, prompt speaker, audio-rate dispatch only)
- apps/mobile/lib/features/learning/application/learning_controller.dart (dictation token-text synchronization, injected audio command/provider only)
- apps/mobile/lib/features/learning/data/learning_repository.dart (explicit authored dictation tokens only; grading unchanged)
- apps/mobile/lib/features/learning/data/lesson_audio_repository.dart (new abstract + honest mock unavailable repository, if required for G-DATA)
- apps/mobile/test/features/learning/exercises_i2_test.dart (new)
- apps/mobile/test/exercises_i2_ui_master_golden_test.dart (new)
- apps/mobile/test/goldens/ui_master/ex_wordbank_*.png
- apps/mobile/test/goldens/ui_master/ex_listen_*.png
- specs/exercises-i2.md (new measured spec; repository path)
No other files. Request necessary expansion; learning_models count gate is separate, do not silently tighten canCheck. Root supplies shared I2 tokens in core/design/lesson_motion.dart and exercise_tiles.dart after sampling.

## References and acceptance
Root fetched all four via live Gummble MCP this continuation: sc_e45fcb804f984bcd902f4c99a09736a7 (assembled translation, NOT idle), sc_11aa3aa234e943b6a6edd4d71f994194 (incorrect), sc_66370c6f1b2e4884bf03e8521db69ef5 (listen idle), sc_923aeb3b27b5495e8c35279b78bc6625 (listen assembled). Fetch details yourself first. Original PNGs in docs/design/references/catalog-cache/. Per-screen palette and coordinates admitted in palette_from_refs.json. Read external specs/exercises-i2-preflight.md and exercises.md sections 2/3. Unknown motion -> official Duolingo web research with URL. PM 250ms easeOutCubic/lift timings are authored targets, not proven from stills. No invented UI or new cropped text/art; bundled original art only.

Acceptance from IMPLEMENTATION_PLAN: “SC01–22 and12exercise typedfake flows; close state/guard/exit/feedback gaps without screen rewrite”. SCREEN_INVENTORY SC17: “12 registered renderers, feedback, retry queue”. COMPONENT_STATES: “repeated tokens distinct IDs”; “require authored count; no remote operation per gesture”; “speed selects authored asset; failure text alternative; no progress on playback”. Preserve current count rule here and record its separate gap.

## Implementation and failing tests first
Execute PM I2 with one shared WordBank for wordBank/sentenceOrder/authored-token dictation, immediate stable-ID VM updates plus independent Overlay decoration. Retain same-size placeholders, 250ms forward/return flight, rapid taps inventory invariant, reduced-motion immediate; cancel overlays on pause/new exercise/dispose. No screen-per-frame rebuilds. Dictation still grades text: sync authored token labels/punctuation in VM. Existing no-token dictation retains TextField and current substitution; no invented keyboard mode. No XP/heart/retry/receipt changes. Screens consume repository->provider->controller state, never fixture constants. Audio rate callback is dispatched through typed abstract+Mock repository/provider; honest unavailable notice remains, no playback claim. Use shared widgets first.
Meaningful RED cases: bank-to-answer+placeholder, return, five rapid distinct taps/repeated text IDs, midflight/reduced-motion/dispose, busy/feedback lock, dictation sync correct/wrong text grading and no-token fallback, slow rate .5 dispatch, failed grading retention, text2 semantics/48dp. Run actual RED before renderer implementation and persist log /workspace/tools/coc-i2-red.log. Do not author tests that only mirror private code.

Environment source . /workspace/tools/env.sh on separate line (it can return1). Flutter commands serialized: worker has runner until returning results, root does not run Flutter concurrently. Use --no-pub and env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u all_proxy NO_PROXY=127.0.0.1,localhost no_proxy=127.0.0.1,localhost.
Analyze --fatal-infos plus targeted behavior/goldens. PM390x844 idle/assembled/midflight/listen states plus 360x800/430x932 x text1/text2 assembled BOTH kinds; all in ui_master. Open every capture and list source deltas, never infer exact motion/text2 parity. No golden changes outside allowlist. Root independently repeats analyze/tests/palette, rotates child to QA, commits verified slice under latest targeted-commit authorization. Full/native/global palette gates remain open and cannot be labelled passed.

Return RED/GREEN counts/commands, scoped diff, every golden path, source deltas, test additions count and limitations. No worker commits/log/claim edits. Send progress every minute, persist small stages promptly for interruption recovery.

## Mandatory owner quality rules — verbatim

# QUALITY GATES — Phase A (owner order 2026-10-10: "fast AND correct, break NOTHING")

These gates are law for the lead and every worker. Speed comes from parallel workers, never from skipping a gate.

## 0. Never break what works
- Before any change, record baseline: `flutter analyze` result + full `flutter test` pass count (write it in TEAM_STATE.md "Baseline").
- No commit may lower the pass count, add an analyzer warning/error, or delete/skip/weaken an existing test or golden to make it pass.
- Never delete a screen, route, widget, provider or feature that exists. Refactors only when a test proves behaviour is kept.
- Never touch services/, appwrite/, packages/api_contracts/, CI secrets, pubspec dependency versions (adding a dep needs a written reason in TEAM_STATE.md and must be pure-Dart/Flutter, no native setup).
- Router/main.dart and shared design tokens: lead only. Workers stay inside their EXCLUSIVE_CHANGE_AREA; a worker needing a file outside it asks the lead.
- No `git push`, `reset --hard`, `rebase`, force, `clean -fd`, branch deletion. Commit locally only.

## 1. Per slice loop (each worker)
1. Read the Gummble reference(s) via gummble MCP; write the exact spec (sizes, colors as tokens, spacing, radius, shadow/3D offset, copy, states, motion timings/curves) in specs/<slice>.md. Unknown = mark UNKNOWN + web research Duolingo with URL; never invent.
2. Write failing widget test(s) first: layout/state/interaction (tap, disabled, correct, wrong, retry, empty, loading, error, reduced-motion).
3. Implement with existing design tokens/components; no hard-coded hex/magic numbers if a token exists.
4. Motion: use the documented durations/curves; every animation respects reduced motion (MediaQuery.disableAnimations) and has a test that pumps through it without exceptions; no jank: no rebuilding whole screens per frame, dispose controllers.
5. Goldens 360 and 430 width × text scale 1.0 and 2.0 (light theme) in test/goldens/ui_master/. Check text overflow, clipping, RTL-safe paddings, tap targets ≥ 48dp, semantics labels.
6. `flutter analyze` (0 issues) + targeted tests + goldens green.

## 2. Lead review gate (before every commit)
- Read the full diff. Reject: invented UI, TODO stubs on user paths, dead buttons, print/debug code, unrelated edits, copied Duolingo binary assets.
- Run FULL `flutter test` (not only targeted). Pass count ≥ baseline + new tests.
- QA agent compares each new golden with its Gummble screenshot side by side and lists deltas in docs/design/qa/UI_MASTER_LOG.md; any visible delta in layout/color/spacing/copy = fix before commit.
- Commit message: `UI: <slice> — <task id> — Gummble <id>`; update docs/agent/task-status.json + plan docs per TASK_PROTOCOL; update TEAM_STATE.md.

## 3. End-to-end flow gate (A→Z, mock data)
Integration/widget flow tests that run the real router with mock repositories:
onboarding → placement/path → lesson (every exercise type, correct + wrong + hearts loss) → completion/celebration → back to path with progress → Practice, Stories, League, Quests, Profile/Friends, Shop/Super → settings. Every button on these screens must navigate or act; no crash, no red screen, no overflow warnings in logs.

## 4. Done definition
All scope task IDs closed by their repo acceptance text; analyze 0 issues; full suite green; goldens committed; flow tests green; UI_MASTER_LOG lists remaining known deltas (must be empty or explicitly accepted by the owner). Never write "pixel-perfect"/"production-ready" without this evidence.

## 5. If stuck
Same failure twice → stop that slice, write the exact error + what was tried in TEAM_STATE.md "Blocked", move to the next slice. Never "fix" by deleting tests.

## G-COLOR (bắt buộc từ 10/10 11:25, anh yêu cầu đúng màu 1:1)
- Nguồn màu DUY NHẤT: docs/design/qa/palette_from_refs.json (màu lấy mẫu pixel từ ảnh Gummble trong docs/design/references). Cấm tự bịa hex.
- Trước khi commit: `python3 tool/palette_check.py` — mọi màu mới/sửa trong diff phải có trong ref (sai số ≤6/kênh). Màu cũ chưa khớp: thay bằng màu ref gần nhất của chính màn đó (per_screen), dùng color picker (PIL getpixel) trên đúng vùng ref, ghi tọa độ pixel đã lấy vào commit message.
- Khi đổi token dùng chung: chỉ đổi nếu getpixel trên ref chứng minh; cập nhật golden cũ CHỈ khi golden mới gần ref hơn (đo bằng mean ΔRGB vùng tương ứng), ghi số đo vào docs/design/qa/UI_MASTER_LOG.md.

## G-DATA (user rule 2026-10-10 16:41)
- Screens never read fixtures/constants directly. Each feature: domain models -> `data/<feature>_repository.dart` (abstract) + `Mock<Feature>Repository` -> Riverpod provider -> UI. API swap = override the repository provider only.
- Reuse shared widgets (core/design, shared components) before writing new ones; no copy-pasted widget trees.
- Text/numbers shown on screen come from data, not baked into cropped art (crop only graphics).
- Goldens must stay unchanged when refactoring to repositories (proves zero visual change).
