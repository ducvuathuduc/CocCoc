# English Score information

Analyzed2026-10-06 using live Gummble MCP Score information
`d70eeb1a-cca9-47f3-b55d-1817937a4c6f`(3) and More about score
`0f480cf3-2057-412c-999a-fe9a54bed855`(4). Ordered original screen IDs/URLs remain
in [source index](../references/ORDERED_FLOW_INDEX.json).

`sc_b77f2cd860ba42beba67a79ccdaa31ad`: course popover over the path; selected
course flag, horizontal course choices, white rounded Score card, current/next
values around a green progress bar, gray score caption and MORE ABOUT SCORE.
Only language content is implemented. Existing English selector/add-course and
section entry remain available.

`sc_b0a8a3f37157451783e5135f760faa0f`:49px close/share row; centered course flag
and large current score; horizontally scrollable bands with blue selection and
3px underline; independently scrolling body;18px gray explanatory text with
bold CEFR fragment. Three native speech bubbles show small original Junior,
Lily and Vikram portraits, blue audio control, study sentence and translation.
The French/English source examples are adapted to authored English/Vietnamese
fixtures. Selecting a band reads information without altering current progress.

`sc_2a653020036145dca923b9a6629a92fb`:130–160 band selected; original lock icon,
gray rounded availability notice, C1/C2 description and no example bubbles.
The older source variant uses labels10–20/20–30/115–130; the newer source and
[official Duolingo Score article](https://blog.duolingo.com/duolingo-score/)
use inclusive boundaries0–9,10–19,20–29,30–59,60–79,80–99,100–114,115–129,
130–160. The implementation selects these inclusive bands. This educational
progress fixture does not represent a certified English Test result.

The official article and primary engineering explanation of
[Rive character state machines](https://blog.duolingo.com/world-character-visemes/)
were checked during this continuation. Rive requires authored animation inputs
and aligned audio timing; adding the runtime alone cannot reproduce speech.
Source screenshots expose an audio button, not its original speech/viseme file.
Local playback state is deterministic, single-active and lifecycle-safe; real
speech/audio is separately tracked. The share control opens a local copy card;
no archived share sheet or external LinkedIn publishing flow was supplied.

Current-band text and selected-band information are distinct: selecting a future
or locked band never describes that band as the learner's current proficiency.
Tabs expose selected semantics and scroll the current band into view on entry.
Close/background/unmount stop local playback. Clipboard commands reject duplicate
in-flight actions, invalidate stale completions and clear feedback on a new share
dialog. The local learning producer caps this educational Score at160 while XP
and completed lessons continue increasing. Live progress remains server-owned.

Original illustration sources `score-information.png` and `score-unavailable.png`
are byte-identical copies of the named saved MCP frames. Controls and sentences
are native widgets, not rasterized screenshots. State tests/captures and exact
capability limits belong in the continuation QA report.
