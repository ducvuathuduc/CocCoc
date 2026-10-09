# Central failure and recovery catalog

Every row is an acceptance scenario. Telemetry contains code/requestId/operation, never credentials or raw learner audio/text by default. Retry policy: [service catalog](../architecture/SERVICE_CATALOG.md). “Same key” means reuse the operation ID and identical canonical body.

| ID / condition | Detection | User-visible result | Retry / recovery | Telemetry |
|---|---|---|---|---|
| EC01 expired/revoked/deleted session | Account.get 401/blocked | sign in; input retained privately until logout decision | pause journal; verify same user after login | AUTH_EXPIRED |
| EC02 auth upstream outage | 5xx/deadline | cache-only practice; auth retry | no fail-open identity | AUTH_UNAVAILABLE |
| EC03 OAuth cancel/provider/network/duplicate identity | SDK callback outcome | return to login, link help when appropriate | restart clean flow; no silent account merge | AUTH_PROVIDER_FAILURE without provider token |
| EC04 onboarding process killed | persisted step | same question/choice | local restore; no duplicate account init | ONBOARDING_RESTORED |
| EC05 locked node/stale path | server enrollment revision | prerequisite/current path | fetch frontier; no optimistic unlock | NODE_LOCKED |
| EC06 content retired/hash invalid/unknown type | bundle/schema check | repeat updated lesson or old complete cache | quarantine bad asset; fetch signed manifest | CONTENT_VERSION_RETIRED / CACHE_CORRUPT |
| EC07 duplicate answer/completion | receipt/body hash | original result once | same key; ledger/aggregate invariant | IDEMPOTENCY_REPLAY |
| EC08 key reused with different body | receipt hash differs | cannot submit altered retry | new legitimate action ID only after explicit state refresh | IDEMPOTENCY_CONFLICT |
| EC09 two devices / concurrent active session | expectedRevision/active slot | resume current or confirm abandon | transaction prevents overwrite; older device refreshes | SESSION_CONFLICT |
| EC10 network drops / uncertain commit | client deadline | selection or reward syncing retained | same key queries persisted receipt; no second award | NETWORK_TIMEOUT |
| EC11 DB conflict/outage | transaction409/5xx | retry or offline queue | bounded re-stage; uncertain commit receipt read | DB_CONFLICT / DB_UNAVAILABLE |
| EC12 rate limit / free quota exhausted | 429 Retry-After/capability disabled | wait; use cached unit/shadowing | no automated paid upgrade | RATE_LIMITED / QUOTA_EXHAUSTED |
| EC13 Realtime duplicate/missing/disconnect | socket state | stale badge, polling fallback | full refetch after reconnect | REALTIME_DISCONNECTED |
| EC14 partial sync / rejected operation | journal state | pending/rejected list with repeat action | serial replay; permanent rejected retained | SYNC_REJECTED |
| EC15 process killed in SENDING | persisted journal | recovering | reset to PENDING; same-key replay | JOURNAL_RECOVERED |
| EC16 wrong-user cached data | namespace mismatch | signed-out shell | wipe private cache, never display it | CACHE_SUBJECT_MISMATCH |
| EC17 journal corruption / disk full | SQLite integrity/write error | stop new offline work; reconnect/export | preserve valid entries, no guessed completion | JOURNAL_CORRUPT / STORAGE_FULL |
| EC18 microphone denied/permanently denied | permission API | typed/shadowing alternative; settings action | no repeated OS prompt after permanent denial | MIC_PERMISSION_DENIED |
| EC19 mic busy/not found | capture init error | retry after device available | dispose capture; release audio session | MIC_UNAVAILABLE |
| EC20 silence / excessive noise | capture RMS/duration + ASR low confidence | “No clear speech detected”; no score | retry, quieter place, optional headset | SPEECH_NO_INPUT |
| EC21 user stop mid-utterance | stop command | explicit partial/ungraded | finalize short recording if ≥300ms voiced; otherwise discard | SPEECH_CANCELLED |
| EC22 partial transcript never final | 3s after end marker | recoverable transcript pending | close epoch; turn-mode retry once, no score from partial | STT_FINAL_TIMEOUT |
| EC23 live socket disconnect / slow network | heartbeat/queue thresholds | reconnect/degraded mode | new epoch; never replay buffered old speech | VOICE_DISCONNECTED |
| EC24 duplicate/out-of-order/stale audio event | epoch/sequence/turn ID | no audible stale data | discard; snapshot reconnect | VOICE_STALE_EVENT |
| EC25 provider outage/timeout | adapter deadline/breaker | turn mode/template/bundled audio | quota-aware single fallback | AI_PROVIDER_UNAVAILABLE |
| EC26 invalid AI JSON/hallucinated correction | schema/reference checks | authored correction | discard response; no XP/grading mutation | AI_INVALID_OUTPUT |
| EC27 pronunciation unavailable/low confidence | assessor capability/result | score not available; transcript/recording feedback | nullable fields; retry or unscored practice | ASSESSMENT_UNAVAILABLE |
| EC28 TTS/playback failure | decode/audio session error | text tutor response, replay | bundled reply or device voice only if installed | AUDIO_PLAYBACK_FAILED |
| EC29 background/resume/incoming call/focus loss | OS lifecycle/interruption event | paused, mic off | stop capture and playback; reopen with consent on resume | AUDIO_INTERRUPTED |
| EC30 Bluetooth switch / route changed | native route event | pause/restart audio safely | recreate recorder at required sample rate; test actual device | AUDIO_ROUTE_CHANGED |
| EC31 timezone / DST / device clock change | server zone version/time vs local | scheduled timezone change, authoritative day | historical day immutable; device clock ignored | ZONE_CHANGE_SCHEDULED |
| EC32 midnight event arrives late | event occurredAt + inbox lag | corrected day/streak after sync | recompute chronological days, freeze consumption no refund | REWARD_LATE_EVENT |
| EC33 duplicate notification/reminder | stable schedule ID | one reminder | replace/cancel on logout/timezone changes | REMINDER_DEDUPED |
| EC34 league race / late event / settlement gap | watermark/checkpoint/inbox | settling status, no premature tier change | reconcile event totals before immutable close | LEAGUE_SETTLING |
| EC35 quest/freeze double click / insufficient gems | unique claim/purchase receipt | original award or explicit funds error | transaction+same key | WALLET_CONFLICT |
| EC36 profile private/blocked/follow race | authoritative lookup/revision | generic unavailable/pending | no unverified public profile fallback | PROFILE_UNAVAILABLE |
| EC37 temporary audio upload interrupted/expired | job file TTL/hash/status | retry recording; no lost lesson progress | cleanup orphan upload; never permanent public audio | ASSESSMENT_UPLOAD_FAILED |
| EC38 partial account purge | owner ack set/dead-letter | deletion accepted; inaccessible account | bounded retry with tombstone, verify each owner | ACCOUNT_PURGE_PENDING |
| EC39 permanent cloud benefit expiry | console expiry/quota snapshot | local demo mode or cached study | pre-rehearsed local services; no spend | BENEFIT_EXPIRED |

Fault injection must cover EC07–EC17 and EC22–EC26 before release. Native audio EC18–EC30 requires device evidence; passing mocked tests cannot satisfy it.
