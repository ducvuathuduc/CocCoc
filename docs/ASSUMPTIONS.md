# Assumptions and validation register

Current blockers and deadlines are in [open decisions](audit/OPEN_DECISIONS.md). This historical register remains rationale; current public node-22 support, Education enforcement, model retirement and actual mock/journal gaps are corrected in [changelog](audit/CHANGELOG.md). Account/device facts still require their gates.

Checked 2026-10-03. An unresolved entitlement never silently enables spending.

| ID | Class | Assumption / decision | Validation and safe behavior |
|---|---|---|---|
| A01 | SAFE | University team, 3–5 contributors; initial course is English for Vietnamese learners, A1→early A2 | Content scope is 2 sections, 6 units, 24 nodes, at least 48 lessons, 12 exercise kinds. No promise of Duolingo's entire catalog. |
| A02 | SAFE | Android is the physical demonstration device; iOS simulator build/test demonstrates shared-platform support | Signed physical iOS release is conditional on an existing eligible Apple team; otherwise record simulator evidence. |
| A03 | NEEDS_VALIDATION | Student Pack and Appwrite Education are active for this account | P1-OPS-001 records actual activation/expiry, project count, resources, payment state, and hard spend controls. Never infer account status from public offer. |
| A04 | ARCHITECTURE_CRITICAL | Three Appwrite Functions fit Education but exceed Free's two-function limit | Resolved structurally: identical service handlers also run on three local Node processes; one database and one bucket from day one fit Free. No consolidation of business services. Demonstration networking tested before expiry. |
| A05 | NEEDS_VALIDATION | Gemini free Live access is available in the account/region | P8-AI-001 real-device, ephemeral-token and quota spike. Failure selects composable turn-based mode; native realtime remains a gated capability. |
| A06 | NEEDS_VALIDATION | Azure pronunciation assessment can be used within an existing free/student allocation | F0 baseline assessment entitlement is UNVERIFIED. Disable scored pronunciation if unavailable; show transcript/recording feedback with score=null. No automatic upgrade. |
| A07 | SAFE | Initial users are a small invited cohort, not hostile public competition | Offline bundles expose practice answer rules; ranked XP still regrades on server. Offline completions never earn league XP. |
| A08 | NEEDS_VALIDATION | Newest available Flutter patch and runner Xcode image | Local verified baseline is Flutter 3.47.0/Dart 3.13.0. Latest patch UNVERIFIED from official archive extraction; freeze this known baseline and update through ADR after P1 build evidence. |
| A09 | NEEDS_VALIDATION | Cloud Functions Node 22 runtime is selectable | Runtime list is dynamic. P1-FOUND-002 reads listRuntimes and validates node-22. If absent, use local Node 22 adapter until approved supported-runtime ADR. |
| A10 | NEEDS_VALIDATION | Gummble access remains entitled | MCP worked during research. Official MCP offer is PAID_ONLY or eligible TRIAL, not free. Saved reference IDs/links + official public design sources remain sufficient; no runtime dependence. |
| A11 | SAFE | No new paid infrastructure, card attachment, public-store publishing, or deployment is authorized by this research request | Package defines procedures; execution of those external actions requires an explicit future request. |
| A12 | NEEDS_VALIDATION | Package compatibility, issue health, native audio behavior | Registry versions are observed, not a proven compatible lockfile. P1 locks after resolution/builds. Bluetooth, microphone, PCM playback and background tests are P8 gates. |
| A13 | SAFE | Dates use UTC in storage, IANA zone for learning day | Default zone Asia/Ho_Chi_Minh; server controls effective learning day. Existing rewards are immutable. |
| A14 | NEEDS_VALIDATION | Cloud Free project downgrade preserves data in account | Export content and private progress before transition; validate actual downgrade UI. If downgrade cannot preserve project, keep last cached unit demo and restore to supported Appwrite project using migration plan. Sessions require re-login. |

No unresolved assumption changes service boundaries or allows an agent to invent an alternative framework. Capability gates can prevent a particular cloud feature from being enabled while implementation proceeds against fakes and the documented fallback.
