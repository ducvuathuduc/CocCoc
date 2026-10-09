# Evidence-based readiness gate

This gate prevents document checks, mocks and compile artifacts from becoming production/device claims. Targets in [NFR](../architecture/NFR.md) are design targets until measured. [Traceability](TRACEABILITY.md) maps FR/NFR to screen/API/table/event/test tasks; [behavior map](../product/SCREEN_BEHAVIOR_MAP.md) distinguishes actual source controls from future authority.

| Evidence | Required command / receipt | Current capability boundary |
|---|---|---|
| Documentation integrity | blueprint + audit validator, internal links, JSON/YAML/Mermaid parsing | structural consistency only |
| Contracts | AJV positive/negative fixtures, Redocly, reproducible generated type hash | no cloud protocol/permissions implied |
| Backend | strict TS/lint/format; per-owner tests/artifact builds; fake async smoke | local in-memory fixture; business routes fail closed |
| Mobile | Dart format, analyzer, all Flutter tests, web/debug APK build | mocks; no physical-device performance/audio or real auth proof |
| Cloud authority | admitted auth/permission/runtime/schema/transaction/async deployment probes | NOT RUN without test project authorization/access |
| Native voice/pronunciation | actual account/token misuse/PCM/interruption/cancel/locale/quality tests | PENDING BENCHMARK; nullable unassessed scores |
| iOS | actual macOS simulator compile/tests then optional signed device | no local Windows Xcode; CI file is not CI receipt |
| Billing | sandbox vendor state/RTDN/restore/refund/entitlement tests | design/fake only; live purchase account absent |
| Reliability/cost | measured device traces/load/restore/expiry/failure drills | no 0 VND guarantee or capacity claim |

Architecture freeze may be conditional for gated optional capabilities; required coursework realtime/cloud proof must pass before final coursework completion. If rubric demands a topology different from three Functions, architecture approval remains blocked until its actual page/line is supplied. Do not lower an assignment gate simply because mocks work.

Rollback retains previous immutable service artifact and compatible schema/read path; deploy old revision then run ownership/duplicate/smoke checks. Additive schema changes remain until reviewed cleanup. No destructive migration, production publish, merge or force-push is authorized by the research request.
