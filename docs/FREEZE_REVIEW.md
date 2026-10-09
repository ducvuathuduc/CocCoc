# Architecture freeze review

Historical 2026-10-04 review retained. Current [freeze report](ARCHITECTURE_FREEZE_REPORT.md), [audit](audit/CHANGELOG.md) and [fresh validation](audit/VALIDATION.md) supersede implementation/vendor status assumptions, without advancing cloud/device gates.

Review2026-10-04. Scope: complete Phase0 specification and agent handoff. Application code, actual cloud entitlement, generated dependency locks, deployed runtime, load/device evidence and signed distribution remain future gated work. [ASSUMPTIONS](ASSUMPTIONS.md) and [IMPLEMENTATION_PLAN](agent/IMPLEMENTATION_PLAN.md) define those probes and deterministic fallbacks.

## Eight-role adversarial review

Question for every role: “What would still force an implementer to guess?” Corrections are reflected in the canonical files, not deferred as informal advice.

| Role | Ambiguity found | Resolution / owner |
|---|---|---|
| Staff Flutter engineer | Cross-device lesson resume lacked previous answer state; matching pairs encoded only authored IDs; raw PCM playback support assumed; generation choices unclear | Session answerHistory/lastFeedback and actual leftId/rightId connections in OpenAPI; typed per-exercise grading requirements; one-blank V1 rule; explicit native PCM bridge; schema-mapped DTO serializers/Drift generation in STACK |
| Distributed systems engineer | Race on simultaneous sessions; course/reward ownership unclear; initial gem balance not reconciled; purge ack callback could disappear; transaction operation count ambiguous | l_/a_active_slots, owner adapters, Learning frontier/Progress reward separation, INITIAL ledger credit, durable owner outbox acknowledgements, bounded≤100-operation transactions in DATA_MODEL/EVENTS_ERRORS |
| SRE | Free downgrade cannot host3Functions; direct voice cannot be stopped by Appwrite; league closure could omit late work | Same3local Node adapters with managed data/auth; provider enforced expiry/config gate plus conservative quota; watermark including dead letters and immutable settling checkpoint; admitted load/cost breakers and expiry rehearsal |
| DevOps engineer | Installed Node24/JBR25 conflated with selected runtime; Windows iOS/signing promise; future workflow scripts portrayed as existing | Node22/JDK17 compatibility probe, known Flutter baseline, cloud macOS simulator default/Codemagic fallback, conditional eligible signing, P1 creates actual workflows and verifies scope/runtime/config |
| AI speech engineer | Nullable LIVE token, missing active-slot/quota annotations, timer/refund loophole, ambiguous token delivery, asynchronous score retry, STT/LLM score confusion | LIVE/TURN lease union, atomic quota/slot/job/receipt, no native remint/refund on client close, terminal delivery uncertainty, measured quota per audio dispatch, scoreState with null metrics/provenance constraints, explicit fallback and async same-Function dispatch |
| QA lead | Targets mixed with measurements; no stable coverage map or device boundaries; no content integrity recipe | TRACEABILITY maps39functional/19NFR requirements to operations/local boundaries/screens/tasks; fixtures validate contract negatives; NFR/device gates separate; JCS+Ed25519/key IDs, manifest file hashes and semantic publisher rules fixed |
| Codex implementation agent | Overlapping docs/skills, undefined first task decisions, later-phase parallel start | Single canonical owners;17ADRs; P1-FOUND-001 scope/input/test/commands; complete12phase table/38tasks; phase precedence and change-area locks; short nested AGENTS |
| Claude Code implementation agent | Skills not discoverable in Claude path; Windows hook executable/shell handling; absent commit scanner silently passes | Four discovery wrappers link canonical skills; two read-only reviewers; JSON command hooks resolve executables safely, reject missing staged scanner, skip app proof in Phase0; example MCP/OAuth steps without secrets/global mutation |

The isolated speech researcher also performed a narrow adversarial contract review. Some reported table omissions reflected the pre-update file; final validation checks current active-slot and assessment-quota annotations. The payload review confirmed that750000bytes is an outer JSON envelope limit, while640064characters/480044decoded WAV bytes separately bound15-second audio. These units now have explicit definitions.

## Consistency check

