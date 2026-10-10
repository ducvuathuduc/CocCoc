# I1 palette and visual QA — P2-FE-001 / P2-QA-001 / UI-QA-014

Independent read-only review, 2026-10-10. Source images freshly fetched through
Gummble MCP and opened; all sixteen I1 goldens and twelve design-control crops
opened. The continuation receipt below reviews actual current testImage renders; the
earlier sections retain the pre-correction failing visual evidence. No implementation, tests, goldens, git
operations or Flutter commands performed by QA.

Acceptance and ownership: [I1 QA brief](I1_QA_WORKER_BRIEF.md),
[worker/quality rules](PHASE_A_WORKER_BRIEFS.md),
[canonical design](../DESIGN.md), [component states](../COMPONENT_STATES.md).
PM11 supplies geometry/motion targets. Its palette targets are superseded by
the later source-only G-COLOR rule in external tickets/QUALITY_GATES.md,
mandatory10/10 11:25. English/Vietnamese fixture data and independent three-pair columns
are authored course content, not archived French course copy.

## Continuation recheck — current renders, 2026-10-10

Independent QA freshly fetched all six references with
`gummble_get_screen_details_batch` (6 available, 0 restricted), downloaded the
original URLs with `curl -L --fail --silent --show-error`, and opened the six
source PNGs, all sixteen existing I1 goldens, all twelve design-control goldens
and all sixteen new failure captures. Python urllib returned HTTP403 once;
curl succeeded. Inspection sheets are temporary artifacts under
`/tmp/coc-i1-qa-resume/`, not application assets. No Flutter runner, test,
implementation, golden or git mutation was performed by QA.

The latest actual captures are
`apps/mobile/test/failures/ex_*_testImage.png`, timestamp
2026-10-10 04:55:30–37 UTC, from the lead's full candidate run. Existing
`ex_*.png` goldens still contain older PM inks/fills and white woman rectangles.
**Compare the actual testImage captures before attributing those stale defects
to current implementation.** Current code scopes the modern palette through
ReferenceButtonPalette.lesson and ExerciseTileTokens; ReferenceColors defaults
remain unchanged.

Actual captures fix the selected/correct woman background rectangle and the
idle woman's clipped left hair. Actual correct fill/border/ink are now
#D6FFB8/#A5ED6E/#58A700; selected border/ink are #84D7FF/#1CB0F6;
wrong adaptation is #FFDFE0/#EA2B2B. These values were independently re-sampled
from the original reference coordinates in the table above. The old text-match
capture retains its own #FEFCFE/#E7E5E7/#DBFFBB/#A9EE73 palette.

Still-open actual defects/deltas:

- **I1-A2 wrong-boy art:** obvious white rectangular crop at approximately
  x47..156/y297..424 inside the wrong tile. Current woman-specific state
  crop fix does not cover boy. No wrong-image source tile is available;
  establish a supported background integration approach and retain UNKNOWN
  rather than treating translation-feedback pixels as wrong-tile proof.
- **I1-G1 image geometry remains:** 390×844 actual idle/selected tile extents
  y280..476 and493..689 versus idle source y274..495.33 and516.67..738.
  The first row is6dp lower and25.33dp shorter; second bottom49dp higher.
  Current16dp authored grid gap differs from source21.33dp. No owner acceptance
  or exact-source closure is asserted.
- **I1-G2 match placement remains:** first-row top231dp versus older text-match
  approximately239.33dp and audio-match257.33dp. Text-match is the closer
  structural reference; do not shift a text exercise solely to an audio still.
  Three authored English/Vietnamese rows remain different from source five
  French/text rows or four audio rows.
- **I1-C2 prompt ink:** title still inherits legacy #4D4B4E. Modern source
  sc_b7f6add9(63,522) is #4B4B4B. Suggested lead-scoped fix:
  lesson_screen.dart exercise.title headingStyle.copyWith color
  ExerciseTileTokens.ink only for I1. Do not alter global theme ink.
