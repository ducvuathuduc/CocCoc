# English UI flow checklist

Updated 2026-10-08. 148 scoped flows / 912 ordered screen occurrences.

This is the persistent completion register. ✅ means the scoped native mock UI was implemented and verified; exact pixel/motion and production gates remain separate. Existing families below are reused. A pending source variant does not authorize rebuilding its shared controller or screen.

Edit FLOW_COVERAGE.json after checking evidence, then run `node tools/scripts/flow-coverage.mjs --write`. Regeneration reads existing marks; it does not reset them.

## Existing reusable families

| State | Family | Evidence | Open limits |
| --- | --- | --- | --- |
| ✅ | Onboarding | [analysis](../flows/01_ONBOARDING.md) | Source variants and exact archived pixel/motion still require reconciliation. |
| ✅ | Mock login/recovery | [analysis](../flows/02_LOGIN.md) | Source variants and exact archived pixel/motion still require reconciliation. |
| ✅ | Original Duo motion | [analysis](../flows/03_DUO_MOTION.md) | Source variants and exact archived pixel/motion still require reconciliation. |
| ✅ | English course/path | [analysis](../flows/04_COURSE_PATH.md) | Source variants and exact archived pixel/motion still require reconciliation. |
| ✅ | Lesson/results | [analysis](../flows/05_LESSON_RESULTS.md) | Source variants and exact archived pixel/motion still require reconciliation. |
| ✅ | Hubs/account baseline | [analysis](../flows/06_HUBS_ACCOUNT.md) | Native locked/Welcome/joined League, profile/Back/status and deterministic ranking verified. Archived settlement/promotion/event variants, historical identities, exact pixel/motion and real progress service remain separate. |
| ✅ | Registration/friends/speech baseline | [analysis](../flows/07_REGISTRATION_SOCIAL_SPEECH.md) | Source variants and exact archived pixel/motion still require reconciliation. |
| ✅ | Words/sections/energy/Super | [analysis](../flows/08_ENGLISH_EXTENDED.md) | Source variants and exact archived pixel/motion still require reconciliation. |
| ✅ | Story/radio/typed roleplay | [analysis](../flows/09_ENGLISH_STORY_RADIO_ROLEPLAY.md) | Source variants and exact archived pixel/motion still require reconciliation. |
| ✅ | Rapid/Legendary | [analysis](../flows/10_ENGLISH_CHALLENGES.md) | Source variants and exact archived pixel/motion still require reconciliation. |
| ✅ | Passport Adventure | [analysis](../flows/11_ENGLISH_ADVENTURE.md) | Source variants and exact archived pixel/motion still require reconciliation. |
| ✅ | Explain My Answer | [analysis](../flows/12_EXPLAIN_ANSWER.md) | Source variants and exact archived pixel/motion still require reconciliation. |
| ✅ | Stories library | [analysis](../flows/13_STORIES_LIBRARY.md) | Source variants and exact archived pixel/motion still require reconciliation. |
| ✅ | Max/family tour/checkout | [analysis](../flows/14_MAX_SUBSCRIPTION.md) | Source variants and exact archived pixel/motion still require reconciliation. |
| ✅ | Timer Boost | [analysis](../flows/15_TIMER_BOOST.md) | Source variants and exact archived pixel/motion still require reconciliation. |
| ✅ | Streak/family reactions | [analysis](../flows/16_STREAK_SOCIAL.md) | Source variants and exact archived pixel/motion still require reconciliation. |
| ✅ | Achievements/monthly badges | [analysis](../flows/17_ACHIEVEMENTS.md) | Source variants and exact archived pixel/motion still require reconciliation. |
| ✅ | Friends Clash | [analysis](../flows/18_FRIENDS_CLASH.md) | Source variants and exact archived pixel/motion still require reconciliation. |
| ✅ | Status/feed/comments | [analysis](../flows/19_STATUS_FEED.md) | Source variants and exact archived pixel/motion still require reconciliation. |
| ✅ | Course management/removal | [analysis](../flows/20_COURSE_MANAGEMENT.md) | English replaces archived French; Math/Music/Chess excluded. Existing Settings layout is reused. Crying Duo is original still;350ms local removal wait does not establish original timing. |
| ✅ | Profile report/block and QR/copy | [analysis](../flows/21_PROFILE_ACTIONS.md) | Local fixture identity and existing profile layout differ from the archived profile. Report/block confirmation is explicitly local; nothing is sent. Cupertino action sheet uses bundled readable Duo font; exact iOS system typography remains open. QR and clipboard use identical local preview URL; source encoded contents and rounded eye geometry differ. Source profile fixture/layout and original QR dialog timing are not certified. |
| ✅ | Saved-account management | [analysis](../flows/23_SAVED_ACCOUNT_MANAGEMENT.md) | Saved name/email are local demo fixtures. Native opaque popover replaces source liquid-glass compositing. Existing original Welcome/Login motion is reused; exact archived pose/frame timing remains unresolved. |
| ✅ | Mock password change | [analysis](../flows/22_CHANGE_PASSWORD.md) | Full native Profile editor/password draft return verified locally. Real account updates and exact archived iOS route timing remain pending. |
| ✅ | Original avatar customization | [analysis](../flows/24_AVATAR_ASSET_RESEARCH.md) | Original public rig/config/SVGs obtained; 8 categories/282 choices implemented. Archived item mappings, Profile variants and exact iOS timing remain separate. |
| ✅ | Full Profile editor | [analysis](../flows/22_CHANGE_PASSWORD.md) | Native first/last/username/password/email/phone and saved avatar are implemented. Real account/email/phone updates remain pending; exact archived layout/timing certification is separate. |
| ✅ | Native own Profile and lower sections | [analysis](../flows/25_PROFILE_SOURCE_RECONCILIATION.md) | Local English identity/progress/months adapted; original avatar and illustration regions integrated. Older Profile hierarchy, six-tab source shells and exact motion remain separate. |
| ✅ | Profile Courses and Following/Followers lists | [analysis](../flows/25_PROFILE_SOURCE_RECONCILIATION.md) | Courses/Following/empty and populated Followers, guarded Follow back and return verified locally. Non-language subjects excluded; names/English counts adapted. Original individual portraits, archived pixel/motion timing and real social service writes remain separate. |
| ✅ | English Score information and course popover | [analysis](../flows/26_ENGLISH_SCORE_INFORMATION.md) | Nine current inclusive bands, locked state, lifecycle and clipboard verified. Examples/audio/share are local fixtures; older range labels and device/pixel/motion proof remain separate. |
| ✅ | Historical English Year in Review | [analysis](../flows/28_YEAR_REVIEW_WIDGETS.md) | Source stills and authored transitions; original private timeline and live analytics are separate. |
| ✅ | Seven original Duo widget looks | [analysis](../flows/28_YEAR_REVIEW_WIDGETS.md) | Native in-app gallery/guidance; no OS widget extension or launcher reconstruction. |

