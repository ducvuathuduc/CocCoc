# Service catalog and operational contracts

All API operation ownership is in [OpenAPI](../api/openapi.yaml). Data ownership is in [DATA_MODEL](../data/DATA_MODEL.md). Common limits below are normative.

| Service | Business responsibility / owned data | APIs / events | Dependencies | Deployment / scale | Tests / telemetry |
|---|---|---|---|---|---|
| Learning | catalog, immutable bundles, enrollments/frontier, sessions/answers, mastery/review, reports, outbox | courses/path/bundle/enroll/session/review/report/content publish; emits lesson.completed.v1, account.purged.v1 | Appwrite Auth validation, TablesDB, Storage; Progress inbox asynchronously | one Function/package; stateless HTTP; shared DB transactions serialize conflicting session/frontier commands; schedules drain outbox | grading reducer, content schema, stale version, duplicate answer/complete, offline regrade, transaction conflict, table allowlist; completion latency/outbox age |
| Progress | profile, zone history, reward ledger, day activity/streak, gems/freeze, quest claims, follows, league runs, inbox/outbox, deletion status | me/profile/rewards/quests/claim/follow/league/freeze/settings/delete; consumes lesson.completed; emits account.deleted/zone.changed | Auth, TablesDB; Account deletion via restricted admin SDK; Learning/AI delete consumers | one Function/package; independent scale; projection jobs checkpoint batches; row contention on user/league aggregates | duplicate events/claims/follows, exact day boundaries, stable rankings, permission probes, failed purge; lag/conflicts/inbox duplicates |
| AI | capability manifest, voice sessions/reservations, text jobs, recording assessment jobs, deletion inbox | capabilities/tutor/voice-session/heartbeat/close/assessment/results; consumes account.deleted | Auth, TablesDB, temporary Storage, provider APIs | one Function/package; audio bypasses Function for native Live; async recorded assessment worker; provider quotas dominate capacity | adapter contracts, invalid output, expiry/reconnect, quota reservation race, silence/noise, cleanup; tokens/seconds/queue/429 by provider |

All three have read-only /health and /ready; internal endpoints require signature, timestamp and replay protection, not a user JWT.

| Dependency / failure | Deadline | Retry | Idempotency / recovery |
|---|---|---|---|
| Account.get JWT validation | 2s within request deadline | one retry only for transport/5xx and sufficient budget | never treat failure as authenticated; return AUTH_UNAVAILABLE |
| TablesDB read | 2s | at most 2 attempts, jitter 100–400ms | no retry permission/schema/404 as transport failure |
| Business transaction | total 5s | at most 3 conflict re-stages with fresh rows; backoff 50–250ms | unique receipt key scoped to user+operation; return persisted original response after uncertain commit |
| Storage asset | 5s | 2 transient attempts | SHA-256 manifest verifies cached file; use old complete bundle on failure |
| Progress event delivery | 5s | persisted nextAttemptAt: 1s, 5s, 30s, 2m, 10m, then hourly; jitter ±20% | eventId unique inbox; after 10 failed deliveries dead-letter, alert; requeue manually after fix |
| Tutor text | 8s provider; 12s handler | fallback once before deadline; no retry ambiguous billable work blindly | reserve request ID, response cache; template feedback on final failure |
| Assessment worker | 20s provider; 60s worker | max2definitive transient attempts; each audio dispatch reserves additional measured seconds; ambiguous/crashed dispatch never blind-retried | canonical job/dedupe policy in EVENTS_ERRORS; no score on failure |
| Live connect | 5s | one same-lease reconnect only if proven provider resumption; otherwise TURN | never remint under old native reservation; new grant only after original expiry+quota; discard stale epoch/audio |
| Provider breaker | 5 failures in 60s | open 60s; one half-open probe per process | local breaker limits waste but durable user/daily reservation is global authority |

Function public deadline 20s is below documented 30s hard synchronous limit. Background worker is bounded and returns checkpoint before configured timeout. Never hold a Function open for a multi-minute voice conversation.

No automatic retry of non-idempotent business writes. Every mutation except harmless close/heartbeat has a caller operation key. Body hash mismatch under the same key is IDEMPOTENCY_CONFLICT. Retain receipts 30 days; completed sessions and reward ledgers retain stable dedupe IDs longer, so receipt cleanup cannot permit a second award.

Dependencies do not cascade: Progress outage → path works/rewards pending; AI outage → ordinary lessons/audio caches work; Realtime outage → fetch/poll; Storage outage → cached complete bundles; Auth outage → existing offline cache read/practice only; TablesDB outage → queue offline work and show unavailable for online-only operations.

## Why domains are grouped

Identity credentials stay Appwrite; profile in Progress. Catalog, session and course progression stay Learning for atomic unlocks. Streak/XP/quests/social share Progress reward ledger and projection cadence. Native live speech, assessment and tutoring share AI provider quotas and lifecycle. Notifications consume Progress's state and use local reminders first. Analytics uses redacted events, not a new deployment. Admin content CLI calls Learning with maintainer identity. Any later split needs measured independently scaling load, a stable ownership boundary and an ADR with migration.