- **State/source gaps remain:** right-first selected pair, settled-disabled
  pair, wrong image/pair, pressed and text2 captures are not available. Mapping
  modern image/feedback roles to pairs is an authored adaptation, not1:1 proof
  against the older text-pair capture. The archived image idle action reads
  CONTINUE while the authorized PM behavior uses CHECK/HINT; no new owner
  acceptance is inferred by this report.

Every current capture was opened, with its corresponding original reference:

| Actual testImage stem | Reference and current review |
|---|---|
| ex_image_idle | sc_f691b4ff; idle hair corrected; I1-G1/I1-C2 and CHECK/HINT copy delta remain |
| ex_image_selected | sc_b7f6add9; woman rectangle corrected; sampled selected roles exact; I1-G1/I1-C2 remain |
| ex_image_correct | sc_925a4125; woman rectangle corrected; sampled correct roles exact; I1-G1/I1-C2 remain |
| ex_image_incorrect | sc_3b88d8f1 feedback only; wrong fill/edge exact to feedback; I1-A2/I1-G1/I1-C2; wrong tile source UNKNOWN |
| ex_image_selected_360_text1 | sc_b7f6add9; rectangle corrected; selected tile bottom initially obscured by action area, scroll reachability requires behavior evidence; I1-G1/I1-C2 |
| ex_image_selected_430_text1 | sc_b7f6add9; rectangle corrected; both rows readable; I1-G1/I1-C2 |
| ex_image_selected_360_text2 | sc_b7f6add9 structure only; selected woman initially below viewport, scrolling adaptation; text readable; source text2 UNKNOWN |
| ex_image_selected_430_text2 | sc_b7f6add9 structure only; selected woman partially below viewport; visible crop rectangle corrected; source text2 UNKNOWN |
| ex_match_idle | sc_ceb894f1 idle/sc_5b3164cb text structure; modern surface/idle border exact; I1-G2/I1-C2 |
| ex_match_selected_right | sc_5b3164cb structure only; modern selected image-role adaptation; I1-G2/I1-C2; selected-right source UNKNOWN |
| ex_match_matched | sc_5b3164cb; modern correct image-role adaptation differs from old matched source; I1-G2/I1-C2 |
| ex_match_wrong | no wrong-pair source; local finite red decoration, no global panel; I1-G2/I1-C2; source UNKNOWN |
| ex_match_idle_360_text1 | sc_ceb894f1/sc_5b3164cb structure; I1-G2/I1-C2 |
| ex_match_idle_430_text1 | same; I1-G2/I1-C2 |
| ex_match_idle_360_text2 | text structure only; independent column wrapping readable; source text2 UNKNOWN; no behavior certification from pixels |
| ex_match_idle_430_text2 | same; independent column wrapping readable; source text2 UNKNOWN |

### Actual role-patch improvement receipt

Each box is current/old golden [x0,y0,x1,y1), sampled separately with Pillow.
Mean ΔRGB is sum of absolute RGB channel differences divided by three times
pixel count, against the uniform exact source pixel below. This measures
comparable uniform roles; it is not a whole-screen similarity score.

| Role/capture | Golden patch | Exact source pixel | Old → actual mean ΔRGB |
|---|---|---|---|
| image correct fill | ex_image_correct(211,503,222,521) | sc_925a4125(66,1255) #D6FFB8 |0.333→0.000|
| image correct border | ex_image_correct(204,521,205,530) | sc_925a4125(46,1109) #A5ED6E |128.667→0.000|
| selected woman's old white background | ex_image_selected(332,512,335,515) | sc_b7f6add9(541,1252) #DDF4FF |15.000→0.000|
| correct woman's old white background | ex_image_correct(332,512,335,515) | sc_925a4125(66,1255) #D6FFB8 |37.333→0.000|
| wrong image fill, feedback adaptation only | ex_image_incorrect(24,310,36,323) | sc_3b88d8f1(10,1800) #FFDFE0 |1.000→0.000|
| wrong image edge, feedback adaptation only | ex_image_incorrect(17,425,18,435) | sc_3b88d8f1(580,2400) #EA2B2B |38.667→0.000|
| selected pair border, modern image adaptation only | ex_match_selected_right(207,260,209,270) | sc_b7f6add9(49,1158) #84D7FF |99.333→0.000|
| correct pair fill, modern image adaptation only | ex_match_matched(212,260,222,270) | sc_925a4125(66,1255) #D6FFB8 |0.333→0.000|
| correct pair border, modern image adaptation only | ex_match_matched(207,260,209,270) | sc_925a4125(46,1109) #A5ED6E |128.667→0.000|
| wrong pair fill, feedback adaptation only | ex_match_wrong(23,450,33,460) | sc_3b88d8f1(10,1800) #FFDFE0 |1.000→0.000|

