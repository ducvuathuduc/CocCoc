# Cost classification and zero-spend operation

Current 2026-10-09 external prices/offer changes are in [evidence](../audit/RESEARCH_EVIDENCE.md) and [provider benchmark](../ai/PROVIDER_BENCHMARK.md). Historical numeric allowances below are planning observations, not account guarantees. Current Education enforcement and account expiry must be resolved before cloud admission; no new paid signup or spend occurred.

## Four design scenarios and accounting formulas

Illustrative assumptions, not measurements: two lessons/person/day, ten answers/lesson; 25 business requests/day including bootstrap; 60 DB reads/20 row operations/day; 0.6 MB uncached media/day; one tutor request/day at 600 input/120 output tokens; optional two audio minutes/day. Usage varies with cache, retries, content and transaction staging. Do not count database reads/writes as equivalent Function executions or assume every free ceiling can be used simultaneously.

| Cohort / scenario | Daily requests / DB reads / row operations | Daily uncached media | Daily tutor input/output tokens | Optional audio minutes |
|---|---|---|---|---|
| 1 tester | 25 / 60 / 20 | 0.6 MB | 600 / 120 | 2 |
| 10 testers | 250 / 600 / 200 | 6 MB | 6,000 / 1,200 | 20 |
| 100 DAU | 2,500 / 6,000 / 2,000 | 60 MB | 60,000 / 12,000 | 200 |
| 1,000 DAU | 25,000 / 60,000 / 20,000 | 600 MB | 600,000 / 120,000 | 2,000 |

For N active people and D days: text list cost = N×D×(600×inputRate +120×outputRate)/1,000,000; Live = admitted inputMinutes×inputMinuteRate + outputMinutes×outputMinuteRate; storage/transfer/compute/read/write use their distinct measured units and current plan rates after included allowances. CI = billable runner minutes×current OS rate + accumulated artifact/cache storage. Apply actual remaining credit, expiration and account quotas afterward; do not invent a final VND invoice or conversion rate. Optional paid adapters and overage stay off. Hard project/provider quota may reject requests before these design ceilings; ordinary cached learning still works.

Classes: local tools are software with existing hardware cost; recurring free tiers are bounded; Education/trials expire; one-time redeemed credits have actual balances/deadlines; strictly paid store/signing/API resources need separate authorization. Current DigitalOcean balance/expiry and Azure credit eligibility are ACCOUNT-DEPENDENT. Check actual dashboard, never infer them from historical Student Pack offers. Free cloud fallback may not satisfy a rubric requiring three deployed services.

Checked2026-10-03; reviewed2026-10-04. Exact categories: FREE_FOREVER (software/no metered hosted dependency), FREE_TIER (ongoing bounded hosted allocation), STUDENT_BENEFIT, PROMOTIONAL_CREDIT, TRIAL, PAID_ONLY. No hosted service is promised permanently unlimited. Card/account entitlement marked UNVERIFIED when public source does not establish it.

