# Dependency DAG and ownership locks

Phase gate is an implicit dependency of every task in that phase. Strict phases override technical opportunities to work ahead. Within a phase, listed branches can proceed independently after shared contracts are locked.

~~~mermaid
flowchart TD
  P0[Phase0 blueprint / contracts / review] --> P1[Phase1 toolchain / adapters / CI]
  P1 --> P2[Phase2 complete fake-data UI]
  P2 --> P3[Phase3 auth / profile]
  P3 --> P4[Phase4 catalog / enroll / path]
  P4 --> P5[Phase5 lesson engine / offline journal / outbox]
  P5 --> P6[Phase6 reward / review / streak]
  P6 --> P7[Phase7 cached listening]
  P7 --> P8[Phase8 speech / AI]
  P8 --> P9[Phase9 social / quests / leagues]
  P9 --> P10[Phase10 reliability / performance validation]
  P10 --> P11[Phase11 full QA / artifacts]
  P1 --> contracts[Locked API / fixtures / generated types]
  contracts --> P2
  contracts --> P5
~~~

Within P1: foundation scaffold BLOCKS service/Flutter skeleton checks; P1-OPS-001 (schema declaration/apply, infra EXCLUSIVE_CHANGE_AREA) DEPENDS_ON FOUND-001/002 and its admitted-project apply BLOCKS every P3+ task that writes TablesDB; a DATA_MODEL change always lands with `pnpm schema:declare` output in the same commit; mobile/tooling and backend adapters SAFE_PARALLEL after root workspace files. Infrastructure manifest owner EXCLUSIVE_CHANGE_AREA. Within P2: tokens/components BLOCKS individual screens; onboarding/path and practice/social fixture groups SAFE_PARALLEL, router owner exclusive. P3 auth SDK state BLOCKS real profile routing; backend profile and frontend auth SAFE_PARALLEL against fixtures.

P4 content validation/publication BLOCKS real bundle/path smoke; seeded fake content and UI integration separate paths. P5 grader/domain reducer BLOCKS session commands/render wiring; server session and Flutter renderer SAFE_PARALLEL at locked Answer schema; completion transaction BLOCKS real outbox drill. P6 reward inbox BLOCKS streak/quest counters; review heuristic and mobile reward UI SAFE_PARALLEL across owners.

P7 audio asset validation BLOCKS playback offline smoke. P8 normalized transport/controller and native PCM bridge SAFE_PARALLEL after interface frozen; native issuer reservation and assessment adapters SAFE_PARALLEL in distinct AI folders under one shared schema owner; device enablement BLOCKS native/scored flags. P9 social API and Flutter screens SAFE_PARALLEL; league closure depends reward ledger+watermark. P10 offline fault/perf and ops/load can run disjoint test areas; changes to journal or core reducers exclusive. P11 Android and macOS build validation SAFE_PARALLEL after one frozen release candidate commit.

No P8 agent may begin cloud integration while P7 gate is pending. A package-lock change is a shared bottleneck, not an excuse to fork two conflicting dependency edits.

Proposed data-gap tasks (2026-10-12) follow their phase gates: P4-LEARN-003 after LEARN-002; P6-GAME-003 after GAME-002; P6-REVIEW-002 after REVIEW-001; P7-PRACTICE-001 after the P5 session-mode contract; P8-AI-003 after AI-001/002; P9-SOCIAL-002 after SOCIAL-001; P9-LEAGUE-002 after LEAGUE-001; P10-BILL-001 after P9 plus a separate payment authorization. Each starts with an OpenAPI/contract change owned by P1-CONTRACT-001's area.
