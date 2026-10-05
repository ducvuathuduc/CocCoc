# English Adventure: Oscar Finds a Passport

Scope: authorized mock frontend; language learning only. Reference is Gummble
`7343592e-fbc9-49a6-ba14-72fa2f5c238c`, 13 ordered steps. MCP details refreshed
2026-10-04. Original images are in the [ordered catalog](../references/ORDERED_FLOW_INDEX.json).

Before implementation, inspected steps 2–11 and 13 individually: path entry,
objective, airport exploration, passport choices, selected/correct choice,
passport collection, Lucy's reply, object grid, correct passport, completion.
English sentences replace the archived French exercise content intentionally.

| State | Source | Native interaction |
| --- | --- | --- |
| Objective | `sc_1421e947287040c184208ce9d653adf8` | Start/close |
| Explore | `sc_1c39676a8cf34fcab9c5b4abd99359aa` | Passport hotspot with semantic label |
| Identify | `sc_8c6d22cb69094eda97a11098e1b2cd2d` | Two native answer buttons; wrong feedback retries |
| Collect | `sc_89c7776dbb49407e99b9286c0f082060` | Continue; original collected-passport illustration |
| Return | `sc_84225233affe4c679685e1dccc3b369f` | Four native object cards; original icon ROIs |
| Completion | `sc_146aa46a531445ba8902575da41351c4` | Accuracy from local attempts; leave/replay |

1179/1180×2556 source: logical 390-wide viewport, top safe area 59, bottom 34.
Only scene/character/object illustration ROIs are painted. OS chrome, speech,
panels, labels, choices, and navigation remain Flutter widgets. Scrollable panels
must fit widths 360/430 with text scale 1/2; keyboard is unnecessary.

Pause/close keeps the in-memory stage and input; explicit replay resets it.
One correct answer cannot advance twice; wrong input stays until retry.
Award is a local preview receipt, not a server XP write.

Motion evidence: source screenshots establish still poses only. Original Oscar
makerInLesson Rive is an exercise character and does not prove the top-down
walking rig. Do not substitute that rig or infer original walk/viseme timings.
Native panel transitions honor reduced motion; original airport walking and
audio exports remain unresolved. [First-party feature description](https://blog.duolingo.com/adventures/)
confirms object exploration and contextual language choices.
