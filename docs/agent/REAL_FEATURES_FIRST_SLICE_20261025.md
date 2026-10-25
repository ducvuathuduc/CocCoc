# Real feature composition guard — first implementation slice

> For agentic workers: execute task by task using native thin slices and meaningful red/green tests. Use at most one isolated native fork when context genuinely needs splitting. Do not launch concurrent Flutter commands in this checkout.

**Status:** approved for implementation on 2026-10-25; checkboxes below track only verified local work; remaining acceptance stays open. The human chose to retain Appwrite Auth after evaluating Descope. Reuse existing OTP/recovery/session adapters; verify actual email delivery, callback configuration and Android acceptance instead of migrating providers.

**Goal:** freeze the approved UI and prevent a real API build from silently using simulated identity, balances or successful business mutations.

**Architecture:** retain current repository ports, manual Riverpod ViewModels and three owner services. This slice precedes installation of the approved RabbitMQ/Redis/container runtime. It makes the existing API composition auditable and failure-safe first.

**Tech stack:** existing pinned Flutter/Dart/Riverpod and TypeScript/Node 22. No new dependency or lockfile change is required for this slice.

**Spec:** [master execution map](REAL_FEATURES_SETUP_PLAN_20261025.md), [SRS](../product/SRS.md), [DESIGN](../design/DESIGN.md), [OpenAPI](../api/openapi.yaml), [latest UI receipt](../design/qa/ANDROID_NONPAYMENT_COMPLETION_20261024.md).

## Global constraints

- Retain approved routes, source artwork, light/dark tokens, animations, reduced motion and account-scoped state.
- Keep preview/default behavior reproducible; introduce an explicit real-build validation rather than breaking the browser preview.
- Real API mode never catches a failure and substitutes successful fixture business data.
- Do not deploy, apply schema, publish, change payment mode or auto-enable paid AI.
- Do not update unrelated dirty files, golden baselines, locks or global phase gates.

## Review focus

1. Account A's pending response/cache must not populate account B's shell. Own in Task 3.
2. Cold API startup without a snapshot must show the existing loading/unavailable state, not a fixture wallet. Own in Task 3.
3. Partial/invalid config or contradictory mock identity must fail closed before private requests. Own in Task 2.
4. Network/authorization errors must not trigger mock callbacks, top-ups or false deletion success. Own in Task 3.
5. Static UI copy/assets may be shared, but fixture business behavior must not remain transitively reachable. Own in Tasks 1/3/4.

## Task 1 — freeze candidate and enumerate runtime actions

**Files:** create `docs/quality/real-features-20261025/ui-baseline.json`, `runtime-register.json`, `environment-receipt.json`; inspect existing `docs/design/qa/FLOW_COVERAGE.json`, `FLOW_CHECKLIST.md`, source receipts and generated endpoint matrix. Update only this plan's evidence links after files exist.

**Consumes:** current dirty worktree, existing approved reference/QA ledgers and 91 OpenAPI operations. **Produces:** a reproducible UI candidate and an action-level real-runtime acceptance register.

- [x] Record HEAD, branch, dirty tracked diff digest and all scoped untracked source/art/test paths with SHA-256; exclude credentials/caches/build artifacts. Do not stage or discard unrelated work.
- [x] Preserve the current preview APK/web hashes and source asset hashes from the existing QA receipt; verify actual files before recording them. Record device viewport/fonts/motion flags used for future comparisons.
- [ ] Enumerate every reachable route/action/provider against OpenAPI and OS capabilities; use `rg` for exact provider references and targeted reads for branches. Include profile variants, legal links, OTP, icon changes, reports and premium entry points.
- [ ] Use this JSON shape for each action; add concrete real entries rather than a single generic row:

```json
{
  "actionId": "quests.claim",
  "route": "/quests",
  "owner": "progress",
  "operationIds": ["claimQuest"],
  "currentSource": "api-or-preview-by-AppConfig",
  "implementationEvidence": ["apps/mobile/lib/features/quests/data/api_quests_repository.dart"],
  "uiEvidence": ["docs/design/qa/ANDROID_NONPAYMENT_COMPLETION_20261024.md"],
  "acceptance": ["server receipt", "duplicate claim", "account switch", "unchanged reference state"],
  "runtimeStatus": "UNVERIFIED",
  "liveEvidence": []
}
```

- [x] Validate actual operation IDs against OpenAPI rather than trusting examples. Record each entry as VERIFIED_LOCAL, UNVERIFIED, MISSING_IMPLEMENTATION, NEEDS_CONTRACT, EXCLUDED or VERIFIED_LIVE; never infer live status from an API class or mock screenshot.
- [x] Record environment read-only facts: Docker/WSL2 availability, public config, service build IDs, schema/contract/content identities and missing prerequisites. Secret values never enter the receipt. Cloud writes remain a separate execution gate.

**Verification:** parse all three JSON files; validate unique action IDs, referenced files/routes/operations and complete flow/action mapping; run `pnpm blueprint:check` and `pnpm audit:check`. These checks validate documentation, not hosted functionality.

## Task 2 — validate the real build configuration

**Files:** modify `apps/mobile/lib/core/config/app_config.dart`; create `apps/mobile/lib/core/config/real_profile_validation.dart`, `apps/mobile/test/core/config/real_profile_validation_test.dart`; inspect existing `config/real.public.json`, `core/api/client/api_providers.dart` and bootstrap composition. Add a bootstrap call in the smallest existing initialization boundary; the root router remains an exclusive area if it must change.

**Consumes:** `AppConfig` and `ApiService`. **Produces proposed interface:**

```dart
enum RealProfileTarget { localNative, releaseNative }

List<String> validateRealProfile(
  AppConfig config, {
  required RealProfileTarget target,
});
```

