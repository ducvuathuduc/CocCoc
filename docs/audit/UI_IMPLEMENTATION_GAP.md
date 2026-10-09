# UI implementation versus integration gap

Source baseline 2026-10-09. [Machine source inventory](INPUT_INVENTORY.json), [control inventory](SCREEN_CONTROLS.json) and [historical flow checklist](../design/qa/FLOW_CHECKLIST.md) identify actual files/routes. `apps/mobile/lib/main.dart` owns the router; a separate `app/router.dart` does not exist. Feature roots are account/auth/learning/onboarding/practice/progress and core/design. Preserve them; do not regenerate the project to match a sample tree.

| Actual family / paths under `apps/mobile/lib/features` | Implemented evidence | Missing / acceptance gate |
|---|---|---|
| onboarding / auth | step persistence, login/recovery/reset/saved-account UI; mock and Appwrite Auth repositories | Real configured account/OAuth/session recovery and permission proof, P3. |
| learning | path, sections/unit guide/skip, 12 exercise renderers, check/feedback/pause/results, local deterministic explanations | Server sessions/grading/revision authority, 13th comprehension category mapped to existing storyQuestion, durable restart journal, P4/P5. |
| practice | mistakes/words/listen/speak, stories/radio/roleplay/adventure/challenges | Due-word server schedule, real audio playback/microphone/Live/scoring; typed simulations are not speaking assessment, P6–P8. |
| progress | XP/streak/quests/leagues/profile/friends/feed/shop/energy/achievements/year-review/widgets | Ledger/streak/timezone/async convergence, privacy and settlement, P6/P9. |
| account | registration/verification/settings/password/course/profile/avatar/reminders/sync/delete | Verified profile, persistent offline replay, notification permission/token and remote purge, P3/P10. |
| premium preview | Super/Max/trial/plan/family/cancel screen states | Platform purchase adapter, backend verification/entitlements and restore, gated later. |
| design / assets | Existing tokens, original reference art/motion, QA screenshots and component helpers | Fresh device visual/accessibility/audio-focus QA; archived reference does not guarantee current Duolingo parity. |

Important divergences: `MockLearningRepository.saveDraft` retains an in-memory value; kill/restart durability is unproven. `complete` accepts local correct/total/elapsed counts and awards fixture XP; production repository must submit expectedRevision only and consume server result. Mock scoring/transcript/call displays require explicit simulation labels. No network integration is inferred from the presence of SDK dependencies.

Fresh builds/tests are in [validation](VALIDATION.md). Existing major screens are retained. Gummble was not required to redesign any screen in this architecture refresh; its previously saved sources and captures are provenance evidence only.
