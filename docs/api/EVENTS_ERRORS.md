# API conventions, event protocol and errors

Wire schemas and endpoint operation IDs: [openapi.yaml](openapi.yaml). Service base URLs configured independently; mobile never discovers an admin URL from an API error. Prefix /v1. JSON UTF-8, UTC RFC3339 timestamps; identifiers opaque. Pagination cursor opaque, default20/max100, list returns items,nextCursor,asOf. Unknown fields rejected in mutation bodies except explicitly versioned extensible content payload.

Authorization: Appwrite JWT verified by Account.get. X-Request-ID accepted only valid UUID/≤64safe chars, otherwise server generated; return it and propagate through events. traceparent optional validated W3C format including nonzero trace/parent IDs and supported version. Idempotency-Key UUID on business mutations; scoped user+operation+key; canonical body hash. GET no body. HTTP429 Retry-After seconds. Generic body limit64KB; assessment and recorded TURN requests have a750KB exception. Input text512 answer chars/120-word tutor output; no arbitrary fetch URLs.

Error envelope:

~~~json
{"error":{"code":"NODE_LOCKED","message":"Complete the previous node first.","requestId":"uuid","details":{"currentNodeId":"node-id"},"retryable":false}}
~~~

| HTTP | Codes | Behavior |
|---|---|---|
| 400 | VALIDATION_ERROR, UNKNOWN_EXERCISE_TYPE, INVALID_AUDIO, INVALID_TIMEZONE, MODE_UNAVAILABLE | show safe field details, fix input, no auto-retry |
| 401 | AUTH_REQUIRED, AUTH_EXPIRED | restore session/login once, pause sync |
| 403 | FORBIDDEN, ACCOUNT_BLOCKED, MAINTAINER_REQUIRED | no retry, generic inaccessible resource |
| 403 | ENTITLEMENT_REQUIRED, USER_BLOCKED, AD_NOT_ELIGIBLE | plan/block/ad eligibility decided server-side; no retry (details per code below) |
| 404 | NOT_FOUND, PROFILE_UNAVAILABLE, ACTIVITY_NOT_FOUND | avoid exposing private existence; refresh permitted listing |
| 404 | CLASSROOM_CODE_INVALID | unknown and archived codes answer identically |
| 409 | NODE_LOCKED, SESSION_CONFLICT, SESSION_INCOMPLETE, SESSION_EXPIRED, CONTENT_VERSION_RETIRED, IDEMPOTENCY_CONFLICT, REVISION_CONFLICT, INSUFFICIENT_GEMS, FREEZE_CAPACITY, CHECKPOINT_LOCKED | preserve state, fetch current entity or repeat current version; no blind retry |
| 409 | ENERGY_DEPLETED, FRIEND_STREAK_LIMIT, ITEM_UNAVAILABLE, STREAK_REPAIR_EXPIRED, PURCHASE_PENDING, PROMO_ALREADY_REDEEMED, AD_DAILY_CAP | economy/social state conflict; refetch the owning resource, no blind retry (details per code below) |
| 409 | ACTIVE_VOICE_SESSION, VOICE_RESERVATION_CONFLICT, VOICE_SESSION_EXPIRED, VOICE_EPOCH_CONFLICT, VOICE_TOKEN_DELIVERY_UNCERTAIN | voice rules below; no blind remint or client budget refund |
| 413 | PAYLOAD_TOO_LARGE | shorter input/recording; never auto-split graded utterance |
| 429 | RATE_LIMITED, QUOTA_EXHAUSTED | honor Retry-After; capability fallback |
| 503 | AUTH_UNAVAILABLE, DB_UNAVAILABLE, STORAGE_UNAVAILABLE, AI_PROVIDER_UNAVAILABLE, ASSESSMENT_UNAVAILABLE, OPPONENT_UNAVAILABLE | idempotent transient retry bounded; offline/template fallback |
| 503 | SERVICE_NOT_CONFIGURED | hosted service has no enabled business adapter (P1 scaffold fail-closed, also /ready and unsigned internal routes); not retryable until deployment changes |
| 503 | NATIVE_LIVE_DISABLED | current account/device gate failed; select TURN with new session/key, never a paid provider |
| 504 | DEADLINE_EXCEEDED | same-key receipt lookup/retry; never assume uncommitted |
| 500 | INTERNAL_ERROR | redacted message; request ID; no leaked SQL/provider response |