| Capability | Provider / product or model | Category / free forever? | Free monthly or other quota | Student benefit | Trial/credit | Card? | Limits / recommendation |
|---|---|---|---|---|---|---|---|
| Flutter/Dart/Node/SQLite/k6/OTel tooling | official local software | FREE_FOREVER software | no hosted meter | none needed | none | no | selected; existing hardware/electricity not claimed free |
| Auth/data/storage/Functions | Appwrite Education | STUDENT_BENEFIT, no | Pro-equivalent; 2projects; 2TB bandwidth/150GB/200K MAU per project documented | current signup6months | no perpetual benefit assumption | UNVERIFIED for redemption | selected during active offer; confirm console start/expiry |
| Same managed backend after expiry | Appwrite Cloud Free | FREE_TIER, no | 1DB/1bucket/2Functions,5GB transfer/2GBstorage,750Kexecutions/100GB-hour;250Realtime connections | none | none | not asserted from pricing extraction | selected fallback data/auth; three services run locally; project inactivity pause after1week |
| Functions beyond Free | Appwrite Pro | PAID_ONLY | paid allowances | Education may cover temporarily | none | yes paid billing | disabled new paid upgrade; no hidden overage |
| CI | GitHub standard Actions public repository | FREE_TIER, no | standard runner minutes free under public-repo policy; artifacts/storage bounded | optional Pro | none | no extra billing needed within allocation | default if public repo acceptable; larger runners paid |
| CI private repo | GitHub Pro owner | STUDENT_BENEFIT + FREE_TIER |3,000minutes/month;1GB artifacts;10GBcache; macOS different rate | Pro for verified student | none | no extra spending enabled | owner plan matters, org not automatically Pro; actual billing rates control |
| Packages/container artifacts | GitHub Packages / GHCR | FREE_TIER, no | public packages free; Container Registry storage/bandwidth currently free | Pro package quota conditional | none | within no-charge use | archive service artifacts in Actions first; GHCR only local/container deployment need |
| Remote dev optional | Codespaces personal Pro | STUDENT_BENEFIT + FREE_TIER |180core-hours,20GB-month; e.g.2cores≈90wallhours | verify Pack actual account quota | none | no card→quota blocks | optional Linux backend editing; no iOS tooling/emulator substitute |
| iOS CI fallback | Codemagic personal M2 | FREE_TIER, no |500macOSM2minutes/month; no team/Linux/Windows free minutes | student account offer mentioned, exact terms UNVERIFIED | separate product trials not baseline | no billing upgrade enabled | selected fallback; exhausted quota waits/reset |
| Other iOS CI | Appcircle Starter | FREE_TIER, no |20builds/month,30min/build,1concurrent | UNVERIFIED | none relied upon | UNVERIFIED | compared, not selected |
| Other iOS CI | Bitrise current Starter | PAID_ONLY | no current free Starter allocation established | UNVERIFIED | possible trial not relied upon | paid | rejected over selected options |
| iOS simulator tools | Xcode / simulator on included macOS runner | FREE_TIER hosted / FREE_FOREVER software | runner allowance | none needed | none | runner policy | default unsigned simulator proof, no local Windows Xcode |
| Signed device/TestFlight/store | Apple Developer Program | PAID_ONLY unless existing eligible team/waiver | no claimed free distribution quota | university eligibility must be verified | no assumed credit | membership account | optional; cloud build does not supply signing membership |
| Android demo | local APK side-load | FREE_FOREVER software | no store quota | none | none | no | selected; public Play publishing excluded/paid account requirement |
| Text tutoring | current gated Gemini text profile | FREE_TIER, no | token/RPM/RPD depend on account; amount UNVERIFIED | no assumed student API benefit | no credits relied upon | no billing activation default; regional eligibility verified | selected capped100requests/user/day; vendor lower limit wins |
| Native voice | current gated Gemini Live profile | FREE_TIER, no | free pricing row; actual session concurrency/rate account-dependent | none assumed | preview not a trial claim | no billing activation default; verify account | gated default;2grants/user/day×180s admission; no paid auto-fallback |
| Turn STT | Groq Whisper-large-v3-turbo | FREE_TIER, no | base20RPM/2K RPD;7.2K audio sec/hour,28.8K/day;25MB free upload | none | none relied upon | UNVERIFIED from fetched docs | selected bounded15s clips; actual Limits page authoritative |
| Turn STT backup | Cloudflare Workers AI Whisper | FREE_TIER, no |10,000Neurons/day; platform Worker allowance separate100Krequests/day/10msCPU | none | none | no paid upgrade default; verify setup | selected optional backup; no unlimited minutes claim |
| Streaming STT/TTS optional | Deepgram | PROMOTIONAL_CREDIT, no | no monthly recurring free allowance asserted | none |$200signup credit, no expiration documented | no card documented | not baseline; disappears when consumed |
| Dedicated phoneme/fluency score | Azure Speech Pronunciation Assessment | PAID_ONLY for budget / F0 UNVERIFIED | F0 STT5h/month and neural TTS0.5Mchars; assessment F0 entitlement unconfirmed | Azure for Students allocation only if redeemed | credits do not imply forever-free scoring | student/card details UNVERIFIED for this account | gated; prosody add-on not enabled; score=null fallback |
| Google managed STT/TTS | Google Cloud Speech | FREE_TIER + PROMOTIONAL_CREDIT | STT listed V1standard60min/month; TTS Standard4M/WaveNet1Mchars; different SKUs differ | none assumed | new customer$300credit | billing required; card/eligibility verify | compared, unnecessary baseline; do not apply V1 allowance to arbitrary V2/model |
| Paid voice alternative | OpenAI gpt-realtime-2.1-mini | PAID_ONLY | no free API allowance established | ChatGPT subscription not API credit | no assumed promo | paid account funding | disabled; technical fallback only after funded authorization |
| Device fallback | installed TTS / bundled audio / recording | FREE_FOREVER software | hardware/voices supported locally | none | none | no | guaranteed bundled shadowing; OS dictation offline UNVERIFIED |
| Metrics/logs/traces | Grafana Cloud Free | FREE_TIER, no |10Kseries,50GBlogs/50GBtraces monthly,14daysretention | none | paid trial not selected | no card documented | selected minimal telemetry; local NDJSON fallback |
| Mobile crash reporting | Sentry Developer | FREE_TIER, no |1user; numeric error event quota UNVERIFIED from rendered columns | no Pack benefit assumed | team trial not selected | no paid upgrade enabled | optional selected; cap emitted events locally; no sharing paid account |
| UI research | Gummble MCP | PAID_ONLY or eligible TRIAL | no recurring free MCP allowance documented | UNVERIFIED | eligible trial current entitlement | OAuth entitlement; paid billing per account | access worked now; references/official design fallback; no runtime need |
| AI coding tools | existing Codex/Claude subscriptions | PAID_ONLY existing tooling | current user subscription ledger | no new API plan assumed | none | existing account | outside application operating cost; native subagents share quota |

