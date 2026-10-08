# Original avatar builder

2026-10-05: both Creating an avatar variants were retrieved through live Gummble
MCP and visually inspected: [12 ordered screens](https://gummble.com/apps/duolingo-ios?tab=flows&flow=8fa53138-ae46-4d6c-a7d3-75c0493dec5c)
and [15 ordered screens](https://gummble.com/apps/duolingo-ios?tab=flows&flow=e47219c8-2442-423f-95fe-6d34ad03841f).
The ordered IDs and original PNGs remain in the existing
[flow index](../references/ORDERED_FLOW_INDEX.json) and catalog cache. Completed
research and native customization must be reused for each archived variant.

## Verified assets and controls

Agent Reach's GitHub CLI discovery (`gh search repos "duolingo avatar"`) located
the published [avatar configuration](https://github.com/wishflow/wishflow-tools/blob/master/apps/duolingo-avatar/assets/avatar_builder_config.json).
Its asset URL led to the original [Duolingo Rive export](https://avatars.duolingo.com/avatar-builder/avatar_builder_25_sept2025.riv).
The native app bundles this original file, the published default configuration
and 16 selected/unselected category SVGs served by `avatars.duolingo.com`.
No third-party application code or private user configuration was copied.
[Provenance and byte hashes](../references/AVATAR_ASSETS.json) cover all18 files;
`node tools/scripts/avatar-asset-audit.mjs` verifies them and the configured choices.
The Rive file is1,648,636bytes, SHA-256
`8eb0783dc4354204723e927bb987e6d3ad78397abf6ec200eab5007b83b306a7`.

Actual native inspection established artboard `MainAvatar`, bounds1000×250,
state machine `SMAvatar` and27 typed inputs. User controls address only configured
number inputs; `bounce_trig` commits changes using the original transition.
`ENG_ONLY_Zoom` and `ENG_ONLY_Animation` control the original display/animation;
no invented animation input or hand-drawn avatar layer is substituted.

| Category | Published choices |
| --- | --- |
| Body | 15 skin tones, 6 body shapes |
| Expression | 13 eye colors, 57 expressions |
| Hairstyle | 16 hair colors, 72 hairstyles |
| Accessories | 8 glasses colors, 7 glasses, 3 face details, 7 earrings, 4 nose rings |
| Facial hair | 13 colors, 7 styles |
| Headwear | 9 colors, 12 styles |
| Clothing | 9 colors |
| Background | 24 colors |

These are282 configured choices, not a claim that every possible combination or
every historic item was verified. The face-shaped fifth icon is mapped to the
published facial-hair category; it does not establish a separate mask category.

## Native layout and behavior

The source establishes a49px normal header, a fixed preview region up to296px,
a54px horizontal category strip,56px palette options and independently scrolling
three-column choices. Native Flutter text and tactile controls use bundled
DuolingoSans, the source SVGs, blue selection outlines and shared design tokens.
The header grows at large text sizes; choices and later categories remain reachable
at320px/text2. Original Rive previews are cropped centrally from the wide artboard.
Grid choices are built lazily; controllers are freed as widgets unmount. One
reference-counted decoded file is shared by independently owned controllers.

Editing starts from saved values. Selecting changes only the draft. Close/system
back discard it; DONE commits a changed configuration. Reopening starts from the
committed values. Profile, the full Profile editor and own-profile QR use the same
saved avatar; another user's QR must not show this avatar. Profile fields include
first/last name, username, password entry, email and phone; opening Password and
returning preserves the unsaved Profile draft.

The main builder uses original animation and bounce. Option tiles and profile
images use the original static mode. Lifecycle, TickerMode and reduced motion
pause animation without replacing the chosen avatar. A native pixel regression
found that merely stopping the timeline could freeze closed eyes; selecting the
export's static animation mode fixes it while preserving configuration.

[Verification report](../qa/AVATAR_PRODUCT_SURFACE_REPORT.md) links native captures,
behavior tests and refreshed web evidence. Both source sequences retain separate
coverage entries. The newer public2025-09-25 export does not establish exact older
iOS item mapping, every archived Profile layout, route duration or frame timing.
Those differences are reconciled separately; the obtained rig and working editor
are no longer recorded as missing. Crying Duo, Adventure walking and Max speech
rigs remain outside this avatar export's verified capabilities.
