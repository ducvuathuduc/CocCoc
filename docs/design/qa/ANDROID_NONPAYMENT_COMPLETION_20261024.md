# Android non-payment completion — 2026-10-24–25

Dark mode, upgradeable quest chests and the remaining Android Super flow are implemented in the
local code. Payment stays with the existing internal demo checkout. This receipt does not claim
cloud deployment, physical-device performance or whole-app pixel parity.

Scope: [implementation plan](../../archive/agent/ANDROID_COMPLETION_PLAN_20261024.md).
Canonical owners remain [design](../DESIGN.md), [OpenAPI](../../api/openapi.yaml) and
[storage](../../data/DATA_MODEL.md).

## Implemented behavior

| Area | Behavior and evidence |
|---|---|
| Appearance | System Default / On / Off persists locally. Source-backed radio dialog, dark surfaces, borders and text cover the main and secondary screen families. Restoration/write races, system brightness, disposal and 2× text have tests. [Eight dark renders](native-20261024/README.md). |
| Quest chest | Three guarded attempts progress through Common/Rare/Epic/Mega, followed by opening and gem reveal. Reduced motion skips delays. API mode waits for the server; failed claims award no local gems. A stable opaque operation, wallet and QUEST ledger commit atomically; retries replay the same outcome. Account changes cannot leave another user's pending claim stuck. |
| Chest policy | Versioned CocEnglish policy: three server-owned 25% rolls, multipliers 1/2/4/8. These probabilities are not inferred from Duolingo. No client amount, tier or clock is accepted. Existing legacy claim clients remain compatible. |
| Super | Android comparison → access-reminder opt-in → plans/all-plans → unchanged demo checkout → verified-access success → welcome → brand → home coachmark. Prices use the existing catalog. Expiry and success use confirmed entitlement. Reminder permission failure is surfaced; scheduling occurs two days before the actual access end and is reconciled after restart, account change or revocation. |
| Motion | Chest wiggle/scale, gem fade/slide, guarded transitions and reduced-motion behavior run on Android. Five original Rive poses advanced frames on the emulator. Timings are authored; the archive does not establish exact Android timing. |

The chest receipt uses the existing `p_quests.claimOperationId` and reward ledger. No storage
column, service, broker or gateway was added. The API addition is optional for legacy clients.
The local preview uses mock auth/data; private Appwrite integration was not newly verified here.
The frozen service boundaries remain Learning, Progress and AI on TypeScript/Node 22, Appwrite
Auth/TablesDB/Storage, REST/OpenAPI and Flutter manual Riverpod MVVM. Progress owns chest/wallet
writes; Learning receives existing signed service events. Client animation never awards API gems.

## Per-state source traceability

Original URLs, SHA-256 hashes, dimensions, crops and sampled colors are retained in the
[source archive](../references/android-free-20261024/README.md),
[completion asset ledger](../references/android-free-20261024/completion-assets.json) and
[product provenance](../../../apps/mobile/assets/PROVENANCE.md).

| Implemented state | Reference and explicit limits |
|---|---|
| Dark dialog, settings, lesson/home/practice/profile/league/quests/feed | Mobbin Android dark-mode 01–15. Colored illustration pixels are preserved. The source does not cover every secondary dark-art state. |
| Common chest | BestLanguageApp Android `loot-chest.jpg`. Native controls/text and source chest crop. |
| Rare/Epic and gems | Archived 60fps iOS video, extracted at requested 8/15/20 seconds. Android layout adaptation, not Android parity evidence. |
| Mega | AndroidAuthority's public `aa-chest-5.jpg`, identified as iOS from status icons. Original art adapted to Android layout. |
| Super comparison/reminder/plans/all-plans | Mobbin Android Super 01–05. Native prices, selection and copy adapt to the actual CocEnglish entitlement and internal demo. |
| Confirmed access/welcome/brand/home coachmark | Mobbin Android Super 08–12. Success is entitlement-gated. Brand duration is authored. |
| OS purchase/permission | Google Play purchase states 06–07 are excluded; the app does not paint a fake OS purchase sheet. Notification permission uses the platform gateway. |

