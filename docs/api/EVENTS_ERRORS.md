# API conventions, event protocol and errors

Wire schemas and endpoint operation IDs: [openapi.yaml](openapi.yaml). Service base URLs configured independently; mobile never discovers an admin URL from an API error. Prefix /v1. JSON UTF-8, UTC RFC3339 timestamps; identifiers opaque. Pagination cursor opaque, default20/max100, list returns items,nextCursor,asOf. Unknown fields rejected in mutation bodies except explicitly versioned extensible content payload.

Authorization: Appwrite JWT verified by Account.get. X-Request-ID accepted only valid UUID/≤64safe chars, otherwise server generated; return it and propagate through events. traceparent optional validated W3C format including nonzero trace/parent IDs and supported version. Idempotency-Key UUID on business mutations; scoped user+operation+key; canonical body hash. GET no body. HTTP429 Retry-After seconds. Generic body limit64KB; assessment and recorded TURN requests have a750KB exception. Input text512 answer chars/120-word tutor output; no arbitrary fetch URLs.

Error envelope:

~~~json
{"error":{"code":"NODE_LOCKED","message":"Complete the previous node first.","requestId":"uuid","details":{"currentNodeId":"node-id"},"retryable":false}}
~~~

| HTTP | Codes | Behavior |
|---|---|---|
| 400 | VALIDATION_ERROR, UNKNOWN_EXERCISE_TYPE, INVALID_AUDIO, INVALID_TIMEZONE | show safe field details, fix input, no auto-retry |
| 401 | AUTH_REQUIRED, AUTH_EXPIRED | restore session/login once, pause sync |
| 403 | FORBIDDEN, ACCOUNT_BLOCKED, MAINTAINER_REQUIRED | no retry, generic inaccessible resource |
| 404 | NOT_FOUND, PROFILE_UNAVAILABLE | avoid exposing private existence; refresh permitted listing |
| 409 | NODE_LOCKED, SESSION_CONFLICT, SESSION_INCOMPLETE, SESSION_EXPIRED, CONTENT_VERSION_RETIRED, IDEMPOTENCY_CONFLICT, REVISION_CONFLICT, INSUFFICIENT_GEMS, FREEZE_CAPACITY | preserve state, fetch current entity or repeat current version; no blind retry |
| 409 | ACTIVE_VOICE_SESSION, VOICE_RESERVATION_CONFLICT, VOICE_SESSION_EXPIRED, VOICE_EPOCH_CONFLICT, VOICE_TOKEN_DELIVERY_UNCERTAIN | voice rules below; no blind remint or client budget refund |
| 413 | PAYLOAD_TOO_LARGE | shorter input/recording; never auto-split graded utterance |
| 429 | RATE_LIMITED, QUOTA_EXHAUSTED | honor Retry-After; capability fallback |
| 503 | AUTH_UNAVAILABLE, DB_UNAVAILABLE, STORAGE_UNAVAILABLE, AI_PROVIDER_UNAVAILABLE, ASSESSMENT_UNAVAILABLE | idempotent transient retry bounded; offline/template fallback |
| 503 | NATIVE_LIVE_DISABLED | current account/device gate failed; select TURN with new session/key, never a paid provider |
| 504 | DEADLINE_EXCEEDED | same-key receipt lookup/retry; never assume uncommitted |
| 500 | INTERNAL_ERROR | redacted message; request ID; no leaked SQL/provider response |

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

Events: lesson.completed.v1 (Learning→Progress); account.deleted.v1 (Progress→Learning/AI); account.purged.v1 (owner acknowledgement→Progress); zone.changed.v1 (Progress operational notification, not a reason to rewrite old Learning data). Payload user IDs come only from trusted owner records. No raw audio/transcript/password/email. Consumers validate event type/version/producer/ranges. Unknown version dead-letters and alerts; never partially applies.

Learning completion and outbox insert commit atomically. Worker leases≤20due rows with optimistic transaction, lease30s, delivers sequentially within deadline, checkpoints ack. If lease expires another worker may redeliver. Consumer creates inbox and all domain effects in one transaction. Duplicate event with same hash returns accepted/replayed; changed payload hash is409 security error. No claim of exactly-once network delivery; exactly-once **effects** come from dedupe and transactions.

HMAC-SHA256 keys pair-specific, rotated with keyId. Header names X-Service-Key-Id, X-Service-Timestamp, X-Service-Signature. Sign UTF-8 timestamp+"\n"+method+"\n"+pathAndCanonicalQuery+"\n"+sha256(rawBody). Timestamp skew≤300s, constant-time comparison. Receiver validates sender/type allowlist before mutation. Inbox/event ID gives replay protection; read-only watermark signature doesn't create domain effects. Never trust a spoofable header to select scheduler mode; platform provenance validated by P1 negative test or private scheduled entrypoint.

Signature encoding is64lowercase hex characters; HMAC key is≥32random bytes, never published. Timestamp is decimal Unix seconds with no fractional/leading-zero variant; method uppercase. Canonical path is the exact decoded route re-encoded per RFC3986 with slash separators, no dot segments or duplicate slash. Query keys sorted by ASCII/code-unit order; reject duplicate/unknown keys; encode key/value UTF-8 using RFC3986 percent escapes (space=%20, uppercase hex), joined with ampersand and prefixed question mark only when nonempty. GET body hash is SHA-256 of empty bytes. Internal watermark has only validated before normalized as UTC RFC3339; verification uses identical normalization. Fixed signing fixtures cover spaces, Unicode, reordered params, query duplication and body tampering.

Internal endpoints /internal/events (Progress accepts completion/purge ack; Learning/AI accept deletion), /internal/outbox-watermark?before=UTC (Learning) require HMAC. Watermark returns oldestUndeliveredAt|null and pendingBefore integer, including dead letters. League close requires pendingBefore=0 for cutoff and no unprocessed inbox reservation; its own projection checkpoint complete. Downstream outage never drops an event.

Dead-letter after10failures; retain payload/last safe code, alert at age>5min. Recovery script dry-runs selected IDs, requeues under owner revision, then checks consumer ledger and watermark. Event schemas are defined in OpenAPI shared components and signed HTTP operations; a separate AsyncAPI document/broker would duplicate these contracts without benefit.
