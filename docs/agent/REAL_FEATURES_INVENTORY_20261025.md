# Real-features inventory — 2026-10-25 (Phase 1 of the owner's roadmap)

**Purpose:** one table per screen and per OpenAPI operation that says whether a real (`DATA_SOURCE=api`) build reaches a real owner API, a device capability, legitimate authored content, or still a mock — and which roadmap phase closes the gap. Phase numbers are the owner's roadmap phases 2–8, broken down in [PHASE_BREAKDOWN_2_8](PHASE_BREAKDOWN_2_8.md). Keys/config are in [KEYS_AND_CONFIG_CHECKLIST](../devops/KEYS_AND_CONFIG_CHECKLIST.md).

**Not a new owner.** Wire format: [OpenAPI](../api/openapi.yaml). Storage: [DATA_MODEL](../data/DATA_MODEL.md), [PERMISSIONS](../data/PERMISSIONS.md), [MIGRATIONS](../data/MIGRATIONS.md). Action-level acceptance register: [runtime-register.json](../quality/real-features-20261025/runtime-register.json) (120 actions, 684 callbacks) and its [composition receipt](../quality/real-features-20261025/COMPOSITION_GUARD.md). Waves W0–W8: [approved setup plan](REAL_FEATURES_SETUP_PLAN_20261025.md). Global phase gates: [IMPLEMENTATION_PLAN](IMPLEMENTATION_PLAN.md). This file is a dated cross-reference that maps those owners onto the owner's phases; where it disagrees with an owner, the owner wins and this file is stale.

**Method (reproducible, lexical, no device or cloud):** at `main` a300e92, routes were parsed from `apps/mobile/lib/main.dart` (96 `GoRoute`s), each builder class was resolved to its file and feature folder, each feature's providers were checked for an `isApi` branch and for `Mock*`/`Api*`/`Real*` repositories, and every typed call (`LearningApi`/`ProgressApi`/`AiApi`/generated `ApiEndpoints`) was mapped back to its OpenAPI `operationId`. Backend handlers were matched by route template in `services/*/src` (excluding `src/testing`). "Callbacks" is the count of `onTap`/`onPressed`/… bindings in the screen's file from the runtime register; per-button detail is in that register's `callbacks[]` and in [SCREEN_CONTROLS](../audit/SCREEN_CONTROLS.json). Lexical discovery proves where code *can* go, not that a hosted call succeeds: nothing here is live evidence.

## Status legend

| Code | Meaning in a real (`DATA_SOURCE=api`, `USE_MOCK_AUTH=false`) build |
|---|---|
| **REAL-L** | Real owner API/SDK path with behaviour tests passing locally (`VERIFIED_LOCAL` in the register). Still needs keys + live/device acceptance. |
| **API** | Real API/SDK adapter is selected; no local acceptance receipt yet (`UNVERIFIED`). |
| **PARTIAL** | Part of the screen is real, part still reads fixtures/mock or shows "unavailable". |
| **MOCK** | Screen/action still served only by a `Mock*` repository, fixture or preview controller in the real build (or shows unavailable because no caller exists). |
| **CONTRACT** | Cannot be made real without a new/changed OpenAPI or storage contract first (`NEEDS_CONTRACT`). |
| **LOCAL** | Legitimately local: authored content, OS capability or device preference. Needs device proof only. |
| **EXCL** | Real-money payment / ad network — out of scope; simulation is fail-closed on hosted writers. |

## Headline counts

| Measure | Count |
|---|---|
| Routes in `main.dart` | 96 (3 are pure redirects: `/lesson`, `/auth/login`, `/results/:completionId`) |
| Screen routes classified below | 93 |
| — REAL-L | 9 |
| — API | 31 |
| — PARTIAL | 20 |
| — MOCK | 13 |
| — CONTRACT | 3 |
| — LOCAL | 10 |
| — EXCL | 7 |
| OpenAPI operations | 91 (Learning 25, Progress 55, AI 11) |
| — backend handler present | 91/91 (every route template is registered; `switchCourse`/`resetCourse` are generated from one template) |
| — called by the app | 53 |
| — internal/maintainer only (no app call by design) | 11 |
| — client operations with **no app caller** | 27 (list in §3) |
| Runtime-register actions | 120: 11 VERIFIED_LOCAL, 72 UNVERIFIED, 28 MISSING_IMPLEMENTATION, 4 NEEDS_CONTRACT, 5 EXCLUDED, 0 VERIFIED_LIVE |
| Missing contracts (must precede implementation) | 9 (list in §4) |

"Real" therefore means *wired*: 40 of 93 screens (REAL-L + API) take every business action from an owner API, none is yet proven live. The biggest mock islands are social/profile variants, family/referral/year-review, practice journeys (Stories/Adventure/Radio/Clash), streak repair, hearts, and issue reporting.

## 1. Per screen

Endpoints are `operationId`s ([OpenAPI](../api/openapi.yaml)). "Missing" names the concrete gap; the phase is the owner-roadmap phase that closes it.