The Super background is a recorded row-wise interpolation of source 02's edge pixels; source Duo
art remains a crop. Archive cohorts, English copy, accessibility sizing and iOS chest adaptation
prevent an honest claim of “100% identical on Android.”

## Verification

Commands run from the repository root unless stated otherwise. Flutter commands ran sequentially
because concurrent test/drive runs can overwrite this workspace's test assets.

| Check | Result |
|---|---|
| `pnpm backend:verify` | **179 passed, 0 failed, 12 skipped**; TypeScript, bundles, lint and format passed. Includes five chest cases and the historical-ledger replay regression. Cloud/provider tests remain gated. |
| `pnpm verify` | Before the final shell crop refinement: format clean; analyzer clean. **1,124 passed, 273 failed**. All 273 failed-case names occur in the previous Windows baseline; no new failed names. Golden mismatch/Rive host diagnostics remain unresolved. Golden baselines were not rewritten. |
| Final shell refinement | **13 focused functional cases passed**, including source dark nav/locked nodes, reduced-motion mascot background, top-stat hit areas/state and artwork proportions; analyzer clean on five changed areas. Twenty-two source asset records have matching SHA-256 hashes. The selected light tab border retains its previous blue styling. |
| Owner-isolation regression | Five chest tests passed after adding foreign-user and forged-subject rejection checks; no other wallet or ledger is changed. |
| `pnpm contracts:check`, `pnpm api:lint` | Passed. Generated TypeScript and Dart contracts agree with OpenAPI. |
| `pnpm schema:plan`, `pnpm schema:test`, `pnpm seed:check` | Passed locally. No schema application or cloud seed mutation. |
| `pnpm blueprint:check`, `pnpm audit:check` | Passed. |
| `pnpm backend:smoke`, `pnpm dev:smoke` | Passed, including real local HTTP and signed cross-service fixtures. |
| `python tools/palette_check.py` | 84 existing unmatched colors; no new unsourced colors introduced in this slice. Lesson art: zero unmatched. |
| Android instrumented acceptance | Passed on API 34 x86_64 `PRM392_API34_Lite`, `emulator-5554`; 18 screenshots at 1080×2154, including real MainApp home and the coachmark's actual features-screen destination. Production widgets use injected confirmed entitlement and server-receipt fixtures. This does not contact a live store or cloud backend. |
| Android Rive acceptance | Passed: idle/wave/pencil/celebrate/reading advance frames; [motion captures](motion/). |
| Final web build | Passed: `flutter build web --no-pub --release --no-wasm-dry-run --dart-define=USE_MOCK_AUTH=true --dart-define=RIVE_NATIVE_WASM_HOST=rive/`. Optional Wasm dry run passed earlier; final preview targets JavaScript. HTTP-served bundle hash matches the build. |
| Final main APK | Passed: `flutter build apk --debug --dart-define=USE_MOCK_AUTH=true`. The ordinary `lib/main.dart` app was installed and launched on the emulator after acceptance, replacing the test entrypoint. This is a mock-data debug preview APK, not a cloud-connected release. |

Native acceptance command, from `apps/mobile`:

```text
flutter drive -d emulator-5554 --driver test_driver/integration_driver.dart --target integration_test/android_completion_test.dart --dart-define=ENABLE_MASCOT_MOTION=false
flutter drive --no-pub -d emulator-5554 --driver test_driver/integration_driver.dart --target integration_test/motion_test.dart
```

Screens and final build receipts: [Android captures](android-completion-20261024/README.md),
[machine verification](android-completion-20261024/verification.json).

Flutter 3.47's release tooling can remove dev plugins from the generated Android registrant.
After a release web build, running drive with pub regeneration enabled restores `integration_test`;
`drive --no-pub` can retain the stale registration. The receipt run uses regeneration. Each native
test case converts its own screenshot surface. Destination assertions inspect the visible routed
screen, because an imperative push need not change the root route-information URI.

Full-suite baseline comparison is by failed-case identity, not an assertion that the old visual
differences are acceptable. Emulator debug/software-renderer runs logged skipped frames. They do
not prove 60 fps or physical Android animation performance. Real Play Billing, cloud release and
exact Android visual/motion parity remain separate acceptance work.
