# Year in Review and Duo widget looks — 2026-10-08

Assigned tasks: UI-REVIEW-037, UI-WIDGETS-038 and UI-QA-039 in
[the continuation plan](../../agent/FRONTEND_REMAINING_PLAN.md).

Live Gummble MCP returned all eight ordered occurrences from
[Year in Review](https://gummble.com/apps/duolingo-ios?tab=flows&flow=a9b398c8-70c7-42c4-9cbb-d2568cd0d40d)
and seven from
[Widgets](https://gummble.com/apps/duolingo-ios?tab=flows&flow=3821440d-1a63-42dc-99f2-904cbd9edbbf).
Original PNGs are archived; bundled bytes are checked by the reference asset audit.
Artwork regions exclude source controls, course tiles and summary statistics.
All text, navigation, controls and counters render as native Flutter widgets.

## Year in Review

Seven pages follow the source order: 2025 intro, lessons, XP, league, finale gate,
Stellar Student and summary. The historical immutable English fixture retains
the source date of November 30, 2025. It is independent of the learner's live
XP, course, streak and wallet. French/Chess tiles are excluded; summary labels
use English. Profile and Settings link to this historical review.

Manual auto-disposed Riverpod state owns page bounds and asynchronous clipboard
commands. Vertical swipes and native accessible buttons both navigate. Reduced
motion jumps directly; ordinary page animation uses an authored 220ms curve.
Short viewports and large text scroll without shrinking text. Closing/reopening
starts a new review. Clipboard failures preserve the summary and permit retry;
stale completion after exit/restart is discarded. Share uses the local clipboard
and does not send external messages or credit rewards.

Source illustration aspect ratios are retained. Full-bleed hero sizing and a
small alpha edge blend reconcile source stills with the native backgrounds.
These are recorded visual adaptations, not evidence of the private source
animation timeline. Native summary branding avoids clipped embedded labels.

## Widget gallery

Seven moods preserve original Duo artwork: ready, early, practice, last chance,
save, protected and away. Both medium and small cards use native copy, the
learner's current local streak count and source-proportional illustration boxes.
Source weekday/checkmark rows are immutable visual fixtures, not journal events.
Selection changes only the visual mood. Size/mood/count are exposed through
single semantic labels; tests check every mood at 320px and text scales 1/2,
including non-overlapping text/art rectangles and source aspect ratios.

The installation sheet describes generic OS operations using
[Apple's widget instructions](https://support.apple.com/en-nz/118610) and
[Google's widget instructions](https://support.google.com/pixelphone/answer/2781850?hl=en-AS).
It chooses from available app widgets; it does not claim CocEnglish has installed
a WidgetKit or Android AppWidget extension. This task implements the in-app
gallery and guidance, not an OS launcher or native widget target.

Verification commands, captures and capability scope are recorded in
[the finish report](../qa/SESSION_FINISH_REPORT.md).