IDEMPOTENCY_REPLAY (EDGE_CASE_MATRIX EC07) is a telemetry outcome for a same-key/same-body replay that returns the original receipt with its original 2xx status; it is never an error code. Codes of the endpoints promoted on 2026-10-12 (pb/contract2) are wire contract in [OpenAPI](openapi.yaml). They are in the HTTP table above and in `services/shared/src/errors.ts` (added with the Progress owner handlers, 2026-10-12); the table below keeps their per-operation behavior.

| Code | HTTP | Operations | Behavior |
|---|---|---|---|
| ENERGY_DEPLETED | 409 | startSession/submitAnswer under LIMITED energy | offer free mistakes review, refill or wait; never blocks UNLIMITED learning |
| ENTITLEMENT_REQUIRED | 403 | startConversation, createFamily | plan from p_entitlements projection only; show plan screen, no retry |
| USER_BLOCKED | 403 | inviteFriendStreak, sendInteraction, sendGift, followUser | block in either direction; generic unavailable message |
| FRIEND_STREAK_LIMIT | 409 | inviteFriendStreak, respondFriendStreak | 5 PENDING+ACTIVE per user |
| ITEM_UNAVAILABLE | 409 | buyItem, activateBoost, repairStreak, sendInteraction | item not in catalogVersion, not owned, or maxOwned reached; refetch shop |
| STREAK_REPAIR_EXPIRED | 409 | repairStreak | offer window closed or lostStreakDay mismatch |
| PURCHASE_PENDING | 409 | verifyPurchase, sendGift | mock purchase still PENDING; FREE stays available |
| CLASSROOM_CODE_INVALID | 404 | joinClassroom | unknown/archived code, same response for both |
| PROMO_ALREADY_REDEEMED | 409 | redeemPromoCode | new key for a code this user already redeemed; same-key replay returns the stored receipt; unknown/expired/exhausted codes stay NOT_FOUND |
| AD_NOT_ELIGIBLE | 403 | recordAdEvent | SUPER/MAX (ACTIVE/GRACE) users never see ads |
| AD_DAILY_CAP | 409 | recordAdEvent | no free dailyIndex under the configured cap for this placement/kind/day |

Authored activity modes add four codes: `MODE_UNAVAILABLE` (400) when the published content does not author the requested mode or a required `passThreshold`; `ACTIVITY_NOT_FOUND` (404) when `lessonId`/`activityId` does not resolve to authored content; `CHECKPOINT_LOCKED` (409) when section prerequisites are incomplete; `OPPONENT_UNAVAILABLE` (503) when CLASH has no authored scripted opponent. A failed TEST_OUT/CHECKPOINT is **not** an error: the completion succeeds with HTTP 200 and `passed=false`, and it changes no frontier. `passThreshold` is authored and server-owned; clients cannot set or override it.

Client-only codes NETWORK_TIMEOUT, CACHE_CORRUPT, JOURNAL_CORRUPT, MIC_PERMISSION_DENIED, MIC_UNAVAILABLE, SPEECH_NO_INPUT, AUDIO_INTERRUPTED, AUDIO_PLAYBACK_FAILED, VOICE_DISCONNECTED, VOICE_STALE_EVENT, AI_INVALID_OUTPUT, SYNC_REJECTED map to [edge cases](../product/EDGE_CASE_MATRIX.md); never returned as fictional vendor error codes.

## Voice and job retry exceptions

Generic body limits use decimal bytes:64KB=64000;750KB=750000 complete UTF-8 request bytes for assessment/TURN. Both WAV fields additionally enforce≤640064 base64 characters and decoded mono16kHz PCM WAV≤480044 bytes/15s. Envelope limit never increases audio duration.

