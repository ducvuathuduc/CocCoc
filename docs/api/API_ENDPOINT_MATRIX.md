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

Health/ready shapes apply to all three independent service domains; Learning is the primary OpenAPI declaration owner. Internal events have receiver-specific allowlists, not cross-owned writes.

## Proposed endpoints (not yet in OpenAPI)

Hand-maintained; `tools/audit/endpoint-matrix.mjs` (`pnpm docs:endpoints`) keeps this section when it regenerates the table above. These are PROPOSED for the 59-table data model (DATA_MODEL M002). None exists in openapi.yaml, generated types or handlers; each needs its OpenAPI operation, x-requirements trace, Idempotency-Key on mutations and an owner-task acceptance test before implementation. Table names are the owner tables the operation would touch.

| Route (proposed) | Operation / owner | Duolingo feature | Owned tables | Planned task |
|---|---|---|---|---|
| GET /v1/me/energy | getEnergy / learning | Energy battery | l_energy | P6-GAME-003 |
| POST /v1/enrollments/{courseId}/activate · /reset · DELETE /v1/enrollments/{courseId} | switchCourse, resetCourse, removeCourse / learning | multiple courses, reset/remove course | l_enrollments, l_receipts | P4-LEARN-003 |
| GET /v1/mistakes | listMistakes / learning | Practice Hub Mistakes | l_mistakes | P6-REVIEW-002 |
| GET /v1/words | listWords / learning | Practice Hub Words (recent/alphabetical) | l_review_items | P6-REVIEW-002 |
| GET /v1/activities | listActivityProgress / learning | Stories, Adventures, DuoRadio, side quests, Clash library | l_activity_progress | P7-PRACTICE-001 |
| GET/PATCH /v1/me/preferences | getPreferences, updatePreferences / progress | notification, sound, speaking/listening settings | p_preferences, p_receipts | P3-AUTH-002 |
| GET /v1/shop · POST /v1/shop/purchases | listShop, buyItem / progress | shop power-ups, energy refill, streak repair | p_inventory, p_item_ledger, p_reward_ledger, p_rewards, p_outbox, p_receipts | P6-GAME-003 |
| POST /v1/me/boosts | activateBoost / progress | XP boost, timer boost | p_inventory, p_item_ledger, p_boosts, p_receipts | P6-GAME-003 |
| POST /v1/me/streak-repair | repairStreak / progress | streak repair | p_rewards, p_reward_ledger, p_item_ledger, p_receipts | P6-GAME-003 |
| GET/POST /v1/friend-streaks · POST /v1/friend-streaks/{pairId}/respond | listFriendStreaks, inviteFriendStreak, respondFriendStreak / progress | Friend Streak | p_friend_streaks, p_follows, p_receipts | P9-SOCIAL-002 |
| POST /v1/interactions | sendInteraction / progress | nudge, high-five, kudos, gift XP boost | p_interactions, p_reward_ledger, p_boosts, p_receipts | P9-SOCIAL-002 |
| POST /v1/blocks · DELETE /v1/blocks/{userId} | blockUser, unblockUser / progress | block user | p_blocks, p_follows, p_friend_streaks, p_receipts | P9-SOCIAL-002 |
| POST /v1/user-reports | reportUser / progress | report user | p_user_reports, p_receipts | P9-SOCIAL-002 |
| GET /v1/league/result · POST /v1/league/result/seen | getLeagueResult, markLeagueResultSeen / progress | league result screen, Diamond Tournament | p_league_profiles, p_receipts | P9-LEAGUE-002 |
| GET /v1/me/entitlement · POST /v1/billing/purchases · POST /internal/billing/notifications | getEntitlement, verifyPurchase, billingNotification / progress | Super/Max, gems purchase | p_entitlements, p_purchases, p_outbox, p_receipts | P10-BILL-001 |
| POST /v1/family · POST /v1/family/{groupId}/members · DELETE …/members/{userId} | createFamily, joinFamily, removeFamilyMember / progress | Family Plan | p_family_groups, p_entitlements, p_receipts | P10-BILL-001 |
| POST /v1/gifts · POST /v1/gifts/{giftId}/redeem | sendGift, redeemGift / progress | gift Super/Max | p_gifts, p_purchases, p_entitlements, p_receipts | P10-BILL-001 |
| GET /v1/me/referral · POST /v1/referrals/redeem | getReferral, redeemReferral / progress | invite friends | p_referrals, p_entitlements, p_receipts | P10-BILL-001 |
| GET /v1/me/year-review/{year} | getYearReview / progress | Year in Review | p_year_reviews, p_day_activity | P9-SOCIAL-002 |
| POST /v1/feedback | sendFeedback / progress | settings feedback | p_feedback, p_receipts | P3-AUTH-002 |
| POST /v1/classrooms/join · DELETE /v1/classrooms/{classroomId}/membership | joinClassroom, leaveClassroom / progress | Duolingo for Schools join | p_classrooms, p_classroom_members, p_receipts | P9-SOCIAL-002 |
| GET /v1/conversations · POST /v1/conversations · POST /v1/conversations/{conversationId}/complete | listConversations, startConversation, completeConversation / ai | Roleplay, Video Call review | a_conversations, a_voice_sessions, a_outbox, a_receipts | P8-AI-003 |
