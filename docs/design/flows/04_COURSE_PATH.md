# Course and learning path analysis

Analyzed 2026-10-04 before UI implementation. Sources are ordered live Gummble MCP flows: [Completing a lesson](https://gummble.com/apps/duolingo-ios?tab=flows&flow=068dbdc0-5d4a-4de2-a477-b0e5c8cdc3e8), frames01/02/22; [Courses](https://gummble.com/apps/duolingo-ios?tab=flows&flow=1320dade-dca0-48cc-ac06-28573d375d6b), frames01–03 inspected. Byte-original files/IDs/dimensions live in references/lesson/manifest.json and references/courses/manifest.json.

The former archive has hearts and a green beginner unit; the latter has energy and a blue advanced unit. They represent different archived states, not evidence of current product rules. The preview starts at the beginner French unit matching onboarding, with local fixture counters. Production course rules remain in [SRS](../../product/SRS.md).

| Screen/state | Layout in approximately390 logical pixels | Actions and transitions |
|---|---|---|
| Beginner path01 | Safe area; header about64h, four status items;16px margins; green unit banner78h/r16/4px base; title20 bold, section14; scrolling curved path | Flag opens course switch; flame opens streak; gems opens shop; hearts explains fixture; banner guide opens without advancing |
| Node/default | Oval70×60 with8px base,24px star; current node100px ring with rounded arc; Start speech badge; alternate horizontal offsets | Current→anchored green lesson popup. Locked→prerequisite explanation. Completed→replay. Background tap dismisses |
| Node popup02 | Green r16 panel within26px horizontal margins; arrow at top; title20, lesson16; white tactile CTA | Start creates exactly one local lesson. Resume restores draft; no duplicate completion award |
| Path22 after result | Same path; counters/active arc changed; Continue badge | Result receipt updates mock path once. Replay does not move frontier |
| Course switch02/03 | Header retained, white expanded panel, scrim over path; flag course tile, Add course; score progress card; optional new-course icons | Current flag closes panel; Add opens existing language choices in a local picker; score opens informational sheet. Math/music/chess are outside frozen language-learning product scope |

Bottom tabs use original art from path screenshot and keep state/scroll independently. Product tab semantics remain Home/Practice/Quests/League/Profile per [inventory](../../product/SCREEN_INVENTORY.md); archived six-tab experiments do not replace frozen product navigation. No generic dashboard.

Guide: use unit banner color/header, native phrase rows and audio controls; matching guide reference must be inspected before implementation. Motion: tactile presses, node ring change, anchored popup scale/fade, independently animated original path character timeline when source identified. Screenshot positions are measurable; archived animation duration cannot be established from still frames. Reduced motion removes translation/loops and preserves final state.
