# Android reference audit — 2026-10-24

**Verdict: full Android visual parity remains unverified.** The subsequent
[non-payment completion receipt](ANDROID_NONPAYMENT_COMPLETION_20261024.md) records the implemented
dark theme, upgradeable chest and remaining Super states, plus native-emulator evidence.
Free reference collection is now independent of
Gummble: 118 Mobbin Android frames across eight flows, five additional Android review captures,
five Lazyweb iOS frames kept separately, a playable archived Android Pageflows video and an iOS
60fps motion clip. [Sources, platform checks and access limits](../references/android-free-20261024/README.md).
The [machine manifest](../references/android-free-20261024/manifest.json) preserves original image
URLs, indices, dimensions and hashes. These are frames, not 123 distinct product screens.

## Comparison and remaining screens

| Android flow/state | Source | Current CocEnglish status | Remaining work |
|---|---|---|---|
| Welcome, onboarding questions and selections | Mobbin onboarding 1–23 | Existing Flutter onboarding | Per-state Android visual comparison and motion measurements. English text is an explicit content adaptation. |
| Lesson token/choice/listening, feedback, retries, results | Mobbin lesson 1–18, first lesson 1–27 | Existing typed exercise engine and results | Pixel and animation validation for Android. Korean alphabet exercises are outside the English course. |
| Shop promo entry and account-specific membership copy | Mobbin promo 1 | Native Promo Code card with original ticket crop; REDEEM opens the existing reader/form and Back preserves wallet. Max subscriber banner appears only for Max; navigation is guarded and the action has a 48 px target | Surrounding Shop sections/gem-pack offers still differ from this Android cohort. Real store integration is absent. The 131 px source card is a minimum; accessible controls and large text can increase its height. |
| Promo empty/typed/processing | Mobbin promo 2–4 | Reworked from the original Android layout: native field and bottom Apply; pending/double-tap/disposal tests pass | Loading dots are static; original timing is unmeasured. Existing error/success states are functional fallbacks, absent from this four-frame source. |
| Super comparison/reminder/plan/trial/welcome/brand | Mobbin Super 1–12 | Comparison, opt-in access reminder, plans/all-plans, verified-access welcome, brand and home coachmark implemented with source art and native controls; existing demo checkout retained | Real Play Billing excluded. Copy uses confirmed entitlement expiry rather than claiming an unearned trial. Physical-device timing and exact pixel acceptance remain open. |
| Google Play purchase overlay | Mobbin Super 6 | Internal billing simulation only | Real Play Billing test integration; do not reproduce the OS payment sheet as a fake app screen. |
| Dark mode System Default/On/Off and dark product screens | Mobbin dark mode 1–15 | Persisted theme mode, native source dialog and sampled dark neutrals across shared controls and main/secondary screen families; restoration/account/disposal tests and captures | Source-owned illustrations stay intact; absent Android dark-art states and physical-device color parity remain unverified. |
| Friend Streak empty/invite/invited/pending/active | Mobbin Friend Streaks 1–5 | Existing streak/invite screens and social repositories | Compare all five Android states, accessibility and motion; live authenticated integration remains unproven. Observed invite counts are not a product rule. |
| Level intro, harder correction, results/gems, Legendary offer | Mobbin leveling up 1–14 | Existing level/lesson/results flows | Per-frame Android comparison and transition timing. |
| Score first-unlock celebration | BestLanguageApp `score-unlock.jpg` | Android presentation linked after the first claimed demo completion; original Duo/background region, native English flag/text, actual demo projection, details and existing COPY/share fallback | API has no score-unlock event, so real mode skips this celebration. English adaptation and motion remain unverified against an English-cohort capture; no fabricated proficiency/trigger. |
| Common → upgrade attempts → Rare/Epic/Mega → gems chest | BestLanguageApp Android Common; 60fps and AndroidAuthority iOS later tiers | Three guarded upgrade attempts, four rarities, reveal/reduced-motion behavior and server-owned atomic receipt/ledger claim implemented; emulator captures saved | Rare/Epic/Mega geometry uses explicitly marked iOS corroboration. Timing and 25% upgrade policy are CocEnglish choices; exact Android motion remains unmeasured. |
| Android home-screen widget | Official widget article; existing Android native widget source | Native provider/layout exists with flame art | Original Android widget captures and visual/device acceptance; iOS crops do not establish Android parity. |

