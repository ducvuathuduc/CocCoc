# Derived endpoint ownership matrix

Generated from [OpenAPI](openapi.yaml); wire DTOs/headers/errors/idempotency/rate/version behavior remain there and in [auth](AUTH.md)/[events-errors](EVENTS_ERRORS.md). [Behavior map](../product/SCREEN_BEHAVIOR_MAP.md) identifies consuming mock seams; [traceability](../quality/TRACEABILITY.md) names acceptance tests. Hosted business handlers are not implemented by a generated matrix.

| Route | Operation / owner | Requirements | Owned tables | Access |
|---|---|---|---|---|
| GET /health | getHealth / learning | health/internal | none | public health |
| GET /ready | getReadiness / learning | health/internal | none | JWT or specified internal signature |
| GET /v1/courses | listCourses / learning | FR-COURSE-001 | l_courses | JWT or specified internal signature |
| GET /v1/courses/{courseId}/manifest | getManifest / learning | FR-COURSE-001, FR-CONTENT-001 | l_content_versions | JWT or specified internal signature |
| POST /v1/enrollments | enrollCourse / learning | FR-COURSE-002 | l_enrollments, l_receipts | JWT or specified internal signature |
| GET /v1/courses/{courseId}/path | getPath / learning | FR-PATH-001 | l_enrollments, l_content_versions | JWT or specified internal signature |
| GET /v1/lessons/{lessonId}/bundle | getBundle / learning | FR-CONTENT-001, FR-LISTEN-001 | l_content_versions | JWT or specified internal signature |
| POST /v1/sessions | startSession / learning | FR-LESSON-001, FR-COURSE-002, FR-PRACTICE-001, FR-PATH-002 | l_sessions, l_active_slots, l_receipts | JWT or specified internal signature |
| GET /v1/sessions/{sessionId} | getSession / learning | FR-LESSON-004 | l_sessions, l_answers | JWT or specified internal signature |
| POST /v1/sessions/{sessionId}/answers | submitAnswer / learning | FR-LESSON-003 | l_sessions, l_answers, l_receipts | JWT or specified internal signature |
| POST /v1/sessions/{sessionId}/complete | completeSession / learning | FR-LESSON-006, FR-GAME-001 | l_sessions, l_enrollments, l_review_items, l_outbox, l_receipts | JWT or specified internal signature |
| POST /v1/sessions/{sessionId}/abandon | abandonSession / learning | FR-LESSON-004 | l_sessions, l_active_slots, l_receipts | JWT or specified internal signature |
| POST /v1/offline-completions | syncOfflineCompletion / learning | FR-LESSON-007, FR-SYNC-001 | l_sessions, l_answers, l_enrollments, l_outbox, l_receipts | JWT or specified internal signature |
| GET /v1/review | getReview / learning | FR-PRACTICE-001, FR-PRACTICE-002 | l_review_items | JWT or specified internal signature |
| POST /v1/reports | createReport / learning | FR-LESSON-005 | l_reports, l_receipts | JWT or specified internal signature |
| POST /v1/admin/content-versions | publishContent / learning | FR-CONTENT-001, FR-ADMIN-001 | l_courses, l_content_versions, l_receipts | JWT or specified internal signature |
| GET /v1/me | getMe / progress | FR-AUTH-002, FR-SET-001, FR-GAME-004 | p_profiles, p_achievements | JWT or specified internal signature |
| PATCH /v1/me | updateMe / progress | FR-SET-001 | p_profiles, p_zone_history, p_receipts | JWT or specified internal signature |
| POST /v1/me/initialize | initializeProfile / progress | FR-AUTH-001 | p_profiles, p_rewards, p_reward_ledger, p_zone_history, p_receipts | JWT or specified internal signature |
| GET /v1/me/rewards | getRewards / progress | FR-GAME-001, FR-GAME-002 | p_rewards, p_reward_ledger, p_day_activity | JWT or specified internal signature |
| GET /v1/quests | listQuests / progress | FR-QUEST-001, FR-QUEST-002 | p_quests, p_friend_quests | JWT or specified internal signature |
| POST /v1/quests/{questId}/claim | claimQuest / progress | FR-QUEST-001, FR-QUEST-002 | p_quests, p_rewards, p_reward_ledger, p_receipts | JWT or specified internal signature |
| POST /v1/me/freezes | buyFreeze / progress | FR-GAME-003 | p_rewards, p_freeze_ledger, p_receipts | JWT or specified internal signature |
| GET /v1/profiles/{userId} | getPublicProfile / progress | FR-SOCIAL-001 | p_profiles, p_rewards, p_follows, p_achievements | JWT or specified internal signature |
| POST /v1/follows | followUser / progress | FR-SOCIAL-001 | p_follows, p_receipts | JWT or specified internal signature |
| DELETE /v1/follows/{userId} | unfollowUser / progress | FR-SOCIAL-001 | p_follows, p_receipts | JWT or specified internal signature |
| GET /v1/friends | listFriends / progress | FR-SOCIAL-001 | p_follows, p_profiles | JWT or specified internal signature |
| GET /v1/activity | listActivity / progress | FR-SOCIAL-001, FR-GAME-004 | p_activity, p_follows | JWT or specified internal signature |
| GET /v1/league | getLeague / progress | FR-SOCIAL-002 | p_league_members, p_league_runs | JWT or specified internal signature |
| POST /v1/league/join | joinLeague / progress | FR-SOCIAL-002 | p_league_members, p_receipts | JWT or specified internal signature |
| POST /v1/friend-quests/opt-in | optInFriendQuest / progress | FR-QUEST-002 | p_friend_quests, p_receipts | JWT or specified internal signature |
| POST /v1/me/deletion | deleteAccount / progress | FR-AUTH-005 | p_deletions, p_outbox, p_receipts | JWT or specified internal signature |
| GET /v1/ai/capabilities | getCapabilities / ai | FR-SPEECH-001, FR-AI-001 | a_usage | JWT or specified internal signature |
| POST /v1/tutor | tutorFeedback / ai | FR-AI-001 | a_jobs, a_usage, a_receipts | JWT or specified internal signature |
| POST /v1/voice-sessions | createVoiceSession / ai | FR-SPEECH-002 | a_voice_sessions, a_active_slots, a_usage, a_receipts | JWT or specified internal signature |
| POST /v1/voice-sessions/{sessionId}/heartbeat | heartbeatVoiceSession / ai | FR-SPEECH-002 | a_voice_sessions | JWT or specified internal signature |
| POST /v1/voice-sessions/{sessionId}/close | closeVoiceSession / ai | FR-SPEECH-002 | a_voice_sessions | JWT or specified internal signature |
| POST /v1/assessment-jobs | createAssessment / ai | FR-SPEECH-003 | a_jobs, a_usage, a_receipts | JWT or specified internal signature |
| GET /v1/assessment-jobs/{jobId} | getAssessment / ai | FR-SPEECH-003 | a_jobs | JWT or specified internal signature |
| POST /v1/voice-sessions/{sessionId}/turns | submitVoiceTurn / ai | FR-SPEECH-002 | a_voice_sessions, a_usage, a_jobs, a_receipts | JWT or specified internal signature |
| POST /internal/events | consumeEvent / progress | FR-GAME-001, FR-AUTH-005 | p_inbox, p_reward_ledger, p_rewards, p_day_activity, p_quests | JWT or specified internal signature |
| GET /internal/outbox-watermark | getOutboxWatermark / learning | FR-SOCIAL-002 | l_outbox | JWT or specified internal signature |
| GET /v1/me/energy | getEnergy / learning | FR-GAME-005 | l_energy | JWT or specified internal signature |
| POST /v1/enrollments/{courseId}/activate | switchCourse / learning | FR-COURSE-002 | l_enrollments, l_receipts | JWT or specified internal signature |
| POST /v1/enrollments/{courseId}/reset | resetCourse / learning | FR-COURSE-002 | l_enrollments, l_receipts | JWT or specified internal signature |
| DELETE /v1/enrollments/{courseId} | removeCourse / learning | FR-COURSE-002 | l_enrollments, l_receipts | JWT or specified internal signature |
| GET /v1/mistakes | listMistakes / learning | FR-PRACTICE-002 | l_mistakes | JWT or specified internal signature |
| GET /v1/words | listWords / learning | FR-PRACTICE-002 | l_review_items | JWT or specified internal signature |
| GET /v1/activities | listActivityProgress / learning | FR-PRACTICE-001 | l_activity_progress | JWT or specified internal signature |
| GET /v1/me/preferences | getPreferences / progress | FR-SET-001 | p_preferences | JWT or specified internal signature |
| PATCH /v1/me/preferences | updatePreferences / progress | FR-SET-001 | p_preferences, p_receipts | JWT or specified internal signature |
| POST /v1/feedback | sendFeedback / progress | FR-SET-001 | p_feedback, p_receipts | JWT or specified internal signature |
| GET /v1/shop | listShop / progress | FR-GAME-003 | p_inventory, p_rewards | JWT or specified internal signature |
| POST /v1/shop/purchases | buyItem / progress | FR-GAME-003 | p_inventory, p_item_ledger, p_reward_ledger, p_rewards, p_freeze_ledger, p_outbox, p_receipts | JWT or specified internal signature |
| POST /v1/me/boosts | activateBoost / progress | FR-GAME-003 | p_inventory, p_item_ledger, p_boosts, p_receipts | JWT or specified internal signature |
| POST /v1/me/streak-repair | repairStreak / progress | FR-GAME-003 | p_rewards, p_reward_ledger, p_item_ledger, p_inventory, p_receipts | JWT or specified internal signature |
| GET /v1/friend-streaks | listFriendStreaks / progress | FR-SOCIAL-001 | p_friend_streaks, p_profiles | JWT or specified internal signature |
| POST /v1/friend-streaks | inviteFriendStreak / progress | FR-SOCIAL-001 | p_friend_streaks, p_follows, p_blocks, p_receipts | JWT or specified internal signature |
| POST /v1/friend-streaks/{pairId}/respond | respondFriendStreak / progress | FR-SOCIAL-001 | p_friend_streaks, p_receipts | JWT or specified internal signature |
| POST /v1/interactions | sendInteraction / progress | FR-SOCIAL-001 | p_interactions, p_reward_ledger, p_rewards, p_boosts, p_blocks, p_receipts | JWT or specified internal signature |
| POST /v1/blocks | blockUser / progress | FR-SOCIAL-001 | p_blocks, p_follows, p_friend_streaks, p_receipts | JWT or specified internal signature |
| DELETE /v1/blocks/{userId} | unblockUser / progress | FR-SOCIAL-001 | p_blocks, p_receipts | JWT or specified internal signature |
| POST /v1/user-reports | reportUser / progress | FR-SOCIAL-001 | p_user_reports, p_receipts | JWT or specified internal signature |
| POST /v1/classrooms/join | joinClassroom / progress | FR-SOCIAL-001 | p_classrooms, p_classroom_members, p_receipts | JWT or specified internal signature |
| DELETE /v1/classrooms/{classroomId}/membership | leaveClassroom / progress | FR-SOCIAL-001 | p_classroom_members, p_receipts | JWT or specified internal signature |
| GET /v1/me/year-review/{year} | getYearReview / progress | FR-SOCIAL-001 | p_year_reviews | JWT or specified internal signature |
| GET /v1/league/result | getLeagueResult / progress | FR-SOCIAL-002 | p_league_profiles | JWT or specified internal signature |
| POST /v1/league/result/seen | markLeagueResultSeen / progress | FR-SOCIAL-002 | p_league_profiles, p_receipts | JWT or specified internal signature |
| GET /v1/me/entitlement | getEntitlement / progress | FR-SET-001 | p_entitlements | JWT or specified internal signature |
| POST /v1/billing/purchases | verifyPurchase / progress | FR-SET-001 | p_purchases, p_entitlements, p_reward_ledger, p_rewards, p_outbox, p_receipts | JWT or specified internal signature |
| POST /internal/billing/notifications | billingNotification / progress | FR-SET-001 | p_purchases, p_entitlements, p_inbox, p_outbox | JWT or specified internal signature |
| POST /v1/family | createFamily / progress | FR-SET-001 | p_family_groups, p_entitlements, p_outbox, p_receipts | JWT or specified internal signature |
| POST /v1/family/{groupId}/members | joinFamily / progress | FR-SET-001 | p_family_groups, p_entitlements, p_outbox, p_receipts | JWT or specified internal signature |
| DELETE /v1/family/{groupId}/members/{userId} | removeFamilyMember / progress | FR-SET-001 | p_family_groups, p_entitlements, p_outbox, p_receipts | JWT or specified internal signature |
| POST /v1/gifts | sendGift / progress | FR-SET-001 | p_gifts, p_purchases, p_blocks, p_receipts | JWT or specified internal signature |
| POST /v1/gifts/{giftId}/redeem | redeemGift / progress | FR-SET-001 | p_gifts, p_entitlements, p_outbox, p_receipts | JWT or specified internal signature |
| GET /v1/me/referral | getReferral / progress | FR-SET-001 | p_referrals | JWT or specified internal signature |
| POST /v1/referrals/redeem | redeemReferral / progress | FR-SET-001 | p_referrals, p_entitlements, p_outbox, p_receipts | JWT or specified internal signature |
| POST /v1/promo-codes/redeem | redeemPromoCode / progress | FR-SET-001 | p_promo_codes, p_promo_redemptions, p_entitlements, p_reward_ledger, p_rewards, p_item_ledger, p_inventory, p_outbox, p_receipts | JWT or specified internal signature |
| POST /v1/ad-events | recordAdEvent / progress | FR-GAME-005 | p_ad_events, p_entitlements, p_reward_ledger, p_rewards, p_outbox, p_receipts | JWT or specified internal signature |
| GET /v1/conversations | listConversations / ai | FR-AI-001 | a_conversations | JWT or specified internal signature |
| POST /v1/conversations | startConversation / ai | FR-AI-001, FR-SPEECH-002 | a_conversations, a_voice_sessions, a_receipts | JWT or specified internal signature |
| POST /v1/conversations/{conversationId}/complete | completeConversation / ai | FR-AI-001 | a_conversations, a_voice_sessions, a_outbox, a_receipts | JWT or specified internal signature |
| POST /internal/jobs/streak-rollover | runStreakRollover / progress | FR-GAME-002 | p_rewards, p_day_activity, p_freeze_ledger, p_profiles | JWT or specified internal signature |
| POST /internal/jobs/league-settlement | runLeagueSettlement / progress | FR-SOCIAL-002 | p_league_runs, p_league_members, p_league_profiles, p_reward_ledger, p_rewards | JWT or specified internal signature |
| POST /internal/jobs/deletion-purge | runDeletionPurge / progress | FR-AUTH-005 | p_deletions, p_profiles, p_rewards, p_reward_ledger, p_receipts | JWT or specified internal signature |
| POST /internal/jobs/progress-outbox-relay | runProgressOutboxRelay / progress | FR-AUTH-005, FR-SET-001, FR-GAME-005 | p_outbox | JWT or specified internal signature |
| POST /internal/jobs/learning-outbox-dispatch | runLearningOutboxDispatch / learning | FR-GAME-001 | l_outbox | JWT or specified internal signature |

Health/ready shapes apply to all three independent service domains; Learning is the primary OpenAPI declaration owner. Internal events have receiver-specific allowlists, not cross-owned writes.

## Proposed endpoints

None. On 2026-10-12 (branch pb/contract2) every endpoint previously listed here as proposed for the 62-table model (MIGRATIONS M002 + M003) was promoted into [OpenAPI](openapi.yaml) and now appears in the generated table above: 41 operations covering energy, course switch/reset/remove, mistakes, words, the activity library, preferences, feedback, shop/boosts/streak repair, friend streaks, interactions, blocks, user reports, classrooms, Year in Review, league result, mock billing/entitlement/family/gifts/referrals, promo redemption, mock ad events and AI conversations. Each carries its x-requirements trace, owner tables and an Idempotency-Key on user mutations; handlers and owner-task acceptance tests remain with the planned tasks in [IMPLEMENTATION_PLAN](../agent/IMPLEMENTATION_PLAN.md). `tools/audit/endpoint-matrix.mjs` (`pnpm docs:endpoints`) still preserves this hand-maintained section, so new proposals can be listed here before their contract change.
