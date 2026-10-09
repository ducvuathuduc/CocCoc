# Duo motion evidence and implementation task

Date: 2026-10-04. User instruction: reproduce the original reference appearance, sizes, fonts, tactile buttons and smooth Duo motion; keep onboarding/login on mock data first.

Gummble MCP was rechecked against `duolingo-ios`, version 800 (Dec 30, 2025). It supplies screen PNGs and ordered flows. Its exposed tools do not supply animation timelines or source motion files. The still-frame screen analyses remain [onboarding](01_ONBOARDING.md) and [login](02_LOGIN.md).

Duolingo documents [Rive state machines for interactive characters](https://blog.duolingo.com/world-character-visemes/). The official [rive-flutter runtime](https://github.com/rive-app/rive-flutter) is suitable for an authored `.riv`; choosing the runtime alone cannot produce the original Duo poses.

Further inspection found original vector timelines in the unauthenticated public web client's [app bundle](https://d35aaqx5ub95lt.cloudfront.net/js/app-0de7c4e4.js). The bundle itself names onboarding states and frame ranges. These supply real articulated wing/eye/body/book/pencil motion, so a whole-image bobbing approximation is unnecessary for these five states. Current web assets are not proven identical to the archived iOS animation.

| Local asset | First-party URL | Composition / source timeline |
|---|---|---|
| duo-wave.json | [43931](https://d35aaqx5ub95lt.cloudfront.net/lottie/funboarding/ed177eb496e0280c95367b83efb512d2.json) | 916×939, 60fps; wave 600–755, web resting frame 635 |
| duo-idle.json | [68839](https://d35aaqx5ub95lt.cloudfront.net/lottie/funboarding/679e4fbde0d7bb55821bcfc215744dbb.json) | 645×486, 60fps; idle 0–220, scribble 220–360 |
| duo-pencil.json | [85814](https://d35aaqx5ub95lt.cloudfront.net/lottie/funboarding/a3c85b28676df146ce9d53540978f3e5.json) | 645×486, 60fps; pencilRaise 0–213, web resting frame 25 |
| duo-celebrate.json | [31488](https://d35aaqx5ub95lt.cloudfront.net/lottie/funboarding/4e5c13bf6b0be65006ae027f066362fc.json) | 916×939, 60fps; celebration 759–965; clipboard 966–1079 |
| duo-reading.json | [DUO_BOOKS / 92846](https://d35aaqx5ub95lt.cloudfront.net/lottie/pathCharacters/dc7f54a73e6340a16176a91bf0d18b83.json) | 1080×1080, 60fps; 0–365; book page, arms, pupils and eyelid layers |

Implementation: pinned `lottie` 3.6.1 ([runtime source](https://github.com/xvrh/lottie-flutter)); cached local compositions; explicit source frame segments; Canvas clipping/scaling into each measured illustration region; controller lifecycle and route visibility respected. Reduce Motion uses the archived still pose. Visual captures also select that still pose explicitly, so layout metrics are separate from motion verification. Buttons retain a 4 logical-pixel tactile press; smooth release and progress changes use short Flutter animations.

The player is MIT licensed; the first-party artwork has no established open-source asset license. Source files are kept byte-intact for this user-requested local reference reproduction. No app-store publication, asset relicensing or external distribution is part of this task. The GetStream SwiftUI recreation and Rive community Eddy example were inspected as alternatives; neither was substituted for the requested Duo assets.

Verification must establish playback/frame differences, paused/reduced-motion behavior, disposal, no font/layout regression, and Android runtime rendering. A pixel-perfect or 100% motion equivalence claim requires matching source video/timeline for the archived iOS flows; static screenshot error metrics cannot establish it.

Additional path sources identified2026-10-04: original [DUO_JUMPFLAP](https://d35aaqx5ub95lt.cloudfront.net/lottie/8bb6c897c3f01efa2cbd0c138772ef67.json),1080²/60fps/frames0–220, drives the native path character through its measured illustration viewport. Original [DUO_TWIRL](https://d35aaqx5ub95lt.cloudfront.net/lottie/01a1427cc5613179ea3d7568a5f7445b.json),1080²/60fps/frames0–280, is identified and retained but not activated on a screen. Both keep source bytes and hashes in asset provenance. Tests parse all seven compositions and establish advancing path frames/reduced-motion fallback; no new Android path-motion or physical frame-rate measurement is claimed. Other result/call character artwork remains static where a matching archived timeline has not been identified.

Primary motion research rechecked2026-10-06: [Duolingo's designer/developer
handoff](https://rive.app/blog/creative-technologists-duolingo-s-solution-to-the-designer-to-developer-handoff)
describes authored Rive state machines and explicit input specifications,
including reward interactions. [Lily Video Call](https://framer.rive.app/blog/duolingo-s-ai-powered-video-call-brings-lily-to-life)
describes modular head/body machines, expression and viseme control in an internal
call asset. These articles establish the production workflow; they do not provide
a downloadable original call rig or the missing crying/walking Duo timelines.
The available in-lesson Lily rig is therefore not evidence of equivalent call
motion. Community recreations were not substituted or labeled as original.
The shipped public avatar export and ten in-lesson character exports remain
separate, verified assets. Exact archived motion still needs the matching source
timeline and a frame-level comparison.
