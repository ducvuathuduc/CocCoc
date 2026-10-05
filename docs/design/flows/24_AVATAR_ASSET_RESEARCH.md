# Avatar builder research status

2026-10-05: live Gummble flow `8fa53138-ae46-4d6c-a7d3-75c0493dec5c`
returned12 ordered screens; all12 were visually inspected before deciding whether
the original builder could be implemented. Flow
`e47219c8-2442-423f-95fe-6d34ad03841f` has15 catalogued steps; its full visual
deconstruction remains pending. Neither flow is implemented or marked complete.

The12-step archive shows a horizontal category strip, a fixed large character
viewport, selectable circular swatches and native choices. Visible categories
include body/skin, face, hair, glasses, mask, hat, shirt and background. Preview
area is roughly296logical pixels high; the list scrolls independently. Changes
include dark/pink skin, alternate hair, clothing and a green background. The final
step returns to Profile. These screenshots establish those recorded states, not
every selectable combination or an original animation rig.

Primary reference: [Duolingo avatar creator](https://blog.duolingo.com/avatar-creator/).
It describes customization and profile entry, but supplies no reusable Flutter
asset export. The public first-party client bundle contains user-specific avatar
configuration routes; no public original rig/configuration export was established.
No private user configuration was requested. Agent Reach's documented GitHub CLI
search, `gh search repos "duolingo avatar builder" --limit5`, returned no matches.

Existing makerInLesson Rive assets animate lesson characters. Their verified
`character_statemachine` inputs do not establish a composable avatar editor or
crying-Duo rig. Keep using existing original exports only for their mapped poses.
The new course-removal Duo is a byte-intact source still; its motion is unresolved.

Next work: finish the15-step visual deconstruction, locate an original public
layer/rig export, then implement only configurations with traceable visual output.
Do not replace this with invented character parts or mark billions of combinations
or archived timing as reproduced.
