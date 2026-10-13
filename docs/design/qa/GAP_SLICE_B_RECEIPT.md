# Slice B validation — 2026-10-12

Scope: [audit rows 8 and 9](../GAP_AUDIT.md), archived Gummble `sc_12b09a6c`,
`sc_269d6ffb`, `sc_b4ac42c6`; Friends Chest flow `f6869640`.
Measured reference mapping: [slice specification](../specs/gap_slice_b.md).

Implemented in the current worktree:

- Connectivity repository with stream/current value, settable online-by-default
  mock, observed API transport implementation, hand-written Riverpod providers.
- Conditional offline banner, grey inactive path/mascot/stars and streak.
  The current node and unit header retain their existing colors.
- Boost model, mock/API repositories and controller; API duration comes from
  server receipt timestamps and failed activation retries keep the same key.
- `/xp-boost/activated`, repository-supplied multiplier/minutes/copy, reward
  entrance and lifecycle-aware bubbles, pinned Continue and large-text scrolling.
- Friends Chest keeps the existing gems sheet, then (`98d08ad`) activates the
  boost and opens `/xp-boost/activated`; a failed activation shows the
  repository's safe error (the gems claim itself is already credited once).

The only existing expectation changed is the owner-approved (2026-10-13)
Friends Chest flow in `settings_shop_taps_test.dart`; no dependency declaration
or lock changed. Other worktree hearts/energy edits were left untouched. No cloud or
device verification is claimed, and this screen does not grant XP.

## Added files

All mobile paths below are relative to `apps/mobile/`:

| Area | Added files |
|---|---|
| Connectivity | `lib/features/connectivity/domain/connectivity_copy.dart`, `data/connectivity_repository.dart`, `data/api_connectivity_repository.dart`, `application/connectivity_provider.dart`, `presentation/offline_banner.dart` |
| XP Boost | `lib/features/xp_boost/domain/boost.dart`, `data/boost_repository.dart`, `data/api_boost_repository.dart`, `application/boost_controller.dart`, `presentation/xp_boost_activated_screen.dart` |
| Tests | `test/features/gap/offline_path_test.dart`, `offline_golden_test.dart`, `xp_boost_test.dart`, `xp_boost_golden_test.dart` |
| New goldens | `test/goldens/gap/xp_boost_activated_360.png`, `test/goldens/gap/offline_path_360.png` |
| Documentation | `docs/design/specs/gap_slice_b.md`, this receipt (repository-root paths) |

The new 360×780, text-scale-1 golden was opened and compared to both XP boost
captures. Layout/copy/button placement were adjusted after inspection. Visible
art difference: the reused shop flask has a cork; the activation reference has
an open flask. Background bubbles and timing are authored approximations of
archived stills. The gradient's lower color uses a palette-backed sample at
`(10,2200)` rather than the unsampled darker bottom pixel.

## Commands and evidence

Every shell sources `/workspace/tools/env.sh`. Mobile commands run in
`apps/mobile`; root commands run at the repository root.

```sh
flutter pub get --offline
# From root, immediately after dependency restoration:
git checkout -- apps/mobile/pubspec.lock

flutter analyze --no-pub
flutter test --no-pub --dart-define=ENABLE_MASCOT_MOTION=false test/features/gap/offline_path_test.dart
flutter test --no-pub --dart-define=ENABLE_MASCOT_MOTION=false test/features/gap/xp_boost_test.dart
flutter test --no-pub --dart-define=ENABLE_MASCOT_MOTION=false test/features/gap/xp_boost_golden_test.dart
flutter test --no-pub --dart-define=ENABLE_MASCOT_MOTION=false test/path_ui_master_golden_test.dart
flutter test --no-pub --dart-define=ENABLE_MASCOT_MOTION=false test/app_shell_sprint_test.dart
flutter test --no-pub --dart-define=ENABLE_MASCOT_MOTION=false test/settings_shop_taps_test.dart --plain-name 'Friends Chest and Genshin CLAIM credit the wallet once (reduced motion: true)'
flutter test --no-pub --dart-define=ENABLE_MASCOT_MOTION=false test/features/shop/shop_screen_test.dart

python3 tools/palette_check.py
pnpm install --frozen-lockfile
pnpm blueprint:check
pnpm audit:check
git diff --check
```

The failing acceptance tests were written first: both new behavior files failed
to compile before their repositories/screens existed. New-golden generation
used `--update-goldens` only with `xp_boost_golden_test.dart`.

- Analyzer: **No issues found** on the final implementation.
- Offline tests: **4 passed**, covering online/offline toggling, transition
  duration/reduced motion, current-node taps, text scale 2, transport failure,
  HTTP recovery and non-network errors.
- Boost tests: **6 passed**, covering alternate repository values, reduced
  motion, text scale 2, Continue, the real Friends Chest/router chain,
  server-authoritative receipt mapping and stable retry idempotency.
- New XP golden: generation passed and the PNG was visually reviewed.
- Palette: **85 unmatched legacy colors**, unchanged from the pre-edit baseline;
  lesson artwork **0 unmatched colors**. The checker exits 1 for that legacy
  baseline; no newly introduced literal is unmatched.
- Blueprint: passed. Diff whitespace check: passed.

## Status (2026-10-13)

Pushed to `main` by fast-forward (no force):

| Commit | What |
|---|---|
| `50af76c` | row 8: connectivity repository, offline banner, greyed path/streak |
| `3497411` | row 9: XP Boost model/repositories/controller, `/xp-boost/activated` |
| `98d08ad` | row 9 trigger: Friends Chest gems sheet -> XP Boost activated; owner-approved `settings_shop_taps_test` flow change |
| `462c136` | visual QA: offline streak icon used `BlendMode.srcIn`, which flooded the art crop into a grey square; now uses the path's grey wash. Adds `offline_path_360` golden |

Validation after rebasing on `3261ed5`: analyzer **No issues found**; targeted
suite **93 passed, 2 failed** (known `main` baseline: `core_path` 3.21%,
`core_lesson_intro` 0.95%, `shop_360_scale1`; reproduced on clean `origin/main`).
The earlier shell 360 golden failures were an image-decode timing flake under
parallel load: `app_shell_sprint_test` passes 11/11 alone on this tree.

Visible differences that remain against the refs (side-by-side PNGs in
`work/qa/gap/`): the activated flask has a cork (ref: open flask); the current
path node keeps full color and the START bubble while offline (ref: current node
also lightened, no bubble); the stats bar shows Energy where the ref shows Hearts
(app uses the Energy model); bottom navigation and OS chrome are outside the
golden harness.
