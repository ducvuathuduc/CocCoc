# System architecture

Current audit: [evidence](../audit/RESEARCH_EVIDENCE.md), [consistency contract](CONSISTENCY.md), [conditional freeze](../ARCHITECTURE_FREEZE_REPORT.md). Three service deploy artifacts exist locally; cloud/domain adapters are disabled. The managed platform is not counted as a bespoke service.

Status: V1 specification frozen; runtime capability gates remain in [assumptions](../ASSUMPTIONS.md). Decisions are project prescriptions. Vendor behavior evidence: [R01–R12](../research/RESEARCH_EVIDENCE.md).

## C4 context

~~~mermaid
flowchart LR
  learner[Learner on Android / iOS] --> mobile[CocEnglish Flutter]
  author[Course author / maintainer] --> tools[Versioned content CLI]
  mobile --> auth[Appwrite Auth]
  mobile --> platform[CocEnglish business services]
  tools --> platform
  platform --> data[Appwrite TablesDB / Storage]
  mobile --> voice[Provider Live audio with ephemeral credential]
  platform --> vendors[Text / STT / pronunciation providers]
  platform --> telemetry[Bounded telemetry]
~~~

## C4 containers and trust

~~~mermaid
flowchart TB
  subgraph device[Untrusted mobile device]
    ui[Flutter views + Riverpod ViewModels]
    repos[Repositories + typed API clients]
    cache[Drift journal / bundles / audio files]
    adapter[Speech transport adapter]
    ui --> repos --> cache
    ui --> adapter
  end
  subgraph backend[Three deployment units]
    l[Learning service]
    p[Progress service]
    a[AI service]
    l -->|signed outbox delivery| p
    p -->|profile deletion event| l
    p -->|profile deletion event| a
  end
  repos -->|Appwrite session| auth[Appwrite Account]
  repos -->|Appwrite JWT / HTTPS REST| l
  repos -->|Appwrite JWT / HTTPS REST| p
  repos -->|Appwrite JWT / HTTPS REST| a
  adapter -->|single-use credential / WSS| live[Gemini Live]
  a -->|server key| api[Gemini text / Groq STT / Azure assessment]
  l --> db[(One TablesDB database)]
  p --> db
  a --> db
  l --> objects[(One Storage bucket)]
  a --> objects
~~~

One database with service-prefixed tables and one bucket deliberately fit Appwrite Free later. Each service has its own handlers, tests, configuration, deployment and table allowlist. Project-wide Appwrite API scopes **do not establish hard isolation between service tables**. No unverified table-restricted key feature is assumed. Separate module adapters and write-ownership tests enforce logical isolation; a compromised admin key can affect other tables. Separate projects/databases with verified resource-restricted credentials require a future security ADR, not a misleading claim.

## Service boundaries

**Learning** owns catalog/publishing, immutable lesson bundles, enrollment/node frontier, sessions/answers, mastery and review scheduling. Keeping grading, session completion and path unlock together avoids a distributed transaction on the critical learning path.

**Progress** owns public/private profile, learning-zone history, XP/streak/gems, quests, friendships and league projections. “Progress” means reward/social progress; course progress remains Learning's authoritative state.

**AI** owns capability configuration, tutoring/assessment requests, quota reservations and bounded voice session metadata. It does not change correct answers, course unlocks or authoritative XP.

Auth/OAuth, database, object storage, Functions and Realtime are managed infrastructure. Notifications are a Progress module plus local device reminders. Analytics is an append-only operational event/log module. Content administration is a checked-in CLI/pipeline in Learning. No separate auth, catalog, notification, analytics, admin, speech, gateway, broker or cache service.

## Learning components

~~~mermaid
flowchart LR
  http[Request / schema / auth] --> controller[Command handlers]
  controller --> grading[Versioned deterministic grader]
  controller --> sessions[Session aggregate]
  controller --> content[Immutable bundle loader]
  sessions --> store[Allowlisted TablesDB adapter]
  sessions --> tx[Transaction / idempotency]
  tx --> outbox[Learning outbox]
  worker[Scheduled bounded drain] --> outbox
  worker --> signed[Progress internal inbox endpoint]
~~~

Mobile feature layout: presentation (View + manual Riverpod AsyncNotifier/Notifier), data (repository + DTO mapper + remote/local service), optional domain (lesson reducer, answer normalization, sync coordinator, speech lifecycle). Domain models are immutable Dart sealed classes; DTOs validate wire input. Views never import Appwrite or provider SDKs. Repositories own cache and retry; ViewModels own commands, selection and async UI state; services wrap stateless I/O. No use-case class for a simple pass-through read.

## Session completion sequence

~~~mermaid
sequenceDiagram
  participant M as Flutter
  participant L as Learning
  participant D as TablesDB
  participant W as Learning outbox drain
  participant P as Progress
  M->>L: POST /sessions/{id}/complete + idempotency key
  L->>D: Stage completion, frontier, review update, response receipt, outbox
  L->>D: Commit transaction
  D-->>L: committed or conflict
  L-->>M: authoritative completion + rewardStatus=pending
  W->>D: Claim due outbox batch with short lease
  W->>P: HMAC signed lesson.completed event
  P->>D: Stage inbox, reward ledger, aggregate, daily activity, quest counters
  P->>D: Commit
  P-->>W: accepted / already applied
  W->>D: Mark acknowledged
  M->>P: GET /me/rewards?completionId=...
  P-->>M: credited totals and streak, or pending
~~~

Critical lesson completion never waits for AI or Progress. Rewards are eventually consistent. UI shows “syncing rewards” until authoritative response; local predicted XP is labeled pending. Outbox crash before acknowledgement causes redelivery; Progress's unique inbox and reward ledger prevent double awards. Full protocol is [EVENTS_ERRORS](../api/EVENTS_ERRORS.md).

## Offline, caching and realtime

See [OFFLINE](OFFLINE.md) for replay, integrity and reconciliation. Published public content can be read from Storage using immutable versioned manifests. Business writes always use service APIs. Realtime is used only as a hint to refetch one's safe reward notification row; it never pushes secrets or authoritative commands. Poll visible progress every 15s while pending if subscription unavailable; stop polling in background.

No cross-service foreign-key relationship columns; use opaque IDs and event/API validation. No joins over private user data in Flutter. Read models are rebuilt from event/ledger data by their owner.

## Hosting adapters

Cloud: each service deploys as one Appwrite Function with a REST router plus scheduled worker mode. Configure 20s application deadline for public calls, 60s worker timeout, batches of at most 20 events. Worker mode can be selected only by verified platform schedule context, never by a client query/header alone. P1 proves metadata cannot be spoofed; otherwise deploy a private scheduler entrypoint using the same Learning package.

Expiry/demo: run the same three domain handlers as local Node HTTP processes, ports 4101/4102/4103, retaining cloud Auth/TablesDB/Storage; TLS reverse proxy only for device access to a LAN demo host. No cloud paid gateway. Android emulator uses host forwarding; physical device uses an authenticated HTTPS LAN endpoint with a trusted demo certificate. Public network production serving from a student laptop is out of V1.

Read-only health /health reports build identity without secrets; /ready checks configuration and cached DB reachability. Health is the sole unauthenticated business-service endpoint.