createVoiceSession atomically writes active native slot,180s usage reservation, voice metadata and token-free receipt before mint. Client never selects model/provider: capability booleans govern available UI; lease configVersion/providerAlias/model are server-selected transport data. LIVE leases require nonempty ephemeralToken/connectExpiresAt; TURN leases require both null. TURN can start while a spent native lease expires; it does not claim a second native slot.

ACTIVE_VOICE_SESSION returns original sessionId/expiresAt; resume an already held credential only under tested resumption policy, or start a distinct TURN session. VOICE_RESERVATION_CONFLICT retries the same key at most once after refetch; exhaustion selects TURN. VOICE_SESSION_EXPIRED requires a new sessionId/key after capability check. VOICE_EPOCH_CONFLICT returns current epoch; discard stale buffers and update it, no automatic old-audio replay. Background resumes a fresh TURN session; LIVE uses a fresh grant after original expiry unless tested same-lease resumption applies.

VOICE_TOKEN_DELIVERY_UNCERTAIN is terminal for that native reservation, including ambiguous mint and any retry after a successful mint whose token is no longer in the issuing response. Store only the error/sessionId/expiry receipt, never token bytes. Same-key replay returns this token-free state and never mints again. Budget remains consumed; after original expiry a new native grant needs a new session/key and quota. A new TURN session may start immediately. A known pre-mint failure releases unspent reservation/slot and returns provider unavailable; same-key error replay remains immutable, next attempt uses a new key. Generic504 same-key retry must obey this exception.

Assessment acceptance atomically reserves validated WAV duration in recorded-speech allowance with job and receipt. QUOTA_EXHAUSTED creates no job or provider request. Same key/body returns the original job identity and current state; differing body is IDEMPOTENCY_CONFLICT. A terminal FAILED/EXPIRED retry uses both a new jobId and new key; existing jobId with new body/key cannot dispatch again. Provider retries stay within the job identity but every additional audio dispatch reserves additional measured duration first. No automatic retry after ambiguous provider acceptance; mark FAILED with safe reason. Definitive pre-dispatch failures release reservation. Results/job polling never consumes more audio allowance. TURN uses the same allowance and turnId/key dedupe policy. Dispatch lease recovery cannot prove no side effect: ambiguous crashed dispatch fails rather than silently resending.

## Business event envelope

~~~json
{"eventId":"uuid","type":"lesson.completed.v1","schemaVersion":1,"producer":"learning","aggregateId":"session-id","occurredAt":"2026-10-03T10:00:00Z","requestId":"uuid","payload":{"completionId":"session-id","userId":"user-id","courseId":"vi_en","lessonVersion":"v1","rewardIdentity":"lesson-1","source":"ONLINE","mode":"LESSON","originalCount":10,"originalCorrect":9,"assisted":false}}
~~~

