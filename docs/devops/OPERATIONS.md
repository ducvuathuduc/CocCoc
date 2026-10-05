# Observability, load testing and operational runbook

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
