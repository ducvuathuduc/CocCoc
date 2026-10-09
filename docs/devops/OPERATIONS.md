# Observability, load testing and operational runbook

Current admission/receipt: [Appwrite setup](APPWRITE_SETUP.md), [fresh validation](../audit/VALIDATION.md), [demo](../quality/DEMO_PLAYBOOK.md). Runbooks below are procedures and required recovery tests, not fabricated incident drills.

## Explicit failure-to-recovery contract

| Symptom / detection | Likely cause / user feedback | Retry or compensation / exact recovery gate |
|---|---|---|
| Auth401/403, refresh overlap, OAuth callback absent | expired/revoked session, endpoint/platform mismatch; preserve email and route intent, no private access | single-flight refresh; one restore; AUTH-revoke/refresh-race/callback fixture then actual P3 receipt |
| Provider429/5xx, empty/malformed tutor or locale mismatch | quota/outage/schema; authored explanation and typed/shadowing mode | honor Retry-After, breaker, no blind ambiguous paid retry; AI-invalid/quota/locale eval |
| Education disabled / spend cap hit | term/plan/resource mismatch; cached demo remains available | export/restore/downgrade admission; local three-service fallback; account receipt before cloud enablement |
| Migration partial / index pending / conflict | additive schema not ready; stop new writer, retain prior version | wait statuses; match checksum; re-stage transaction; schema-conflict/no-partial/outbox fixture and live P1 probe |
| Outbox stuck/missing/duplicate, league stale | failed consumer/ack/lease; reward pending and league settling | retain event, lease retry/dead letter; owner requeue dry-run; ledger+watermark converge; P6 event recovery gate |
| Cache schema/corruption/storage full / queue stuck | old bundle/journal damaged; preserve quarantined data and explain repeat/export | no destructive silent reset; free space/re-download full hash-valid bundle; SYNC-corrupt/diskfull/reject/upgrade P5/P10 |
| Other account/device switched or app killed during sync | invalid cache identity/in-flight epoch; old user data inaccessible | invalidate callbacks, scoped encrypted journal, same receipt replays after same-account restore; cross-account/kill tests |
| Mic denied/restricted/disconnected, call/Bluetooth change, no audio/noise | OS permission/audio focus/device; explicit typed/record-replay option | stop capture/playback, clear buffers, settings action for permanent denial; actual device P8 lifecycle matrix |
| VAD false start/late transcript, voice expired/back/cancel | stale provider epoch/network; do not replay old audio or show fabricated score | cancel/dispose, discard stale events, new TURN session; token/epoch/cancel/interruption eval |
| Assessment unsupported locale/absent prosody | provider capability/entitlement; score null | reference locale validation, nonnumeric feedback; scorer-separation P8 |
| Purchase killed/pending/refunded, duplicate RTDN | vendor state not reconciled; free access and verification pending | fetch vendor current state, dedupe, restore; sandbox purchase lifecycle gate in MONETIZATION |
| Notifications disabled/token expired | OS preference/provider registration; no misleading sent banner | update/remove own device token, settings prompt once; permission/token-rotation tests P9 |
| CI secret/minutes/signing missing; unsigned iOS artifact | configuration/quota/team; visible blocked capability | deterministic no-secret checks still run; signing never faked; macOS/signed-device evidence separate |
| Red deployment / vendor outage / rollback | incompatible revision or config; safe cached behavior | select prior compatible artifact, additive schema retained; ownership/smoke/duplicate checks and measured restore drill |

Logs contain only safe code, owner, request/correlation ID, revision, attempt, duration and outcome; no raw JWT, provider credentials, learner audio, purchase token or full model prompt. Required alerts use actual configured platform capabilities after admission, not imaginary monitoring services.

## Telemetry and dashboards

Minimum stack: structured JSON through Appwrite function context log/error; OpenTelemetry-compatible trace/request IDs; bounded Grafana Free export; optional Sentry Flutter crash capture. Local demo writes NDJSON and can export using local process lifetime. Do not assume a serverless background exporter survives response return. Cloud export, if enabled, is awaited with150ms best-effort budget; failure never rolls back business transaction. Always emit local context log before response. Traces/log export is sampled and redacted.

Log fields: timestamp,level,service,environment,buildId,requestId,traceId,spanId,operation,status,errorCode,durationMs,attempt,providerAlias when relevant. No email, token, headers, raw transcript/answer/audio, storage key or prompt by default. User ID hashed/pseudonymous only where debugging needs it. Metric labels bounded: service/operation/statusClass/provider/mode; never userId/sessionId/requestId. Capture all crashes within client cap; nonfatal errors sampled/deduped, no session replay/profiling by default.

