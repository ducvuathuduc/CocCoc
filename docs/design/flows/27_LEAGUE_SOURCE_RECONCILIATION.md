# League ranking — 2026-10-08

Continuation UI-LEAGUE-036 adds the source historical result, Silver promotion
and 40-gem acknowledgement. The fixture is immutable; acknowledgement does not
promote current membership, credit gems or rewrite learner XP. Result → promotion
→ reward → return is bounded/idempotent; closing, system Back and reopening are
tested through the real router. Missing results and no-promotion/no-reward,
demotion and Diamond fixtures are handled separately. Auto-disposed view state
starts at the result when history is reopened.

Original source artwork remains byte-identical. The source-sized result frame
uses a 370-logical minimum on roomy phones, Silver art preserves 1179:1010,
Close overlays the safe area and Continue stays pinned while text2 content
scrolls. Three native state captures and the final behavior/analyzer gate are
recorded in [the finish report](../qa/SESSION_FINISH_REPORT.md). These historical
UI variants do not implement server settlement or the private trophy timeline.

Assigned slices: UI-LEAGUE-034 and UI-LEAGUE-035 in
[continuation plan](../../agent/FRONTEND_REMAINING_PLAN.md). Canonical design and
state contracts remain [DESIGN](../DESIGN.md) and
[COMPONENT_STATES](../COMPONENT_STATES.md).

Fresh Gummble MCP retrieves both ordered iOS Leaderboard journeys:
[11 steps](https://gummble.com/apps/duolingo-ios?tab=flows&flow=95cfcf38-001a-4432-b49e-b4282f9703a4)
and [6 steps](https://gummble.com/apps/duolingo-ios?tab=flows&flow=30488f3a-22f6-4c25-a883-db83e851d5cd).
These archived captures show different shells and lesson gates. Neither is
treated as the current Duolingo product rule or our server eligibility contract.

| Source | Observed layout/state | Native implementation / remaining scope |
| --- | --- | --- |
| sc_720ee9469bde455f992879eb3973facf | Silver title at left, orange6days, previous/current/locked trophy strip; ranks1–7, three medals and green learner row | Joined Bronze fixture uses this header hierarchy and native row geometry. Original medal source bytes are bundled. |
| sc_c6e694401b1c414c8fdfcbaf01f34428 | Same header while ranking scroll begins at rank3 | Header stays pinned at ordinary phone sizes. The keyed list restores its offset after a foreign Profile visit. Large text/short windows permit the header to scroll. |
| sc_259ab70b5de5483191ff40b507c9b8f0 / sc_8852c8a028b046a3bfa9383fa20623e3 | Locked illustration and8/9remaining lessons | Native original illustration/count typography; the authorized local prerequisite is one completed lesson. A visible Start a lesson returns to the learning path.8/9lesson product eligibility remains unverified. |
| sc_98120696dc1a45b4a33fa1ebf0599891 | Duo on podium, welcome text and Continue | Native eligible Welcome with original source crop and Continue membership action. Still image provides no original timeline. |
| sc_8218b579af9644988b58eabc20dd1501 / sc_66df6038334b48a4b752bd9d9e9a0eb4 / sc_859527b88dda4524aa4131de8fa2a9aa | Last-week result, Silver promotion,40gems | Settlement/promotions/rewards remain open; no countdown, gem credit or server claim is fabricated. |
| sc_ad532eacf33f44e2a5fa6371d913ab1f | Diamond ladder, event bubble, multi-year streak/status adornments | Separate variants remain open. |

The source ratio is1179/390. Original medal colored bounds are x28–101 and
y887–975/1094–1182/1301–1389; complete crops include four pixels of padding.
The207pixel row step gives approximately69logical pixels. Native controls use
45pixel portraits,20pixel bold names,19pixel XP and the original Duolingo font.
Between-row borders and the former generic centered trophy/sample caption are
removed. Bronze and locked trophy crops retain their source aspect ratios.

The immutable manual Riverpod provider derives seven authored foreign summaries
and the learner. XP sorting is descending with stable fixture order for ties.
Opening or returning from a Profile never credits XP. The current local Bronze
membership is preserved; archived Silver totals, names, status flags and15-place
promotion cutoff are not copied into product logic. The6day label is an authored
mock fixture, independent of the client clock. Foreign public Rive avatar choices
match their own Profile fixtures; the learner uses the saved avatar and separate
status action. All small list portraits are static and release their controllers.
Each row is keyed at the list delegate boundary so XP reordering retains its
mounted avatar state. Decorative rank/name/XP semantics are suppressed; a foreign
row exposes one profile action, and the learner exposes profile plus status.

At320/text2, XP can move below the name, keeping large values readable. The
original shell here has six tabs; the app continues its authorized five-tab shell.
Medals/trophies are source stills. No private promotion/event timeline or100%
motion equivalence is claimed from screenshots.

UI-LEAGUE-035 uses the locked skeleton artwork and native orange remaining count.
The eligible source podium crop is `(145,500,890,850)`, excluding source labels;
native headline/copy/Continue render separately. Entry actions scroll into view
at320/text2 and short desktop viewports. Completing a local lesson exposes the
welcome state without joining; Continue opts into the fixture once and never
credits XP, modifies lesson progress or creates a reward receipt.

Source-sized captures measure the locked figure at approximately290logical
pixels wide and the podium crop at294. Original source bytes are unchanged;
the entry surface is white to avoid a rectangular seam around the source crop.
The locked figure has equal flexible space above/below its text group, with a
32logical art-to-heading gap. Welcome uses native24logical bold headline,
20logical body text and a6logical text gap. Actions have16logical horizontal
and bottom padding. The five-tab native shell has a different height from the
archived six-tab shell, so absolute bottom coordinates are not equivalent.

Verification: [review regressions](../qa/league-review-red.log) reproduce avatar
state replacement and duplicated spoken labels; [focused pass](../qa/league-review-green.log)
covers20tests. [Native capture receipt](../qa/profile-source-complete-captures.log)
renders26states and checks entry interaction/large text. The
[full gate](../qa/profile-source-complete-gate.log) covers363tests; the final
spacing polish is additionally exercised by the capture/entry rerun. Actual
original Rive portraits render in the ranking and owner/status captures.
