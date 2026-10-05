# Existing documentation audit

Inventory: workspace enumeration before writing found **no existing files**, including no Git repository, SRS, architecture, API, designs, database plan, or source implementation. One user attachment was supplied: “MASTER RESEARCH DIRECTIVE — Production-Grade Flutter Language Learning Platform”, 2,491 lines. All sections 0–50 were read. Missing source documents are not treated as reviewed artifacts.

| Existing item | Keep | Modify | Remove | Missing information | Reason |
|---|---:|---:|---:|---|---|
| Flutter-first / Windows constraint (§2–3) | Yes | Yes | No | Toolchain and remote macOS evidence | Android can be developed on Windows; iOS requires macOS/Xcode. Freeze verified local SDK. |
| Microservices mandate (§4) | Yes | Yes | No | Bounded contexts, ownership, transaction rules | Three business services satisfy independent deployment. Appwrite Auth/Storage are infrastructure. |
| Appwrite preference (§5–6) | Yes | Yes | No | Exact benefit duration, Free fallback, credentials | Current Education page says 6 months; 2026 changelog says 2 projects. Older lifetime-student offer is stale/conflicting. |
| 0 VND objective (§7) | Yes | Yes | No | Capability limits and account entitlement | Zero spend is viable for bounded demo, not unlimited AI, signed iOS distribution, or 10,000 cloud connections. |
| Current Duolingo parity (§8–10) | Yes | Yes | No | Platform/course/version evidence | Gummble latest capture is Dec 2025; official 2026 product evidence overrides old subscription/heart assumptions. |
| Gummble as design input | Yes | Yes | No | Cost and sample provenance | MCP currently paid/eligible trial. Access worked here, but does not prove forever-free team entitlement or generate production Flutter. |
| State-management candidates (§11–12) | No | Yes | No | Winner, current packages, compatibility | Freeze Riverpod MVVM; omit mandatory clean-architecture layer for CRUD. |
| AI candidate list (§13–16) | Yes | Yes | No | Exact models, credentials, pronunciation | Generic STT cannot supply validated phoneme scores. Live preview and quotas require fallback. |
| Arbitrary cloud audio relay | No | No | Yes | Hosting duration/transport | Synchronous Appwrite execution is 30 seconds; direct provider audio removes an unnecessary persistent relay. |
| Learning science (§17–18) | Yes | Yes | No | Deterministic review rules and evidence limits | Retrieval/spacing evidence supports review, not a claim that a chosen interval sequence is optimal. |
| Auth/offline/performance (§19–27) | Yes | Yes | No | Trust, day boundary, duplicate and killed-process recovery | Blueprint defines server regrading, safe offline XP, bounded transactions and revocation. |
| API example (§28) | Yes | Yes | No | Full schemas, endpoint owner, error/status mapping | One OpenAPI contract and one error catalog replace informal snippets. |
| CI/test aspirations (§29–31) | Yes | Yes | No | Trigger, secrets, phase, cost, artifacts | Simulator success does not establish signed-device success. CI never calls live AI. |
| Agent workflow (§32–38) | Yes | Yes | No | Current discovery/hooks and change-area locking | Short root/nested guidance, four canonical skills, two read-only Claude reviewers. |
| Example 12 phases (§39) | Yes | Yes | No | Concrete task IDs and foundational reliability | Offline journal/authorization/idempotency begin early; phase 10 validates and hardens them. |
| Example repository tree (§42) | No | Yes | Yes | Purpose and canonical owners | Remove empty package layers, duplicate bilingual/docs files, web admin, broker/gateway/cluster scaffolds. |
| Freeze declaration (§49–50) | Yes | Yes | No | Evidence and review scope | Ready means specification and first task ready; does not claim cloud entitlements, load benchmarks, or app build success. |
| Additional prior documents | No | No | No | All are absent | Cannot assert a diff against documents never supplied. |

Resolved contradictions: three Functions versus Free limit → local service adapter; iOS plus Windows → cloud macOS simulator first; dedicated pronunciation plus zero guaranteed paid quota → nullable assessment and explicit capability gate; “full UX first” plus data correctness → phase 2 fake repositories conform to final contracts; frozen architecture plus drift-prone versions → ADR-controlled upgrades.