| Route | Screen (file under `apps/mobile/lib/features/`) | Callbacks | Status | Endpoints used in real build | Missing / contract gap | Phase |
|---|---|---|---|---|---|---|
| `/connecting` | RealConnectionScreen (`session/`) | 4 | API | getMe, initializeProfile, updateMe, listCourses, enrollCourse, getPath, getRewards | Live two-account bootstrap; one profile/enrollment per key | 2 |
| `/welcome` | WelcomeScreen (`onboarding/`) | 2 | LOCAL | — (routes to `/auth/register` in API mode) | — | 2 |
| `/onboarding` | OnboardingFlow (`onboarding/`) | 12 | PARTIAL | step state local (`PreferencesOnboardingRepository`); goal later via updateMe | Persist chosen goal/course server-side on first sign-in; `MockOnboardingContentRepository` holds authored copy only (rename/extract) | 2 |
| `/login` | LoginEntryScreen (`onboarding/`) | 0* | API | Appwrite Account: email/password, email OTP, Google OAuth, session restore/logout | Live delivery of OTP mail; OAuth callback on device; Facebook/Apple disabled by define | 2 |
| `/reset-password` | LoginEntryScreen (recovery) | 0* | API | Appwrite Account recovery (`cocenglish://auth/reset-password`) | `APPWRITE_RECOVERY_URL` + verified app link/redirect page | 2 |
| `/activity/resume` | redirect → lesson activity | — | LOCAL | Android lesson activity resume | Physical-device proof | 8 |
| `/stories` | StoryLibraryScreen (`practice/`) | 2 | MOCK | — (`stories_repository.dart` authored list) | `listActivityProgress` has no caller; STORY session mode not in `SessionRequest.mode` | 6 (contract in 3) |
| `/explanation` | ExplanationScreen (`learning/`) | 4 | LOCAL | authored `english_explanations.dart` | AI generated explanation is Phase 7 (tutorFeedback) | 7 |
| `/nodes/:id` | SessionEntryScreen (`learning/`) | 1 | API | startSession (LESSON/MASTERY) | Live session + revision conflict | 3 |
| `/placement` | PlacementEntryScreen (`placement/`) | 7 | API | startSession(PLACEMENT), submitAnswer, completeSession | Live run against published content | 3 |
| `/placement/result` | PlacementResultScreen (`placement/`) | 6 | API | completion receipt, getPath | — | 3 |
| `/onboarding/demo` | SessionEntryScreen guest | 2 | LOCAL | bundled guest demo (isolated by design) | Must never write account state | 3 |
| `/home` | LearningShell + path (`learning/`, `progress/`) | — | API | listCourses, getManifest, getPath, getRewards, getEnergy | All pages fetched; publish-pointer/hash verification live | 3 |
| `/practice` | PracticeHubScreen (`practice/`) | 23 | PARTIAL | listMistakes, listWords, startSession(REVIEW) | Listen/speak/journey tiles still authored/mock; due-word server schedule | 3 / 6 |
| `/quests` | QuestsScreen (`quests/`) | 5 | API | listQuests, claimQuest | Friend quest opt-in (`optInFriendQuest`) has no caller; monthly roll live | 4 / 6 |
| `/league` | LeagueScreen (`progress/`) | 9 | PARTIAL | getLeague | `league_ranking_provider` still has fixture candidates; `joinLeague` no caller; settlement worker live | 6 |
| `/profile/me` | ProfileScreen own (`progress/`) | 9 | PARTIAL (header is REAL-L) | getMe, getRewards | Lower social/achievement sections; standalone tab uses `profileMockNew/Rich` (MISSING) | 2 / 6 |
| `/lesson/:id` | LessonScreen (`learning/`) | 19 | API | submitAnswer, completeSession, syncOfflineCompletion, createAssessment (speak) | `abandonSession` never called on quit; 12-type live run; speech scores null until Phase 7 | 3 |
| `/results/:completionId/rewards` | ResultsChainScreen (`results/`) | 0 | API | completion receipt + getRewards (`ApiResultsRepository`) | Pending→credited reconciliation live; reward exactly once | 3 / 4 |
| `/path-return` | PathReturnScreen (`results/`) | 6 | API | getPath | — | 3 |
| `/courses` | CoursesScreen (`progress/`) | 9 | PARTIAL | listCourses, enrollCourse | `switchCourse`/`resetCourse`/`removeCourse` have handlers but **no app caller** | 3 |
| `/units/:id/guide` | UnitGuideScreen (`learning/`) | 2 | LOCAL | authored guidebook in bundle | — | 3 |
| `/units/:id/skip` | UnitSkipScreen / CourseUnavailableScreen | 16 | CONTRACT | API mode shows unavailable | Test-out/skip session mode absent from `SessionRequest.mode` | 3 |
| `/sections/:section/check` | UnitSkipScreen / CourseUnavailableScreen | 16 | CONTRACT | API mode shows unavailable | Section checkpoint mode absent from contract | 3 |
| `/sections`, `/sections/:section` | SectionsScreen / SectionDetailScreen (`learning/`) | 6 | API | getPath, getManifest | — | 3 |
| `/score` | ScoreScreen (`progress/`) | 9 | PARTIAL | getMe | Score/Legendary/proficiency projection (P4-LEARN-003) not exposed to app | 3 |
| `/hearts/earned` | HeartEarnedScreen (`hearts/`) | 2 | MOCK | `MockHeartsRepository` only | Hearts are legacy display; energy policy unlimited — remove from real path or bind to getEnergy | 4 |
| `/ad` | AdScreen (`ads/`) | 4 | EXCL | recordAdEvent (hosted writer fail-closed) | Mock ads only, by owner decision | — |
| `/energy` | EnergyScreen (`progress/`) | 3 | API | getEnergy | Refill is mock-only preview; ENERGY_REFILL purchase via buyItem | 4 |
| `/super`, `/super/tour` | SuperScreen / SuperTourScreen | 17 | EXCL (purchase; entitlement read is API) | getEntitlement, verifyPurchase (simulated) | Entitlement from promo/server only; no paid grant | 4 |
| `/max`, `/max/tour` | MaxScreen / MaxTourScreen | 10 | EXCL (entitlement read is API) | getEntitlement | same | 4 |
| `/subscription`, `/subscription/cancel` | SubscriptionScreen / CancelSubscriptionScreen | 17 | EXCL | getPurchase, cancelSubscription (simulation) | Real store billing excluded | — |
| `/subscription/family`, `/subscription/family/invite` | FamilySubscriptionScreen / FamilyPlanScreen | 8 / 17 | MOCK | — | `createFamily`/`joinFamily`/`removeFamilyMember` have handlers, **no app caller** | 6 |
| `/streak` | StreakScreen (`progress/`) | 20 | PARTIAL | getRewards, buyFreeze | `streak_controller` fixture calendar; `repairStreak` no caller (`MockStreakRepairRepository`) | 4 |
| `/streak/widgets` | StreakWidgetsScreen | 6 | LOCAL | home_widget (Android receiver present) | Device proof | 8 |
| `/year-review` | YearReviewScreen | 12 | MOCK | — | `getYearReview` no caller | 6 |
| `/league/results` | LeagueResultScreen | 2 | PARTIAL | getLeagueResult, markLeagueResultSeen | `league_result_controller` still fixture-heavy; one result per settled week live | 6 |
| `/streak/invite` | FriendStreakInviteScreen | 20 | API | listFriendStreaks, inviteFriendStreak, respondFriendStreak | Two-account live | 6 |
| `/achievements`, `/achievements/:id` | AchievementsScreen / AchievementDetailScreen | 7 | API | getMe (achievements) via `ApiAchievementsRepository` | — | 6 |
| `/badges` | MonthlyBadgesScreen | 7 | PARTIAL | getMe | Monthly badges fixture (`profile_achievements_provider`) | 6 |
| `/clash` | ClashScreen (`practice/`) | 9 | MOCK | journey repository | CLASH session mode not in contract | 6 (contract in 3) |
| `/shop` | ShopScreen (`shop/`) | 9 | REAL-L | listShop, buyItem, buyFreeze | Legacy free offers need contract | 4 |
| `/xp-boost/activated` | XpBoostActivatedScreen | 1 | API | activateBoost | Boost window applied at server completion | 4 |
| `/timer-boost/success` | TimerBoostSuccessScreen | 5 | MOCK | `timer_boost_controller` local | TIMER_BOOST via buyItem/activateBoost not bound | 4 |
| `/friends` | FriendsScreen (`profile/`) | 3 | PARTIAL | listFriends | `followUser`/`unfollowUser` no caller | 6 |
| `/activity`, `/feed`, `/feed/learning` | FeedScreen / FeedLearningScreen | 22 | PARTIAL | sendInteraction | `listActivity` no caller; `social_controller` fixture/unavailable | 6 |
| `/learning-stats` | LearningStatsScreen | 1 | API | getLearningStats | Needs **M004** columns applied before writer deploy | 3 |
| `/profile/courses`, `/profile/friends` | ProfileCoursesScreen / ProfileFriendsScreen | 8 | PARTIAL | getMe, listFriends | `profile_lists_controller` fixture rows | 6 |
| `/profile/:userId` | ProfileScreen foreign | 9 | MOCK | blockUser/unblockUser exist | `getPublicProfile` and `reportUser` no caller; `profile_actions_controller` mock moderation receipts | 6 |
| `/practice/:kind` | PracticeDetailScreen | 23 | PARTIAL | listMistakes, listWords, startSession(REVIEW) | Listen/speak kinds use authored audio/typed simulation | 3 / 7 |
| `/journeys/:kind`, `/journeys/:kind/session` | JourneyEntryScreen / JourneyScreen | 21 | MOCK | `journey_repository` | ADVENTURE/RADIO/SIDE_QUEST/UNIT_REVIEW session modes + `listActivityProgress` caller | 6 (contract in 3) |
| `/challenges/:kind` | ChallengeIntroScreen | 3 | MOCK | — | Rapid/side-quest challenge session mode | 6 |
| `/adventures/passport` | AdventureScreen | 7 | MOCK | — | ADVENTURE progress (`listActivityProgress`) | 6 |
| `/journeys/roleplay/feedback`, `/roleplay`, `/roleplay/topics/:id`, `/roleplay/scenarios/:id`, `/roleplay/results` | Roleplay screens (`roleplay/`, `practice/`) | 13–21 | API | listConversations, startConversation, tutorFeedback, completeConversation | Hosted provider is scripted/authored; Gemini not implemented | 7 |
| `/speaking/record` | SpeakingRecordScreen | 4 | API | createAssessment | `getAssessment` polling no caller; speech provider disabled → null score | 7 |
| `/speaking/call` | VideoCallScreen (`call/`) | 8 | REAL-L (captured audio; provider off) | createVoiceSession, submitVoiceTurn, closeVoiceSession, start/completeConversation | `heartbeatVoiceSession` no caller; provider keys; `getCapabilities` no caller | 7 |
| `/speaking/result/:id` | SpeakingResultScreen | 23 | PARTIAL | assessment result from submit | `getAssessment` no caller | 7 |
| `/auth/register` | RegistrationScreen (`account/`) | 16 | API | Appwrite create account + session, initializeProfile | Live two-account acceptance | 2 |
| `/auth/verify` | VerificationScreen (`account/`) | 28 | REAL-L (email; phone is CONTRACT) | Appwrite verification create/confirm + readback | `APPWRITE_VERIFICATION_URL` + app link; phone OTP contract/provider | 2 |
| `/settings` | SettingsScreen (`account/`) | 28 | API | getMe, getPreferences | — | 2 |
| `/settings/courses` | CourseManagementScreen | 4 | PARTIAL | listCourses | switch/reset/remove no caller | 3 |
| `/settings/profile` | EditProfileScreen | 28 | PARTIAL (nickname REAL-L; other fields CONTRACT) | updateMe(expectedRevision) | Username, separate names, verified email/phone change semantics | 2 |
| `/settings/avatar` | AvatarBuilderScreen | 5 | CONTRACT | updateMe(avatarId) | Rive option map saved locally; needs versioned avatar-config contract + storage | 2 |
| `/settings/password` | PasswordChangeScreen | 4 | API | Appwrite Account updatePassword | Session invalidation proof | 2 |
| `/settings/preferences`, `/settings/privacy` | PreferencesScreen / PrivacySettingsScreen | 28 | REAL-L | getPreferences, updatePreferences, getMe, updateMe | — | 2 |
| `/settings/notifications`, `/settings/notifications/:category` | NotificationSettingsScreen / NotificationCategoryScreen | 28 / 7 | REAL-L | getPreferences, updatePreferences | OS delivery on device | 2 / 8 |
| `/settings/legal/{terms,privacy,acknowledgements}` | LegalDocumentScreen (`legal/`) | 1 | LOCAL | versioned documents (`MockLegalRepository` holds authored text) | Rename to content repository; no backend needed | 2 |
| `/support/help` | HelpCenterScreen | 28 | LOCAL | authored help | — | — |
| `/support/feedback` | FeedbackScreen | 28 | API | sendFeedback | — | 2 |
| `/settings/schools` | SchoolsSettingsScreen | 28 | PARTIAL | joinClassroom | `leaveClassroom` no caller | 6 |
| `/settings/social` | SocialAccountsScreen | 28 | MOCK | API mode returns unavailable | Appwrite identity linking (OAuth) not implemented | 2 |
| `/settings/reminders` | ReminderScreen | 28 | REAL-L | preferences + local notifications | Device delivery | 8 |
| `/account/delete` | DeleteAccountScreen | 5 | API | deleteAccount (`RealDeletionReceipt`) | Purge job + local purge live | 2 |
| `/sync` | SyncScreen | 28 | REAL-L | syncOfflineCompletion, getMe, getRewards | Process-kill against admitted backend | 4 |
| `/recovery` | RecoveryScreen | 28 | API | journal + fresh reads | Same as `/sync` | 4 |

