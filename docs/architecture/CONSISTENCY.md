# Authority, transactions and cross-service delivery

Canonical [storage](../data/DATA_MODEL.md), [events](../api/EVENTS_ERRORS.md), [auth](../api/AUTH.md) and [offline protocol](OFFLINE.md) remain unchanged. One database saves platform resources; service-owned tables and signed commands are logical boundaries, not hard per-project key isolation.

Learning owns content/frontier/session/regrade/completion/review scheduling/mistakes/energy/outbox; Progress owns profile/XP/streak/economy/social/leagues/entitlements; AI owns usage/leases/jobs/conversations/temporary audio. Cross-owner effects travel only as signed events: lesson.completed.v1 and ai.practice.completed.v1 into Progress; entitlement.changed.v1 and energy.granted.v1 out of Progress (same outbox/inbox/dedupe rules as below). Only the owner writes its prefix. Transport/shared code contains no grading/reward model. Independent package/artifact/function/revision/tests distinguish genuine deploy boundaries; cloud integration and the teacher's acceptance of Functions remain unproven.

Completion validates verified subject, pinned bundle and all required attempts. A short Learning transaction writes session completion/frontier/result/receipt/outbox atomically. It never increments Progress XP. UI may show completion and reward pending. Scheduled Learning dispatcher leases due outbox rows and sends signed versioned events; Progress validates signature/schema/producer, atomically commits inbox+ledger+day aggregate, then acknowledges. Network delivery is at least once; durable unique IDs give one logical application per receipt/event. No exactly-once network claim.

[TablesDB transactions](https://appwrite.io/docs/products/databases/tablesdb/transactions) support staged operations and conflict detection; actual concurrent/crash probes remain P1/P6. Keep operation count below the plan cap, retry by reading current state and staging again, never replay an expired transaction blindly. Schema changes are outside row transactions. A scheduled minute trigger is not a promised one-second reward latency.

| Failure boundary | Preserved authority / UI | Recovery and proof |
|---|---|---|
| Before Learning commit | unchanged session; input retained | same key retries; forced rollback leaves no outbox |
| Commit response lost | completion may already exist; unknown UI | query/replay same receipt ID; never new key from timeout |
| Dispatcher loses connection | pending/leased event retained | lease expires, bounded jitter retry; delivery may duplicate |
| Progress fails before commit | no inbox or XP change | redelivery processes once |
| Progress commits but ack lost | award exists, Learning remains pending | identical event replays ack; payload substitution rejected |
| Conflict/multi-device | one valid revision; authoritative totals | unique completion/reward identity; ledger conservation |
| Dead letter / late event | no silent drop; reward pending; league settling | owner requeue after dry-run, reconcile watermark and ledger |
| Logout/other account | old encrypted journal inaccessible | stop sync and invalidate request epochs; no cross-user replay |

The scaffold's `pnpm backend:smoke` uses in-memory fixture ports, injects receiver failure and lost ack, validates real OpenAPI event schema and verifies one reward effect. It proves the local workflow only: no durable lease, HMAC transport, Cloud transaction, timezone/replay cap or process-crash recovery is implemented by those mock stores. Cloud entrypoints import only transport, so fixture counts cannot award live XP.

Scheduled jobs (P1-OPS-001 cron wiring; OpenAPI `/internal/jobs/*`, EVENTS_ERRORS "Scheduler ticks"):

| Job | Owner / code | Appwrite cron (one schedule per function) | Effect |
|---|---|---|---|
| Learning outbox dispatch | Learning `dispatchOutbox` (worker mode, `runLearningOutboxDispatch`) | `* * * * *` on coc-learning, pending until Learning persistence is enabled | lease ≤20 due l_outbox rows, deliver lesson.completed.v1 to Progress |
| Progress outbox relay | Progress `relayOutbox` | `* * * * *` on coc-progress (every tick) | account.deleted.v1 / entitlement.changed.v1 → Learning+AI, energy.granted.v1 → Learning |
| Deletion purge retry | Progress `purgeDeletedAccount` | same tick | bounded purge of PURGING tombstones to COMPLETED |
| Streak day rollover | Progress `processMissedDays` | same schedule, UTC minute 5 of each hour | consume equipped freezes per missed day or end the streak (candidates: last qualified day ≥2 UTC days old) |
| League settlement | Progress `settleLeagueWeek` | same schedule, UTC minute 15 of each hour | settle the last ended week and every SETTLING week once the Learning watermark is zero |

Learning energy (P6-GAME-003): with `COC_ENERGY_MODE=LIMITED` a LESSON/MASTERY answer spends one unit inside the answer transaction and an empty battery is ENERGY_DEPLETED at answer and lesson start; REVIEW and PLACEMENT are free; the default (unset) mode is UNLIMITED. energy.granted.v1 refills or adds through the l_inbox row; entitlement.changed.v1 projects SUPER/MAX (ACTIVE/GRACE, unexpired) as UNLIMITED and keeps only the newest entitlement revision.

```mermaid
sequenceDiagram
  participant M as Flutter
  participant L as Learning
  participant D as Learning dispatcher
  participant P as Progress
  M->>L: Complete expectedRevision and idempotency key
  L->>L: Transaction session frontier receipt outbox
  L-->>M: Committed result reward pending
  D->>L: Lease due outbox event
  D->>P: Signed lesson.completed.v1
  P->>P: Transaction inbox ledger day totals
  P-->>D: Acknowledge or replay
  D->>L: Mark acknowledgement
  M->>P: Refetch own reward state
  P-->>M: Credited authoritative totals
```
