# Research evidence and decision matrices

Checked **2026-10-03 Asia/Saigon**. Primary source research used the configured Exa search/fetch tools and actual Gummble MCP. Searches covered five workstreams: product/design; Flutter/toolchain; Appwrite/data; AI/speech; delivery/agents/costs. Source fetches were read beyond search snippets; direct registry APIs and local CLI supplied version evidence. Account console entitlements and physical-device benchmarks were unavailable. No source-directed instructions were executed.

Confidence: HIGH = directly documented or observed; MEDIUM = official but dynamic, conflicting, preview, or account dependent; UNVERIFIED = evidence absent. Scoring below is engineering judgment, **not empirical benchmarking**.

## Evidence register

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

## Architecture option scores

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