Dashboard panels: requests/sec; warm/cold p50/p95/p99; status/error rate; DB conflict rate; outbox oldest/pending/dead; reward lag; sync pending/rejected; active voice reservations; mint failures/token expiry; provider429/deadline; assessed vs unassessed count; audio init/playback errors; export usage; storage/Functions/read/write/transfer quotas; mobile crash-free session denominator. Build/deploy annotation links receipt.

Alerts: dead letter>0; oldest outbox>5min; error rate>5% for5min at≥20requests; provider429>10% at≥10calls; quota thresholds70/85/95%; mobile fatal crash new build reproducible. Alerts go to configured maintainer dashboard/email only after future setup authorization; no messaging connector is used by this research. Runbook first checks deployment/config/quota before retries.

## Load tests (k6)

Open-source local [k6](https://grafana.com/docs/k6/latest/) avoids paid load SaaS. No live AI load test: fake adapters preserve deadlines/429/reservation/inbox behavior. Service/user credentials are synthetic scoped test users. Never aim1000/10000users at a free Cloud project without quota/cost check and authorization.

| Scenario | Mix / assertion | Stage |
|---|---|---|
| authentication |10%Account login/get; revocation; documented provider rate limits | small dedicated auth test, not brute force |
| home bootstrap |20%parallel path+profile/rewards, cursor/cached content | burst-sensitive |
| course/path |15%published metadata/path/bundle | download bandwidth separated |
| lesson |30%start→10answers→complete, duplicate5%, delay/crash/retry | reward effect once |
| progress/social |15%reward fetch/quests/league | eventual convergence and safe auth |
| realtime hint |5%subscriber disconnect/reconnect | per-plan connection cap |
| fakeAI |5%capability/reserve/turn/job; injected429/timeout | bounded reservations, no provider cost |

Profiles: smoke5VUs1min; demo ramp0→20→100 over5min, hold10min, ramp down2min; spike100→30030s then recover; soak20VUs2h on local adapters. 1000/10000 scenarios are architectural/local mocked capacity exploration only until hosting quota admitted. Use arrival-rate executors to model RPS separately from socket concurrency. Tests generate distinct users; do not mistake many VUs contending one learner row for platform throughput.

Thresholds NFR-PERF-004 and NFR-REL; unexpected failed requests<1%, warm p95≤800ms, no double awards, no lost completion, outbox clears within5min recovery, RSS does not grow continuously in soak. Exclude intentionally injected429/503 from success SLO denominator but report them. Report actual environment/vendor quotas and reject unsupported scaling conclusions.

## Failure drills and recovery

1 Provider down/quota: inspect safe capability/error metrics, open circuit, set native/assessment false, select turn/shadowing/template; never auto-enable paid adapter.
2 Reward lag: check source outbox+Progress inbox+DB conflicts, requeue owner dead letters after dry-run, compare ledger to aggregate, verify watermark; do not manually increment XP.
3 DB outage: preserve offline journal, disable online wallet/social mutations; restore connectivity then receipt-based replay.
4 Storage outage/corruption: verify SHA; keep last full cached bundle; re-fetch manifest/asset, no half-published lesson.
5 Deployment regression: pause deployments, select prior compatible artifact, run permission/smoke/duplicate completion; additive schema remains.
6 Expired Education: verify current resources/export, run DEMO_MODE local3services with trusted local scheduler and Cloud Auth/DB; use cached-only intro if cloud account inaccessible. No public internet exposure.
7 Account deletion partial: confirm blocked user, inspect per-owner ack, retry purge, then delete Appwrite user; record complete only after all owners.
8 Restore: decrypt daily export on controlled host, restore IDs/content/ledger to supported environment, recompute read models, test user mapping/login and permissions. RPO24h/RTO2h target measured in rehearsal.

Local adapter boundary: explicit DEMO_MODE; authenticated HTTPS LAN scope; keys from process environment/private local file ignored by Git; cloud JWT validation and TablesDB transactions remain authoritative. Trusted scheduler lives in the Node supervisor, invokes functions in process, and cannot be selected via HTTP headers. Host uptime/local TLS/privacy and external network reachability differ from Cloud; this is an invited demo deployment, not a public production endpoint.
