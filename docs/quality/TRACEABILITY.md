# Requirement traceability

This is a coverage index, not another product specification. [SRS](../product/SRS.md) owns functional behavior; [NFR](../architecture/NFR.md) owns target metrics; [OpenAPI](../api/openapi.yaml) owns operation schemas; [screens](../product/SCREEN_INVENTORY.md) own UI states; [plan](../agent/IMPLEMENTATION_PLAN.md) owns tasks. Listed acceptance evidence is required future work, not a claim that tests already ran. tools/blueprint/validate.mjs checks IDs and API mapping drift.

| Requirement | API operation IDs or local/managed boundary | Screens | Owning tasks | Acceptance evidence to produce |
|---|---|---|---|---|
| FR-ONB-001 | LOCAL: persisted onboarding choices | SC02, SC03, SC04, SC05, SC06, SC07 | P2-FE-001 | Kill/resume onboarding, unavailable course, offline guest result is unranked. |
| FR-ONB-002 | LOCAL: bundled guest lesson | SC02, SC03, SC04, SC05, SC06, SC07 | P2-FE-001 | Kill/resume onboarding, unavailable course, offline guest result is unranked. |
| FR-AUTH-001 | initializeProfile | SC01, SC08, SC09, SC10, SC11, SC41, SC42 | P3-AUTH-001, P3-AUTH-002, P3-QA-001 | SDK restoration/OAuth cancellation/revocation/tombstone and cross-user cache isolation. |
| FR-AUTH-002 | getMe | SC01, SC08, SC09, SC10, SC11, SC41, SC42 | P3-AUTH-001, P3-AUTH-002, P3-QA-001 | SDK restoration/OAuth cancellation/revocation/tombstone and cross-user cache isolation. |
| FR-AUTH-003 | LOCAL: Appwrite Account OAuth | SC01, SC08, SC09, SC10, SC11, SC41, SC42 | P3-AUTH-001, P3-AUTH-002, P3-QA-001 | SDK restoration/OAuth cancellation/revocation/tombstone and cross-user cache isolation. |
| FR-AUTH-004 | LOCAL: Appwrite Account logout and cache | SC01, SC08, SC09, SC10, SC11, SC41, SC42 | P3-AUTH-001, P3-AUTH-002, P3-QA-001 | SDK restoration/OAuth cancellation/revocation/tombstone and cross-user cache isolation. |
| FR-AUTH-005 | consumeEvent, deleteAccount | SC01, SC08, SC09, SC10, SC11, SC41, SC42 | P3-AUTH-001, P3-AUTH-002, P3-QA-001 | SDK restoration/OAuth cancellation/revocation/tombstone and cross-user cache isolation. |
| FR-COURSE-001 | getManifest, listCourses | SC12, SC14 | P4-LEARN-001, P4-LEARN-002, P4-FE-001 | Published-only listing, score7/8 placement boundary, duplicate enroll monotonicity. |
| FR-COURSE-002 | enrollCourse, startSession | SC12, SC14 | P4-LEARN-001, P4-LEARN-002, P4-FE-001 | Published-only listing, score7/8 placement boundary, duplicate enroll monotonicity. |
| FR-PATH-001 | getPath | SC13, SC15, SC16 | P4-LEARN-002, P4-FE-001, P5-LESSON-002 | Locked/current/completed/mastery states, no offline unlock, no repeated reward. |
| FR-PATH-002 | startSession | SC13, SC15, SC16 | P4-LEARN-002, P4-FE-001, P5-LESSON-002 | Locked/current/completed/mastery states, no offline unlock, no repeated reward. |
| FR-CONTENT-001 | getBundle, getManifest, publishContent | SC15, SC17 | P4-LEARN-001 | Typed publication alternatives/assets/signature/key/hash tests and atomic pointer flip. |
| FR-LESSON-001 | startSession | SC17, SC18, SC19, SC20, SC21, SC40 | P5-LESSON-001, P5-LESSON-002, P5-FE-001, P5-QA-001 | 12kinds, repeated token/match IDs, retry passes, concurrent revision, duplicate/uncertain commit, killed-process journal. |
| FR-LESSON-002 | LOCAL: input reducer and durable draft | SC17, SC18, SC19, SC20, SC21, SC40 | P5-LESSON-001, P5-LESSON-002, P5-FE-001, P5-QA-001 | 12kinds, repeated token/match IDs, retry passes, concurrent revision, duplicate/uncertain commit, killed-process journal. |
| FR-LESSON-003 | submitAnswer | SC17, SC18, SC19, SC20, SC21, SC40 | P5-LESSON-001, P5-LESSON-002, P5-FE-001, P5-QA-001 | 12kinds, repeated token/match IDs, retry passes, concurrent revision, duplicate/uncertain commit, killed-process journal. |
| FR-LESSON-004 | abandonSession, getSession | SC17, SC18, SC19, SC20, SC21, SC40 | P5-LESSON-001, P5-LESSON-002, P5-FE-001, P5-QA-001 | 12kinds, repeated token/match IDs, retry passes, concurrent revision, duplicate/uncertain commit, killed-process journal. |
| FR-LESSON-005 | createReport | SC17, SC18, SC19, SC20, SC21, SC40 | P5-LESSON-001, P5-LESSON-002, P5-FE-001, P5-QA-001 | 12kinds, repeated token/match IDs, retry passes, concurrent revision, duplicate/uncertain commit, killed-process journal. |
| FR-LESSON-006 | completeSession | SC17, SC18, SC19, SC20, SC21, SC40 | P5-LESSON-001, P5-LESSON-002, P5-FE-001, P5-QA-001 | 12kinds, repeated token/match IDs, retry passes, concurrent revision, duplicate/uncertain commit, killed-process journal. |
| FR-LESSON-007 | syncOfflineCompletion | SC17, SC18, SC19, SC20, SC21, SC40 | P5-LESSON-001, P5-LESSON-002, P5-FE-001, P5-QA-001 | 12kinds, repeated token/match IDs, retry passes, concurrent revision, duplicate/uncertain commit, killed-process journal. |
| FR-PRACTICE-001 | getReview, startSession | SC23, SC24, SC25, SC26, SC27 | P6-REVIEW-001, P6-FE-001 | Empty pool/reveal assisted, heuristic interval reset, bounded private snapshot and dedupe. |
| FR-PRACTICE-002 | getReview | SC23, SC24, SC25, SC26, SC27 | P6-REVIEW-001, P6-FE-001 | Empty pool/reveal assisted, heuristic interval reset, bounded private snapshot and dedupe. |
| FR-GAME-001 | completeSession, consumeEvent, getRewards | SC21, SC22, SC33, SC37 | P6-GAME-001, P6-GAME-002, P6-FE-001 | Ledger sum, first/replay/daily caps, late/zone/DST, freeze purchase/consume once, milestone once. |
| FR-GAME-002 | getRewards | SC21, SC22, SC33, SC37 | P6-GAME-001, P6-GAME-002, P6-FE-001 | Ledger sum, first/replay/daily caps, late/zone/DST, freeze purchase/consume once, milestone once. |
| FR-GAME-003 | buyFreeze | SC21, SC22, SC33, SC37 | P6-GAME-001, P6-GAME-002, P6-FE-001 | Ledger sum, first/replay/daily caps, late/zone/DST, freeze purchase/consume once, milestone once. |
| FR-GAME-004 | getMe, listActivity | SC21, SC22, SC33, SC37 | P6-GAME-001, P6-GAME-002, P6-FE-001 | Ledger sum, first/replay/daily caps, late/zone/DST, freeze purchase/consume once, milestone once. |
| FR-GAME-005 | LOCAL: unlimited energy config | SC21, SC22, SC33, SC37 | P6-GAME-001, P6-GAME-002, P6-FE-001 | Ledger sum, first/replay/daily caps, late/zone/DST, freeze purchase/consume once, milestone once. |
| FR-LISTEN-001 | getBundle | SC26 | P7-AUDIO-001, P7-AUDIO-002 | Cached normal/slow playback, interruption/asset hash/typed substitute and physical audio. |
| FR-SPEECH-001 | getCapabilities | SC27, SC28, SC29, SC30 | P8-AI-001, P8-AI-002, P8-FE-001, P8-QA-001 | Mic denial/silence/Bluetooth/epoch, constrained expiry, ambiguous mint, nullable dedicated score, fallback. |
| FR-SPEECH-002 | closeVoiceSession, createVoiceSession, heartbeatVoiceSession, submitVoiceTurn | SC27, SC28, SC29, SC30 | P8-AI-001, P8-AI-002, P8-FE-001, P8-QA-001 | Mic denial/silence/Bluetooth/epoch, constrained expiry, ambiguous mint, nullable dedicated score, fallback. |
| FR-SPEECH-003 | createAssessment, getAssessment | SC27, SC28, SC29, SC30 | P8-AI-001, P8-AI-002, P8-FE-001, P8-QA-001 | Mic denial/silence/Bluetooth/epoch, constrained expiry, ambiguous mint, nullable dedicated score, fallback. |
| FR-AI-001 | getCapabilities, tutorFeedback | SC19, SC29 | P8-AI-002, P8-QA-001 | Reference-bound correct explanation, malformed/off-topic output template, bounded usage. |
| FR-SOCIAL-001 | followUser, getPublicProfile, listActivity, listFriends, unfollowUser | SC32, SC34, SC35, SC36 | P9-SOCIAL-001, P9-LEAGUE-001, P9-FE-001 | Private opt-in/reciprocal friends, deterministic ranks, late events/watermark before closure. |
| FR-SOCIAL-002 | getLeague, getOutboxWatermark, joinLeague | SC32, SC34, SC35, SC36 | P9-SOCIAL-001, P9-LEAGUE-001, P9-FE-001 | Private opt-in/reciprocal friends, deterministic ranks, late events/watermark before closure. |
| FR-QUEST-001 | claimQuest, listQuests | SC31, SC35 | P9-SOCIAL-001, P9-FE-001 | Claim/period dedupe, pending metric, frozen pair membership, no partner solo fallback. |
| FR-QUEST-002 | claimQuest, listQuests, optInFriendQuest | SC31, SC35 | P9-SOCIAL-001, P9-FE-001 | Claim/period dedupe, pending metric, frozen pair membership, no partner solo fallback. |
| FR-SET-001 | getMe, updateMe | SC33, SC38 | P3-AUTH-002, P6-FE-001 | Revision conflict, valid goal/zone with explicit effective UTC instant, local accessibility persists. |
| FR-NOTIFY-001 | LOCAL: device reminder permission/scheduler | SC39 | P6-FE-001 | First explanation/OS consent, reminder deduplication, handling denied permissions, disabled reminders and logout. |
| FR-SYNC-001 | syncOfflineCompletion | SC40, SC42 | P5-FE-001, P5-QA-001, P10-REL-001 | Airplane/kill/reorder/retired content/expired auth preserve and converge journal. |
| FR-ADMIN-001 | publishContent | — | P1-OPS-001, P4-LEARN-001 | Role/permission probe, dry-run migration/publish/seed and compatible rollback. |
| NFR-PERF-001 | LOCAL: measurement/fault gate | — | P10-PERF-001 | Measured release/profile launch/frame/API/audio/size traces; budgets remain targets until P10. |
| NFR-PERF-002 | LOCAL: measurement/fault gate | — | P10-PERF-001 | Measured release/profile launch/frame/API/audio/size traces; budgets remain targets until P10. |
| NFR-PERF-003 | LOCAL: measurement/fault gate | — | P10-PERF-001 | Measured release/profile launch/frame/API/audio/size traces; budgets remain targets until P10. |
| NFR-PERF-004 | LOCAL: measurement/fault gate | — | P10-PERF-001 | Measured release/profile launch/frame/API/audio/size traces; budgets remain targets until P10. |
| NFR-PERF-005 | LOCAL: measurement/fault gate | — | P10-PERF-001 | Measured release/profile launch/frame/API/audio/size traces; budgets remain targets until P10. |
| NFR-PERF-006 | LOCAL: measurement/fault gate | — | P10-PERF-001 | Measured release/profile launch/frame/API/audio/size traces; budgets remain targets until P10. |
| NFR-SPEECH-001 | LOCAL: measurement/fault gate | — | P8-QA-001, P10-PERF-001 | Actual mic/transport/final/first-audio/score timing on named device/network; no fixture timing proof. |
| NFR-SPEECH-002 | LOCAL: measurement/fault gate | — | P8-QA-001, P10-PERF-001 | Actual mic/transport/final/first-audio/score timing on named device/network; no fixture timing proof. |
| NFR-REL-001 | LOCAL: measurement/fault gate | — | P5-QA-001, P6-GAME-001, P10-REL-001, P10-OPS-001 | Crash before/after transaction/ack,100duplicate/reorder trials, ledger equality and event lag. |
| NFR-REL-002 | LOCAL: measurement/fault gate | — | P5-QA-001, P6-GAME-001, P10-REL-001, P10-OPS-001 | Crash before/after transaction/ack,100duplicate/reorder trials, ledger equality and event lag. |
| NFR-REL-003 | LOCAL: measurement/fault gate | — | P5-QA-001, P6-GAME-001, P10-REL-001, P10-OPS-001 | Crash before/after transaction/ack,100duplicate/reorder trials, ledger equality and event lag. |
| NFR-OFF-001 | LOCAL: measurement/fault gate | — | P5-QA-001, P10-REL-001 | 30min airplane-mode unit, last committed answer after kill, replay convergence and cache namespace. |
| NFR-SEC-001 | LOCAL: measurement/fault gate | — | P3-QA-001, P8-QA-001, P10-REL-001 | Secret/binary/log scan, verified-subject negatives, HMAC/body replay and resource permission probes. |
| NFR-SEC-002 | LOCAL: measurement/fault gate | — | P3-QA-001, P8-QA-001, P10-REL-001 | Secret/binary/log scan, verified-subject negatives, HMAC/body replay and resource permission probes. |
| NFR-COST-001 | LOCAL: measurement/fault gate | — | P10-OPS-001, P11-DEMO-001 | Actual console quota/expiry screenshots, no new bill, optional paid flags disabled, rehearsed local fallback. |
| NFR-STORE-001 | LOCAL: measurement/fault gate | — | P10-PERF-001 | Steady/peak RSS, disk cache and compressed download size on admitted devices. |
| NFR-DATA-001 | LOCAL: measurement/fault gate | — | P10-OPS-001 | Encrypted daily export and real restore rehearsal, measured RPO/RTO, no private files in Git. |
| NFR-OBS-001 | LOCAL: measurement/fault gate | — | P10-OPS-001 | Redacted log schema/request propagation and bounded exporter drop behavior. |
| NFR-TEST-001 | LOCAL: measurement/fault gate | — | P1-OPS-001, P11-QA-001 | Isolated fake CI requires no live AI/private account/mic/store credentials. |

Every functional requirement maps to an owner task and either a business operation or named local/managed SDK boundary. Common auth/error/offline requirements also apply to every protected operation, without copying them into each endpoint. Data tables used only by owner workers (outbox sweeps, inbox acknowledgements, achievements, quotas/settlement) are governed by DATA_MODEL and service allowlists even when no public API writes them. Phase2 covers every screen fixture; later tasks connect the same commands to real repositories.
