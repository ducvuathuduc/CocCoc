# Static Flutter render receipts — 2026-10-24

Originals and platform/cohort limits: [Android source audit](../ANDROID_REFERENCE_AUDIT_20261024.md).
Original source crops and hashes: [implementation assets](../../references/android-free-20261024/implementation-assets.json).
Exact functional command, results and final served-web/APK hashes: [verification receipt](verification.json).

| Surface | 360 px | 430 px | 320 px at 2× text |
|---|---|---|---|
| Android Super comparison | [render](android-super-360-text1.0.png) | [render](android-super-430-text1.0.png) | [render](android-super-320-text2.0.png) |
| Android Score unlock | [render](score-unlock-360-text1.0.png) | [render](score-unlock-430-text1.0.png) | [render](score-unlock-320-text2.0.png) |
| iOS brand companion | [render](super-brand-360-text1.0.png) | [render](super-brand-430-text1.0.png) | [render](super-brand-320-text2.0.png) |
| Android promo | [source / implementation](promo-source-implementation.png) | [render](promo-430-text1.0.png) | [render](promo-320-text2.0.png), [keyboard](promo-320-text2-keyboard.png) |

The [Android Shop promo entry](android-shop-promo-360.png) preserves the complete source ticket
illustration and native text/actions. Its 48 px action can increase the card above the source's
131 px minimum. Free accounts no longer display Max subscriber copy; Max retains its existing banner.
The final [browser screenshot](browser-shop-promo.png) comes from the compiled web build in the
verification receipt. Browser actions verified Home → Free Shop → scroll → REDEEM → empty promo
form → Close → the same Shop position with the wallet still at 5. The preview tab remains open.

Captured with `test/native_surfaces_layout_test.dart`, reduced motion enabled and real bundled
fonts/assets. Controls remain reachable at the listed sizes. These are Flutter test renders;
they do not establish native-device appearance, original animation timing or whole-app pixel parity.
An additional [Android safe-area render](score-unlock-android-safe-area.png) checks 24 px status
and navigation insets; the Score gradient maps its join after the top inset and Continue stays operable.

Visual review corrected the Score crop/gradient join, restored original cloud silhouettes and
the English flag's white rounded frame, and reduced Android Super row-label weight. Cloud crops
use `BlendMode.lighten` over the native gradient to avoid rectangular JPEG background patches;
the original source files are untouched. English copy/flag, demo Score and configured trial length
are explicit adaptations. Full acceptance remains open in the linked audit.

Dark-mode source-family receipts use the Android cohort's sampled neutral
palette (`#172021` surface, `#233034` raised surface, `#3A464E` border) and
preserve colored banners and illustration pixels:

| Practice | Profile | Quests | Feed |
|---|---|---|---|
| [render](dark-practice.png) | [render](dark-profile.png) | [render](dark-quests.png) | [render](dark-feed.png) |

They were captured at 360×717 with bundled fonts/assets by
`test/dark_mode_source_surfaces_test.dart`. They verify Flutter layout and
readable neutral surfaces, not physical-device color calibration or motion.

Secondary form, read-only and modal surfaces were also checked at 360×717
with 2× text scaling:

| Schools form | Feedback form | League entry | Status picker |
|---|---|---|---|
| [render](dark-settings-schools-text2.png) | [render](dark-settings-feedback-text2.png) | [render](dark-league-entry-text2.png) | [render](dark-status-picker-text2.png) |

These renders come from `test/dark_mode_secondary_surfaces_test.dart`. The
locked-league illustration and status artwork retain their source-owned light
pixels; the available Android dark references do not include those states.