The validator returns stable issue codes, no secrets. Caller refuses to admit the real session when issues are present. Preview configuration is not passed through this real-profile gate. Appwrite endpoint/project and all three service URLs must be present. Release endpoints use HTTPS. Local native permits only explicitly selected test/local endpoints with documented emulator/physical-device mapping; it never treats localhost as the physical host by assumption. URL user-info and fragments are rejected. API mode plus `useMockAuth=true` is invalid. Invalid `DATA_SOURCE` values must not silently become mock for an explicitly real build.

- [x] Write the failing test before adding the validator, then run it to prove red:

```dart
test('real profile rejects mixed API data and mock identity', () {
  final issues = validateRealProfile(
    const AppConfig(dataSource: DataSource.api, mockAuthOverride: true),
    target: RealProfileTarget.releaseNative,
  );
  expect(issues, contains('MOCK_AUTH_FOR_REAL_PROFILE'));
});
```

- [x] Add table-driven cases for all three missing URLs, HTTP release endpoints, URL credentials/fragments, blank Appwrite project, invalid source value, valid HTTPS configuration and explicit local-native mapping. Test existing preview remains loadable without a real profile.
- [x] Implement minimal parsing/validation and connect it before private session preparation. Do not add configuration details to product copy; use an existing unavailable/error component for invalid builds and a redacted developer diagnostic.
- [x] From `apps/mobile`, run `flutter test --no-pub test/core/config/real_profile_validation_test.dart test/bootstrap_test.dart`; run analyzer on changed areas and existing config/client tests. Preserve locked dependencies.

## Task 3 — remove real-shell fixture fallbacks and mutation callbacks

**Files:** inspect/modify `features/shell/data/api_app_shell_repository.dart`, `features/shell/application/app_shell_providers.dart`, `features/progress/data/progress_snapshot.dart`, `features/account/data/account_repository.dart`, `api_account_repositories.dart`, settings repository composition and the equivalent gift/call branches only as the runtime register proves necessary. Create `test/real_runtime_composition_test.dart`; extend `test/features/api_snapshot_repositories_test.dart` and the existing real learning/auth tests.

**Consumes:** authenticated account identity, `ProgressSnapshotSource`, owner API responses and existing snapshot states. **Produces:** real providers that use same-account authoritative/cached data and immutable content, never preview mutations. A preview adapter stays available only through the demo branch.

- [x] Write red acceptance cases against current code: cold API rewards unavailable does not expose a fixture gem value; delayed A snapshot after switching to B cannot appear; failed delete does not show a completed request; failed reward claim does not change wallet; invalid/expired token does not run a mock callback.
- [x] Use the current test fake transport and provider overrides to complete request B before A. Assert B's account and server gems remain displayed after A resolves; assert the existing error/pending component remains visible on 401/503. Assert retry uses the same command identity and does not top up gems.
- [x] Extract immutable account/settings/plan presentation content from mock command repositories where reused. Keep exact copy/layout. Remove preview callbacks from API mutation success/failure paths; drive account/deletion state from the authenticated controller and actual returned receipt.
- [x] Represent missing real snapshot through existing loading/error/cache state. If existing repository interfaces cannot express unavailable data, add the smallest immutable state variant and update only its ViewModel binding; no invented balance or new screen.
- [x] Reuse `RealLearningSessionRepository` and existing auth expiry handling; avoid duplicate bootstrap or duplicate create-profile/enrollment keys.
- [x] Run from `apps/mobile`: `flutter test --no-pub test/real_runtime_composition_test.dart test/features/api_snapshot_repositories_test.dart test/real_learning_flow_test.dart test/features/auth/auth_session_test.dart --dart-define=ENABLE_MASCOT_MOTION=false`. Then run exact UI tests for any changed presentation binding and analyzer.

**Boundary:** do not attempt to fix every feature in this task. Record remaining concrete mock commands in runtime-register entries assigned to the master waves, with their actual files and acceptance cases. A partial slice must not declare the full real build complete.

## Task 4 — integration/visual receipt and next task claim

**Files:** create `docs/quality/real-features-20261025/COMPOSITION_GUARD.md`; update register status/evidence. Update `docs/agent/task-status.json` with the scoped task claim/results only; do not advance full phase gates.

**Consumes:** Tasks 1–3 evidence and unchanged source art. **Produces:** reviewable code/test/UI receipt and precise W1 prerequisites.

- [ ] Compare approved mock/API-backed shell and account states with identical fixture values, source art, viewport, fonts, light/dark theme and motion settings. Review screenshots for spacing, colors, typography and hit areas; do not rebaseline historical goldens.
- [ ] Run narrow/wide, text scale 2, system Back and reduced-motion cases for affected bindings. Run Flutter commands sequentially.
- [ ] Run root `pnpm blueprint:check`, `pnpm audit:check`, `pnpm contracts:check`, plus `git diff --check`. If contracts are unchanged, do not regenerate them. Run the area's required Flutter gate and report unresolved baseline failures by exact names/platform, not a blanket pass.
- [x] Update the runtime register with verified **local** composition status. If no admitted live environment was exercised, keep liveEvidence empty and live status unverified.
- [x] Summarize changed paths, red/green test counts, UI comparisons, remaining runtime gaps and the next master-wave task. Preserve the running preview. Do not push, deploy, apply schema or start paid providers.

## Completion condition

This slice is complete only when the action inventory is reproducible, real configuration fails closed, the affected API composition cannot return fixture success, account-switch tests pass and approved UI comparisons show no unintended change. It is not completion of the full integration, broker/cache proposal or cloud/device acceptance.
