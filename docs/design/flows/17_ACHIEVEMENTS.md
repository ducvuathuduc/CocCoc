# Achievements and monthly badges

Date: 2026-10-05. Scope: mock-first English preview for achievements, award details, and monthly badges. Routes are `/achievements`, `/achievements/:id`, and `/badges`; route registration is owned by the parent integration task.

## Sources

Archived Duolingo iOS references, original size 1179×2556:

- Achievements flow `2e5aac3c-9eb5-4126-9ab0-effa7cf75842`: `sc_63db961aee1548789e61d02a278d2dbe` (header, personal records, first six awards) and `sc_d50cee03355441958590da0d87045641` (remaining seven awards).
- Detail flow `f42ff737-2a4b-4818-b1f7-5c6aed16ebe3`: `sc_bdc76f3293a64150b4d6fb0e9e3a7a6b` (locked XP, 24/100 source state) and `sc_bda51f8df2464c75bee4cf75027ef528` (earned Perfect Week and claim action).
- Monthly flow `df71c72f-2817-4042-ba06-5a8047534ecf`: `sc_dfb14f8da11740a78ca9c30e121d25c8` (2025 and start of 2024) and `sc_45f09d0c864c41afb2ba12597a3d8c13` (2024 and three visible 2023 badges).

The captures are archived evidence, not current product rules. Copied PNGs remain byte-identical. Flutter paints only these bounded illustration regions (left, top, width, height in source pixels):

ROI review corrected an initial resized-preview coordinate error. Current bounds are measured against original1179×2556 pixels. Canonical rectangles live in [achievement models](../../../apps/mobile/lib/features/progress/domain/achievement_models.dart) and [monthly repository](../../../apps/mobile/lib/features/progress/data/achievements_repository.dart); they exclude source headings, native tier text and personal-record numerals.

- Personal records: `(138,562,250,235)`, `(581,564,290,232)`, `(1049,577,130,222)`.
- Top awards: Mistake Mechanic `(435,1297,288,335)`, Early Riser `(821,1284,301,348)`, Sleepwalker `(75,1896,262,348)`, Quest Explorer `(435,1923,288,321)`, Cheerleader `(831,1897,291,347)`.
- Bottom awards: XP Olympian `(75,653,262,346)`, Legend `(435,651,288,348)`, Flawless Finisher `(846,650,284,349)`, Speed Racer `(75,1276,278,335)`, Social Butterfly `(448,1267,298,313)`, League MVP `(830,1276,286,304)`, Rarest Diamond `(72,1894,261,298)`.
- Locked XP detail `(293,631,600,789)`; Perfect Week detail and grid art `(236,635,710,779)` use the clean detail illustration without the source NEW label.
- Monthly rectangles use individual original illustration bounds plus4px padding rather than a guessed uniform grid. November2025 includes its tall ears. The three2023 rectangles reach the original image bottom at2556; no unseen region is filled in.

## Layout and interaction

All three screens use a native back header with a muted 23px title and bottom divider. Achievements uses horizontally scrolling 146×194 personal-record cards and a native three-column award grid. Illustration numerals stay inside each source ROI; award names and tier progress are native text. Selecting an award opens its matching detail. Unknown IDs show a safe unavailable state with Back.

Locked XP detail uses its grayscale source art, a native yellow progress bar, and current XP from `learningStateProvider` against the authored 100-XP preview threshold. Perfect Week uses its matching boxer art, archived fixture date, earned explanation, local Share preview, and a fixed bottom claim button. Claim is idempotent and local to the achievements provider. Locked and unknown awards reject claims. The command does not change production XP, gems, or any learning receipt.

Share opens a local bottom sheet containing preview text and a close action. It sends no external message. Claim state survives normal Back navigation while the provider scope remains mounted.

Monthly Badges renders all twelve source-visible 2025 badges, all twelve source-visible 2024 badges, and only the three visible 2023 badges. Native year and month labels describe each ROI. No unseen 2023 badge is invented.

## Mock and motion limits

Award completion states, archived dates, and monthly ownership are authored preview fixtures. Personal XP, streak, and lesson totals always read the current learning ledger. Exact service-side award eligibility, claim receipts, historical calendars, reward amounts, and cross-device persistence remain outside this slice.

The screens use no timer or autoplay loop. Standard button press feedback follows `ReferenceButton`, which becomes immediate when reduced motion is enabled. Artwork is static and excluded from semantics; native labels carry meaning. Narrow 360/430 layouts and text scale 1/2 are required widget checks.