\* Login callbacks live in shared auth widgets, so the file count is 0; see the register's `auth.*` actions.

### Non-route surfaces (sheets, dialogs, background)

| Surface | Feature | Status | Endpoints | Missing | Phase |
|---|---|---|---|---|---|
| Exercise "report a problem" sheet | `report/` | MOCK | — (`MockIssueReportRepository`) | `createReport` has a handler but no caller; app-level issue report needs contract review | 3 (exercise) / 6 (user) |
| Promo code redeem | `promo/` | API | redeemPromoCode | **M003** tables not applied | 4 |
| Gift send/redeem | `gift/` | EXCL | sendGift (hosted fail-closed), redeemGift no caller | Non-monetary gift semantics decision | 6 |
| Referral | (account/progress) | MOCK | — | `getReferral`/`redeemReferral` no caller; `COC_PROGRESS_CODE_SECRET` not declarable | 6 |
| Super trial / Super features | `super_trial/`, `super_features/` | MOCK | — | Read getEntitlement instead of mock repositories | 4 |
| App icon change | `app_icon/` | MOCK | memory only | Native aliases + launcher resources | 8 |
| Phone verification | `phone/` | CONTRACT | — (real mode refuses fixed OTP) | Provider + challenge contract (SMS is paid) | 2 |
| Connectivity banner | `connectivity/` | API | health/reads via `ApiConnectivityRepository` | — | 4 |
| Appearance / dark mode | `appearance/` | LOCAL | SharedPreferences | Device proof | 8 |
| Vocabulary notebook | `vocabulary/` | LOCAL | account-scoped local store | Cloud notebook sync would need a contract (not requested) | — |
| Reminders scheduling, streak widget | `reminders/`, Android receivers | LOCAL | local notifications / home_widget | Physical device | 8 |
| Offline lesson journal (Drift v2) | `core/cache` | REAL-L | syncOfflineCompletion | Process kill + reconnect live | 4 |

