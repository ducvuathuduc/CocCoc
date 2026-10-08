# Original avatar and clean product surface

2026-10-05 local continuation; mock-data authorization remains. Completed families
are reused. No backend, deployment, GitHub Release or device-build claim is added.

## Changes

The web wrapper now contains only the app: no Mock preview title, developer
buttons, instructions or credentials. Phones use the full viewport; desktop
keeps a centered390×844 app. The Flutter page title is CocEnglish.

Ordinary account/learning/practice/subscription/social screens no longer expose
Mock/Preview labels, diagnostic receipts, simulation chips or implementation
instructions. Permission/offline/recovery fixtures remain test inputs; speaking
lifecycle/fallback and plan cancel/confirm commands retain their existing local
behavior. This presentation cleanup does not connect microphone, AI, email,
billing, notifications or cloud services, and does not complete production gates.

The native editor uses the original Duolingo avatar Rive/config/SVG assets:
[research and source mapping](../flows/24_AVATAR_ASSET_RESEARCH.md),
[18-file provenance](../references/AVATAR_ASSETS.json). Eight categories expose
282 configured choices. Draft selection, cancel/back, save/reopen, full Profile
fields and own-profile avatar/QR integration share native Riverpod state.

Main-avatar motion uses the original state machine. Lazy choices and profile
images use its static mode. Background/reduced-motion preserves the selected
character. The actual white-eye-pixel regression prevents a closed-eye frozen
pose. Input changes, lifecycle and animate-property transitions are tested.

## Verification

- Native source-sized captures: [body](avatar/state-0.png),
  [expression](avatar/state-1.png), [hair](avatar/state-2.png),
  [accessories](avatar/state-3.png), [facial hair](avatar/state-4.png),
  [headwear](avatar/state-5.png), [clothing](avatar/state-6.png),
  [background](avatar/state-7.png), [editor](avatar/state-8.png),
  [profile](avatar/state-9.png). All10 were visually reviewed. These are actual
  native Rive frames with local fonts, not screenshots rendered as controls.
- `flutter test test/avatar_controller_test.dart test/avatar_builder_test.dart
  test/avatar_capture_test.dart test/avatar_route_test.dart
  test/profile_editor_test.dart test/password_change_route_test.dart
  --dart-define=ENABLE_MASCOT_MOTION=false --dart-define=CAPTURE_AVATAR_UI=true`:
  11pass in [targeted log](avatar-targeted.log).
- `flutter test test/avatar_motion_test.dart`: actual original native rig/input
  contract, lifecycle, static-mode transition, failed-load retry, concurrent use
  and in-flight disposal: 3pass in [active motion log](avatar-motion-active.log).
- Touched speaking, Max, achievements, course guard, profile/QR and motion tests:
  37pass in [product regression log](avatar-product-green.log). Meaningful RED
  receipts cover missing product controls, frozen eyes, failed-load poisoning and
  inconsistent full-name limits before their fixes.
- `node tools/scripts/avatar-asset-audit.mjs`: 18files/8categories/282choices pass.
- `node tools/scripts/mobile-check.mjs --with-blueprint`: blueprint, format,
  fatal-info analyzer and293tests pass in [full gate](avatar-product-gate.log).
- Final removal of the demo-wallet button routes GET GEMS into Shop without
  minting a balance and preserves the selected pack on return: 10Timer Boost
  tests pass in [final wallet regression](product-wallet-final.log). Funding is
  injected through test fixtures, not exposed as a product action. The broader
  wallet/all-screen regression is16pass in [wallet layout log](product-wallet-green.log).
- Final analyzer has no issues in [analyzer receipt](avatar-analyze.log).
- `node tools/scripts/mobile-web-build.mjs`: final release web build passes in
  [build receipt](avatar-web-build-final.log). The first build exposed a missing
  Cupertino font; pinning the official
  [cupertino_icons1.0.9 asset package](https://pub.dev/packages/cupertino_icons/versions/1.0.9)
  includes its glyphs and removes that warning. This does not change the existing
  Flutter Cupertino API. Browser verification of this continuation was blocked
  by the browser tool's security policy; no alternate browser or CDP workaround
  was used. Native captures and the web build are separate evidence.

## Source differences

The asset export is2025-09-25. It establishes its authored motion and choices,
not older iOS frame timing, every archived item mapping or all Profile variants.
The later native Profile/Score continuation replaces the prior Profile overview;
see [source reconciliation](../flows/25_PROFILE_SOURCE_RECONCILIATION.md).
Avatar sequences keep per-screen differences separate from this reusable editor.
Other missing mascot rigs are not supplied by this file. Auth/email/phone changes
remain local mock commands; implementation capability notes live in docs only.
Initial DONE stays disabled until the configuration changes, matching the
inspected source default state; accepting an untouched source default is not
asserted as supported. Private distribution/production/device gates are separate.
