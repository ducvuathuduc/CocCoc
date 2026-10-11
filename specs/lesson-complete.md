# Lesson complete — UI sprint 2026-10-11

Claim: root, SC21 / P2-FE-001, `int/phaseA`. Saved Gummble fallback:
`docs/design/references/results/02.png`, screen
`sc_23afb65ade9a45f19dba4cf32e1fd5ab`, captured 2026-10-04, archived iOS.
Also inspect `lesson/12.png` for the imperfect completion variant.
MCP is not exposed in this session. Full current-product equivalence is UNKNOWN.

Perfect: medal Duo graphic only; native Flawless heading, actual mistake copy,
three native stat cards TOTAL XP / AMAZING / BLAZING, and fixed CLAIM XP CTA.
Imperfect reference labels are TOTAL XP / GREAT / QUICK. Labels are presentation
copy, not pronunciation or grading scores. All metrics retain immutable receipt
values; animations never award progress. Guest/placement retain practice copy.

Geometry at reference width 1180: graphic ROI (209,481,772,771); cards start
around y1805, widths around298, outer radius48 (~16dp), outline8 (~3dp).
Heading ~32dp, body20dp; CTA inset48 (~16dp), existing tactile control reused.
At text2 use the existing scrollable stacked statistic layout and reachable CTA.
Existing 500ms counts / 600ms finite confetti are mock approximations; exact
archived timings and curves UNKNOWN. Preserve reduced motion and lifecycle tests.

Colors come only from `docs/design/qa/palette_from_refs.json`, results/02:
background #FFFDFE (0,0), XP #FFCA02 (130,1840), blue #1DB2FB (800,1850),
CTA edge #1A9AD8 (80,2400), green #5BCD05 (sample flat card header).
Existing shared tokens remain within six channels of these sampled colors.

Native reference refinements: metric gap52 source pixels; 430dp artwork
772×771 scaled by430/1180, without distorting the graphic. Header bands use
the observed x523..559,578..642,664..700 at y1806, shifting42px by y1858.
Native type is laid out with explicit line heights so fitted labels do not
shrink because of inherited paragraph leading. CTA scales with the reference
width and retains its shared tactile/reduced-motion behavior.

Streak source: `lesson/18.png`, sc_80524686d64f4b2ca387b31023436c15,
1179×2556. Graphics-only flame ROI427,359,329,586; native numeral/caption;
Wed→Tue window, Wed/Thu checked for the two-day mock and Thu highlighted.
Calendar and explanatory text share one rounded outlined container separated
by a rule. Native numeral gradient samples #FFB423 at581,1010 to #FF9600;
description #787878 sampled285,1882. These values occur in the palette.
This is an archived mock window, not an inferred real-user calendar history.

The new sprint goldens use the source10-XP receipt; the original20-XP goldens,
arbitrary repository override and motion tests still prove actual reward data.
At text2, tests scroll to the final stat and calendar description and verify
the fixed action remains reachable. Widget captures omit OS-painted status
and home indicators; the side-by-side PNG preserves those source differences.

Data seam: abstract CompletionRepository -> MockCompletionRepository -> Riverpod
repository/content providers -> native widgets. Copy and formatted values belong
in repository/domain data; graphics have no embedded text. Override the repository
alone to replace source content. Preserve existing receipt claim idempotency.

Acceptance follows ticket40's latest owner rule, SPEED FIRST: meaningful failing
reference-label test, repository overrides, existing summary/motion/claim tests,
360/430 text1/2 goldens, clean analyzer, targeted tests, palette evidence and
opened ref|ours comparison before an individual screen commit. Small visual
differences are allowed; the interrupted full-suite gate remains separately open.