## 2. Schema cross-check (offline, 2026-10-25)

| Check | Result |
|---|---|
| `pnpm schema:plan` | PASS, `DRY_RUN_NO_NETWORK`. Declaration equals tables/columns/indexes/permissions derived from DATA_MODEL + PERMISSIONS. 62 tables, 664 columns, 117 indexes (66 unique), 1 bucket; declaration SHA-256 `3a2059be…2c7c72d06`. |
| `pnpm schema:test` | PASS, 24/24 (drift, parser, apply guard, ops). |
| `pnpm seed:check` | PASS, typed `vi_en` catalog seed, 0 network writes; full curriculum publish still `NOT_STARTED`. |
| Live TEST project (last recorded 2026-10-12, [Appwrite setup](../devops/APPWRITE_SETUP.md)) | 59 tables / 630 columns / 108 indexes applied, declaration `16394f13…`. Expected delta to today's declaration: +3 tables, +34 columns, +9 indexes = M003 + M004. |

| Migration | Declared in docs + `foundation.json` | Applied to TEST | Blocks |
|---|---|---|---|
| M001–M002 (59 tables) | yes | yes (2026-10-12) | — |
| M003 (+`p_promo_codes`, `p_promo_redemptions`, `p_ad_events`) | yes | **no** — "user applies" | `redeemPromoCode` (Phase 4), mock ad events |
| M004 (`p_day_activity.trackedOriginalCount/Correct`, nullable) | yes (`schema:plan` includes the columns) | **no** | `getLearningStats` accuracy; MIGRATIONS requires applying M004 **before** deploying the Progress writer |

