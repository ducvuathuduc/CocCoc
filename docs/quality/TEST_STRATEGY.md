# Test strategy, device matrix and release gate

Use meaningful behavior tests. No implementation-mirroring tests for reversible copy changes. Deterministic normal CI has fake clocks, random seeds, providers, repositories and native adapter boundaries; live provider benchmarks separate. [NFR](../architecture/NFR.md) owns targets, [edge cases](../product/EDGE_CASE_MATRIX.md) owns failure scenarios.

| Layer | Required coverage / examples | Evidence |
|---|---|---|
| Dart unit / ViewModel | lesson transitions, repeated token IDs, NFC/diacritics/alternatives, cancellation, auth route guards, sync crash recovery | flutter_test passing; fake repository overrides |
| Repository/cache | sqlite journal transaction, namespace isolation, corrupt bundle/hash, conflict reconciliation, no lost pending write | actual temporary SQLite, process restart fixture |
| Widget/semantics | all12 exercise types, CHECK validity, accessible feedback, text scale2, error/offline states | tests + semantic assertions |
| Golden |42screen fixture states, narrow/wide, light/dark, reduced motion | pinned Linux/font artifact and reviewed diff |
| Mobile integration | onboarding→auth→path→lesson→rewards; offline kill/sync; native permission/routing | integration_test; Patrol only when native automation justified |
| Backend unit | grader, XP/caps/zone/freeze rules, event schema/HMAC, provider output validation | Vitest fake clocks/providers |
| Backend integration | real TablesDB transactions/conflicts/indexes/permissions, receipt reconstruction, outbox crash/leases, deletion tombstone | disposable Appwrite environment after compatibility gate |
| Contract | OpenAPI valid, positive/negative body/response fixture, stale client schema, all x-owner/table/requirement refs | schema validator + compatibility diff |
| Resilience/security | EC07–EC17, negative subjects/header spoof/scheduler, ambiguous token mint, no paid fallback | fault-injection logs/ledger assertions |
| Load/smoke | rehearsal cohort and modeled capacity, retries/reward convergence | k6 JSON+environment report |
| AI | structured/null scorer/constraint/fallback fixtures; optional live phrase/latency dataset | [AI eval](../ai/AI_EVALS.md) reports, never nondeterministic PR CI |

Device matrix: AndroidAPI24 emulator for minimum compatibility, currentAPI36 emulator, midrange4GB physical Android for performance/audio, iOS15-compatible simulator and current cloud simulator for native build, physical iPhone/headset only with eligible signing access. OS version/image pinned after actual runner availability. Test speaker, wired/USB headset if available, Bluetooth, interruption and background. Missing iOS physical evidence must be reported; simulator does not certify real microphone/Bluetooth behavior.

Release P11 gate: previous phases verified; essential auth/ownership/duplicates/offline/deletion/security tests pass; all known P0/P1 regressions resolved; reviewed screen-state goldens; Android install/offline/performance rehearsal; iOS simulator build/smoke; optional speech capability evidence recorded independently; backup restore;0newVND usage check; artifacts/checksums/build and dependency lock identities; rollback rehearsal. No “release ready” from lint alone, no fabricated test counts.

Requirements map to task IDs in IMPLEMENTATION_PLAN and API x-requirements; non-API local/UI requirements map to screen IDs plus mobile tests. Phase2 fake UX covers all routes before full backend implementation; fixtures conform to contract and cannot become private server entities.

Phase0 verification tools: node tools/blueprint/validate.mjs performs dependency-free structural/reference/ownership/coverage checks. tools/blueprint/validate-schemas.mjs compiles all schemas with AJV2020 plus ajv-formats and checks positive/negative contracts. For isolated tools, install @redocly/cli2.57.0, ajv8.20.0, ajv-formats3.0.1 in a temporary directory; pass that directory as the schema script's sole optional argument and invoke its Redocly CLI for OpenAPI lint. This installs no app dependency or backend implementation. P1 pins these verifier dependencies in the workspace and requires both checks in CI.
