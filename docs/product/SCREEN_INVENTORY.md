# Screen inventory

Source audit: these 42 IDs describe V1 contracts, not the count of actual routes/widgets. Current evidence is in [UI gap](../audit/UI_IMPLEMENTATION_GAP.md) and [behavior map](SCREEN_BEHAVIOR_MAP.md); main.dart owns the existing router. Preserve finished mock flows; reconcile routes before adding/moving screens.

Each screen implements loading/content/error/empty/offline as applicable, with retry preserving entered data. Common tokens and states live in [DESIGN](../design/DESIGN.md) and [COMPONENT_STATES](../design/COMPONENT_STATES.md). Routes are frozen; API operation IDs are in OpenAPI. “Local” means no network command.

| ID | Route / screen | ViewModel command / data | Special states / exit |
|---|---|---|---|
| SC01 | /boot | restoreAuth | restoring, unavailable, cacheOnly; route guard |
| SC02 | /welcome | startGuest/signIn | guest intro available offline |
| SC03 | /onboarding/language | chooseCourse | unavailable course, previous choice |
| SC04 | /onboarding/purpose | choosePurpose | optional skip |
| SC05 | /onboarding/experience | chooseExperience | placement vs beginner |
| SC06 | /onboarding/goal | chooseGoal | 5/10/15-min options |
| SC07 | /onboarding/demo | startGuestDemo | bundled local lesson |
| SC08 | /auth/register | registerEmail | inline validation, duplicate/server failure |
| SC09 | /auth/login | loginEmail/oauth | cancellation, offline, expired |
| SC10 | /auth/verify | sendVerification/checkAuth | rate-limited, email link expired |
| SC11 | /auth/reset | sendRecovery | generic sent state, link expired |
| SC12 | /placement | startPlacement | fixed ten originals, exit confirmation |
| SC13 | /home | getPath/getMe | current node, syncing, locked, retired course |
| SC14 | /courses | listCourses/enrollCourse | active course, no data |
| SC15 | /units/:id/guide | getBundle | cached static guide |
| SC16 | /nodes/:id | select lesson/mastery | locked/explainer, practicedPending |
| SC17 | /lesson/:id | submitAnswer/completeSession | 12 registered renderers, feedback, retry queue |
| SC18 | lesson exit sheet | pauseLocal/abandonSession | unsaved/pending answers |
| SC19 | hint/explain sheet | revealHint/tutorFeedback | authored, optional AI loading/fallback |
| SC20 | exercise report sheet | createReport | queued, accepted, failed retry |
| SC21 | /results/:completionId | getRewards | first/replay, pending/credited/capped |
| SC22 | streak/milestone sheet | acknowledge local display | reduced motion, protected day |
| SC23 | /practice | getReview | four skill tiles, empty due set |
| SC24 | /practice/words | startReview | recall/reveal/assisted |
| SC25 | /practice/mistakes | startReview | no mistakes |
| SC26 | /practice/listen | startSession/audio local | focus loss, missing asset, substitution |
| SC27 | /practice/speak | getCapabilities | permissionDenied, unsupported/online needed |
| SC28 | /speaking/record | createAssessment/poll | silence/noise/capturing/upload/queued/unscored |
| SC29 | /speaking/call | createVoiceSession | guided/free, connect/listen/respond/reconnect/degraded |
| SC30 | /speaking/result/:id | getAssessment | nullable score, per-word feedback, recording expiry |
| SC31 | /quests | listQuests/claimQuest | pending claim, daily/monthly/cooperative |
| SC32 | /league | getLeague | opt-in, empty, ranked, settling |
| SC33 | /profile/me | getMe | stats/badges/private edit |
| SC34 | /profile/:userId | getPublicProfile/followUser | private/unavailable/follow pending |
| SC35 | /friends | listFriends | requests/cooperative quest, empty |
| SC36 | /activity | listActivity | opt-in summaries only |
| SC37 | /shop | buyFreeze | funds/slot exhausted; virtual only |
| SC38 | /settings | updateMe/local settings | timezone scheduled/revision conflict |
| SC39 | reminder sheet | local scheduling | OS denial, configured, disabled |
| SC40 | /sync | syncOfflineCompletion | count/pending/rejected/retired content |
| SC41 | account/delete sheet | deleteAccount | confirm/request accepted/blocked |
| SC42 | global error/recovery sheet | retry originating command | 401/login, 429/wait, timeout, cache restore |

Bottom navigation: Home, Practice, Quests, League, Profile. Keep tab state and scroll position independently. Speaking belongs inside Practice and may also be a path node; do not create a generic dashboard. Settings are profile action. Pop from a dirty lesson goes through SC18. A router redirect preserves deep link and suppresses infinite loops during auth restoration.

Every screen has fixtures for content, loading, recoverable failure and offline where permitted. Phase2 goldens use narrow360×800 and wide430×932 logical sizes, text scale1.0/2.0, light/dark supported tokens. The route fixture browser is a development mode in the actual Flutter app, not a web replacement.
