# English course navigation — 2026-10-09

Tasks UI-COURSE-040, UI-GUIDE-041, UI-SKIP-042 and UI-COURSE-QA-043
continue the existing [frontend plan](../../agent/FRONTEND_REMAINING_PLAN.md).
Feature-first manual Riverpod MVVM and pinned dependencies are preserved.

Live Gummble MCP returned 21 ordered occurrences across these archived flows:

- [Choosing a section](https://gummble.com/apps/duolingo-ios?tab=flows&flow=31460692-382a-4403-884b-847cc7dd715c): catalog → existing path.
- [Sections](https://gummble.com/apps/duolingo-ios?tab=flows&flow=b3ad8692-1624-4e6d-9e56-7bdda74127ae): path → catalog top → section eight/Daily Refresh.
- [Section details](https://gummble.com/apps/duolingo-ios?tab=flows&flow=4d849f99-ddfb-45e1-b14b-0cf990cce168): catalog → blue hero/example → CEFR expansion → grammar expansion.
- [Unit guidebook](https://gummble.com/apps/duolingo-ios?tab=flows&flow=831dee9f-9353-42ad-ad79-2c81a1cad5ad): path → Bea header → key phrases → blue tip/Oscar illustration.
- [Skipping a unit](https://gummble.com/apps/duolingo-ios?tab=flows&flow=e5507c39-9c84-43a8-856c-8829498d35a6): target path → Duo intro → wordbank → incorrect answer → last-heart warning → failed/pass result → selected path.

Thirteen byte-intact source PNGs are bundled. Native text, score badges,
progress, cards, grammar expansion, word tokens and buttons sit over extracted
illustration regions; screenshots are not used as screen backgrounds. Header
and main regions use the original aspect ratio. Normal text uses local
DuolingoSans; controls reuse tactile design primitives and native semantics.

## State and commands

The eight English section samples and eight unit guides are authored reading
fixtures, with Vietnamese translations. Their grammar/CEFR examples are
English adaptations of archived French layouts, not a complete course service.
Section details and guides use their validated route arguments; malformed IDs
show a product return state instead of silently becoming section/unit one.

Catalog browse and cancellation preserve XP, score, streak and wallet. A
separate immutable local target projection is updated only by an acknowledged
completed check. Check providers carry `(unit, section, sectionCheck)` so a
section result cannot unlock another unit or leak into another course target.
Duplicate acknowledgement/close and fresh-entry disposal are tested. Five
local hearts decrease once per incorrect check, retain selected tokens and
show the final-heart warning once. Correct feedback alone advances questions.

Higher-target path exercises review that target's guide phrases using scoped
node IDs and guest/practice receipts: they do not issue ranked XP or advance
the baseline lesson path. Baseline Section 1/Unit 1 continues its existing
lesson/reward pipeline. This prevents browsing prototypes from relabeling the
same reward-eligible lesson as another course. Audio has the defined existing
unavailable state; translations remain readable after a failed listen action.

## Measured reference and limits

Catalog cards use 2px borders, 20px corners, 173px short heroes and a 244px
section-eight hero. Large text switches to intrinsic content rather than
overlapping the illustration. Detail hero uses blue and a right-aligned Duo;
CEFR/grammar states keep independent native expansion. Guide header becomes
sticky on scroll; key phrases have dotted native underlines and translation
sheets. English copy changes wrap lengths, and real local counters replace
the source's historical progress. Daily Refresh remains locked.

The unit check reuses original Lin Rive reset/correct/incorrect inputs during
answer feedback, with destination/question identity to reset on retries and
new questions. Its other poses use original stills and authored 220ms native
transitions; reduced motion is immediate. Original private Duo timelines and exact
archived easing are not established by these stills. Source XP/elapsed-time
claims are replaced with actual local metrics and CONTINUE. Existing five-tab
shell/path is reused across archived versions; source six-tab arrangements,
middle-section artwork variants and full curriculum/server settlement are
separate acceptance scope. These are verified mock UI states, not production
backend/device certification or a 1:1 motion claim.

The existing character assets and state-machine inspection are recorded in
[asset provenance](../../../apps/mobile/assets/PROVENANCE.md) and
[original-character-assets.json](../qa/original-character-assets.json).
[Duolingo's animation article](https://blog.duolingo.com/world-character-visemes/)
describes state-driven reactions; [Rive Flutter documentation](https://rive.app/docs/runtimes/flutter/flutter)
documents its runtime and resource management. These sources were rechecked
2026-10-09. No runtime upgrade, new speech input or invented lip-sync is added.

[QA receipts](../qa/COURSE_FINISH_REPORT.md) record captures and commands.
