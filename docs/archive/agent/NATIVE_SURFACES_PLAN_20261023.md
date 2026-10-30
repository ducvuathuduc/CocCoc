# Reference-backed native surfaces implementation plan

**Goal:** complete the four user-requested gaps using archived Duolingo references: Dynamic Island/Live Activities, the iOS widget target, Super branding interstitial, and login legal links.

**Architecture:** preserve Flutter/manual Riverpod. Native WidgetKit/ActivityKit render OS-owned surfaces; a local MethodChannel carries display-only lesson progress. Existing legal readers and trial flow are reused. No server/schema/payment integration changes.

**Spec:** [design](../../design/DESIGN.md), [screen inventory](../../product/SCREEN_INVENTORY.md), [gap audit](../../design/GAP_AUDIT.md). User explicitly requires reference-backed reproduction without invented screens.

**2026-10-24 scope update:** Android is the primary target. Gummble access expired; the user
explicitly requested broad free research (Mobbin, Pinterest, Lazyweb and alternatives), Android
screen/effect comparison and the full English curriculum. See the
[source collection](../../design/references/android-free-20261024/README.md) and
[comparison/remaining work](../../design/qa/ANDROID_REFERENCE_AUDIT_20261024.md).

## Constraints and review focus

- Root owns router, Flutter behavior, shared activity state and reference manifest. One isolated worker owns the existing widget target wiring only.
- Keep source PNGs untouched; record IDs, URLs, dimensions, crop rectangles and SHA-256. OS chrome is a reference context, not an in-app screen to imitate.
- Activity data has no grading or reward authority. Disabled/unsupported ActivityKit must not interrupt learning. Finish/exit/account changes must end stale activity.
- Opening legal documents preserves the login draft and works before authentication; Return restores the originating form.
- Interstitial Continue advances to the existing trial exactly once; Back declines safely; no extra purchase/ad credit is awarded.
- Respect large text, safe areas, reduced motion and lifecycle. Stills do not establish original animation timing.
- Windows cannot compile or visually verify WidgetKit/ActivityKit. Record this as an outstanding Mac/device gate, not a passing iOS result.

## Tasks

- [x] Inspect selected cached reference states; create per-surface source/asset manifest and decomposition.
- [x] Add red-first navigation/draft/semantics tests for login Terms and Privacy; wire the existing readers without changing footer appearance.
- [x] Add red-first Super interstitial navigation tests; reproduce archived iOS source artwork/geometry, muted glyph and native Continue before the existing trial. Android ordering remains separate.
- [x] Wire the existing WidgetKit extension into Xcode, including dependency/embed/App Groups; verify project graph locally. Mac compilation/signing is still open.
- [x] Implement source-backed native widget art and lesson ActivityKit compact/expanded/Lock Screen views; connect local lesson start/progress/pause/finish and safe deep links through a tested gateway. Native device acceptance remains open.
- [x] Collect 118 original Android frames from eight free Mobbin flows and check Pinterest, Lazyweb, Pageflows, 60fps and alternatives; preserve platform/date/version gaps.
- [x] Rework Android promo entry/processing and fix late-response disposal races with red-first tests.
- [x] Verify all 512 English lesson bundles and 1,760 media files; add real-router serving and one-completion-per-unit acceptance without changing immutable curriculum or publishing to cloud.
- [x] Implement the source-backed Android Super comparison and first claimed demo Score celebration; guard duplicate navigation, receipt mismatch and replay. API Score stays disabled without an unlock event.
- [x] Correct the browser-observed Free/Max Shop mismatch; add the original Android promo entry with source ticket art, 48 px action, repeat/double-tap-safe routing and wallet-preserving return.
- [x] Capture Flutter screens at source size, narrow/wide and text2; inspect promo, Super and Score against originals and correct artwork joins, clouds, flag framing and text weight. These are static render receipts, not full pixel/motion acceptance. Mac screenshots remain required.
- [x] Run targeted regression tests, analyze/format, structural/contracts/audit checks, full Flutter gate, Android debug build and web release preview. Record the 273 matching Windows baseline failures and unverified device/cloud gates; preserve existing audit edits. Running a gate is not a passing release gate.

## Evidence

See [Android comparison and validation](../../design/qa/ANDROID_REFERENCE_AUDIT_20261024.md),
[render receipts](../../design/qa/native-20261024/README.md),
[asset/source crops](../../design/references/android-free-20261024/implementation-assets.json)
and the earlier [Windows baseline](../qa-receipts/MAIN_WINDOWS_CHECK_20261023.md).
No full phase gate advances from this slice.