| Relationship | Evidence / conclusion |
|---|---|
| SRS ↔ API | Every business operation's x-requirements resolves; all functional requirements map to operation IDs or explicit local/Account SDK boundaries; TRACEABILITY detects drift |
| API ↔ database | x-tables resolves to DATA_MODEL; owner matches; parameter/schema refs resolve; original answer/lease/assessment/job shapes are explicit |
| Database ↔ services | One writer per table;3prefix allowlists; shared platform key blast radius explicit; worker-only rows have owner protocol |
| Services ↔ flows | Completion/frontier transaction separate from eventual rewards; report/hint no submit; private profile/quest/wallet commands derive verified subject |
| Flows ↔ UI |42screens and12renderer contracts; loading/disabled/error/empty/offline recovery; guest/cached auth and media substitutes specified |
| AI ↔ backend | Server selects allowlisted provider/config; direct credential never persisted; actual token/PCM/permission/prosody gates; no AI authority over XP/course answer rules |
| CI ↔ tests | Deterministic PR fixtures versus explicitly gated Appwrite integration and live speech/device eval; simulator/physical proofs separate |
| Phases ↔ DAG | All12phase gates,38task IDs and current-phase parallel locks agree; reliability foundation begins with owner features |
| Agent rules ↔ tree | Root/nested guidance, four canonical/eight discovered skill files, reviewer/hooks/MCP templates and future-path distinctions match approved layout |

## Simplicity and cost check

Three business services; no custom auth, payment service, additional admin frontend, event broker, Redis, always-on speech relay, Kubernetes or mandatory clean-architecture ceremony. One database/bucket fits the intended Free fallback. No duplicate C4/ERD/PRD/tokens/motion/AI/runbook/DoD documents. Source content is authored once; generated app copies carry hashes. Native animations first; heavy Rive/Lottie/WebRTC/on-device model packages stay deferred.

[COST_MODEL](devops/COST_MODEL.md) classifies selected and compared software/hosted dependencies, separates Education/free tiers/credits/trials/paid-only, marks uncertain card/entitlement/numeric quota facts, and contains disablement/expiry/local fallback. Gummble research access worked but is paid/eligible trial; existing coding/search tools are outside new app spend. Signed iOS, unlimited hosted AI and10Kcloud capacity are not claimed free. No external paid plan or deployment was performed.

## Fresh verification

The following checks are run against the final files. Exact counts and outcome are recorded after the last successful run; none are application/device claims.

- Dependency-free validator: document links, unique requirement/screen/task/edge IDs, all A–L parts, phase rows, ADR structure, skill metadata, schema refs, operation/auth/ownership/table/requirement coverage and critical resume/voice/score/ledger invariants.
- Redocly CLI2.57.0 recommended OpenAPI lint; AJV8.20.0/ajv-formats3.0.1 compile schemas and exercise30positive/negative fixtures.
- Node syntax checks for hooks/validators; harmless hook format/secret/stop paths plus expected fail-closed commit attempts for missing scanner and a non-Git workspace. No actual commit is executed.
- Skills frontmatter validation and nearest-module instruction inventory. Additional generator compatibility/native API probes belong to P1/P8.

Validation outcome2026-10-04: **PASS**. Dependency-free validation checked81files (73Markdown),167local links,39functional requirements,19NFRs,42screens,39edge cases,38tasks,37owned tables,94schemas,41paths/42operations,680resolved refs,17ADRs and8skill entrypoints. Redocly recommended lint passed with zero errors/warnings. AJV compiled all94schemas;30positive/negative fixtures passed. All8skills passed the skill-creator quick validator. Node syntax checks and harmless format/secret/stop hook cases passed; expected blocked commit fixtures returned2for missing scanner/non-Git root. Commands used existing Node/Python and isolated temporary verifier packages; no app/cloud execution.

The hook test discovered Gitleaks8.30.1 returning0after a Git error outside a repository. The final hook now requires the intended Git root and rejects ERR/FATAL scanner output; it cannot mistake that failure for a clean staged scan. This corrective check was rerun. The final structural validation is rerun after recording this evidence.

## Readiness boundary

An implementation agent can take P1-FOUND-001 using exact frozen choices and verification commands. External facts cannot be fabricated: actual Education/Free transition, Appwrite runtime/transaction/security behavior, compatible locks/Xcode image, live-model entitlements/expiry/audio and dedicated scoring are explicit acceptance gates with safe alternatives. If a probe fails, implement the documented disabled/local mode or raise the named ADR; do not improvise a framework/provider/paid deployment.

Phase0 is complete: specification checks passed and evidence recorded. No task after Phase0 has been implemented.

ARCHITECTURE BLUEPRINT V1 — READY FOR IMPLEMENTATION