The stricter own-screen comparison must retain the old match palette:
sc_5b3164cb(83,726)=#DBFFBB and(84,720)=#A9EE73.
Against its actual old-match fill, changing #D7FFB8 to #D6FFB8 makes mean
ΔRGB **2.333→2.667**, farther by0.334/channel. Therefore the modern-state
adaptation table cannot be reported as improved old-match fill fidelity.
Admission/mapping or an owner decision is still necessary; QA supplies no
self-acceptance. Source sc_5b3164cb remains absent from palette_from_refs.json
per_screen. The other five references are present under full catalog-cache
file-path keys, not bare screen IDs.

Fresh read-only `python3 tool/palette_check.py` returned exit1 with
**68 unmatched colors**. No new I1 role was listed. The checker scans all lib
files against the union of admitted colors and cannot establish per-screen role
correctness. Existing unmatched colors include protected and unrelated features;
their presence authorizes no broad palette rewrite. Before a local feature
commit, the lead must preserve the exact checker result, resolve applicable
new/changed roles and record the source coordinates and measured improvements
in its commit/UI_MASTER_LOG receipts.

The current full-run log records an exercises_i1_test.dart compilation failure:
`Method not found: 'referenceTheme'`, line43. This is the lead's runner,
not independent QA execution; no test changes made by QA. Later corrected
captures, analyzer/behavior results and the completed full-suite receipt must
supersede this observation. Report remains **OPEN**; production/device/browser
and unsupported motion/source-state claims remain unestablished.

## Fresh source measurements

MCP `gummble_get_screen_details_batch` resolved all six requested IDs without
restriction. Original PNGs downloaded to `/workspace/tools/i1-palette-qa/` and read with
Pillow; dominant RGB regions and opaque glyph/border bounds sampled without
resizing. Modern captures are 1179×2556, normalized by three to 393×852dp.
The older text-pair capture is 1180×2556; dimensions were measured from its
PNG because MCP metadata omitted them. These are archived captures, not
fresh device/product facts or recovered design constants.

