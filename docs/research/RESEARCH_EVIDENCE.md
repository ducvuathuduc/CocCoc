# Research evidence

Single canonical evidence file. It holds two dated registers: the **current register** (2026-10-09–10), which wins wherever the two disagree, and the **historical register** (2026-10-03), kept for decision rationale.

## Current register — accessed 2026-10-09–10

Primary official documentation only. VERIFIED means the public page supports the claim; ACCOUNT-DEPENDENT means actual access/limits/resources need account evidence; BENCHMARK-REQUIRED means device/quality/latency/correctness is not measured; UNVERIFIED means the required evidence was unavailable. Public availability is not configured integration. The [historical register](#historical-register--checked-2026-10-03) below retains its original date; this current register supersedes changing operational claims.

R01–R27 were accessed 2026-10-09; registry compatibility/resolution continued across 09–10. R29 runtime download/verification was accessed 2026-10-10.

Research questions: (1) actual UI/spec gap and course scope; (2) Functions/transactions/ownership fit; (3) voice/token/assessment distinctions; (4) zero-new-spend/expiry/Windows/iOS delivery; (5) reproducible contracts and agent workflows. Exa searched Functions and fetched official pages in batches; web search corroborated Appwrite/GitHub/Student offers; one isolated voice researcher deep-read provider sources. Gummble returned one real catalog match. No account dashboard, provider inference or load benchmark was executed. Source titles, links, access date and supported claims are recorded here; no source-count/coverage promise is inferred from search snippets.

| ID / source title and URL | Exact supported claim (paraphrased) | Classification / ADR |
|---|---|---|
| R01 [Appwrite Education enforcement](https://appwrite.io/changelog/entry/2026-09-30) | Six-month term enforcement begins 2026-11-01; organizations already beyond term must select a plan or face disablement. Account expiry is not supplied. | VERIFIED public / ACCOUNT-DEPENDENT expiry; ADR-0004 |
| R02 [Appwrite Education](https://appwrite.io/education), [April project-limit change](https://appwrite.io/changelog/entry/2026-04-07) | Public Education offer is two Pro-equivalent projects for six months. April comparison lists Free two functions/one database/one bucket; confirm current console limits before downgrade. | VERIFIED offer/dated comparison; ACCOUNT-DEPENDENT transition; ADR-0004 |
| R03 [Functions runtimes](https://appwrite.io/docs/products/functions/runtimes) | Cloud list includes node-22. A particular account/project runtime was not probed. | VERIFIED public / ACCOUNT-DEPENDENT project; ADR-0003 |
| R04 [Execution modes](https://appwrite.io/docs/products/functions/execute), [Function settings](https://appwrite.io/docs/products/functions/functions) | Synchronous execution has 30-second deadline; settings document a system maximum 900 seconds. Longer async compute does not establish full-duplex audio relay. | VERIFIED limits; inference about unsuitable relay; ADR-0011 |
| R05 [TablesDB transactions](https://appwrite.io/docs/products/databases/tablesdb/transactions) | createTransaction; stage with transactionId/createOperations; updateTransaction commit/rollback. Commit detects externally changed rows. Free 100 operations; schema changes excluded. | VERIFIED contract / BENCHMARK-REQUIRED actual conflicts; ADR-0016 |
| R06 [Server Node TablesDB reference](https://appwrite.io/docs/references/cloud/server-nodejs/tablesDB) | Runtime column/index and transaction APIs exist; project-scoped server keys are not per-table owner isolation. | VERIFIED API / ACCOUNT-DEPENDENT scopes; ADR-0007 |
| R07 [Function context](https://appwrite.io/docs/products/functions/develop) | Entrypoint receives req/res/log/error; req.bodyText/bodyJson and res.json. Supplied user-id header does not replace verified Account.get identity. | VERIFIED context; project security decision; ADR-0006 |
| R08 [Flutter architecture guide](https://docs.flutter.dev/app-architecture/guide) | View/ViewModel/Repository/Service responsibilities and optional domain layer support the chosen structure. | VERIFIED; ADR-0001/0002 |
| R09 [Flutter iOS setup](https://docs.flutter.dev/platform-integration/ios/setup) | iOS native build toolchain requires macOS/Xcode. Windows source/tests are not iOS build evidence. | VERIFIED; ADR-0014 |
| R10 [Gemini deprecations](https://ai.google.dev/gemini-api/docs/deprecations/) | Legacy Live preview has earliest retirement 2026-11-17; replacement gemini-3.8-live. 2.5 text access limited to prior active users; not announced deprecated. | VERIFIED / ACCOUNT-DEPENDENT access; ADR-0010 |
| R11 [Gemini ephemeral credentials](https://ai.google.dev/gemini-api/docs/live-api/ephemeral-tokens) | Live/v1beta-only short credentials, single-use and configuration constraints; reconnection/expiry need provider enforcement testing. A client timer is not a security budget. | VERIFIED protocol / BENCHMARK-REQUIRED abuse bounds; ADR-0011 |
| R12 [Google libraries](https://ai.google.dev/gemini-api/docs/libraries) | Ordinary Dart google_generative_ai is not actively maintained; do not infer a maintained native Dart Live SDK. | VERIFIED / BENCHMARK-REQUIRED Flutter raw WebSocket/native audio; ADR-0010 |
| R13 [Gemini pricing](https://ai.google.dev/gemini-api/docs/pricing.md) | Current text/Live/streaming-STT/batch-STT/TTS IDs and listed units are in the provider benchmark. Free price does not establish project quotas. | VERIFIED price snapshot / ACCOUNT-DEPENDENT quotas; ADR-0010 |
| R14 [Azure pronunciation assessment](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/how-to-pronunciation-assessment), [locale table](https://learn.microsoft.com/en-gb/azure/ai-services/speech-service/language-support?tabs=pronunciation-assessment) | Dedicated accuracy/fluency/completeness and phoneme metrics; prosody restricted to en-US. vi-VN assessment support does not imply Vietnamese prosody or phoneme-name support. | VERIFIED fields / ACCOUNT-DEPENDENT entitlement / BENCHMARK-REQUIRED quality; ADR-0012 |
| R15 [Groq file transcription](https://console.groq.com/docs/speech-to-text) | Whisper large-v3/turbo are batch upload STT; transcript is not phoneme assessment. | VERIFIED / ACCOUNT-DEPENDENT allowance; ADR-0010 |
| R16 [Mistral audio](https://docs.mistral.ai/studio/audio/overview) | Distinct realtime transcription and TTS APIs/models; vendor latency claims are not measured mobile results. | VERIFIED capabilities / BENCHMARK-REQUIRED; ADR-0010 |
| R17 [MiniMax streaming TTS](https://platform.minimax.io/docs/api-reference/speech-t2a-websocket) | WebSocket TTS exists; it is a separate speech capability, not a pronunciation grader. | VERIFIED / ACCOUNT-DEPENDENT model access; ADR-0010 |
| R18 [DeepSeek API](https://api-docs.deepseek.com/api/create-chat-completion/) | Text API can be a tutor candidate; speech/phoneme API not established by this source. | VERIFIED text / UNVERIFIED speech; ADR-0010 |
| R19 [OpenAI model catalog](https://platform.openai.com/docs/models) | gpt-realtime and gpt-realtime-mini are current audio/text candidates. Old beta ephemeral TTL does not prove current GA configuration. No ChatGPT subscription API entitlement assumed. | VERIFIED catalog / UNVERIFIED GA TTL/account credits; ADR-0010 |
| R20 [Workers AI pricing](https://developers.cloudflare.com/workers-ai/platform/pricing/), [models](https://developers.cloudflare.com/workers-ai/models/index.md) | Neurons-based free allowance and model-specific inference charges differ from Worker execution limits; Whisper is a transcription candidate. | VERIFIED billing model / ACCOUNT-DEPENDENT allowance; ADR-0010 |
| R21 [Student Developer Pack](https://education.github.com/pack) | Partner offers vary; current Appwrite six-month offer appears. Existing DigitalOcean balance/expiry cannot be determined from Pack listing. | VERIFIED offer snapshot / ACCOUNT-DEPENDENT redemption; ADR-0017 |
| R22 [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions), [runner pricing](https://docs.github.com/en/billing/reference/actions-runner-pricing) | Public standard runners free; private minutes/storage depend on repository owner. Larger runners paid; do not extrapolate a stale multiplier or student allowance. | VERIFIED policy / ACCOUNT-DEPENDENT budget; ADR-0014 |
| R23 [Apple membership comparison](https://developer.apple.com/support/compare-memberships/) | Simulator compile differs from provisioned physical device, TestFlight and store distribution. Cloud runner does not supply membership/signing. | VERIFIED / ACCOUNT-DEPENDENT team; ADR-0014 |
| R24 [Play backend](https://developer.android.com/google/play/billing/backend), [subscription lifecycle](https://developer.android.com/google/play/billing/lifecycle/subscriptions) | Backend verifies purchase state; RTDN deduplication and purchases.subscriptionsv2.get reconciliation drive entitlements. | VERIFIED / ACCOUNT-DEPENDENT console access; billing design |
| R25 [Flutter purchase plugin](https://pub.dev/packages/in_app_purchase) | Maintained platform purchase adapter exists. Presence does not implement server verification or purchase restoration. Not added to current UI lock. | VERIFIED package / BENCHMARK-REQUIRED integration; billing design |
| R26 [Gummble Codex setup](https://gummble.com/blog/gummble-mcp-in-codex-setup-oauth), [catalog](https://gummble.com/apps/duolingo-ios) | Official command matches local codex help. Real MCP search returned Duolingo iOS on 2026-10-09. Paid/trial entitlement is not free runtime infrastructure. | VERIFIED tool receipt / ACCOUNT-DEPENDENT continued access; design reference |
| R27 [Claude skills](https://code.claude.com/docs/en/skills), [hooks](https://code.claude.com/docs/en/hooks), [Codex guidance](https://developers.openai.com/codex/guides/agents-md), [skills](https://developers.openai.com/codex/skills) | Short scoped guidance and reusable on-demand skills/hooks are documented; existing project workflows retained. Proposed launchpad blog was not treated as required truth. | VERIFIED behavior; agent system |
| R28 [npm registry](https://registry.npmjs.org/typescript), [node-appwrite registry](https://registry.npmjs.org/node-appwrite), [pub.dev package API](https://pub.dev/api/packages/appwrite) | Backend registry versions checked via npm view; compatible pins/lock recorded on disk. Flutter versions come from supplied lock and fresh local SDK, not a claim of latest release. | VERIFIED resolution/type/build checks; ADR-0003 |
| R29 [Official Node22 distribution](https://nodejs.org/dist/v22.23.3/), [published checksums](https://nodejs.org/dist/v22.23.3/SHASUMS256.txt) | Portable Windows22.23.3 downloaded to ignored local cache, SHA-256 matched published manifest, backend16 tests/smoke/audit executed under actual binary. Does not prove Appwrite runtime version. | VERIFIED local / ACCOUNT-DEPENDENT cloud; ADR-0003 |
| R30 [Gradle directory documentation](https://docs.gradle.org/current/userguide/directory_layout.html) | Current manual verifies GRADLE_USER_HOME directory behavior; actual local wrapper is9.3.1. A separate user home isolates the diagnostic without deleting old cache; successful retry would not identify the process that changed it. Version-specific9.3.1 page was inaccessible through browser tool. | VERIFIED current directory behavior / local retry receipt; platform gate |

Source gap: `docs.gummble.com/docs/mcp` was not sufficient evidence for current setup; use verified official Gummble article and actual CLI help/tool receipt. Claude CLI on this machine reports missing AgentRouter authentication even for the attempted help command; installation/auth success is not claimed. Gstack router/document workflow was consulted; its skill-start binary is absent, so unrelated onboarding/telemetry were skipped and no push was performed.

## Historical register — checked 2026-10-03

Preserved as written on 2026-10-03. The [current register](#current-register--accessed-2026-10-09-10) above supersedes changing vendor/package/model/offer claims and distinguishes public documentation from actual account access. IDs R01… restart in each register; cite as `current R05` or `historical R05`.

Checked **2026-10-03 Asia/Saigon**. Primary source research used the configured Exa search/fetch tools and actual Gummble MCP. Searches covered five workstreams: product/design; Flutter/toolchain; Appwrite/data; AI/speech; delivery/agents/costs. Source fetches were read beyond search snippets; direct registry APIs and local CLI supplied version evidence. Account console entitlements and physical-device benchmarks were unavailable. No source-directed instructions were executed.

Confidence: HIGH = directly documented or observed; MEDIUM = official but dynamic, conflicting, preview, or account dependent; UNVERIFIED = evidence absent. Scoring below is engineering judgment, **not empirical benchmarking**.

### Evidence register

| ID | Source and finding | Status / confidence |
|---|---|---|
| R01 | [Appwrite Education](https://appwrite.io/education): current enrollment offer is six months with Pro resources | HIGH; older lifetime-student announcement conflicts and is not used |
| R02 | [Education limit change, 2026-04-07](https://appwrite.io/changelog/entry/2026-04-07): two projects; 2 TB bandwidth, 150 GB storage, 200K MAU per project | HIGH; actual account expiry/allowances need console |
| R03 | [Appwrite pricing](https://appwrite.io/pricing), [rendered comparison](https://new.appwrite.io/pricing): Free one database/bucket, two Functions; 5 GB transfer, 2 GB storage, 750K executions, 100 GB-hours; Free 250 realtime connections | MEDIUM; renderer incomplete on first URL, quota snapshot corroborated by changelog |
| R04 | [Transactions](https://appwrite.io/docs/products/databases/tablesdb/transactions): staged operations, atomic commit, conflict detection, Free 100 operations | HIGH |
| R05 | [Permissions](https://appwrite.io/docs/products/databases/tablesdb/permissions): table OR row permission grants access; row security must be enabled | HIGH |
| R06 | [JWT](https://appwrite.io/docs/products/auth/jwt): expires in 15 minutes or session deletion; per-request JWT client; API key bypasses user permissions | HIGH |
| R07 | [Function execution](https://appwrite.io/docs/products/functions/execute): sync HTTP 30s hard limit; schedule/event async | HIGH |
| R08 | [Function development](https://appwrite.io/docs/products/functions/develop): context req/res, req.bodyJson, x-appwrite-trigger/user-jwt/key | HIGH |
| R09 | [Functions](https://appwrite.io/docs/products/functions/functions), [runtimes](https://appwrite.io/docs/products/functions/runtimes): dynamic scopes/runtime and configurable execution timeout | HIGH behavior; exact Cloud node-22 availability UNVERIFIED |
| R10 | [Flutter architecture](https://docs.flutter.dev/app-architecture/guide), [recommendations](https://docs.flutter.dev/app-architecture/recommendations): View/ViewModel/Repository/Service, optional domain logic | HIGH |
| R11 | [Flutter 3.47 announcement](https://flutter.dev/blog/whats-new-in-flutter-3-47), [release notes](https://docs.flutter.dev/release/release-notes): stable 3.47 baseline; Android API 36, Java 17 minimum; iOS 15 minimum | HIGH baseline; newest patch UNVERIFIED |
| R12 | [Android setup](https://docs.flutter.dev/platform-integration/android/setup), [iOS setup](https://docs.flutter.dev/platform-integration/ios/setup): Windows Android SDK; Xcode/macOS iOS | HIGH |
| R13 | [Practice tab, 2026-02-18](https://blog.duolingo.com/guide-to-duolingo-practice-hub/): practice now available free; mistakes/words/speak/listen; Explain My Answer free | HIGH announcement, rollout variation possible |
| R14 | [Energy](https://blog.duolingo.com/duolingo-energy/): experiment replacing hearts, recharge/correct-answer rewards | HIGH existence; universal rollout UNVERIFIED |
| R15 | [Falstaff, 2026-01-14](https://blog.duolingo.com/beginner-video-call-with-falstaff/): guided Max calls, iOS, selected languages | HIGH published availability; October account rollout UNVERIFIED |
| R16 | [Max help](https://www.duolingo.com/help/what-is-duolingo-max/): Roleplay and Video Call, limited courses/mobile platforms | MEDIUM; older hearts/practice text conflicts with newer announcement |
| R17 | [Speaking, 2026-02-09](https://blog.duolingo.com/covering-all-the-bases-duolingos-approach-to-speaking-skills/): repeat/translation/dialogues/dictation microphone/flashcards | HIGH described features, course-specific |
| R18 | [Video Call engineering](https://blog.duolingo.com/ai-and-video-call/): level-targeted conversation opener/question/turns/closer | HIGH; our architecture borrows controlled turn structure, not proprietary implementation |
| R19 | [App Store](https://apps.apple.com/us/app/duolingo-language-lessons/id570060128), [Play Store](https://play.google.com/store/apps/details?id=com.duolingo): mobile language skills, streaks/leaderboards; store claims do not prove every UI flow | MEDIUM current listing; Play extracted update 2026-07-27 |
| R20 | [Official colors](https://design.duolingo.com/identity/color), [typography](https://design.duolingo.com/identity/typography), [design site](https://design.duolingo.com/): public brand guidance, not an engineering DESIGN.md | HIGH |
| R21 | [Gummble Duolingo](https://gummble.com/apps/duolingo-ios): latest available capture Dec 30 2025; 1,103 screens | HIGH catalog observation; not October 2026 live app |
| R22 | [Gummble Codex setup](https://gummble.com/blog/gummble-mcp-in-codex-setup-oauth), [Claude setup](https://gummble.com/mcp/claude-code), [MCP offer](https://gummble.com/mcp): OAuth HTTP server; paid or eligible trial | HIGH |
| R23 | [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions): public standard runners free; Pro private 3,000 minutes, 1 GB artifacts | HIGH; owner plan matters, larger runners paid |
| R24 | [Codespaces](https://docs.github.com/en/billing/concepts/product-billing/github-codespaces): personal Pro 180 core-hour allowance and 20 GB-month; Linux environment | HIGH; not a Mac or mobile emulator |
| R25 | [GitHub Packages](https://docs.github.com/en/billing/concepts/product-billing/github-packages): public packages free; Container Registry storage/bandwidth currently free | HIGH current policy; no forever guarantee |
| R26 | [Student Pack](https://education.github.com/pack): student offers include GitHub Pro and changing partner benefits | MEDIUM; vendor redemption page controls current terms |
| R27 | [Codemagic pricing](https://docs.codemagic.io/billing/pricing/): personal M2 macOS 500 minutes/month, no free team/Linux/Windows minutes | HIGH |
| R28 | [Bitrise pricing](https://bitrise.io/pricing), [Appcircle](https://appcircle.io/pricing): Bitrise default Starter paid; Appcircle 20 builds/month, 30-min build, one concurrency | HIGH extracted pricing; not selected |
| R29 | [Apple memberships](https://developer.apple.com/support/compare-memberships/): personal-team provisioning expires after 7 days; distribution/TestFlight require developer program | HIGH; signing not solved merely by a cloud runner |
| R30 | [Grafana free](https://grafana.com/products/cloud/free-tier/), [pricing](https://grafana.com/pricing/): no card, bounded free telemetry, 14-day retention, 10K metric series and 50 GB logs/traces | HIGH |
| R31 | [Sentry](https://sentry.io/pricing/): Developer one user, free error monitoring; numeric Developer event quota unclear in extracted column layout | HIGH plan; event count UNVERIFIED, do not reuse paid 50K number |
| R32 | [Codex AGENTS](https://developers.openai.com/codex/guides/agents-md), [skills](https://developers.openai.com/codex/skills), [MCP](https://developers.openai.com/codex/mcp): nested guidance, .agents skills, HTTP OAuth | HIGH; local codex-cli 0.153.4 help verified |
| R33 | [Claude skills](https://code.claude.com/docs/en/skills), [subagents](https://code.claude.com/docs/en/sub-agents), [hooks](https://code.claude.com/docs/en/hooks): project skill/agent frontmatter and deterministic command hooks | HIGH; minimal schemas used |
| R34 | [Primary retrieval study](https://learninglab.psych.purdue.edu/downloads/2007/2007_Karpicke_Roediger_JEPLMC.pdf), [retrieval/feedback experiments](https://link.springer.com/article/10.3758/MC.38.1.116): repeated recall with feedback supports retention; exact expanding schedule superiority not universal | HIGH study findings; product schedule is a design heuristic |
| R35 | [k6 official](https://grafana.com/docs/k6/latest/), [OpenTelemetry JS](https://opentelemetry.io/docs/languages/js/): tooling references for tests/telemetry | Tooling selection; exact versions locked in P1 |

AI vendor evidence, current model names, pricing, transports, free allowances, and unresolved account facts are owned by [AI_EVIDENCE](AI_EVIDENCE.md). Package observations are owned by [STACK](../architecture/STACK.md). No cross-vendor performance measurements were conducted.

### Architecture option scores

Weights for frontend: simplicity 20%, testability 15%, agent reliability 15%, scale 10%, compile safety 10%, low generation burden 10%, ecosystem 5%, maintainability 5%, low boilerplate 5%, feature-module fit 5%.

| Candidate | Simple | Test | Agent | Scale | Safety | Generation | Ecosystem | Maintain | Boilerplate | Feature | Weighted /10 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Riverpod MVVM, manual providers | 9 | 9 | 9 | 8 | 9 | 9 | 9 | 9 | 9 | 9 | 8.90 |
| BLoC/Cubit feature-first | 7 | 9 | 8 | 9 | 9 | 9 | 9 | 8 | 6 | 9 | 8.25 |
| Provider + ChangeNotifier MVVM | 9 | 7 | 7 | 6 | 7 | 10 | 9 | 7 | 9 | 7 | 7.80 |
| Mandatory four-layer Clean Architecture | 4 | 9 | 6 | 9 | 9 | 7 | 8 | 6 | 3 | 9 | 6.85 |

Winner Riverpod: typed dependency overrides, explicit asynchronous state and cancellation, minimal event ceremony. Fallback Cubit only by ADR if repeated lifecycle errors remain after tests. Official MVVM defines responsibilities independently of state library.

| Category | Candidates and score /10 | Winner | Fallback and trigger |
|---|---|---|---|
| Backend language | TypeScript 9; Dart server 7; Go 7; Python 5 | TypeScript/Node 22 | Supported Node runtime update via ADR; no Python without ML evidence |
| Service decomposition | 3 contexts 9; 2 combined 7; 10 tiny 3 | Learning, Progress, AI | Scale a service without splitting until ownership or operational need changes |
| API | REST/OpenAPI 9; GraphQL 6; gRPC mobile 5 | REST/OpenAPI 3.1 | Internal HTTP events; no broker |
| Local database | Drift 9; Hive CE 7; Isar original 3; preferences 2 for journal | Drift SQLite | Hive CE only if verified SQLite integration blocks target platform |
| Mobile networking | Appwrite SDK + http 9; SDK + Dio 8; raw REST only 5 | Appwrite auth SDK; http business APIs | Dio only for measured cancellation/upload requirements |
| Animation | native Flutter 9; Rive 7; Lottie 7 | Native widgets/tweens | Add Rive for an authored interactive asset with size/perf evidence |
| iOS CI | GitHub standard macOS 9; Codemagic personal 8; Appcircle 6; Bitrise 4 | GitHub Actions | Codemagic M2 personal quota; no new signing purchase |
| Observability | JSON + Appwrite + Grafana + Sentry 8; JSON only 5; self-run cluster 3 | Thin OTel/log exporters, bounded Sentry | Local NDJSON dashboards when cloud quota ends |
| Cross-service delivery | transactional outbox 9; direct-only 4; managed broker 5 | outbox + idempotent inbox | Broker only if tested backlog/reliability cost warrants ADR |

Scores encode suitability for this student project, not general superiority. Source R10 supports separation; R04 enables outbox atomicity; R07 rules out a persistent Function audio relay; R23/R27 establish selected iOS CI cost.
