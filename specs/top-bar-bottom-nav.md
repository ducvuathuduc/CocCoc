# Top stats and bottom navigation — sprint I

Root claim UI-SPRINT-I-SHELL. Gummble MCP unavailable; saved archived iOS
2026-10-04 references: lesson/01 sc_e793f7fdfb3349cc8a32a78d9648ee07;
practice/04 (Practice manifest); expanded Energy flow15d44bfd-9a78-4987-88e2-6c6fd020144c
frames01/02 sc_28609e32a15f4b3a96a5607c40c81d87/sc_365781ef5eb74a1b93a6dd472006b367.

Four top controls: course flag/score, streak, gems, energy. Native values
project current controllers through AppShellRepository -> Mock -> Riverpod.
No client reward changes; unlimited energy is repository-formatted infinity.
Native tooltips and spoken values come from the same repository projection.
Use source graphic crops only; preserve their aspect ratios. Energy/01 supplies
the inactive flame crop(343,212,77,78), with no text. Repository activity
metadata controls the gray/orange variant; the local mock uses its completed
lesson fixture, never the device clock. These are presentation states, not
production streak rules. Top inset24dp follows Energy/01 margins. Source pink
energy sample expanded Energy/02 (1070,380) #FF86CD, present in palette.
Unlimited energy uses existing source-backed purple token.

Stat controls have minimum48dp hit areas, 20dp bold value text, source-sized
24–30dp icons; wrap at text2 rather than clipping. Tab border2dp, radius14dp,
selected fill/border existing reference tokens; each icon keeps its source
ratio in a centered38dp box. Five state-preserving branches remain
Home/Practice/Quests/League/Profile, as frozen in04_COURSE_PATH; archived
six-tab experiments do not replace product navigation. This is an explicit
source-variant difference. Existing quest onboarding hides the nav.

Existing selection transition140ms and press120ms/ease-out are local mock
timings from project components; exact archived motion remains UNKNOWN from
still captures. Respect reduced motion. Test tap/cancel, selection settling,
repository-only override, current values, branch return and no exceptions.
360/430 × text1/2 goldens; comparison scopes the two shell strips, with source
counts/course variant recorded. Whole-screen body belongs to later slices.

Per-screen acceptance follows ticket40 SPEED FIRST: clean analyze, targeted
tests, own goldens, opened comparison, commit and DONE line. No whole-sprint,
physical device or full-suite claim.

Official motion research checked2026-10-10:
[Duolingo core tabs redesign](https://blog.duolingo.com/core-tabs-redesign/)
shows consistent tab craft and visual iteration, but gives no tap/selection
millisecond values. [Animating the streak](https://blog.duolingo.com/streak-milestone-design-animation/)
explains iteration on timing and energy and includes a milestone animation; it
does not specify shell interaction timing. These primary references do not
justify claiming120/140ms as exact Duolingo timings. Saved app captures remain
the visual source; project motion timing stays explicitly a mock approximation.
