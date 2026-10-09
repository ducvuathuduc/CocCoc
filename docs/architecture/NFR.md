# Non-functional requirements

These are **target acceptance budgets**, not measured results or Appwrite/provider SLAs. Baseline test device: midrange Android with 4 GB RAM, Android API 24 minimum, release/profile build; iOS 15 minimum with simulator plus an eligible physical device when available. Network baseline 10 Mbps, 80ms RTT, 1% loss; impaired 1 Mbps, 300ms RTT, 5% loss. Record actual hardware/OS/network in evidence.

| ID | Priority | Metric and threshold | Measurement / gate |
|---|---|---|---|
| NFR-PERF-001 | P0 | cold app first usable cached screen p95 ≤2.5s; warm ≤800ms | 30 release launches per device; P10 |
| NFR-PERF-002 | P0 | navigation p95 ≤150ms; cached lesson open ≤300ms; online open ≤1.5s | Flutter timeline, 50 transitions; cold Function latency separated |
| NFR-PERF-003 | P0 | 60Hz frame budget 16.7ms; <1% frames exceed budget during path/lesson; 120Hz devices 8.3ms target | profile build, 60s trace, no debugger |
| NFR-PERF-004 | P0 | warm non-AI API p95 ≤800ms, p99 ≤2s; error rate <1% at accepted demo load | k6; auth/provider/network errors separated |
| NFR-PERF-005 | P1 | cached listening audible start p95 ≤200ms; downloaded uncached ≤800ms | recorder timestamps on device |
| NFR-PERF-006 | P1 | text tutor first complete response p95 ≤3s target; timeout fallback ≤12s | live eval separate from CI |
| NFR-SPEECH-001 | P1 | Live connect ≤5s; end speech→first tutor audio p95 ≤1.5s target; barge-in mute ≤150ms | device mic+speaker timestamps; provider claims not measurement |
| NFR-SPEECH-002 | P1 | composable turn response p95 ≤4s target; assessment job ≤30s target | STT 1.5s, LLM 1.5s, TTS/playback 1s target; grade parallel, not blocking conversation |
| NFR-REL-001 | P0 | accepted completion/reward exactly once under 100 duplicate/reorder trials; no lost committed outbox | fault injection, crash/retry suite |
| NFR-REL-002 | P0 | 99.5% successful non-AI demo requests target over rehearsal period; no vendor SLA claimed | 24h rehearsal and request/error denominator |
| NFR-REL-003 | P0 | pending rewards settle p95 ≤60s, max 5min under normal worker schedule | outbox age/inbox latency; overdue UI visible |
| NFR-OFF-001 | P0 | one cached unit works 30min without network; process kill restores last committed answer; queue replay converges | airplane-mode + kill/restart + reconnect |
| NFR-SEC-001 | P0 | zero provider/admin keys in binary/logs; all private endpoints enforce verified subject | secret scan, binary string scan, authorization probes |
| NFR-SEC-002 | P0 | cross-user read/write tests all deny; replay/body substitution rejected | JWT/HMAC/row-permission/idempotency suite |
| NFR-COST-001 | P0 | 0 VND newly billed demo operations; any paid capability disabled absent approved allocation | console snapshots, hard usage limits, local fallback rehearsal |
| NFR-STORE-001 | P1 | steady app RSS target ≤200 MB, peak speech ≤300 MB; cache ≤200 MB; compressed Android download target ≤40 MB excluding optional models | release memory/size reports; no assumed package size |
| NFR-A11Y-001 | P0 | ≥48 logical px targets, text scale 2.0 without clipping, screen reader order/labels; success/error not color-only | widget semantics + device QA; verify contrast |
| NFR-DATA-001 | P0 | content/profile/progress export restore succeeds; RPO ≤24h, RTO ≤2h for student demo | restore rehearsal, encrypted private export outside Git |
| NFR-OBS-001 | P0 | every request log has requestId, service, operation, status, duration, build; no transcript/audio/token by default | schema/log redaction tests |
| NFR-TEST-001 | P0 | deterministic CI requires no live AI, private account, user microphone, or store signing | isolated mock-mode job |

## Load model and capacity boundary

Assume each active learner sends 6 reads and 3 writes/min; average 0.15 public requests/sec/user, with home bursts at 1 request/sec/user. A bundled lesson completion is a small bounded transaction, not one DB write per keystroke. These are planning assumptions to measure.

| Active concurrent users | Approx steady RPS / one-second home burst | Expected bottleneck / action |
|---|---|---|
| 100 | 15 / 100 | demo target; ≤100 optional Realtime connections; test Function cold starts, DB write contention; cloud limits verified first |
| 1,000 | 150 / 1,000 | exceeds Free 250 / listed Pro 500 Realtime concurrency; disable realtime hints and poll by visible screen, raise paid capacity only via future authorization; AI admits bounded sessions |
| 10,000 | 1,500 / 10,000 | not a free-tier commitment; gateway/auth reads/Functions DB quotas and provider concurrency require measured paid or self-hosted capacity plan |
| Burst ×3 for 30s | 45 / 450 at 100 baseline | reject excess with 429 Retry-After, preserve completions in local journal |

At 100 continuously active users for one hour, 54K public requests before DB/asset overhead is already material to free quotas. MAU allowance is not concurrent capacity. No “supports 10,000 users” claim without a successful representative load test and quota/cost plan.

Optimizations map to bottlenecks: bundle fetching removes per-exercise network waits; cursor pagination limits path/league payloads; image lazy-loading + precache current prompt reduces decode jank; coalesced repository requests avoid rebuild refetch storms; pregenerated audio avoids per-play AI; outbox decouples reward failure; no raw-audio relay avoids Function duration/transfer limits. Compression comes from hosting; pre-encode WebP images and bounded AAC/WAV audio. Use AVIF only after decode-support/device evidence.