Events: lesson.completed.v1 (Learning→Progress); account.deleted.v1 (Progress→Learning/AI); account.purged.v1 (owner acknowledgement→Progress); zone.changed.v1 (Progress operational notification, not a reason to rewrite old Learning data). Added to the OpenAPI BusinessEvent union on 2026-10-12 (producers ship with their owner tasks): ai.practice.completed.v1 (AI→Progress; conversationId as completionId, kind ROLEPLAY/VIDEO_CALL, xp, wordsUsed; consumed since 2026-10-12: Progress accepts it only from producer ai with payload.userId = aggregateId, credits one PRACTICE ledger row per user+conversation under the SRS practice cap, AI's scheduled ai-outbox-relay drains a_outbox every minute); entitlement.changed.v1 (Progress→Learning/AI; userId, plan, status, expiresAt, entitlement revision; consumers keep only the newest revision); energy.granted.v1 (Progress→Learning; operationId, amount or refill-to-capacity, reason SHOP/CHEST/FRIEND/QUEST/AD/PROMO). lesson.completed.v1 mode gains the reserved session modes listed in DATA_MODEL l_sessions. Payload user IDs come only from trusted owner records. No raw audio/transcript/password/email. Consumers validate event type/version/producer/ranges. Unknown version dead-letters and alerts; never partially applies.

Learning completion and outbox insert commit atomically. Worker leases≤20due rows with optimistic transaction, lease30s, delivers sequentially within deadline, checkpoints ack. If lease expires another worker may redeliver. Consumer creates inbox and all domain effects in one transaction. Duplicate event with same hash returns accepted/replayed; changed payload hash is409 security error. No claim of exactly-once network delivery; exactly-once **effects** come from dedupe and transactions.

HMAC-SHA256 keys pair-specific, rotated with keyId; hosted Functions read the keyring from the COC_SERVICE_KEYS environment variable (JSON list of keyId/sender/secretHex, secrets ≥32 bytes). Header names X-Service-Key-Id, X-Service-Timestamp, X-Service-Signature. Sign UTF-8 timestamp+"\n"+method+"\n"+pathAndCanonicalQuery+"\n"+sha256(rawBody). Timestamp skew≤300s, constant-time comparison. Receiver validates sender/type allowlist before mutation. Inbox/event ID gives replay protection; read-only watermark signature doesn't create domain effects. Never trust a spoofable header to select scheduler mode; platform provenance validated by P1 negative test or private scheduled entrypoint.

Receiver allowlists (services/shared/src/transport.ts EVENT_ALLOWLIST): Progress accepts lesson.completed.v1 from Learning and account.purged.v1 from Learning/AI; Learning accepts account.deleted.v1, entitlement.changed.v1 and energy.granted.v1 from Progress; AI accepts account.deleted.v1 and entitlement.changed.v1 from Progress. A receiver without the consumer effect answers 503 SERVICE_NOT_CONFIGURED (the relay retries, then dead-letters); it never acknowledges an event it did not apply. Progress relays each p_outbox row to every target owner (account.deleted.v1 and entitlement.changed.v1 to Learning and AI, energy.granted.v1 to Learning) and marks ACK only when all targets acknowledged; 400/403/IDEMPOTENCY_CONFLICT dead-letter immediately, anything else retries with jittered backoff and dead-letters after 10 attempts.

Scheduler ticks: the signed POST /internal/jobs/* operations (runStreakRollover, runLeagueSettlement, runDeletionPurge, runProgressOutboxRelay on Progress; runLearningOutboxDispatch on Learning) accept only a `scheduler` or `maintainer` sender key from COC_SERVICE_KEYS (body JobTickRequest, answer JobRunReport). On Appwrite the same jobs also run in the hosted entry's worker mode for platform cron executions (`x-appwrite-trigger: schedule` at `/`); a client cannot set that trigger over the public domain (live probe 2026-10-12: a forged header is executed as trigger `http` and answered 401). The worker takes no request input and every job is idempotent.

Signature encoding is64lowercase hex characters; HMAC key is≥32random bytes, never published. Timestamp is decimal Unix seconds with no fractional/leading-zero variant; method uppercase. Canonical path is the exact decoded route re-encoded per RFC3986 with slash separators, no dot segments or duplicate slash. Query keys sorted by ASCII/code-unit order; reject duplicate/unknown keys; encode key/value UTF-8 using RFC3986 percent escapes (space=%20, uppercase hex), joined with ampersand and prefixed question mark only when nonempty. GET body hash is SHA-256 of empty bytes. Internal watermark has only validated before normalized as UTC RFC3339; verification uses identical normalization. Fixed signing fixtures cover spaces, Unicode, reordered params, query duplication and body tampering.

Internal endpoints /internal/events (Progress accepts completion/purge ack; Learning/AI accept deletion), /internal/outbox-watermark?before=UTC (Learning) require HMAC. Watermark returns oldestUndeliveredAt|null and pendingBefore integer, including dead letters. League close requires pendingBefore=0 for cutoff and no unprocessed inbox reservation; its own projection checkpoint complete. Downstream outage never drops an event.

Dead-letter after10failures; retain payload/last safe code, alert at age>5min. Recovery script dry-runs selected IDs, requeues under owner revision, then checks consumer ledger and watermark. Event schemas are defined in OpenAPI shared components and signed HTTP operations; a separate AsyncAPI document/broker would duplicate these contracts without benefit.
