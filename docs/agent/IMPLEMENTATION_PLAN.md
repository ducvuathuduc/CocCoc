# CocEnglish Implementation Plan

Goal: implement the frozen Flutter language platform in small verified tasks.
Architecture: Riverpod MVVM mobile; Learning/Progress/AI services; Appwrite platform; offline journal and transactional events.
Tech stack: [STACK](../architecture/STACK.md). Spec: [SRS](../product/SRS.md), [OpenAPI](../api/openapi.yaml).
Worker method: native thin slices with meaningful behavior tests; an isolated reviewer when context split helps. No application implementation performed in Phase0.

2026-10-09–10 [authorized refresh](RESEARCH_REFRESH_PLAN.md): actual audit, current vendor evidence and local TypeScript foundation supplement P1. Separate service artifacts, generated wire types, fake async tests and schema dry-run are available. Account/runtime/permissions/transactions, full schema/curriculum, native voice and device/iOS receipts remain required; no full phase advances from this refresh.

Current user-authorized task, 2026-10-04: [FRONTEND_FLOW_PLAN](FRONTEND_FLOW_PLAN.md). Flutter scaffold, onboarding/login and the remaining planned learning/practice/progress/account UI families are implemented as a mock frontend baseline. [Checks/artifacts](../design/qa/FULL_FRONTEND_REPORT.md) are recorded separately; exact fidelity and full P1/P2/P3 gates remain pending. Original Duolingo appearance and mock data override prior asset adaptation for this slice without changing service boundaries or production identity rules.

Global constraints: Flutter Android/iOS; TypeScript/Node22; no provider keys in mobile; no live AI in deterministic CI; no paid/external release action without request; fixed contracts/owners; strict predecessor gates.

Review focus: uncertain commit/duplicate award; user cache/auth switch; timezone/late event; short credential expiry/ambiguous mint; native mic/PCM/audio-focus mismatch. Owning tasks below name acceptance cases.

## Phase gates

| Phase / goal | Inputs / dependencies | Parallel work / modules | Deliverables | Verification / acceptance | Exit gate / DoD |
|---|---|---|---|---|---|
| 0 Research & architecture | directive, official evidence | isolated speech evidence/review | canonical docs, OpenAPI, ADRs, agent guidance, tree, tasks | document/schema/coverage/ownership/link checks; adversarial consistency review | specification ready; account/device facts explicitly gated |
| 1 Repository/toolchain | P0 gate | apps/mobile vs services after workspace contract | Git/local scaffold, pinned locks,3handlers/adapters, config/schema scripts, CI | Flutter analyze/unit/buildAndroid+macOS simulator; fake service smoke; transaction/runtime/permission probe in admitted test env | toolchain reproducible; account resources/expiry recorded; no undefined runtime |
| 2 Design system/full UX | P1 | token owner then disjoint screen families |42routes/states,12exercise fixtures, fake repositories, mock audio/native | screenshots narrow/wide/text2, semantics, router guards, visual references | full UI demo without backend; no undefined button/action |
| 3 Auth/profile | P2 | Appwrite auth Flutter vs Progress profile | session/route state, email/OAuth/verify/recovery/logout/delete groundwork | authcancel/expiry/user-switch/private permission/tombstone tests | real account path to enrolled-ready shell, keys absent |
| 4 Course/path | P3 | Learning content vs mobile path | seed2sections6units24nodes48lessons, placement/enroll/guide | content schema/hash/alternative/index probes, placement and monotonic frontier | real immutable content path, offline read of unit |
| 5 Lesson engine | P4 | grading/server vs typed Flutter renderer |10original flow,12types, sessions/receipts/outbox, offline journal | duplicate/stale/concurrent/kill/sync/uncertaincommit tests | complete lesson frontier exactly once; rewards may still mocked pending |
| 6 Progress/review/gamification | P5 | Progress inbox/rewards vs Learning review vs UI |XP/streak/freeze/achievements/review + reminder hook | ledger totals/late/midnight/DST/caps/freeze/duplicate tests | reward lag/convergence; ordinary cached learning works |
| 7 Listening | P6 | author audio assets vs playback adapter |normal/slow cachedaudio, focus/skip/poor-network | asset hash/replay/offline and device playback | no live TTS dependency for ordinary listening |
| 8 AI/speech | P7 | issuer/reservations vs assessor/turn vs native bridge |provider adapters, nullable scores, normalized lifecycle, fallbacks | fixture evals plus actual account/audio/expiry/concurrency probe | baseline TURN/shadowing passes; native/scored capability only after evidence |
| 9 Social/quests/league | P8 | backend projections vs Flutter screens |follow/profile/feed, daily/monthly/friend quests, cohort league |private visibility/claim/rank/order/watermark/settlement tests | no duplicate wallet change or premature tier update |
| 10 Reliability/offline/perf | P9 | fault tests vs perf/ops |quota caps, observability, cache tuning, restore/local fallback | NFR device traces/k6 admitted loads/failure drills; measured outcomes | demonstrated limits documented; no invented10Kfree capacity |
| 11 Full QA/artifacts | P10 | Android and macOS at same candidate |releaseAPK, simulatorapp, optional signedIPA, checksums/runbook/demo script |regression, physicalAndroid, iOSsimulator, optionalphysicaliOS, backup/rollback/0spend | all release gate evidence; publishing remains separate authorization |