Doc drift found (fix in the Phase 2 setup task, not here): [00_START_HERE](../00_START_HERE.md) and [Appwrite setup](../devops/APPWRITE_SETUP.md) mention only M003; [MIGRATIONS](../data/MIGRATIONS.md) records M004 under a separate heading instead of the migration-log table. Both are additive create-if-absent, so one `pnpm schema:apply` on TEST applies both (needs the owner's explicit request).

## 3. Per OpenAPI operation

Columns: backend handler registered in `services/<owner>/src/http`; app caller (feature folders that reach the typed call); runtime-register status. A handler existing is not live proof — hosted business routes only answer when the owner's adapter is **admitted** (§5).

| operationId | Owner | Route | Handler | App caller | Register |
|---|---|---|---|---|---|
| `getCapabilities` | ai | `GET /v1/ai/capabilities` | yes | **none — no app caller** | UNVERIFIED |
| `createAssessment` | ai | `POST /v1/assessment-jobs` | yes | learning | UNVERIFIED |
| `getAssessment` | ai | `GET /v1/assessment-jobs/{jobId}` | yes | **none — no app caller** | MISSING_IMPLEMENTATION |
| `listConversations` | ai | `GET /v1/conversations` | yes | roleplay | UNVERIFIED |
| `startConversation` | ai | `POST /v1/conversations` | yes | call, roleplay | UNVERIFIED |
| `completeConversation` | ai | `POST /v1/conversations/{conversationId}/complete` | yes | call, roleplay | UNVERIFIED |
| `tutorFeedback` | ai | `POST /v1/tutor` | yes | roleplay | UNVERIFIED |
| `createVoiceSession` | ai | `POST /v1/voice-sessions` | yes | call | UNVERIFIED |
| `closeVoiceSession` | ai | `POST /v1/voice-sessions/{sessionId}/close` | yes | call | UNVERIFIED |
| `heartbeatVoiceSession` | ai | `POST /v1/voice-sessions/{sessionId}/heartbeat` | yes | **none — no app caller** | MISSING_IMPLEMENTATION |
| `submitVoiceTurn` | ai | `POST /v1/voice-sessions/{sessionId}/turns` | yes | call | UNVERIFIED |
| `getHealth` | learning | `GET /health` | yes | internal/maintainer (no app call by design) | MISSING_IMPLEMENTATION |
| `runLearningOutboxDispatch` | learning | `POST /internal/jobs/learning-outbox-dispatch` | yes | internal/maintainer (no app call by design) | MISSING_IMPLEMENTATION |
| `getOutboxWatermark` | learning | `GET /internal/outbox-watermark` | yes | internal/maintainer (no app call by design) | MISSING_IMPLEMENTATION |
| `getReadiness` | learning | `GET /ready` | yes | internal/maintainer (no app call by design) | MISSING_IMPLEMENTATION |
| `listActivityProgress` | learning | `GET /v1/activities` | yes | **none — no app caller** | MISSING_IMPLEMENTATION |
| `publishContent` | learning | `POST /v1/admin/content-versions` | yes | internal/maintainer (no app call by design) | MISSING_IMPLEMENTATION |
| `listCourses` | learning | `GET /v1/courses` | yes | learning | UNVERIFIED |
| `getManifest` | learning | `GET /v1/courses/{courseId}/manifest` | yes | learning | UNVERIFIED |
| `getPath` | learning | `GET /v1/courses/{courseId}/path` | yes | learning, session | UNVERIFIED |
| `enrollCourse` | learning | `POST /v1/enrollments` | yes | learning, session | UNVERIFIED |
| `removeCourse` | learning | `DELETE /v1/enrollments/{courseId}` | yes | **none — no app caller** | MISSING_IMPLEMENTATION |
| `switchCourse` | learning | `POST /v1/enrollments/{courseId}/activate` | yes | **none — no app caller** | MISSING_IMPLEMENTATION |
| `resetCourse` | learning | `POST /v1/enrollments/{courseId}/reset` | yes | **none — no app caller** | MISSING_IMPLEMENTATION |
| `getBundle` | learning | `GET /v1/lessons/{lessonId}/bundle` | yes | **none — no app caller** | UNVERIFIED |
| `getEnergy` | learning | `GET /v1/me/energy` | yes | progress | UNVERIFIED |
| `listMistakes` | learning | `GET /v1/mistakes` | yes | practice | UNVERIFIED |
| `syncOfflineCompletion` | learning | `POST /v1/offline-completions` | yes | learning | UNVERIFIED;VERIFIED_LOCAL |
| `createReport` | learning | `POST /v1/reports` | yes | **none — no app caller** | UNVERIFIED |
| `getReview` | learning | `GET /v1/review` | yes | **none — no app caller** | UNVERIFIED |
| `startSession` | learning | `POST /v1/sessions` | yes | learning, practice | UNVERIFIED |
| `getSession` | learning | `GET /v1/sessions/{sessionId}` | yes | learning | UNVERIFIED |
| `abandonSession` | learning | `POST /v1/sessions/{sessionId}/abandon` | yes | **none — no app caller** | UNVERIFIED |
| `submitAnswer` | learning | `POST /v1/sessions/{sessionId}/answers` | yes | learning | UNVERIFIED |
| `completeSession` | learning | `POST /v1/sessions/{sessionId}/complete` | yes | learning | UNVERIFIED |
| `listWords` | learning | `GET /v1/words` | yes | practice | UNVERIFIED |
| `billingNotification` | progress | `POST /internal/billing/notifications` | yes | internal/maintainer (no app call by design) | EXCLUDED |
| `consumeEvent` | progress | `POST /internal/events` | yes | internal/maintainer (no app call by design) | MISSING_IMPLEMENTATION |
| `runDeletionPurge` | progress | `POST /internal/jobs/deletion-purge` | yes | internal/maintainer (no app call by design) | MISSING_IMPLEMENTATION |
| `runLeagueSettlement` | progress | `POST /internal/jobs/league-settlement` | yes | internal/maintainer (no app call by design) | MISSING_IMPLEMENTATION |
| `runProgressOutboxRelay` | progress | `POST /internal/jobs/progress-outbox-relay` | yes | internal/maintainer (no app call by design) | MISSING_IMPLEMENTATION |
| `runStreakRollover` | progress | `POST /internal/jobs/streak-rollover` | yes | internal/maintainer (no app call by design) | MISSING_IMPLEMENTATION |
| `listActivity` | progress | `GET /v1/activity` | yes | **none — no app caller** | UNVERIFIED |
| `recordAdEvent` | progress | `POST /v1/ad-events` | yes (hosted writer fail-closed: simulation) | ads | EXCLUDED |
| `verifyPurchase` | progress | `POST /v1/billing/purchases` | yes (hosted writer fail-closed: simulation) | billing | EXCLUDED |
| `getPurchase` | progress | `GET /v1/billing/purchases/{purchaseId}` | yes | billing | UNVERIFIED |
| `cancelSubscription` | progress | `POST /v1/billing/subscription/cancel` | yes | billing | UNVERIFIED |
| `blockUser` | progress | `POST /v1/blocks` | yes | progress | UNVERIFIED |
| `unblockUser` | progress | `DELETE /v1/blocks/{userId}` | yes | progress | UNVERIFIED |
| `joinClassroom` | progress | `POST /v1/classrooms/join` | yes | account | UNVERIFIED |
| `leaveClassroom` | progress | `DELETE /v1/classrooms/{classroomId}/membership` | yes | **none — no app caller** | UNVERIFIED |
| `createFamily` | progress | `POST /v1/family` | yes | **none — no app caller** | MISSING_IMPLEMENTATION |
| `joinFamily` | progress | `POST /v1/family/{groupId}/members` | yes | **none — no app caller** | MISSING_IMPLEMENTATION |
| `removeFamilyMember` | progress | `DELETE /v1/family/{groupId}/members/{userId}` | yes | **none — no app caller** | MISSING_IMPLEMENTATION |
| `sendFeedback` | progress | `POST /v1/feedback` | yes | account | UNVERIFIED |
| `followUser` | progress | `POST /v1/follows` | yes | **none — no app caller** | UNVERIFIED |
| `unfollowUser` | progress | `DELETE /v1/follows/{userId}` | yes | **none — no app caller** | UNVERIFIED |
| `optInFriendQuest` | progress | `POST /v1/friend-quests/opt-in` | yes | **none — no app caller** | UNVERIFIED |
| `listFriendStreaks` | progress | `GET /v1/friend-streaks` | yes | progress | UNVERIFIED |
| `inviteFriendStreak` | progress | `POST /v1/friend-streaks` | yes | progress | UNVERIFIED |
| `respondFriendStreak` | progress | `POST /v1/friend-streaks/{pairId}/respond` | yes | progress | UNVERIFIED |
| `listFriends` | progress | `GET /v1/friends` | yes | profile | UNVERIFIED |
| `sendGift` | progress | `POST /v1/gifts` | yes (hosted writer fail-closed: simulation) | gift | EXCLUDED |
| `redeemGift` | progress | `POST /v1/gifts/{giftId}/redeem` | yes (hosted writer fail-closed: simulation) | **none — no app caller** | EXCLUDED |
| `sendInteraction` | progress | `POST /v1/interactions` | yes | progress | UNVERIFIED |
| `getLeague` | progress | `GET /v1/league` | yes | progress | UNVERIFIED |
| `joinLeague` | progress | `POST /v1/league/join` | yes | **none — no app caller** | UNVERIFIED |
| `getLeagueResult` | progress | `GET /v1/league/result` | yes | progress | UNVERIFIED |
| `markLeagueResultSeen` | progress | `POST /v1/league/result/seen` | yes | progress | UNVERIFIED |
| `getMe` | progress | `GET /v1/me` | yes | account, progress, session | MISSING_IMPLEMENTATION;UNVERIFIED;VERIFIED_LOCAL |
| `updateMe` | progress | `PATCH /v1/me` | yes | account, session | NEEDS_CONTRACT;UNVERIFIED;VERIFIED_LOCAL |
| `activateBoost` | progress | `POST /v1/me/boosts` | yes | xp_boost | UNVERIFIED |
| `deleteAccount` | progress | `POST /v1/me/deletion` | yes | account | UNVERIFIED |
| `getEntitlement` | progress | `GET /v1/me/entitlement` | yes | billing | UNVERIFIED |
| `buyFreeze` | progress | `POST /v1/me/freezes` | yes | shop | UNVERIFIED |
| `initializeProfile` | progress | `POST /v1/me/initialize` | yes | account, session | UNVERIFIED |
| `getLearningStats` | progress | `GET /v1/me/learning-stats` | yes | progress | UNVERIFIED |
| `getPreferences` | progress | `GET /v1/me/preferences` | yes | account, notifications | UNVERIFIED;VERIFIED_LOCAL |
| `updatePreferences` | progress | `PATCH /v1/me/preferences` | yes | account, notifications | UNVERIFIED;VERIFIED_LOCAL |
| `getReferral` | progress | `GET /v1/me/referral` | yes | **none — no app caller** | MISSING_IMPLEMENTATION |
| `getRewards` | progress | `GET /v1/me/rewards` | yes | account, learning, progress, session | MISSING_IMPLEMENTATION;UNVERIFIED;VERIFIED_LOCAL |
| `repairStreak` | progress | `POST /v1/me/streak-repair` | yes | **none — no app caller** | MISSING_IMPLEMENTATION |
| `getYearReview` | progress | `GET /v1/me/year-review/{year}` | yes | **none — no app caller** | MISSING_IMPLEMENTATION |
| `getPublicProfile` | progress | `GET /v1/profiles/{userId}` | yes | **none — no app caller** | UNVERIFIED |
| `redeemPromoCode` | progress | `POST /v1/promo-codes/redeem` | yes | promo | UNVERIFIED |
| `listQuests` | progress | `GET /v1/quests` | yes | progress, quests | UNVERIFIED |
| `claimQuest` | progress | `POST /v1/quests/{questId}/claim` | yes | quests | UNVERIFIED |
| `redeemReferral` | progress | `POST /v1/referrals/redeem` | yes | **none — no app caller** | MISSING_IMPLEMENTATION |
| `listShop` | progress | `GET /v1/shop` | yes | shop | UNVERIFIED;VERIFIED_LOCAL |
| `buyItem` | progress | `POST /v1/shop/purchases` | yes | shop | UNVERIFIED;VERIFIED_LOCAL |
| `reportUser` | progress | `POST /v1/user-reports` | yes | **none — no app caller** | MISSING_IMPLEMENTATION |
**Client operations with a handler but no app caller (27):** `getCapabilities`, `getAssessment`, `heartbeatVoiceSession` (Phase 7); `listActivityProgress` (Phase 6, contract in 3); `switchCourse`, `resetCourse`, `removeCourse`, `abandonSession`, `createReport` (Phase 3); `getBundle`, `getReview` (not needed while `startSession` embeds the bundle and review snapshot — keep or document as unused); `repairStreak` (Phase 4); `listActivity`, `followUser`, `unfollowUser`, `getPublicProfile`, `reportUser`, `joinLeague`, `optInFriendQuest`, `leaveClassroom`, `createFamily`, `joinFamily`, `removeFamilyMember`, `getReferral`, `redeemReferral`, `getYearReview`, `redeemGift` (Phase 6; `redeemGift` waits on the gift decision).

## 4. Missing contracts (contract-first, exclusive OpenAPI/schema owner)

| # | Gap | Evidence | Needed before | Phase |
|---|---|---|---|---|
| C1 | Phone verification / account-link challenge (provider, expiry, attempts, replay) | register `phone.verifyExistingAccount` | `/auth/verify` phone branch | 2 (or keep "unavailable" — phone needs paid SMS) |
| C2 | Profile identity fields: username, given/family name, verified email/phone change | `ProfilePatch` has only nickname/avatarId/publicOptIn/dailyGoal/learningZone | `/settings/profile` | 2 |
| C3 | Versioned avatar configuration (Rive option map) + storage column | register `profile.avatarConfiguration` | `/settings/avatar` | 2 |
| C4 | Account linking (Appwrite identities) — mostly SDK, but a "linked providers" projection if shown cross-device | register `settings.linkIdentity` | `/settings/social` | 2 |
| C5 | Session modes beyond `LESSON/REVIEW/MASTERY/PLACEMENT`: unit test-out/skip, section checkpoint, STORY, ADVENTURE, RADIO, SIDE_QUEST, CLASH, UNIT_REVIEW, rapid challenge | `SessionRequest.mode` enum; `ActivityProgress.kind` already lists the six activity kinds | `/units/:id/skip`, `/sections/:s/check`, `/stories`, journeys, clash | 3 (contract) → 6 (screens) |
| C6 | App-level issue report vs exercise report (`createReport` covers exercise only) | setup plan "Issue report / exercise report" row | report sheet, `/support/*` | 3 / 6 |
| C7 | Shop "free offers" (legacy) | register `shop.realInventoryPurchase` | free shop tiles | 4 |
| C8 | Event application-receipt endpoint + per-target ack storage + AMQP envelope/key rotation | [ADR-0018](../architecture/adr/0018-container-event-cache-runtime.md) §event contract; register `runtime.rabbitMqApplicationReceipts` | any RabbitMQ cutover | 5 |
| C9 | Gemini text/explanation capability (provider adapter, `Capabilities.textTutor` provenance, quota fields) | `COC_GEMINI_ENABLED` is forced `false` by `ops-lib`; no Gemini code reads a key | AI explanations / roleplay generation | 7 |

Redis (Phase 5) needs no wire contract, only the ADR's cache namespace rules.

## 5. Service configuration, adapters and flags

Owners: [services/AGENTS.md](../../services/AGENTS.md), [appwrite/AGENTS.md](../../appwrite/AGENTS.md), [ops/project.json](../../appwrite/ops/project.json), [env.public.example](../../infra/docker/env.public.example). `pnpm appwrite:plan` PASS (3 functions, auth methods/policies, Google OAuth client id, 2 platforms, 3 schedules, declaration `6c1f02eb…`).

| Service | Persistence flag | Admission flag | Appwrite credential | Other flags | Finding |
|---|---|---|---|---|---|
| Learning (`coc-learning`) | `COC_LEARNING_PERSISTENCE=appwrite` declared | `COC_LEARNING_ADMITTED=reviewed-cloud-gate` declared | dynamic `x-appwrite-key` first, fallback `COC_LEARNING_APPWRITE_KEY`/`APPWRITE_API_KEY` | `COC_PROGRESS_URL`, `COC_CONTENT_PUBLIC_KEYS` (currently the **dev** content key), `COC_ENERGY_MODE` (unset ⇒ unlimited), `COC_MAINTAINER_USER_IDS` (**not declared** ⇒ nobody can `publishContent`) | Production content signing key pair needed |
| Progress (`coc-progress`) | `COC_PROGRESS_PERSISTENCE=appwrite` declared | **`COC_PROGRESS_ADMITTED` not declared** | dynamic key first, fallback `COC_PROGRESS_APPWRITE_KEY` | `COC_LEARNING_URL`, `COC_AI_URL`; `COC_PROGRESS_CODE_SECRET` read by code but **cannot be declared** (`ops-lib` allows only `COC_SERVICE_KEYS` as a secret, no Progress provider secrets) | Hosted transport refuses business routes for a non-admitted adapter (`services/shared/src/transport.ts`), so **every Progress business route fails closed on TEST** until the flag is declared; referral/family codes fall back to a built-in secret |
| AI (`coc-ai`) | `COC_AI_PERSISTENCE=appwrite` declared | `COC_AI_ADMITTED` declared | dynamic key first, fallback `COC_AI_APPWRITE_KEY` | `COC_AI_PROVIDER=speech`, `COC_AZURE_SPEECH_REGION=eastasia`, `COC_SPEECH_DAILY_SECONDS=540`, `COC_GEMINI_ENABLED=false` (enforced), provider secrets `COC_AZURE_SPEECH_KEY`/`COC_ASSEMBLYAI_API_KEY`/`COC_DEEPGRAM_API_KEY` (allow-listed, not yet set ⇒ `turnSpeech=false`), `COC_AI_ROLEPLAY_MIN_PLAN`/`COC_AI_VIDEO_CALL_MIN_PLAN` | No Gemini adapter exists |
| All | — | — | — | `COC_SERVICE_KEYS` (HMAC keyring, generated by `appwrite:apply`), schedules active every minute | Deployed bundles on TEST are from 919c37a (2026-10-12): a redeploy is needed after M003/M004 |
| Containers (ADR-0018) | env files `.secrets/{learning,progress,ai}.env` | same `*_ADMITTED` | must use `COC_*_APPWRITE_KEY` (no dynamic key outside Functions) | `COC_WORKER_INTERVAL_MS`, HTTPS `COC_*_URL` | No AMQP/Redis variables exist yet (Phase 5 defines them) |
| Mobile | `DATA_SOURCE=api`, `USE_MOCK_AUTH=false` via [config/real.public.json](../../apps/mobile/config/real.public.json) | `validateRealProfile` | — | `APPWRITE_RECOVERY_URL`, `APPWRITE_VERIFICATION_URL` (**absent** from `real.public.json`), `APPWRITE_{GOOGLE,FACEBOOK,APPLE}_ENABLED=false` though Google is enabled on TEST | Turn on Google define after device OAuth proof |

## 6. Offline checks run for this inventory

All on a clean checkout of `main` a300e92, Node 22.23.4, pnpm 10.15.0, no keys, no network writes.

| Command | Result |
|---|---|
| `pnpm schema:plan` | PASS (62 tables, see §2) |
| `pnpm schema:test` | PASS 24/24 |
| `pnpm seed:check` | PASS (0 network writes) |
| `pnpm appwrite:plan` | PASS (dry run, no network) |
| `pnpm contracts:check` | PASS (157 schemas, 105 fixture cases, Dart DTOs up to date) |
| `pnpm backend:verify` | PASS: 212 tests, 200 pass, 12 gated skips, 0 fail; tsc, esbuild bundles, ESLint, Prettier |

These validate declarations and local code only. No schema apply, deploy, live probe, device or provider result is claimed.