Evidence links: [Appwrite](../research/RESEARCH_EVIDENCE.md#evidence-register), [AI vendor sources](../research/AI_EVIDENCE.md), [GitHub billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions), [Codemagic](https://docs.codemagic.io/billing/pricing/), [Grafana](https://grafana.com/products/cloud/free-tier/), [Sentry](https://sentry.io/pricing/), [Gummble](https://gummble.com/mcp).

Other selected local libraries/build/research verification software (Flutter packages, cryptography, Appwrite SDK, TypeScript/pnpm/Vitest/ESLint/Prettier, OpenAPI tooling/AJV/Redocly, Gitleaks and local TLS tooling) are FREE_FOREVER software without hosted meters. A library's license is checked/preserved when installed; software cost does not remove API usage charges. Exa/search/browser/Memory supplied in this agent session are existing development capabilities, no runtime dependency or new purchase; budget commercial research access as PAID_ONLY unless an actual FREE_TIER/TRIAL/PROMOTIONAL_CREDIT entitlement is verified. No unknown search entitlement is part of the0VND app operating claim. Claude/Codex subscriptions remain explicitly existing paid tooling.

## Bounded demo budget

Rehearsal cohort20accounts,10concurrent; course assets≤100MB;5lessons/account/day during a7-day demo;≤2native grants/account/day with full180s charged;≤600s recorded speech/account/day; text≤100/user/day but provider/project hard quota lower. These are project ceilings, not a promise that free vendor quota can serve every ceiling simultaneously.

Daily quota snapshot compares actual requests/read/write/transfer/compute/audio/tokens against provider allowances. At70% alert maintainer;85% disable nonessential AI/new downloads;95% reject new cloud AI sessions and serve cached/shadowing; no automatic paid-tier migration. Native issuer uses actual provider availability, not stale cost table.

Seven days before known Education expiry rehearse local3service adapter, content/profile/progress export and actual Free downgrade. Keep one database/bucket from day one. A laptop demo is dependent on host uptime/network; it is not a free public production host. Existing subscriptions/hardware are sunk resources, not priced at0VND.

If no cloud AI is available, app still teaches with authored lessons, cached listening, typed feedback, record/replay and deterministic review. Native realtime and dedicated scored pronunciation have truthful disabled states. Full paid-grade speech quality plus unlimited cloud traffic cannot be guaranteed at0VND; architecture preserves learning when allocations end.