This is a bounded comparison of the collected flows, not an exhaustive audit of every Duolingo
experiment, account tier or region. Store, keyboard and notification-permission surfaces belong
to Android. Current references mix archive cohorts; capture dates/versions are never inferred
from a library's generic marketing copy.

## Implemented companion slice

- Login Terms/Privacy spans open the existing legal readers before authentication and preserve
  form drafts on return. Other settings stay private.
- Archived iOS Super brand interstitial uses the exact source art, a native Continue and guarded
  trial navigation. It is not inserted before Android trial based on an iOS-only source.
- WidgetKit extension is linked into the Xcode target graph. Source-backed widget moods and
  ActivityKit compact/expanded/Lock Screen views use recorded crops and hashes in
  [ReferenceAssets](../../../apps/mobile/ios/StreakWidget/ReferenceAssets.json).
- Display-only lesson progress reaches ActivityKit through a tested optional gateway. Cold-start
  cleanup, account changes, pause/retry progress, completion and quit have Dart coverage.
  Windows cannot compile, sign or visually validate the native iOS target.
- Browser review exposed unconditional Max member copy for Free accounts and the missing Android
  Shop promo entry. Both were corrected; narrow text2, repeat navigation, wallet preservation and
  duplicate-action coverage exercise the actual router.
- The committed English catalog already contains 512 lessons and 6,384 exercises. New offline
  media validation verifies 1,650 AAC + 110 WebP files (14,532,843 bytes) across 14,888 references.
  Learning router acceptance serves all bundles and completes one lesson per 16 units. It does
  not complete all 512 lessons or prove cloud publication.

## Validation receipt

- `pnpm backend:verify`: **174 passed, 0 failed, 12 skipped**.
- Final focused Flutter suite: **112 passed**, covering legal links/readers, brand, promo, Score,
  learning, layout, Shop, Activity, reminders, Super, Energy and results routing. Test names matching
  `[Gg]olden` were deliberately excluded; this is functional coverage, not a golden acceptance claim.
- The final illustration-crop correction passed the separate Shop/layout suite: **18 passed**,
  including all **15 layout/capture cases**. Runs overlap and are not additive unique totals.
- Layout captures cover 360/430 widths, 320 at 2× text, reduced motion, Android status/navigation
  insets and a 2×-text keyboard case. [Static receipts](native-20261024/README.md).
  They establish renderability and visible controls, not full pixel acceptance.
- `node --test tools/tests/ios-streak-widget-project.test.mjs tools/tests/ios-lesson-activity.test.mjs tools/content/verify-media.test.mjs`: **12 passed**.
- Content/media validation, contracts, API lint, schema plan/test, seed check, blueprint and audit
  passed. They establish local schema/fixture consistency, not live database admission.
- `pnpm backend:smoke` and `pnpm dev:smoke` passed, including real local HTTP and signed
  cross-service fixture delivery with dev adapters.
- `pnpm verify`: **1,093 passed, 273 failed**. All 273 failed-case names match the earlier Windows
  baseline exactly; the first run exposed one additional outdated results-chain expectation, which
  was corrected and verified through the real router. The final safe-area-only rendering correction
  and the later Shop correction have the separate targeted receipts above. This full run preceded those
  final small corrections. Full release admission remains blocked by the baseline failures.
- Format and analyzer checks passed. Palette check reports the unchanged **85 legacy unmatched
  colors**; new colors are sampled from original source pixels, and lesson art has no unmatched colors.
- Android debug APK now builds successfully from this slice. The first attempt failed at
  `:app:mergeExtDexDebug` because Gradle detected a modified immutable transform workspace;
  only that entry was moved into a recoverable quarantine before rebuilding. The old October 10
  APK is not used as evidence. This is a build result, not Android device visual acceptance.
- Web release build passed; the final delivery hash/build receipt is recorded with the local logs.
- Final compiled-web browser review verified Free Shop membership copy, the new promo entry,
  form navigation and return to the same scroll position with an unchanged 5-gem wallet.
  [Screenshot and exact build/command receipt](native-20261024/README.md).

Local command logs: `.cache/native-surfaces-20261023/`. The existing Windows golden/Rive failures
are tracked in the [earlier check](../../archive/qa-receipts/MAIN_WINDOWS_CHECK_20261023.md). No baseline was updated to hide
a failure. Mock preview, internal payment simulation and unverified cloud/device gates remain
visible limitations; no global phase gate advances.
