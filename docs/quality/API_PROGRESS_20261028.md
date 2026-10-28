# API progress and DeepSeek handoff — 2026-10-28

Audited checkpoint: `60728e24c42c04939d6f2eaaa42517c30a4c1f79` on `wip/codex-20261027-hardening`. Workspace: `C:\FPT\PRM193\CocCoc`. This is a local code/test audit; no hosted/private API or provider was exercised.

## Verified result

- 91 OpenAPI operations: Learning 25, Progress 55, AI 11. Every operation has a matching registered route or shared built-in. Registration does not certify implementation quality, durable readiness or successful business execution.
- Fresh `node tools/scripts/backend-check.mjs`: PASS; 259 tests, 247 passed, 0 failed, 12 live-gated skips; TypeScript, bundles, ESLint and Prettier pass.
- Fresh contract validation: 157 schemas, 105 fixture cases; generated Dart matches.
- Fresh Dart analyzer: 28 errors, 6 warnings, 2 infos. Wrong support import/await in practice tests, unfinished abandon interface/method and economy test APIs are the main compilation blockers.
- Previous scoped app run on the same source: 37 passed, 2 failed in Mistake Review. This is not a full app regression result.
- No Postman collection/environment was found in tracked project paths at this checkpoint.
- GitHub CI at the same checkpoint: [Backend foundation](https://github.com/ducvuathuduc/CocCoc/actions/runs/40553429413), [Source secret scan](https://github.com/ducvuathuduc/CocCoc/actions/runs/40553429326) and [Container runtime](https://github.com/ducvuathuduc/CocCoc/actions/runs/40553429358) succeeded. [Mobile frontend](https://github.com/ducvuathuduc/CocCoc/actions/runs/40553429689) failed. Container CI success is not durable cloud acceptance.

## Concrete remaining work

1. Three user-facing operations have no direct feature caller found: `abandonSession`, `optInFriendQuest`, `getYearReview`. Backend routes already exist. Eleven other operations without app callers are health/admin/internal/scheduler surfaces and must not be exposed as mobile commands. This is lexical discovery, not semantic integration acceptance.
2. Local auth is inconsistent: Learning supports explicit `COC_DEV_AUTH=1`; Progress and AI dev composition currently supply no user auth port. Therefore `pnpm dev:services` alone cannot support full positive Postman tests of all three private APIs. Use a coherent opt-in dev-only identity adapter, or an admitted durable environment with verified Appwrite JWTs; never weaken production auth.
3. Session modes remain LESSON/REVIEW/MASTERY/PLACEMENT. Additional authored learning modes need contract-first work and actual activity writers.
4. Profile identity/avatar configuration, app-level issue reports and free-offer semantics require review against canonical contracts. Phone and live AI/speech require provider work and separate acceptance.
5. AMQP/Redis adapter implementations and tests exist; no production composition call to their factory functions was found. Receipt helpers exist but the application receipt endpoint/storage/fan-out/runtime admission gates remain incomplete.
6. TEST configuration declarations still lack Progress admission/code-secret and maintainer wiring described in the setup plan. Actual cloud settings were not inspected. Schema, signed-content publishing, permissions and durable transaction recovery must be proved separately.
7. Billing/gift/ad simulation writers intentionally fail closed in hosted mode. This is an existing exclusion, not a reason to enable real money or fabricate successful API behavior.

## Method

OpenAPI was parsed as JSON. Current Learning route factories, Progress wiring and AI route factory were bundled and instantiated to enumerate their method/path arrays without invoking handlers or performing I/O. Shared GET /health, GET /ready and POST /internal/events were included as built-ins. Feature calls were searched in apps/mobile/lib/features, excluding generated API clients. These checks establish registered paths and lexical references only. Historical 2026-10-25 inventories are not current runtime acceptance.

## Complete operation register

| Owner | Method and path | Operation | Route registered | Direct feature caller found |
|---|---|---|---|---|
| learning | GET /health | getHealth | yes | not found |
| learning | GET /ready | getReadiness | yes | not found |
| learning | GET /v1/courses | listCourses | yes | yes |
| learning | GET /v1/courses/{courseId}/manifest | getManifest | yes | yes |
| learning | POST /v1/enrollments | enrollCourse | yes | yes |
| learning | GET /v1/courses/{courseId}/path | getPath | yes | yes |
| learning | GET /v1/lessons/{lessonId}/bundle | getBundle | yes | yes |
| learning | POST /v1/sessions | startSession | yes | yes |
| learning | GET /v1/sessions/{sessionId} | getSession | yes | yes |
| learning | POST /v1/sessions/{sessionId}/answers | submitAnswer | yes | yes |
| learning | POST /v1/sessions/{sessionId}/complete | completeSession | yes | yes |
| learning | POST /v1/sessions/{sessionId}/abandon | abandonSession | yes | not found |
| learning | POST /v1/offline-completions | syncOfflineCompletion | yes | yes |
| learning | GET /v1/review | getReview | yes | yes |
| learning | POST /v1/reports | createReport | yes | yes |
| learning | POST /v1/admin/content-versions | publishContent | yes | not found |
| progress | GET /v1/me | getMe | yes | yes |
| progress | PATCH /v1/me | updateMe | yes | yes |
| progress | POST /v1/me/initialize | initializeProfile | yes | yes |
| progress | GET /v1/me/rewards | getRewards | yes | yes |
| progress | GET /v1/quests | listQuests | yes | yes |
| progress | POST /v1/quests/{questId}/claim | claimQuest | yes | yes |
| progress | POST /v1/me/freezes | buyFreeze | yes | yes |
| progress | GET /v1/profiles/{userId} | getPublicProfile | yes | yes |
| progress | POST /v1/follows | followUser | yes | yes |
| progress | DELETE /v1/follows/{userId} | unfollowUser | yes | yes |
| progress | GET /v1/friends | listFriends | yes | yes |
| progress | GET /v1/activity | listActivity | yes | yes |
| progress | GET /v1/league | getLeague | yes | yes |
| progress | POST /v1/league/join | joinLeague | yes | yes |
| progress | POST /v1/friend-quests/opt-in | optInFriendQuest | yes | not found |
| progress | POST /v1/me/deletion | deleteAccount | yes | yes |
| ai | GET /v1/ai/capabilities | getCapabilities | yes | yes |
| ai | POST /v1/tutor | tutorFeedback | yes | yes |
| ai | POST /v1/voice-sessions | createVoiceSession | yes | yes |
| ai | POST /v1/voice-sessions/{sessionId}/heartbeat | heartbeatVoiceSession | yes | yes |
| ai | POST /v1/voice-sessions/{sessionId}/close | closeVoiceSession | yes | yes |
| ai | POST /v1/assessment-jobs | createAssessment | yes | yes |
| ai | GET /v1/assessment-jobs/{jobId} | getAssessment | yes | yes |
| ai | POST /v1/voice-sessions/{sessionId}/turns | submitVoiceTurn | yes | yes |
| progress | POST /internal/events | consumeEvent | yes | not found |
| learning | GET /internal/outbox-watermark | getOutboxWatermark | yes | not found |
| learning | GET /v1/me/energy | getEnergy | yes | yes |
| learning | POST /v1/enrollments/{courseId}/activate | switchCourse | yes | yes |
| learning | POST /v1/enrollments/{courseId}/reset | resetCourse | yes | yes |
| learning | DELETE /v1/enrollments/{courseId} | removeCourse | yes | yes |
| learning | GET /v1/mistakes | listMistakes | yes | yes |
| learning | GET /v1/words | listWords | yes | yes |
| learning | GET /v1/activities | listActivityProgress | yes | yes |
| progress | GET /v1/me/preferences | getPreferences | yes | yes |
| progress | PATCH /v1/me/preferences | updatePreferences | yes | yes |
| progress | POST /v1/feedback | sendFeedback | yes | yes |
| progress | GET /v1/shop | listShop | yes | yes |
| progress | POST /v1/shop/purchases | buyItem | yes | yes |
| progress | POST /v1/me/boosts | activateBoost | yes | yes |
| progress | POST /v1/me/streak-repair | repairStreak | yes | yes |
| progress | GET /v1/friend-streaks | listFriendStreaks | yes | yes |
| progress | POST /v1/friend-streaks | inviteFriendStreak | yes | yes |
| progress | POST /v1/friend-streaks/{pairId}/respond | respondFriendStreak | yes | yes |
| progress | POST /v1/interactions | sendInteraction | yes | yes |
| progress | POST /v1/blocks | blockUser | yes | yes |
| progress | DELETE /v1/blocks/{userId} | unblockUser | yes | yes |
| progress | POST /v1/user-reports | reportUser | yes | yes |
| progress | POST /v1/classrooms/join | joinClassroom | yes | yes |
| progress | DELETE /v1/classrooms/{classroomId}/membership | leaveClassroom | yes | yes |
| progress | GET /v1/me/year-review/{year} | getYearReview | yes | not found |
| progress | GET /v1/league/result | getLeagueResult | yes | yes |
| progress | POST /v1/league/result/seen | markLeagueResultSeen | yes | yes |
| progress | GET /v1/me/entitlement | getEntitlement | yes | yes |
| progress | POST /v1/billing/purchases | verifyPurchase | yes | yes |
| progress | POST /internal/billing/notifications | billingNotification | yes | not found |
| progress | POST /v1/family | createFamily | yes | yes |
| progress | POST /v1/family/{groupId}/members | joinFamily | yes | yes |
| progress | DELETE /v1/family/{groupId}/members/{userId} | removeFamilyMember | yes | yes |
| progress | POST /v1/gifts | sendGift | yes | yes |
| progress | POST /v1/gifts/{giftId}/redeem | redeemGift | yes | yes |
| progress | GET /v1/me/referral | getReferral | yes | yes |
| progress | POST /v1/referrals/redeem | redeemReferral | yes | yes |
| progress | POST /v1/promo-codes/redeem | redeemPromoCode | yes | yes |
| progress | POST /v1/ad-events | recordAdEvent | yes | yes |
| ai | GET /v1/conversations | listConversations | yes | yes |
| ai | POST /v1/conversations | startConversation | yes | yes |
| ai | POST /v1/conversations/{conversationId}/complete | completeConversation | yes | yes |
| progress | POST /internal/jobs/streak-rollover | runStreakRollover | yes | not found |
| progress | POST /internal/jobs/league-settlement | runLeagueSettlement | yes | not found |
| progress | POST /internal/jobs/deletion-purge | runDeletionPurge | yes | not found |
| progress | POST /internal/jobs/progress-outbox-relay | runProgressOutboxRelay | yes | not found |
| learning | POST /internal/jobs/learning-outbox-dispatch | runLearningOutboxDispatch | yes | not found |
| progress | GET /v1/billing/purchases/{purchaseId} | getPurchase | yes | yes |
| progress | POST /v1/billing/subscription/cancel | cancelSubscription | yes | yes |
| progress | GET /v1/me/learning-stats | getLearningStats | yes | yes |

Next execution instructions: [DeepSeek master prompt](../agent/DEEPSEEK_MASTER_PROMPT_20261028.md).