## Ordered source flows

| State | Flow | Verified screens | Reuse family |
| --- | --- | --- | --- |
| ⬜ | [Energy](https://gummble.com/apps/duolingo-ios?tab=flows&flow=15d44bfd-9a78-4987-88e2-6c6fd020144c) · 15d44bfd-9a78-4987-88e2-6c6fd020144c | 0/3 | extended |
| ⬜ | [Choosing a section](https://gummble.com/apps/duolingo-ios?tab=flows&flow=31460692-382a-4403-884b-847cc7dd715c) · 31460692-382a-4403-884b-847cc7dd715c | 0/2 | extended |
| ✅ | [Score information](https://gummble.com/apps/duolingo-ios?tab=flows&flow=d70eeb1a-cca9-47f3-b55d-1817937a4c6f) · d70eeb1a-cca9-47f3-b55d-1817937a4c6f | 3/3 | extended, score-information, path |
| ✅ | [Widgets](https://gummble.com/apps/duolingo-ios?tab=flows&flow=3821440d-1a63-42dc-99f2-904cbd9edbbf) · 3821440d-1a63-42dc-99f2-904cbd9edbbf | 7/7 | streak-widgets |
| ✅ | [Year in review](https://gummble.com/apps/duolingo-ios?tab=flows&flow=a9b398c8-70c7-42c4-9cbb-d2568cd0d40d) · a9b398c8-70c7-42c4-9cbb-d2568cd0d40d | 8/8 | year-review |
| ⬜ | [Subscribing to Super Duolingo](https://gummble.com/apps/duolingo-ios?tab=flows&flow=26160ad7-fdd5-45e9-a82a-1062682414a9) · 26160ad7-fdd5-45e9-a82a-1062682414a9 | 0/14 | extended |
| ✅ | [Removing a course](https://gummble.com/apps/duolingo-ios?tab=flows&flow=02681cdc-5d55-4755-a529-9e6c7ecaf5c9) · 02681cdc-5d55-4755-a529-9e6c7ecaf5c9 | 5/5 | path, course-management |
| ⬜ | [Completing a lesson](https://gummble.com/apps/duolingo-ios?tab=flows&flow=068dbdc0-5d4a-4de2-a477-b0e5c8cdc3e8) · 068dbdc0-5d4a-4de2-a477-b0e5c8cdc3e8 | 0/22 | lessons |
| ⬜ | [Friends](https://gummble.com/apps/duolingo-ios?tab=flows&flow=0876e919-b55d-4666-8bb5-a5a4f6bf968e) · 0876e919-b55d-4666-8bb5-a5a4f6bf968e | 0/4 | registration |
| ⬜ | [Setting a status](https://gummble.com/apps/duolingo-ios?tab=flows&flow=0e653f8e-e529-4dd7-ba84-0589fd9b7b82) · 0e653f8e-e529-4dd7-ba84-0589fd9b7b82 | 0/4 | feed |
| 🔄 | [More about score](https://gummble.com/apps/duolingo-ios?tab=flows&flow=0f480cf3-2057-412c-999a-fe9a54bed855) · 0f480cf3-2057-412c-999a-fe9a54bed855 | 0/4 | extended, score-information, path |
| ⬜ | [Sorting words](https://gummble.com/apps/duolingo-ios?tab=flows&flow=1496a2ff-7640-4344-a30b-14543a5a4738) · 1496a2ff-7640-4344-a30b-14543a5a4738 | 0/3 | extended |
| 🔄 | [User profile](https://gummble.com/apps/duolingo-ios?tab=flows&flow=14ea3a1f-8b70-41ec-ade1-d77617a3f149) · 14ea3a1f-8b70-41ec-ade1-d77617a3f149 | 1/4 | hubs, profile-surface, profile-actions, achievements |
| ⬜ | [Widgets](https://gummble.com/apps/duolingo-ios?tab=flows&flow=174e45d5-58e6-43b8-a5b1-465aa2f7a274) · 174e45d5-58e6-43b8-a5b1-465aa2f7a274 | 0/1 | New slice |
| ⬜ | [Completing a story lesson](https://gummble.com/apps/duolingo-ios?tab=flows&flow=1a403996-c169-410b-ab69-c28dbfd8a05b) · 1a403996-c169-410b-ab69-c28dbfd8a05b | 0/11 | journeys |
| ⬜ | [Dynamic Island](https://gummble.com/apps/duolingo-ios?tab=flows&flow=21a86a2a-3d9e-4c93-a29b-c59ba6c16cee) · 21a86a2a-3d9e-4c93-a29b-c59ba6c16cee | 0/3 | New slice |
| ⬜ | [Manage subscription](https://gummble.com/apps/duolingo-ios?tab=flows&flow=2893d5ba-2e72-4ae4-9b39-cc83ae1bb6a4) · 2893d5ba-2e72-4ae4-9b39-cc83ae1bb6a4 | 0/3 | extended |
| ⬜ | [No connection](https://gummble.com/apps/duolingo-ios?tab=flows&flow=38c6ac2e-4911-4563-ac9a-4401973f138c) · 38c6ac2e-4911-4563-ac9a-4401973f138c | 0/2 | hubs |
| ⬜ | [Course](https://gummble.com/apps/duolingo-ios?tab=flows&flow=3a0319c2-f139-4958-9792-4e20328e80ff) · 3a0319c2-f139-4958-9792-4e20328e80ff | 0/3 | path |
| ⬜ | [Delete an account](https://gummble.com/apps/duolingo-ios?tab=flows&flow=3ad07107-91dc-48aa-af39-0344879eefc7) · 3ad07107-91dc-48aa-af39-0344879eefc7 | 0/3 | hubs |
| ⬜ | [Nudging a friend](https://gummble.com/apps/duolingo-ios?tab=flows&flow=4091dc46-49a2-4f13-b036-efd9da4416d3) · 4091dc46-49a2-4f13-b036-efd9da4416d3 | 0/4 | New slice |
| ⬜ | [Creating a profile](https://gummble.com/apps/duolingo-ios?tab=flows&flow=48f7489f-ed2c-4cf3-98e8-b8254482cc99) · 48f7489f-ed2c-4cf3-98e8-b8254482cc99 | 0/18 | hubs, registration |
| ⬜ | [Roleplay](https://gummble.com/apps/duolingo-ios?tab=flows&flow=521f5c00-cf33-4324-82c7-197dd1badfd6) · 521f5c00-cf33-4324-82c7-197dd1badfd6 | 0/4 | journeys |
| ⬜ | [Settings](https://gummble.com/apps/duolingo-ios?tab=flows&flow=5a848dfe-cacb-4319-b5a3-7a2a2a982980) · 5a848dfe-cacb-4319-b5a3-7a2a2a982980 | 0/3 | hubs |
| ⬜ | [Practicing to get a heart](https://gummble.com/apps/duolingo-ios?tab=flows&flow=68cd5891-7c55-4e5c-b166-546e9277928c) · 68cd5891-7c55-4e5c-b166-546e9277928c | 0/10 | extended |
| ⬜ | [Starting a roleplay session](https://gummble.com/apps/duolingo-ios?tab=flows&flow=6f109b71-92ba-4bb7-8342-35ac82af3420) · 6f109b71-92ba-4bb7-8342-35ac82af3420 | 0/22 | journeys |
| ⬜ | [Subscribing to Max](https://gummble.com/apps/duolingo-ios?tab=flows&flow=6f140793-7376-4497-8a35-0b8274bcdff4) · 6f140793-7376-4497-8a35-0b8274bcdff4 | 0/14 | max |
| ⬜ | [Hearts](https://gummble.com/apps/duolingo-ios?tab=flows&flow=72b6566a-dc44-4280-b8ce-39488925dfb5) · 72b6566a-dc44-4280-b8ce-39488925dfb5 | 0/2 | extended |
| ⬜ | [Completing a game lesson](https://gummble.com/apps/duolingo-ios?tab=flows&flow=7343592e-fbc9-49a6-ba14-72fa2f5c238c) · 7343592e-fbc9-49a6-ba14-72fa2f5c238c | 0/13 | adventure |
| ⬜ | [Run out of hearts](https://gummble.com/apps/duolingo-ios?tab=flows&flow=73c77dcb-bb8a-41fb-aac4-2dd03d5ded2e) · 73c77dcb-bb8a-41fb-aac4-2dd03d5ded2e | 0/3 | extended |
| ⬜ | [Words](https://gummble.com/apps/duolingo-ios?tab=flows&flow=809cf666-d5a3-45ab-815d-684210cb8e95) · 809cf666-d5a3-45ab-815d-684210cb8e95 | 0/3 | extended |
| 🔎 | [Profile](https://gummble.com/apps/duolingo-ios?tab=flows&flow=8836419b-926a-4a6e-b264-daff94628c88) · 8836419b-926a-4a6e-b264-daff94628c88 | 0/6 | hubs, profile-surface |
| ⬜ | [Customizing reminders](https://gummble.com/apps/duolingo-ios?tab=flows&flow=895e5cfc-9b69-4563-bd92-a2d666d52c37) · 895e5cfc-9b69-4563-bd92-a2d666d52c37 | 0/7 | hubs |
| 🔄 | [Creating an avatar](https://gummble.com/apps/duolingo-ios?tab=flows&flow=8fa53138-ae46-4d6c-a7d3-75c0493dec5c) · 8fa53138-ae46-4d6c-a7d3-75c0493dec5c | 0/12 | avatar, profile-editor, hubs, profile-surface |
| 🔄 | [Leaderboard](https://gummble.com/apps/duolingo-ios?tab=flows&flow=95cfcf38-001a-4432-b49e-b4282f9703a4) · 95cfcf38-001a-4432-b49e-b4282f9703a4 | 7/11 | hubs, profile-surface |
| ⬜ | [Editing profile](https://gummble.com/apps/duolingo-ios?tab=flows&flow=9b66a0be-845f-427e-9e3f-9e7f491e2067) · 9b66a0be-845f-427e-9e3f-9e7f491e2067 | 0/7 | hubs |
| ⬜ | [Duolingo for schools](https://gummble.com/apps/duolingo-ios?tab=flows&flow=a20f851f-87cc-4fd6-940e-74617680e61d) · a20f851f-87cc-4fd6-940e-74617680e61d | 0/4 | New slice |
| ⬜ | [Logging in](https://gummble.com/apps/duolingo-ios?tab=flows&flow=ad65004b-d8d7-4b8a-b3fb-3a548882b2f9) · ad65004b-d8d7-4b8a-b3fb-3a548882b2f9 | 0/6 | New slice |
| ⬜ | [Practice hub](https://gummble.com/apps/duolingo-ios?tab=flows&flow=aed68339-c522-4abd-9159-ea981cfdd03e) · aed68339-c522-4abd-9159-ea981cfdd03e | 0/5 | New slice |
| ⬜ | [Mistakes](https://gummble.com/apps/duolingo-ios?tab=flows&flow=b16ffb11-e472-467e-b078-9aaa1b56a949) · b16ffb11-e472-467e-b078-9aaa1b56a949 | 0/3 | New slice |
| ⬜ | [Stories](https://gummble.com/apps/duolingo-ios?tab=flows&flow=bb0d8a5f-ea93-473d-b241-052b75dd92a1) · bb0d8a5f-ea93-473d-b241-052b75dd92a1 | 0/3 | library |
| ⬜ | [Super](https://gummble.com/apps/duolingo-ios?tab=flows&flow=befb4bf3-6322-44f7-a9c2-f610f16ebbb1) · befb4bf3-6322-44f7-a9c2-f610f16ebbb1 | 0/7 | extended |
| ⬜ | [Following a user](https://gummble.com/apps/duolingo-ios?tab=flows&flow=c285c7c3-6692-40b7-8750-8b9380946f39) · c285c7c3-6692-40b7-8750-8b9380946f39 | 0/2 | registration |
| ⬜ | [Unit guidebook](https://gummble.com/apps/duolingo-ios?tab=flows&flow=c9e8cdbd-6149-4523-a73b-7fa5c5395e14) · c9e8cdbd-6149-4523-a73b-7fa5c5395e14 | 0/7 | extended |
| ⬜ | [Completing a legendary level](https://gummble.com/apps/duolingo-ios?tab=flows&flow=cefa75a7-5e7e-4dc6-9e35-b61a113feedf) · cefa75a7-5e7e-4dc6-9e35-b61a113feedf | 0/15 | challenges |
| ⬜ | [Live Activities](https://gummble.com/apps/duolingo-ios?tab=flows&flow=cf0df5e8-6036-4bd0-b72e-37ecbc17157c) · cf0df5e8-6036-4bd0-b72e-37ecbc17157c | 0/2 | New slice |
| ⬜ | [Shop](https://gummble.com/apps/duolingo-ios?tab=flows&flow=d5ed9067-1ab6-4e60-af09-99e6ecee262f) · d5ed9067-1ab6-4e60-af09-99e6ecee262f | 0/7 | hubs |
| ⬜ | [Completing a video call lesson](https://gummble.com/apps/duolingo-ios?tab=flows&flow=de439dd6-fe0d-4fdd-85a9-95dd3f9d9cf9) · de439dd6-fe0d-4fdd-85a9-95dd3f9d9cf9 | 0/10 | registration, max |
| ⬜ | [Completing a radio lesson](https://gummble.com/apps/duolingo-ios?tab=flows&flow=dec2ad50-d44c-4b6a-af95-b644f99c83fd) · dec2ad50-d44c-4b6a-af95-b644f99c83fd | 0/18 | journeys |
| ✅ | [Reporting a user](https://gummble.com/apps/duolingo-ios?tab=flows&flow=df57517c-845f-4cd4-b910-eea2fb965672) · df57517c-845f-4cd4-b910-eea2fb965672 | 3/3 | profile-actions |
| ⬜ | [Share an achievement](https://gummble.com/apps/duolingo-ios?tab=flows&flow=e2d3c01a-02c5-422a-a9d4-bd115805979c) · e2d3c01a-02c5-422a-a9d4-bd115805979c | 0/2 | achievements |
| ⬜ | [Verify phone number](https://gummble.com/apps/duolingo-ios?tab=flows&flow=e61ea8df-b1fa-4059-b929-dc0cf9770359) · e61ea8df-b1fa-4059-b929-dc0cf9770359 | 0/6 | registration |
| ✅ | [Starting friends clash](https://gummble.com/apps/duolingo-ios?tab=flows&flow=e84cce2a-186d-4e44-9ae2-351b3def1c99) · e84cce2a-186d-4e44-9ae2-351b3def1c99 | 8/8 | registration, clash |
| ⬜ | [Saving an image](https://gummble.com/apps/duolingo-ios?tab=flows&flow=ed313877-29a2-4ce0-a018-fb002e256243) · ed313877-29a2-4ce0-a018-fb002e256243 | 0/3 | New slice |
| ⬜ | [Courses](https://gummble.com/apps/duolingo-ios?tab=flows&flow=ee1aa797-8f02-4783-8a3f-7b4ab2c594c8) · ee1aa797-8f02-4783-8a3f-7b4ab2c594c8 | 0/2 | path |
| ⬜ | [Claiming a reward](https://gummble.com/apps/duolingo-ios?tab=flows&flow=f6869640-633e-4ee9-84b4-20b8a09a8e68) · f6869640-633e-4ee9-84b4-20b8a09a8e68 | 0/4 | New slice |
| ⬜ | [Roleplay](https://gummble.com/apps/duolingo-ios?tab=flows&flow=0276babb-6d63-4e14-ae34-955d8921c34f) · 0276babb-6d63-4e14-ae34-955d8921c34f | 0/3 | journeys |
| ⬜ | [Completing a profile](https://gummble.com/apps/duolingo-ios?tab=flows&flow=058f0f08-23f2-4f21-be14-f2c4eda78320) · 058f0f08-23f2-4f21-be14-f2c4eda78320 | 0/5 | hubs, registration |
| ⬜ | [Courses](https://gummble.com/apps/duolingo-ios?tab=flows&flow=1320dade-dca0-48cc-ac06-28573d375d6b) · 1320dade-dca0-48cc-ac06-28573d375d6b | 0/4 | path |
| ⬜ | [Turning off notifications](https://gummble.com/apps/duolingo-ios?tab=flows&flow=16e51c8c-fa3e-41a3-aac9-47d0bcdd3f1e) · 16e51c8c-fa3e-41a3-aac9-47d0bcdd3f1e | 0/5 | hubs |
| ⬜ | [Following a user](https://gummble.com/apps/duolingo-ios?tab=flows&flow=1725f154-1903-4677-a72a-cfaca3aa293d) · 1725f154-1903-4677-a72a-cfaca3aa293d | 0/2 | registration |
| ⬜ | [Reporting an issue](https://gummble.com/apps/duolingo-ios?tab=flows&flow=175e506f-5eaa-4065-b76a-cd3c41ac4a91) · 175e506f-5eaa-4065-b76a-cd3c41ac4a91 | 0/3 | New slice |
| ⬜ | [Completing a legendary level](https://gummble.com/apps/duolingo-ios?tab=flows&flow=18f074a6-e85d-4e3b-b312-c35ab4cb4d93) · 18f074a6-e85d-4e3b-b312-c35ab4cb4d93 | 0/10 | challenges |
| ⬜ | [Profile (settings)](https://gummble.com/apps/duolingo-ios?tab=flows&flow=1988d4b7-1dea-4ee2-9756-ebac439ca59a) · 1988d4b7-1dea-4ee2-9756-ebac439ca59a | 0/3 | hubs |
| ⬜ | [Deleting an account](https://gummble.com/apps/duolingo-ios?tab=flows&flow=19bb5168-05ff-4e8f-80af-8a80a82368c5) · 19bb5168-05ff-4e8f-80af-8a80a82368c5 | 0/6 | hubs |
| ⬜ | [Quests](https://gummble.com/apps/duolingo-ios?tab=flows&flow=1af0050f-582d-4ce3-b1f4-9a02b01179df) · 1af0050f-582d-4ce3-b1f4-9a02b01179df | 0/6 | hubs |
| ⬜ | [Personal streak](https://gummble.com/apps/duolingo-ios?tab=flows&flow=1bc25485-ebf2-45f8-aedf-120dbeb48d01) · 1bc25485-ebf2-45f8-aedf-120dbeb48d01 | 0/7 | streak |
| ⬜ | [Reactions](https://gummble.com/apps/duolingo-ios?tab=flows&flow=1c824479-2031-4716-acc9-88acc101ef59) · 1c824479-2031-4716-acc9-88acc101ef59 | 0/2 | streak |
| ⬜ | [Verifying a phone number](https://gummble.com/apps/duolingo-ios?tab=flows&flow=1df4ff54-d0aa-47cb-9694-2148a2776aae) · 1df4ff54-d0aa-47cb-9694-2148a2776aae | 0/6 | registration |
| ⬜ | [Completing a video call lesson](https://gummble.com/apps/duolingo-ios?tab=flows&flow=21e52565-b644-4e13-9b41-5d61ae271f35) · 21e52565-b644-4e13-9b41-5d61ae271f35 | 0/13 | registration, max |
| ⬜ | [Completing a lesson](https://gummble.com/apps/duolingo-ios?tab=flows&flow=238c4339-7173-4257-89c5-2716a8a68c44) · 238c4339-7173-4257-89c5-2716a8a68c44 | 0/13 | lessons |
| ⬜ | [Adding a course (language)](https://gummble.com/apps/duolingo-ios?tab=flows&flow=26164d89-d419-472e-980b-2b6b3441d0a8) · 26164d89-d419-472e-980b-2b6b3441d0a8 | 0/12 | path |
| ⬜ | [Join Duolingo for Schools](https://gummble.com/apps/duolingo-ios?tab=flows&flow=2980972d-1767-4f8a-91d3-e6ff1ba0c9f7) · 2980972d-1767-4f8a-91d3-e6ff1ba0c9f7 | 0/4 | New slice |
| ⬜ | [Settings](https://gummble.com/apps/duolingo-ios?tab=flows&flow=2aeaad44-1638-4abe-b16c-cca1c42dfcaa) · 2aeaad44-1638-4abe-b16c-cca1c42dfcaa | 0/4 | hubs |
| ⬜ | [Feed](https://gummble.com/apps/duolingo-ios?tab=flows&flow=2b077547-fa9f-4d10-8e57-1a87d32e1745) · 2b077547-fa9f-4d10-8e57-1a87d32e1745 | 0/5 | feed |
| ⬜ | [Achievements](https://gummble.com/apps/duolingo-ios?tab=flows&flow=2e5aac3c-9eb5-4126-9ab0-effa7cf75842) · 2e5aac3c-9eb5-4126-9ab0-effa7cf75842 | 0/4 | achievements |
| ⬜ | [Home](https://gummble.com/apps/duolingo-ios?tab=flows&flow=2ea1d2e4-9fdf-4697-b2ba-e61dec4ca56a) · 2ea1d2e4-9fdf-4697-b2ba-e61dec4ca56a | 0/9 | path |
| 🔄 | [Leaderboard](https://gummble.com/apps/duolingo-ios?tab=flows&flow=30488f3a-22f6-4c25-a883-db83e851d5cd) · 30488f3a-22f6-4c25-a883-db83e851d5cd | 1/6 | hubs, profile-surface |
| ✅ | [Copying a profile link](https://gummble.com/apps/duolingo-ios?tab=flows&flow=30b7b0ec-8359-4d2a-99c3-618a964a9833) · 30b7b0ec-8359-4d2a-99c3-618a964a9833 | 3/3 | hubs, profile-actions |
| ⬜ | [Completing the first lesson](https://gummble.com/apps/duolingo-ios?tab=flows&flow=364466ca-05eb-419b-8f47-095685a48cbd) · 364466ca-05eb-419b-8f47-095685a48cbd | 0/28 | path, lessons |
| ⬜ | [Adding a status](https://gummble.com/apps/duolingo-ios?tab=flows&flow=3a8e4927-efd3-42b6-b471-845c2353e9a5) · 3a8e4927-efd3-42b6-b471-845c2353e9a5 | 0/3 | feed |
| ⬜ | [Changing app icon](https://gummble.com/apps/duolingo-ios?tab=flows&flow=3b649d91-2d55-41c1-9621-9ebe42f510d6) · 3b649d91-2d55-41c1-9621-9ebe42f510d6 | 0/3 | New slice |
| ⬜ | [Upgrade to Super Family](https://gummble.com/apps/duolingo-ios?tab=flows&flow=3be81d97-2407-4362-b1ae-d2b53cc4e5b4) · 3be81d97-2407-4362-b1ae-d2b53cc4e5b4 | 0/2 | extended, max |
| ⬜ | [Completing a story lesson](https://gummble.com/apps/duolingo-ios?tab=flows&flow=3ca0e3af-c517-4051-9d07-ad097aa1af51) · 3ca0e3af-c517-4051-9d07-ad097aa1af51 | 0/14 | journeys |
| ⬜ | [Topic detail](https://gummble.com/apps/duolingo-ios?tab=flows&flow=44028dbd-e044-467b-a923-6bba91b94669) · 44028dbd-e044-467b-a923-6bba91b94669 | 0/2 | New slice |
| ⬜ | [Removing a friend streak](https://gummble.com/apps/duolingo-ios?tab=flows&flow=4516901e-0cbe-4511-8f1c-b917a305914a) · 4516901e-0cbe-4511-8f1c-b917a305914a | 0/4 | streak |
| ⬜ | [Completing a roleplay lesson](https://gummble.com/apps/duolingo-ios?tab=flows&flow=45b5806b-d844-44ae-b277-22da5a3e70ca) · 45b5806b-d844-44ae-b277-22da5a3e70ca | 0/19 | journeys |
| ⬜ | [Logging out](https://gummble.com/apps/duolingo-ios?tab=flows&flow=45fa9f2f-727a-41db-90a1-4473b723f24e) · 45fa9f2f-727a-41db-90a1-4473b723f24e | 0/2 | hubs |
| ⬜ | [Commenting on a post](https://gummble.com/apps/duolingo-ios?tab=flows&flow=4b22ef56-af26-4b3b-98c0-5474172cc614) · 4b22ef56-af26-4b3b-98c0-5474172cc614 | 0/5 | feed |
| ⬜ | [Section detail](https://gummble.com/apps/duolingo-ios?tab=flows&flow=4d849f99-ddfb-45e1-b14b-0cf990cce168) · 4d849f99-ddfb-45e1-b14b-0cf990cce168 | 0/4 | extended |
| ⬜ | [Starting a lesson](https://gummble.com/apps/duolingo-ios?tab=flows&flow=55608180-814c-4cfa-b79c-982af1c8a797) · 55608180-814c-4cfa-b79c-982af1c8a797 | 0/33 | path, lessons |
| ⬜ | [Stories](https://gummble.com/apps/duolingo-ios?tab=flows&flow=57af8ed6-e170-4f16-95a7-bb11678eca75) · 57af8ed6-e170-4f16-95a7-bb11678eca75 | 0/2 | library |
| ⬜ | [Searching users](https://gummble.com/apps/duolingo-ios?tab=flows&flow=583f187d-19b7-4420-98de-3d1d7de412f1) · 583f187d-19b7-4420-98de-3d1d7de412f1 | 0/3 | registration |
| ⬜ | [Super Duolingo](https://gummble.com/apps/duolingo-ios?tab=flows&flow=5930cea9-738f-4e27-9f53-0d78d27b9a70) · 5930cea9-738f-4e27-9f53-0d78d27b9a70 | 0/4 | extended |
| ⬜ | [Manage a family plan](https://gummble.com/apps/duolingo-ios?tab=flows&flow=5966780e-da37-499b-ae32-f9387d866b43) · 5966780e-da37-499b-ae32-f9387d866b43 | 0/2 | max |
| ✅ | [Changing password](https://gummble.com/apps/duolingo-ios?tab=flows&flow=5985148c-6771-40a1-b8ff-648fad04a7eb) · 5985148c-6771-40a1-b8ff-648fad04a7eb | 4/4 | login, password-change, profile-editor, avatar |
| ⬜ | [Logging in (saved account)](https://gummble.com/apps/duolingo-ios?tab=flows&flow=5a0502bf-5922-44f1-a529-70f3f03184c7) · 5a0502bf-5922-44f1-a529-70f3f03184c7 | 0/3 | login |
| ⬜ | [Inviting a user to a family plan](https://gummble.com/apps/duolingo-ios?tab=flows&flow=5a0c86dd-053f-481c-98b6-588b1ec116d1) · 5a0c86dd-053f-481c-98b6-588b1ec116d1 | 0/5 | max |
| ⬜ | [Claiming a reward](https://gummble.com/apps/duolingo-ios?tab=flows&flow=5c92b19b-239a-4e75-b9cd-45bfb1c5b4bd) · 5c92b19b-239a-4e75-b9cd-45bfb1c5b4bd | 0/3 | New slice |
| ⬜ | [Creating a profile](https://gummble.com/apps/duolingo-ios?tab=flows&flow=60a33cad-5a9c-4875-a93d-03c656a0c500) · 60a33cad-5a9c-4875-a93d-03c656a0c500 | 0/16 | hubs, registration |
| ⬜ | [Giving feedback](https://gummble.com/apps/duolingo-ios?tab=flows&flow=60ba5691-dcd7-4e3f-98d3-3424eb0bbaa9) · 60ba5691-dcd7-4e3f-98d3-3424eb0bbaa9 | 0/4 | feed |
| ⬜ | [Practice](https://gummble.com/apps/duolingo-ios?tab=flows&flow=6b9da1c4-5399-40aa-a175-b1bc1364309b) · 6b9da1c4-5399-40aa-a175-b1bc1364309b | 0/3 | New slice |
| ⬜ | [Courses (settings)](https://gummble.com/apps/duolingo-ios?tab=flows&flow=6fe40fee-e6b1-495b-b943-6705bcd60b6d) · 6fe40fee-e6b1-495b-b943-6705bcd60b6d | 0/2 | path, hubs |
| ⬜ | [Accepting a streak request](https://gummble.com/apps/duolingo-ios?tab=flows&flow=73709a51-1140-482c-996d-515c3009dd1d) · 73709a51-1140-482c-996d-515c3009dd1d | 0/2 | streak |
| ⬜ | [Editing profile](https://gummble.com/apps/duolingo-ios?tab=flows&flow=7418dd7b-75de-494f-931e-ab7d47a87ec1) · 7418dd7b-75de-494f-931e-ab7d47a87ec1 | 0/3 | hubs |
| ⬜ | [Shop](https://gummble.com/apps/duolingo-ios?tab=flows&flow=758476da-0933-4371-bea9-835a17abec26) · 758476da-0933-4371-bea9-835a17abec26 | 0/5 | hubs |
| ⬜ | [Choosing a learning goal](https://gummble.com/apps/duolingo-ios?tab=flows&flow=7aa5ea5a-3f7d-4065-9c30-773a9b056750) · 7aa5ea5a-3f7d-4065-9c30-773a9b056750 | 0/9 | New slice |
| ⬜ | [Completing a rapid review lesson](https://gummble.com/apps/duolingo-ios?tab=flows&flow=7bc9966b-d6e3-499e-a138-4ece4beedd37) · 7bc9966b-d6e3-499e-a138-4ece4beedd37 | 0/7 | challenges |
| ✅ | [Removing a saved account](https://gummble.com/apps/duolingo-ios?tab=flows&flow=7f823279-b5f5-46df-91a4-982c7f915182) · 7f823279-b5f5-46df-91a4-982c7f915182 | 4/4 | login, saved-account-management |
| ⬜ | [Resetting password](https://gummble.com/apps/duolingo-ios?tab=flows&flow=80a70211-7d97-4806-9843-db071f4e16b4) · 80a70211-7d97-4806-9843-db071f4e16b4 | 0/6 | login |
| ⬜ | [Add a widget](https://gummble.com/apps/duolingo-ios?tab=flows&flow=80e393ec-e5d5-4c86-b5b4-5b18b1aed7f7) · 80e393ec-e5d5-4c86-b5b4-5b18b1aed7f7 | 0/3 | New slice |
| ⬜ | [Deleting a course](https://gummble.com/apps/duolingo-ios?tab=flows&flow=81442ef4-fa5c-4185-86ce-6fa53f860167) · 81442ef4-fa5c-4185-86ce-6fa53f860167 | 0/3 | path |
| ⬜ | [Unit guidebook](https://gummble.com/apps/duolingo-ios?tab=flows&flow=831dee9f-9353-42ad-ad79-2c81a1cad5ad) · 831dee9f-9353-42ad-ad79-2c81a1cad5ad | 0/4 | extended |
| ⬜ | [Logging in (new account)](https://gummble.com/apps/duolingo-ios?tab=flows&flow=85a30736-0e4c-4f18-804d-fcdd611a1faa) · 85a30736-0e4c-4f18-804d-fcdd611a1faa | 0/5 | New slice |
| ⬜ | [Completing a game lesson](https://gummble.com/apps/duolingo-ios?tab=flows&flow=87ed9414-90bd-40b5-8518-bd40b84e374a) · 87ed9414-90bd-40b5-8518-bd40b84e374a | 0/12 | adventure |
| ⬜ | [Gift a Super Duolingo](https://gummble.com/apps/duolingo-ios?tab=flows&flow=9006b2f6-2538-45f7-a645-a3c0d343057c) · 9006b2f6-2538-45f7-a645-a3c0d343057c | 0/4 | extended |
| ⬜ | [Downloading an image](https://gummble.com/apps/duolingo-ios?tab=flows&flow=931501de-1dce-46ad-a2ca-cbbcb25c5a0c) · 931501de-1dce-46ad-a2ca-cbbcb25c5a0c | 0/3 | New slice |
| 🔄 | [Profile](https://gummble.com/apps/duolingo-ios?tab=flows&flow=95916d97-d6af-4824-ad39-3550430a319d) · 95916d97-d6af-4824-ad39-3550430a319d | 5/8 | hubs, profile-surface, avatar |
| ⬜ | [Video call](https://gummble.com/apps/duolingo-ios?tab=flows&flow=95c7e3d9-961e-44b1-8865-03f62937cb1f) · 95c7e3d9-961e-44b1-8865-03f62937cb1f | 0/5 | registration, max |
| ⬜ | [Sending a nudge](https://gummble.com/apps/duolingo-ios?tab=flows&flow=99bc37ea-e88d-405e-a60d-7181a540b8c1) · 99bc37ea-e88d-405e-a60d-7181a540b8c1 | 0/3 | streak |
| ⬜ | [Completing a radio lesson](https://gummble.com/apps/duolingo-ios?tab=flows&flow=9ff41a50-d527-4ba1-b886-dbc8a54f21c4) · 9ff41a50-d527-4ba1-b886-dbc8a54f21c4 | 0/14 | journeys |
| ⬜ | [Words](https://gummble.com/apps/duolingo-ios?tab=flows&flow=a102a0d0-637d-4b8a-a6b2-3bcfbc6ae47f) · a102a0d0-637d-4b8a-a6b2-3bcfbc6ae47f | 0/3 | extended |
| ⬜ | [Inviting a friend to start new streak](https://gummble.com/apps/duolingo-ios?tab=flows&flow=abf76af4-3ac1-4227-ad85-255e9339b169) · abf76af4-3ac1-4227-ad85-255e9339b169 | 0/4 | streak |
| ⬜ | [Canceling a subscription](https://gummble.com/apps/duolingo-ios?tab=flows&flow=accff897-6688-4fbd-85fe-4b537e03c46d) · accff897-6688-4fbd-85fe-4b537e03c46d | 0/7 | extended |
| ⬜ | [Dynamic Island](https://gummble.com/apps/duolingo-ios?tab=flows&flow=adb0ba3c-8ce4-4485-a0e6-3298a17e0ee5) · adb0ba3c-8ce4-4485-a0e6-3298a17e0ee5 | 0/4 | New slice |
| ⬜ | [Live Activities](https://gummble.com/apps/duolingo-ios?tab=flows&flow=b141657c-4b72-4df8-a85c-a4063dcd59b7) · b141657c-4b72-4df8-a85c-a4063dcd59b7 | 0/2 | New slice |
| ⬜ | [Playing a game](https://gummble.com/apps/duolingo-ios?tab=flows&flow=b2dac0c0-1634-4512-b0d3-5e29b315a392) · b2dac0c0-1634-4512-b0d3-5e29b315a392 | 0/6 | adventure |
| ⬜ | [Sections](https://gummble.com/apps/duolingo-ios?tab=flows&flow=b3ad8692-1624-4e6d-9e56-7bdda74127ae) · b3ad8692-1624-4e6d-9e56-7bdda74127ae | 0/3 | extended |
| ⬜ | [Mistakes](https://gummble.com/apps/duolingo-ios?tab=flows&flow=b785531d-a744-4730-94e6-fa1800b727f8) · b785531d-a744-4730-94e6-fa1800b727f8 | 0/2 | New slice |
| ⬜ | [Share a year in review](https://gummble.com/apps/duolingo-ios?tab=flows&flow=ba3db644-fbff-4f64-a04f-59d6862576d1) · ba3db644-fbff-4f64-a04f-59d6862576d1 | 0/3 | New slice |
| ⬜ | [Liking a post](https://gummble.com/apps/duolingo-ios?tab=flows&flow=bb7802f4-8e89-4626-b28d-aa51425d212f) · bb7802f4-8e89-4626-b28d-aa51425d212f | 0/3 | feed |
| ⬜ | [User profile](https://gummble.com/apps/duolingo-ios?tab=flows&flow=bd28e203-718a-4938-bc9a-505c1c559381) · bd28e203-718a-4938-bc9a-505c1c559381 | 0/3 | hubs |
| ⬜ | [Streak](https://gummble.com/apps/duolingo-ios?tab=flows&flow=c0faa1a7-462d-4303-ab15-c4bfcdc55957) · c0faa1a7-462d-4303-ab15-c4bfcdc55957 | 0/5 | streak |
| ⬜ | [Subscription](https://gummble.com/apps/duolingo-ios?tab=flows&flow=c678e04c-d7fa-4db5-8853-b542f4e34009) · c678e04c-d7fa-4db5-8853-b542f4e34009 | 0/10 | extended |
| ⬜ | [Friend streaks](https://gummble.com/apps/duolingo-ios?tab=flows&flow=cd7f559e-57e5-4975-bf65-b9c37fa6b598) · cd7f559e-57e5-4975-bf65-b9c37fa6b598 | 0/2 | streak |
| ⬜ | [Explain my answer](https://gummble.com/apps/duolingo-ios?tab=flows&flow=cf9868c6-2516-4188-86b3-1859148661c3) · cf9868c6-2516-4188-86b3-1859148661c3 | 0/3 | explanation |
| ⬜ | [Reporting a user](https://gummble.com/apps/duolingo-ios?tab=flows&flow=cfa1edff-f4e2-41e3-b05d-507703ec0e07) · cfa1edff-f4e2-41e3-b05d-507703ec0e07 | 0/4 | New slice |
| ⬜ | [Purchasing a timer boost](https://gummble.com/apps/duolingo-ios?tab=flows&flow=d3738966-0f4b-4bc8-bf81-750c2a5854b7) · d3738966-0f4b-4bc8-bf81-750c2a5854b7 | 0/5 | boost |
| ⬜ | [Choose a plan](https://gummble.com/apps/duolingo-ios?tab=flows&flow=d3eaa48c-d39f-40fc-88ea-2a2bed4d193b) · d3eaa48c-d39f-40fc-88ea-2a2bed4d193b | 0/3 | New slice |
| ⬜ | [Manage a subscription](https://gummble.com/apps/duolingo-ios?tab=flows&flow=dd362651-db4a-42ed-aff1-471015886f4c) · dd362651-db4a-42ed-aff1-471015886f4c | 0/3 | extended |
| ✅ | [Monthly badges](https://gummble.com/apps/duolingo-ios?tab=flows&flow=df71c72f-2817-4042-ba06-5a8047534ecf) · df71c72f-2817-4042-ba06-5a8047534ecf | 3/3 | achievements, profile-surface |
| 🔄 | [Creating an avatar](https://gummble.com/apps/duolingo-ios?tab=flows&flow=e47219c8-2442-423f-95fe-6d34ad03841f) · e47219c8-2442-423f-95fe-6d34ad03841f | 1/15 | avatar, profile-editor, hubs, profile-surface |
| ⬜ | [Skipping a unit](https://gummble.com/apps/duolingo-ios?tab=flows&flow=e5507c39-9c84-43a8-856c-8829498d35a6) · e5507c39-9c84-43a8-856c-8829498d35a6 | 0/8 | New slice |
| ✅ | [Onboarding](https://gummble.com/apps/duolingo-ios?tab=flows&flow=e6ac09f7-6131-435e-8c21-dae693af84a7) · e6ac09f7-6131-435e-8c21-dae693af84a7 | 20/20 | onboarding |
| ✅ | [Friends](https://gummble.com/apps/duolingo-ios?tab=flows&flow=eec0c487-8831-4772-975f-84e8d1f6d3d4) · eec0c487-8831-4772-975f-84e8d1f6d3d4 | 4/4 | registration, profile-surface, profile-lists |
| ⬜ | [Achievement detail](https://gummble.com/apps/duolingo-ios?tab=flows&flow=f42ff737-2a4b-4818-b1f7-5c6aed16ebe3) · f42ff737-2a4b-4818-b1f7-5c6aed16ebe3 | 0/3 | achievements |
| ⬜ | [Subscribing to Duolingo Max Family](https://gummble.com/apps/duolingo-ios?tab=flows&flow=f87edc8e-f6da-469b-b407-5cbdab5adc35) · f87edc8e-f6da-469b-b407-5cbdab5adc35 | 0/12 | max |
| ✅ | [Courses (profile)](https://gummble.com/apps/duolingo-ios?tab=flows&flow=fe68d9ea-973e-45df-8db1-7dccb1e52c43) · fe68d9ea-973e-45df-8db1-7dccb1e52c43 | 2/2 | path, hubs, profile-surface, profile-lists |

Per-screen IDs, status, evidence and differences are stored in [FLOW_COVERAGE.json](FLOW_COVERAGE.json).