| Reference | Measured source roles | Scope supported |
|---|---|---|
| [image idle sc_f691b4ff](https://gummble.com/screens/sc_f691b4fff7e747c6b5bb85cdaa49e2e0) | surface #FFFFFF; idle stroke/edge/disabled action #E5E5E5; disabled label dominant #B0B0B0 | Image idle surface/border; label varies from match source by one RGB step |
| [image selected sc_b7f6add9](https://gummble.com/screens/sc_b7f6add9477e4c57ba0ed0bc101a37d9) | surface #FFFFFF; selected fill #DDF4FF; border #84D7FF; label #1CB0F6; CHECK #58CC02/#58A700/#FFFFFF | Modern image and CHECK roles |
| [image correct sc_925a4125](https://gummble.com/screens/sc_925a41252ecb4262a3c24780ef20f885) | surface #FFFFFF; correct fill #D6FFB8; border #A5ED6E; label #58A700; CONTINUE #58CC02/#58A700 | Modern correct image; PM exact correct values differ explicitly |
| [match idle sc_ceb894f1](https://gummble.com/screens/sc_ceb894f17ed14dd08762802759a22ced) | surface #FFFFFF; stroke/disabled action #E5E5E5; disabled label #AFAFAF; prompt ink #4B4B4B | Modern match/control roles; this is an audio-to-word four-row exercise |
| [match flash sc_5b3164cb](https://gummble.com/screens/sc_5b3164cb9c6448c1838c229517cebe1b) | surface dominant #FEFCFE; idle stroke/disabled action #E7E5E7; ink #4D4B4E; flash #DBFFBB/#A9EE73; disabled label dominant #B3B0B3 | Older five-row text match capture; incompatible with universal modern white palette |
| [incorrect feedback sc_3b88d8f1](https://gummble.com/screens/sc_3b88d8f19d7e4f3597bdce7d3ea169b7) | surface #FFFFFF; feedback #FFDFE0; text #EA2B2B; action #FF4B4B/#EA2B2B | Translation feedback, **not an incorrect image tile** |

Pending shared `ReferenceColors` changes were surface #FFFDFE→#FFFFFF,
border #E7E5E7→#E5E5E5, disabled #B0AEB0→#AFAFAF and green
#5BCD05→#58CC02. These measurements support the modern I1 controls and
surfaces. They do not justify changing every previously matched archived
screen/golden: even this six-reference set contains a distinct older palette.
Preserve legacy global defaults and explicitly scope modern roles/label
tracking to I1 and its component fixtures; do not regenerate unrelated
goldens merely to accommodate a shared-token change. Protected
league/quests/shop/profile remain read-only.

Earlier PM-selected #1577A4 and correct #235B00 inks are much darker than
the captured #1CB0F6 and #58A700. Earlier PM-correct #D7FFB8 differs by one
red-channel step from source #D6FFB8; PM error #FFE1E1/#A41414 is unobserved
as an image or pair tile in these references. **G-COLOR now requires the
earlier PM colors to be reconciled with the applicable admitted source
palette.** Preserve their history, not unsupported colors. Do not use
translation-feedback pixels as proof of an incorrect image tile.

## G-COLOR coordinates and exact roles

Only `docs/design/qa/palette_from_refs.json` supplies admitted source colors.
Its corresponding `per_screen` catalog entries for the five modern refs are
present; older sc_5b3164cb catalog-cache entry is absent. The lead must run
`python3 tool/palette_check.py` before committing. The current checker admits
the union of all reference palettes across all lib files; its pass alone does
not prove the stronger owner requirement for per-screen roles or improved
mean ΔRGB in a changed existing golden.

Coordinates below are original PNG x/y, verified with `PIL.Image.getpixel`.
Separate fill/border/label roles are necessary: one selectedInk cannot paint
both the observed blue border and label. Local matching catalog-cache PNGs
exist and match dimensions/surface.

| Role | Exact RGB | Source / coordinate |
|---|---|---|
| modern surface | #FFFFFF | sc_b7f6add9 (5,1278) |
| idle border / disabled fill | #E5E5E5 | sc_f691b4ff (296,1552); sc_ceb894f1 (129,2340) |
| disabled label | #AFAFAF | sc_ceb894f1 (578,2339) |
| primary fill / edge | #58CC02 / #58A700 | sc_b7f6add9 (100,2310) / (580,2400) |
| selected fill | #DDF4FF | sc_b7f6add9 (541,1252) |
| selected border / edge | #84D7FF | sc_b7f6add9 (49,1158) |
| selected label | #1CB0F6 | sc_b7f6add9 (403,1398) |
| correct fill | #D6FFB8 | sc_925a4125 (66,1255) |
| correct border / sparkle | #A5ED6E | sc_925a4125 (46,1109) |
| correct label | #58A700 | sc_925a4125 (186,1399) |
| feedback surface / error edge | #FFDFE0 / #EA2B2B | sc_3b88d8f1 (10,1800) / (580,2400) |
| error action face | #FF4B4B | sc_3b88d8f1 (100,2310) |

Incorrect image/pair tile region is UNKNOWN in this six-screen set. A different
confirmed wrong-tile reference must be mapped before claiming1:1 tile proof.
For modern I1 match flash, using admitted modern correct-image roles is an
explicit state-role adaptation; the older text-pair still has a different
palette. No tests or assertions changed by QA.

## Existing bundled woman regions

Opaque hair/skin/dress extents measured from original bundled PNGs: idle
lesson03 x703..1052,y1627..2009 (349×382px); selected lesson05 and correct
lesson06 x128..477,y899..1282 (349×383px). Current idle x735 crop clips32px
of left hair. Suggested padded idle region
`ArtRegion('lesson-03', Rect.fromLTWH(700,1624,355,388))`; selected/correct
`Rect.fromLTWH(125,896,355,389)` from existing lesson05/06. Those state crops
already contain exact #DDF4FF/#D6FFB8 backgrounds, removing the white
rectangle while preserving original art/source PNGs and adding no binary
assets. Choose the appropriate existing state region only for woman. No
wrong-boy source crop was established; do not manufacture recolored artwork.

## Current goldens and measured deltas

All paths below are under `apps/mobile/test/goldens/ui_master/`. **OPEN DELTAS:
4 visual families pending lead correction/reconciliation**: I1-G1 image geometry,
I1-A1 art background rectangle, I1-G2 match vertical placement and I1-C1
source-only palette reconciliation. Earlier PM palette targets are superseded
by G-COLOR as recorded above. Scaled content that scrolls remains an accessibility adaptation,
not a source-text2 match. The lead must recheck captures after actual corrections.

At390×844 image border extents are y280..476 and493..689; idle source
y822..1486 and1550..2214 divided by3 gives y274..495.33 and516.67..738.
First tile starts6dp lower, extent196dp is25.33dp shorter, and second tile
finishes49dp higher. PM16dp grid gaps govern current layout; source21.33dp
gap is recorded, not substituted for that authored requirement. Selected woman
has a visible white rectangular source-crop background within blue fill;
correct woman has the same rectangle within green fill. Incorrect boy shows
white crop corners within red fill. These are visible art integration defects.

Match390×844 borders span231..307,325..401,419..495: each tile72dp face plus
4dp edge,18dp row space,24dp column gap, matching PM geometry. The source
audio-match first tile starts772/3=257.33dp,26.33dp lower; older text-match
first tile starts approximately718/3=239.33dp,8.33dp lower. Row counts and
copy differ by authored fixture. Compare against the matching text exercise
before changing its vertical anchor from an audio-exercise still.

| Golden | Reference | Measured delta/state | Severity / suggested exact owner fix |
|---|---|---|---|
| ex_image_idle.png | sc_f691b4ff | I1-G1; CHECK/HINT instead of archived CONTINUE, supplied PM CHECK guard | Layout review; image_choice.dart artHeight/vertical composition; preserve HINT behavior |
| ex_image_selected.png | sc_b7f6add9 | I1-G1 + I1-A1; PM dark selected ink; woman fourth instead of first, authored stable fixture | Art defect; image_choice.dart/ReferenceArt background treatment without modifying original source |
| ex_image_correct.png | sc_925a4125 | I1-G1 + I1-A1; PM green fill/ink/sparkles; existing feedback retains geometry | Art defect; same scoped art treatment |
| ex_image_incorrect.png | sc_3b88d8f1 feedback only | I1-G1 + I1-A1; feedback #FFDFE0 is confirmed; incorrect image tile source missing | Art defect; reconcile tile colors under G-COLOR, no source parity claim |
| ex_image_selected_360_text1.png | sc_b7f6add9 | border y280..467/483..670, width155dp; I1-A1, scroll may expose bottom content | Geometry/art review; image_choice.dart |
| ex_image_selected_430_text1.png | sc_b7f6add9 | border y280..495/511..726, width190dp; I1-A1; scalable extent differs from390 | Geometry/art review; image_choice.dart |
| ex_image_selected_360_text2.png | sc_b7f6add9 structure only | rows402..608/625..831; lower selected woman initially below viewport; scroll adaptation, no source text2 | Source gap; prove selected content remains scroll-reachable in behavior checks |
| ex_image_selected_430_text2.png | sc_b7f6add9 structure only | rows402..637/654..889; selected woman partly below viewport, I1-A1 | Art defect; same scoped treatment; retain readable scrolling |
| ex_match_idle.png | sc_ceb894f1/sc_5b3164cb | I1-G2; three authored text rows; PM72+4/18/24 geometry matches | Vertical composition review; match_pairs.dart top padding against matching source |
| ex_match_selected_right.png | sc_5b3164cb structure only | right-first blue selection visible; PM fill/ink; I1-G2; selected-right source absent | Source state gap; preserve regression and authored target |
| ex_match_matched.png | sc_5b3164cb | both stable-ID pair tiles green at40ms; PM #D7FFB8/#235B00 versus older #DBFFBB/#A9EE73; I1-G2 | PM state target; final disabled source absent; preserve lifecycle checks |
| ex_match_wrong.png | no wrong-pair source | local red on both tiles mid300ms shake, no global feedback; I1-G2 | Source state/motion gap; PM target, no invented source proof |
| ex_match_idle_360_text1.png | sc_ceb894f1 structure | extents231..307/325..401/419..495, tile widths152; I1-G2 | Vertical composition review |
| ex_match_idle_430_text1.png | sc_ceb894f1 structure | same y extents, widths187; I1-G2 | Vertical composition review |
| ex_match_idle_360_text2.png | sc_5b3164cb structure | left extents316..393/411..488/506..583; right labels grow independently and remain readable | Source text2 gap; no clipping exception proof from pixels |
| ex_match_idle_430_text2.png | sc_5b3164cb structure | left extents316..393/411..488/506..583; right grows for Vietnamese wrapping | Source text2 gap; retained project adaptation |

Contact-sheet evidence opened: `/workspace/tools/i1-palette-qa/i1.png` and
`/workspace/tools/i1-palette-qa/controls.png`; image selected and match idle also opened
at their original390×844 sizes. These temporary inspection artifacts are not
new application assets. Every file was sampled separately before the overview.

## Existing-golden source mappings and palette-region improvement

Only the four existing core_lesson_image goldens correspond to changed I1
renderers: ready→sc_f691b4ff; selected→sc_b7f6add9;
correct→sc_925a4125; incorrect→sc_3b88d8f1 for feedback only. All other
legacy goldens must return unchanged after restoring/scoping legacy defaults.
These measured uniform-role RGB differences provide a reproducible color
comparison; they are not a whole-image similarity score. The lead must verify
final regenerated PNG regions before asserting these candidate improvements.

| Old uniform role | Matching source role | Old mean absolute ΔRGB / expected exact-source candidate |
|---|---|---|
| surface #FFFDFE, all four core image fixtures | #FFFFFF, source(5,1278) |1.000 /0.000|
| idle border #E7E5E7 | #E5E5E5, idle source(296,1552) |1.333 /0.000|
| selected fill #E1F4FF | #DDF4FF, selected source(541,1252) |1.333 /0.000|
| correct fill #D7FFB8 | #D6FFB8, correct source(66,1255) |0.333 /0.000|

Use comparable uniform interior/border patches rather than misaligned whole
screens with different choice order, copy and safe-area content. Each reported
mean is the arithmetic mean of absolute channel differences; both patch
coordinates and final PNG values must accompany the lead's gate receipt.

## Gate limits

Four initial real RED assertions are recorded by the worker at
`/workspace/tools/coc-phase-a-i1-red.log`. Eleven behavior cases and sixteen
I1 golden fixtures were present; QA did not rerun or certify their execution.
The previously recorded candidate floor is510 passes with five known native
Rive failures, subject to the lead's fresh receipt and any further test additions.
No weakening/skipping/deleting tests or changing comparator tolerances allowed.
Neither golden inspection nor document checks establishes device, native
speech, browser, cloud, full-suite or end-to-end success.

Still-image source timing is UNKNOWN. PM100/150/200/300ms targets remain
authored; [official Duolingo animation article](https://blog.duolingo.com/streak-milestone-design-animation/)
describes iteration but does not establish these precise press/match durations.
No source pressed, settled-disabled pair, wrong pair or text2 capture is present.
