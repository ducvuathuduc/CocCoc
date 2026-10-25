# Android non-payment completion — 2026-10-24

Scope: the user's request to complete dark mode, upgradeable chests, the remaining Super screens and Android motion. Real billing, deployment and schema application are excluded. Architecture remains governed by [STACK](../architecture/STACK.md).

References: [archived Android sources](../design/references/android-free-20261024/README.md), especially Mobbin dark-mode 01–15, Super 01–12 and BestLanguageApp `loot-chest.jpg`. Original art is cropped from archived sources; labels, controls and state remain native Flutter. Source stills establish appearance, not Android animation timing. The iOS chest clip is corroboration only.

## Implementation and acceptance

- [x] Persist System Default / On / Off, source radio dialog, context-aware dark neutrals across shared controls and the source's main screen families. Test restore/change races, restart, system brightness, text scale and disposal. Root owns MaterialApp integration; the isolated theme worker owns theme/settings and surface migration.
- [x] Replace the remaining Android Super reminder, plan selection, all-plans sheet, verified-success welcome/brand/coachmark steps using original Android art. Read existing simulated entitlement before success screens. Prices come from the existing product catalog. Do not promise a trial or scheduled reminder that does not exist. Keep the existing checkout unchanged.
- [x] Add a three-tap chest state machine, original Common chest artwork, upgrade/reveal effects, reduced-motion behavior and guarded actions. Claim API rewards before revealing them; failure must not award local gems. Persist/replay the server outcome atomically with the existing claim operation and ledger. No client-supplied rarity, probability, clock or amount.
- [x] Chest economy is a versioned **CocEnglish policy**, not a claim about Duolingo's undisclosed odds: three server-owned rolls, 25% upgrade probability per roll, Common → Rare → Epic → Mega, reward multiplier 1/2/4/8. Original Android evidence covers the Common layout; later rarity geometry/motion must be marked adapted if no matching Android frame is available.
- [x] Add meaningful failing tests first, then targeted tests/analyzer/contracts/backend gates. Capture light/dark and non-payment flow states. Run the installed Android emulator with instrumented acceptance and distinguish screenshots from physical-device verification.
- [x] Build web/APK after integration, open the current web preview and save exact commands/results and remaining source/device limitations in a dated QA receipt. Preserve existing unrelated changes and golden baselines.

Canonical requirements: [SRS](../product/SRS.md), [screens](../product/SCREEN_INVENTORY.md), [wire contract](../api/openapi.yaml), [storage](../data/DATA_MODEL.md). This plan does not advance global implementation phases or constitute cloud/device acceptance.

Completion evidence (2026-10-25): [dated receipt](../design/qa/ANDROID_NONPAYMENT_COMPLETION_20261024.md). Full Flutter Windows golden acceptance, physical-device performance and authenticated cloud release remain open as recorded there.