## Task IDs and concrete ownership

Each task uses checklist: [ ] claim dependencies/paths; [ ] write failing acceptance case for behavior; [ ] implement within contract; [ ] run specified targeted command; [ ] record artifact/evidence and DONE. P1 commands establish the package scripts defined in CI_CD. Later tasks cannot invent those scripts or models.

| Task | Files/modules / interface consumed → produced | Acceptance cases / verify | Parallel/depends |
|---|---|---|---|
| P1-FOUND-001 | existing root package.json,pnpm-workspace.yaml,infrastructure/toolchain.json,.gitignore; existing apps/mobile and pubspec/locks | retain Flutter3.47.0/Dart3.13.0 and finished UI/identifiers; do not regenerate app; verify actual Node22, Android build/device and iOS simulator; baseline schema fixture lint | EXCLUSIVE_CHANGE_AREA root/locks; BLOCKS P1others |
| P1-FOUND-002 | existing services/{learning,progress,ai}/src/index.ts and services/shared/src/{transport,verify-jwt}.ts; add owner-local cloud persistence adapters | preserve separate health bundles; verify per-request JWT and context mapping; Node22 runtime/transaction/conflict/permission probes in admitted account; replace disabled adapters only after gate | DEPENDS_ON001; backend area |
| P1-CONTRACT-001 | existing packages/api_contracts/generated.ts and tools/blueprint/validate-schemas.mjs; planned apps/mobile/lib/core/api/generated | retain OpenAPI-derived TS wire types; add schema-mapped Dart DTO round-trips; malformed/wrong unions rejected; generation idempotent | EXCLUSIVE_CHANGE_AREA API/generated |
| P1-OPS-001 | existing appwrite/schema/foundation.json,appwrite/scripts/{schema,seed}.mjs,.github/workflows/*.yml; admitted deploy tooling added later | extend four-table dry-run to full37-table schema and curriculum; scope/index/row-security/scheduler-spoof probe; actual quotas/expiry; real deterministic CI receipt and macOS simulator | DEPENDS_ON001/002; infra exclusive |
| P2-DES-001 | existing apps/mobile/lib/core/design/* and fixture gallery | preserve tokens/components/motion; close semantics, CHECKdisabled/reducedmotion/text2 and golden gaps | BLOCKS P2screens; design system exclusive |
| P2-FE-001 | existing apps/mobile/lib/features/{onboarding,auth,learning}; existing apps/mobile/lib/main.dart router | SC01–22 and12exercise typedfake flows; close state/guard/exit/feedback gaps without screen rewrite | SAFE_PARALLEL with002; router oneowner |
| P2-FE-002 | existing apps/mobile/lib/features/{practice,progress,account}; map speech/social/settings through current nested screens | SC23–42 allstates incl unscored/empty/offline; close gaps from screen behavior audit; visual reference log | SAFE_PARALLEL with001; DEPENDS_ON DES001 |
| P2-QA-001 | test/goldens,test/widgets; docs/design reference deltas |42screen fixtures narrow/wide/text2+light/dark; accessible failures; no genericdashboard | DEPENDS_ON FE001/002 |
| P3-AUTH-001 | features/auth/data,auth_repository.dart,auth_controller.dart; Appwrite Account | restore/expiry/OAuthcancel/recovery/logout/usercache isolation; fluttertest/integration | SAFE_PARALLEL with002 at lockedProfile |
| P3-AUTH-002 | services/progress/src/profile/*; p_profiles/p_zone_history/p_deletions | initializeProfile/updateMe/deleteAccount; tombstone/no crossuser; pnpmtest:unit/contract/integration | profile owner |
| P3-QA-001 | integration_test/auth_flow_test.dart; backend authnegativefixtures | forgeduserheader/revocation/SDKpersistence/privacy; routeguards | DEPENDS_ON AUTH001/002 |
| P4-LEARN-001 | services/learning/src/content/*, content/vi_en/*; publishing | course/manifest/assets; alltypesalternatives/hash; seed/publish dryrun | SAFE_PARALLEL withFE001 fixtures |
| P4-LEARN-002 | services/learning/src/enrollment/*; l_enrollments | enrollCourse/startPlacement/getPath; score7/8boundary, repeatnoXP | DEPENDS_ON LEARN001 |
| P4-FE-001 | features/learning_path/data; bundle/cache repository | API+cache→Pathmodel; currentnode/guide/retiredversion | SAFE_PARALLEL contractbound |
| P5-LESSON-001 | features/lesson/domain/{reducer,answer}.dart; services/learning/src/grading/* | same authored golden answer cases NFC/repeatedtoken/diacritics;12types | graders different languages same testfixture |
| P5-LESSON-002 | services/learning/src/sessions/*; l_sessions/l_active_slots/l_answers/receipts | submitAnswer/complete/abandon; duplicate+bodyconflict+two devices+uncertaincommit | DEPENDS_ON001 |
| P5-LESSON-003 | services/learning/src/events/*; outbox/inbox transport | commit+outbox; crash before/after ack; fakeconsumerdedupe; signedwatermark | DEPENDS_ON002 |
| P5-FE-001 | features/lesson/{presentation,data}; core/cache/journal.dart | typed renderer→submitAnswer; inputretention/exit; Drift crash/replay; offline regrade | SAFE_PARALLEL server at lockedAnswer |
| P5-QA-001 | integration lesson/offline tests | repeatedrequest no doublefrontier; corrupt/stalebundle/rejection; appkill lastanswer | DEPENDS_ON002/003/FE001 |
| P6-GAME-001 | services/progress/src/rewards/*; inbox/ledger/day/zone | consumeEvent/getRewards; first/replay/cap/late/order/UTCzone/tzmidnight | BLOCKS GAME002 |
| P6-GAME-002 | progress/src/{streak,wallet,achievement}/* | freezeconsume once, no late refund;365historycap; milestoneunique | DEPENDS_ON001 |
| P6-REVIEW-001 | learning/src/review/*; l_review_items/privatebundle | due stage intervals/reset/assisted;20poolmax/64KBsnapshot | SAFE_PARALLEL acrossowner |
| P6-FE-001 | features/{practice,profile,lesson}/data+results; reminderadapter | pending→credited/capped; no viewaward; localOSreminderno duplicate | DEPENDS_ON GAMEcontracts |
| P7-AUDIO-001 | content/audio, tools/content/*; audio manifest | normal/slow keys no duplicate generation; no cloudquota inCI | SAFE_PARALLEL with002 |
| P7-AUDIO-002 | core/audio, features/listening/* | cached playback/focus/route/skip; physicalAndroid audio | DEPENDS_ON assets/lockedadapter |
| P8-AI-001 | services/ai/src/{capabilities,live,reservations}/* | active slots, v1beta constrainedtoken, expireactiveconnection, ambiguousmint no remint/refund | EXCLUSIVE_CHANGE_AREA capabilityconfig |
| P8-AI-002 | ai/src/{adapters,assessment,tutor,turn}/*; privateaudio | Groq/Gemini/Azurenullable providercontracts; scoreState,timeout/fallback | SAFE_PARALLEL with001 afteradaptertypes |
| P8-FE-001 | speaking/domain/session_controller.dart,data/gemini_transport.dart; Android/iOSpcm bridge |16kinput/24koutput,VAD,queuebarge-in/disposal; Kotlin/Swiftbridge limitedI/O | SAFE_PARALLEL backend |
| P8-QA-001 | AI eval fixtures, integrationaudio, evidence/live | actualmodel/accountquota/tokenconstraints; Bluetooth/phone/silence; native disabled until pass | DEPENDS_ON AI001/002/FE001 |
| P9-SOCIAL-001 | progress/src/{social,quests}/* | publicoptin/follow/private, claimdoubleclick, friendmembership | SAFE_PARALLEL FE001 |
| P9-LEAGUE-001 | progress/src/leagues/*; watermarkconsumer | stableties/30cohort/topbottom5/smallcohort/lateweeksettling | DEPENDS_ON rewardledger+watermark |
| P9-FE-001 | social/quests/league repositories/screens | real lists/asOf/pendingclaim/unavailableprofiles | SAFE_PARALLEL contracts |
| P10-REL-001 | journal/transactions/events fault suites | outage/partialsync/kill/reorder recovery, ledger sum, cache namespace | existingdesign; exclusivecore edits |
| P10-PERF-001 | tools/load/*.js, performance integration traces | admitted100users/local1000/10000model; frame/RSS/latency/cache budgets | SAFE_PARALLEL ops |
| P10-OPS-001 | telemetryexporters, runbook evidence, local supervisor | quota breakers/boundedexport/restore/expiryLANfallback; no publicdemo | SAFE_PARALLEL testareas |
| P11-QA-001 | full regressions, release gate report | allP0/P1tests, device capability matrix, unresolved limits explicit | DEPENDS_ON P10 |
| P11-REL-001 | .github/workflows/release*, artifactmanifest | releaseAPK + simulatorappchecksums; optionalIPAonly existingteam | SAFE_PARALLEL builds at onecandidate |
| P11-DEMO-001 | demo rehearsal script/report |20usercohort/airplanemode/rewards/speechfallback/0newspend/rollback | DEPENDS_ON releaseartifacts |

## First task handoff: P1-FOUND-001

Inputs: exact STACK baseline and actual inventory; OpenAPI commit/hash; current AGENTS. Reuse the existing Git repository and Flutter app; do not run flutter create or overwrite finished screens. Only an absent checkout/module may be generated with Android/iOS platforms and projectName cocenglish. Dart SDK stays bundled3.13 baseline; preserve current mobile lock and resolve only assigned missing dependencies; no P8heavy packages. Root pnpm workspace includes services/* and packages/* only. Toolchain manifest records actual SDK/Node/JDK and generated Gradle/AGP/Kotlin; cloud/macOS build evidence remains distinct.

Acceptance fixture: launch FakeAuthRepository as signedOut → welcome; override verifiedprofile+enrollment → pathplaceholder fixture; offlinecacheduser → cacheOnly; no admin/provider credentials. Initial unit test verifies router guard completes each state without looping. First negative test is auth state router undefined; build minimal shell until tests pass. Commands from apps/mobile: flutter pub get, dart format --output=none --set-exit-if-changed lib test, flutter analyze --fatal-infos, flutter test, flutter build apk --debug. Record outputs; Mac build follows P1-OPS-001. Do not implement real lessons/auth/backend in this foundation task.
