# Main integration and CI repair plan — 2026-10-25

**Goal:** integrate every outstanding remote commit into `main` and verify the resulting candidate on GitHub, preserving reference-backed UI and real-feature boundaries.

**Architecture:** retain the three owner services and the approved [runtime ADR](../architecture/adr/0018-container-event-cache-runtime.md). AMQP/cache remain opt-in; no deployment, schema apply or paid provider activation.

**Spec:** [approved feature plan](REAL_FEATURES_SETUP_PLAN_20261025.md), [design](../design/DESIGN.md), [release gates](../quality/RELEASE_GATE.md).

## Constraints and review focus

- Preserve actual test assertions; do not skip failures, add blanket pixel tolerance or regenerate unreviewed screenshots.
- Distinguish platform/font rasterization from changed geometry, fixture state and asynchronous native asset loading.
- Keep broker confirmation distinct from durable application acceptance; malformed/foreign deliveries must fail closed.
- One Flutter process at a time; backend repair owns shared transport interfaces and the pnpm lock exclusively.
- Only report a workflow green from its completed run on the final candidate SHA.

## Tasks

- [x] Fetch all refs; fast-forward the clean checkout to `76221b5`, including the merged Phase 1 inventory.
- [x] Integrate `fix/mobile-ci-baseline`, `fix/mobile-pixel-perfect-screens` and `wip/phase5-amqp-adapter` on `codex/ci-green-integration`; the WIP includes `feat/phase5-amqp-redis`.
- [x] Reproduce backend failures; repair AMQP dependency/type/test defects in `services/shared` and validate `pnpm backend:verify`, smokes and runtime checks.
- [x] Reproduce merged Flutter failures; inspect failing screenshot artifacts against existing source references. Repair fonts/fixtures/layout/lifecycle at their cause and add targeted regressions where behavior changes.
- [x] Record per-file baseline hashes/reasons in [golden provenance](../quality/ci-green-20261025/golden-provenance.json); retain strict comparisons. This evidence does not assert whole-app Duolingo pixel parity.
- [x] Run contracts, API lint, schema dry-run/tests, seeds, content, blueprint/audit, secret scan, Flutter analyzer/full tests and Android build.
- [x] Push the integration candidate and merge all remote branch commits into `main` with a normal fast-forward push.
- [ ] Verify all final-main workflows and repair remaining Android native failures; record actual remaining release limitations.

Starting CI failures: mobile has historical screenshot mismatches; the unfinished AMQP branch fails TypeScript on an undeclared `amqplib` import and an explicitly undefined optional `messageId`. These are diagnoses to verify, not declarations of completion.

## Executed checkpoints

- Backend on Node 22.23.3: 228 tests, 216 passed, 12 gated skips, zero failures; build, TypeScript, ESLint and Prettier pass. Backend/dev/native runtime smokes pass.
- Local Flutter format: 609 files unchanged; analyzer clean; 67 scoped functional tests pass, including native Rive loading with the configured Windows release DLL path.
- Contracts/API lint, schema dry-run/tests, seeds, blueprint/audit and media checks pass. No schema apply or cloud publish occurred.
- Candidate `9c3364f`: GitHub Backend, Container runtime and secret scan pass. Mobile: 1,522 passed, one remaining Shop snapshot failure.
- The Shop failure was reviewed against `docs/design/references/shop/05.png`: three prices moved to the trailing edge through the merged layout correction. A new geometry assertion protects the disabled full-inventory price; its updated strict snapshot is recorded separately in the provenance ledger.
- Candidate `4632eae`: [Mobile CI](https://github.com/ducvuathuduc/CocCoc/actions/runs/40170628303) passes all 1,523 tests, analyzer, format and Android APK build/upload. Backend and secret scan pass; the Container runtime passed on the identical runtime source at `9c3364f`.
- Android E2E run `40170085752` built both APKs and entered the emulator suite; its final result and final-main workflows remain pending at this checkpoint. iOS/manual deployment/cloud/provider acceptance are not inferred.
- Linux is the pinned screenshot platform. Windows full-suite screenshots differ; the direct Windows diagnostic also omitted the required Rive DLL path. Neither that diagnostic nor emulator tests establish physical-device/cloud acceptance.

## Native E2E follow-up

Main `08307ab` passed Mobile, Backend, Container runtime and secret scan. The redundant old manual Android run was cancelled to expose diagnostics while the full main run continued. Before cancellation, permission grant/denial and lesson-cancellation cases each exhausted their six-minute limit; three notification/deep-link cases passed.

The native helper repeatedly waited up to six seconds for `pumpAndSettle`, although audio/idle animation continuously schedules frames. Repeated lesson interactions consumed the whole case budget. `patrol_test/support/advance_frame.dart` now advances one bounded frame interval; finder polling, all seven native cases, their six-minute limits and every OS assertion remain intact. A looping-ticker regression reproduces 6,600 ms with the old helper and requires responsive progress while animation remains active. The fixed helper plus reminder regressions pass 20 tests; analyzer is clean. The resulting full native CI run is still required.

Main `96955ab` passed Mobile (1,524 tests, analyzer, format and APK), Backend, Container runtime and secret scan. Android run `40172663189` completed all seven behavioral paths, including permission grant/denial, real notification taps, cancellation after its scheduled fire time and launcher widget data. Four cases nevertheless failed the framework's teardown invariant: two `audioplayers` frame position updaters remained scheduled after widget disposal. This is a failing native run, not full CI acceptance.

The audio output now disables position polling on its voice/effect players because no lesson UI consumes it. Android low-latency effects do not emit playback-completion events; the default frame updater otherwise continues indefinitely. A regression drives the real Dart plugin through mock native channels without completion events, verifies all three channels still resume, requires zero transient frame callbacks/position queries, and waits for all three native disposals. Removing the fix reproduces three callbacks instead of zero. All seven Patrol assertions remain required on the new commit; cloud/provider, iOS and physical-device acceptance remain separate.

Local validation of this follow-up: `flutter test --no-pub --dart-define=ENABLE_MASCOT_MOTION=false test/features/learning/lesson_audio_test.dart test/patrol_frame_pump_test.dart test/features/reminders/reminder_coordinator_test.dart` passes all 25 tests; `pnpm blueprint:check`, `pnpm audit:check` and `git diff --check` pass. The motion switch is the repository's normal local widget-test configuration; the native Patrol workflow still runs real audio, permission dialogs, notifications and the launcher widget.
