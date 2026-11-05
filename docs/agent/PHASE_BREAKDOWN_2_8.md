# Phase breakdown 2–8 — from inventory to "add keys and it runs"

**Status:** plan, 2026-10-25. Input: [real-features inventory](REAL_FEATURES_INVENTORY_20261025.md) (Phase 1). Keys and config: [KEYS_AND_CONFIG_CHECKLIST](../devops/KEYS_AND_CONFIG_CHECKLIST.md). This maps the owner's roadmap phases 2–8 onto the approved waves of the [setup plan](REAL_FEATURES_SETUP_PLAN_20261025.md) and the task IDs of the [IMPLEMENTATION_PLAN](IMPLEMENTATION_PLAN.md); it does not replace either and does not advance any global phase gate. Every task follows [TASK_PROTOCOL](TASK_PROTOCOL.md): failing test first → implementation → targeted checks → gates. Real-money payments stay out of scope.

| Owner phase | Setup-plan wave | IMPLEMENTATION_PLAN tasks |
|---|---|---|
| 2 Auth/Profile | W2 | P3-AUTH-001/002, P3-QA-001 |
| 3 Real learning loop | W3 (content/lesson) | P4-LEARN-001..003, P4-FE-001, P5-*, P6-REVIEW-* |
| 4 Offline + economy | W3 (offline) + W4 | P5-FE-001, P5-QA-001, P6-GAME-*, P10-PROMO-001 |
| 5 RabbitMQ/Redis | W1 follow-up | ADR-0018, P10-REL-001 |
| 6 Social + practice modes | W5 + P7-PRACTICE-001 | P9-*, P7-PRACTICE-001 |
| 7 Real AI/providers | W6 | P7-AUDIO-*, P8-* |
| 8 Android acceptance + release | W7 + W8 | P10-OPS-001, P11-QA-001 |

## Exclusive change areas

From [AGENTS.md](../../AGENTS.md): **OpenAPI** (+ generated TS/Dart DTOs), **root router** (`apps/mobile/lib/main.dart`), **lockfiles** (`pnpm-lock.yaml`, `pubspec.lock`), **Appwrite schema/migrations** (DATA_MODEL/PERMISSIONS → `appwrite/schema/foundation.json`), **`services/shared` interfaces**. This plan also treats `appwrite/ops/project.json` + `appwrite/scripts/ops-lib.mjs` as single-owner, because every phase that adds a variable or secret edits them. Tags below: `[OPENAPI]`, `[ROUTER]`, `[LOCK]`, `[SCHEMA]`, `[SHARED]`, `[OPS]`.

Proof columns: **offline** = provable in CI/sandbox with no keys (unit, contract, fake transport, `pnpm dev:services`, emulator without cloud); **keys** = needs the TEST project/provider keys; **device** = needs a physical Android phone.

---

## Phase 2 — Auth / Profile

Goal: two real accounts sign up, verify, recover, link Google, edit profile/avatar, switch A↔B and delete, with no cross-account leakage.

| # | Task (dependency order) | Files / areas | Tests to write first |
|---|---|---|---|
| 2.0 | **Setup wiring** (prerequisite for all live acceptance in every phase). Declare `COC_PROGRESS_ADMITTED`, `COC_MAINTAINER_USER_IDS`; let `appwrite:apply` generate a Progress secret `COC_PROGRESS_CODE_SECRET` like the HMAC keyring; allow-list (still disabled) `COC_GEMINI_API_KEY`; add `APPWRITE_RECOVERY_URL`/`APPWRITE_VERIFICATION_URL` to `config/real.public.json`; add `pnpm setup:real` (one command, see checklist) and fix the M004 doc drift | `[OPS]` `appwrite/ops/project.json`, `appwrite/scripts/ops-lib.mjs`, `ops.mjs`, new `tools/scripts/setup-real.mjs`, root `package.json` (scripts only, no deps), `apps/mobile/config/real.public.json`, `docs/data/MIGRATIONS.md`, `docs/devops/APPWRITE_SETUP.md` | `appwrite/test/ops.test.mjs`: Progress admitted flag required when persistence=appwrite; code secret generated, never printed; Gemini key allow-listed but `COC_GEMINI_ENABLED` still forced false. `setup-real --dry-run` test: refuses missing keys, prints plan only |
| 2.1 | **Contract batch A** — C2 profile identity fields, C3 avatar config, C4 linked-identity projection, C1 phone challenge *or* explicit "unavailable" decision. Do C5–C7 (Phases 3/4) in the **same PR** to use the OpenAPI/schema lock once | `[OPENAPI]` `docs/api/openapi.yaml`, generated DTOs; `[SCHEMA]` DATA_MODEL/PERMISSIONS → `foundation.json` (M005: `p_profiles` avatar config + profile fields) | schema fixtures (`packages/api_contracts/fixtures`), `schema:test` for M005, `contracts:check`, `api:lint` |
| 2.2 | Progress profile backend for new fields; revision conflict; public/private projection excludes email/phone | `services/progress/src/application/profile.ts`, `http/routes.ts`, persistence port | node tests: other-user JWT rejected, stale revision → 409, private fields never in public projection |
| 2.3 | Mobile auth: recovery deep link → `/reset-password`, verification link, Google OAuth enable/cancel, session expiry; account linking on `/settings/social` via Appwrite identities | `features/auth/*`, `features/account/*` (`SocialAccountsScreen`), Android manifest intent filters (no router change needed: routes exist) | widget/unit: cancelled OAuth leaves signed-out state; link failure shows existing error state; recovery with bad secret rejected |
| 2.4 | Mobile profile: `/settings/profile` new fields, `/settings/avatar` persists config, standalone profile tab drops `profileMockNew/Rich`, onboarding goal saved via `updateMe`; move authored copy out of `MockLegalRepository`/`MockOnboardingContentRepository` | `features/account/*`, `features/progress/application/profile_*`, `features/onboarding/*`, `features/legal/*` | `real_runtime_composition_test.dart` extensions: no mock class reachable in API mode for these providers; late A response never renders under B |
| 2.5 | Deletion: purge job + local purge + sign-out; A→B switch suite | `services/progress/src/application/jobs.ts`, `features/account/*` | deletion receipt only after server receipt; local journal/cache for A gone |

Acceptance — **offline:** all tests above; `pnpm backend:verify`, `contracts:check`, `schema:plan/test`, scoped Flutter tests; `setup:real --dry-run`. **Keys:** two accounts on TEST (sign-up, OTP mail delivery, recovery mail, Google OAuth, delete + purge); `appwrite:probe-functions` passes with Progress admitted. **Device:** OAuth and recovery app link open the installed app.

## Phase 3 — Real learning loop

Goal: login → placement/enrollment → all 12 exercise types → complete → progress saved → reward exactly once, with published signed content and media.

| # | Task | Files / areas | Tests |
|---|---|---|---|
| 3.1 | (In contract batch A) C5 session modes: unit test-out/skip, section checkpoint, STORY, ADVENTURE, RADIO, SIDE_QUEST, CLASH, UNIT_REVIEW, rapid; C6 app issue report | `[OPENAPI]` `SessionRequest.mode`, report schemas; `[SCHEMA]` only if new columns | contract fixtures |
| 3.2 | Content: production Ed25519 signing key (outside Git), `tools/content/build-course.mjs` with `COC_CONTENT_SIGNING_SEED_HEX/KEY_ID`, `publish-appwrite.mjs` dry-run, set `COC_CONTENT_PUBLIC_KEYS` to the production public key; media upload to `learning-assets` | `tools/content/*`, `content/vi_en/*`, `[OPS]` variable value | `verify-media.test.mjs`, lint-course; signature mismatch rejected by Learning |
| 3.3 | Learning backend: checkpoint/test-out modes, `abandonSession`, switch/reset/remove keep one active enrollment, Legendary/score projection (P4-LEARN-003) | `services/learning/src/application/*`, `http/wiring.ts` | node tests: score 7/8 boundary, repeat gives no XP, switch keeps one active row, abandon releases slot |
| 3.4 | Mobile: call `abandonSession` on quit; course management (`/courses`, `/settings/courses`) callers; `/units/:id/skip` and `/sections/:s/check` use the new modes instead of `CourseUnavailableScreen`; report sheet → `createReport`; `/score` projection | `features/learning/*`, `features/progress/presentation/*` (courses/score files only), `features/report/*` | widget tests per screen; duplicate tap sends one idempotency key |
| 3.5 | End-to-end local loop: `pnpm dev:services` + fake JWT (`COC_DEV_AUTH=1`) drives enroll → 12 types → complete twice → one ledger entry via signed Learning→Progress event | `tools/scripts/` new smoke (no `services/shared` change) | new `learning-loop-smoke` asserting ledger equality and one reward |

Acceptance — **offline:** 3.3/3.4/3.5 tests, grading fixtures for all 12 types, `seed:check`, content lint. **Keys:** M004 applied, content published to TEST, a real account completes one lesson of each type and sees one reward. **Device:** audio playback of lesson media.

## Phase 4 — Offline + economy

Goal: kill the app mid-lesson / offline, recover, sync answers once; shop, quests, promo, streak, entitlement all server-side.

| # | Task | Files / areas | Tests |
|---|---|---|---|
| 4.1 | (In contract batch A) C7 free shop offers — or remove the tiles from the real path | `[OPENAPI]` | fixtures |
| 4.2 | Economy wiring: `repairStreak` caller (replace `MockStreakRepairRepository`), TIMER_BOOST and ENERGY_REFILL via `buyItem`/`activateBoost`, streak calendar from server, `super_trial`/`super_features` read `getEntitlement`, hearts screen removed from real path or bound to `getEnergy` | `features/{streak_repair,xp_boost,super_trial,super_features,hearts,shop}/*`, `features/progress/application/{streak,timer_boost}_controller.dart` | no gem change on failed claim; retry reuses key; real build cannot reach these Mock classes |
| 4.3 | Promo: needs **M003 applied**; maintainer code-creation CLI | `services/progress/src/admin/*`, `features/promo/*` | redeem twice → one grant; wrong code rate-limited |
| 4.4 | Offline: Android emulator test kills the process mid-lesson, restarts against `dev:services`, replays journal once; rejected answers retained | `apps/mobile/integration_test/*`, `core/cache/*` | integration test on emulator (no cloud) |
| 4.5 | Streak rollover/timezone/DST, quest period roll, entitlement expiry worker | `services/progress/src/application/{economy,jobs}.ts` | midnight/DST fixtures; 100 duplicate/reorder trials stay green |

Acceptance — **offline:** all above, including emulator kill test with local services. **Keys:** M003 applied; promo code redeemed on TEST; process-kill against TEST services; scheduler ticks on TEST. **Device:** optional repeat of kill test on a phone.

## Phase 5 — RabbitMQ / Redis (ADR-0018)

Goal: events never lost and rewards never doubled across broker crash/retry; Redis cache with correct invalidation; direct relay stays as rollback.

| # | Task | Files / areas | Tests |
|---|---|---|---|
| 5.1 | Contract batch B — C8 application receipt endpoint, per-target ack storage (M006), AMQP envelope + key rotation; update [EVENTS_ERRORS](../api/EVENTS_ERRORS.md) | `[OPENAPI]` `[SCHEMA]` | fixtures, schema tests |
| 5.2 | Ports: `EventTransport` and `ReadCache` interfaces | `[SHARED]` `services/shared/src/ports.ts` | interface tests; hosted bundles still contain no mock code |
| 5.3 | AMQP adapter: publisher confirms, quorum queues, DLX, delivery limit, consumer ack only after receipt | `services/*/src/runtime/worker.ts`, new adapters; `[LOCK]` AMQP client dependency | ADR fault matrix (crash before/after commit, confirm, receipt, ack; unroutable; >300 s delay; two-target fan-out) |
| 5.4 | Redis adapter: cache-aside for public catalog/manifest/path; namespaced by env/user/schema/revision; invalidate on publish/revision; private snapshots bypass by default | Learning/Progress runtime; `[LOCK]` Redis client | stale-cache, cross-account, Redis-down fallback tests |
| 5.5 | Compose: RabbitMQ + Redis pinned by digest, private network, health gating; `container:check` extension | `infra/docker/*` | container fault tests (Docker available on GitHub runners) |
| 5.6 | Cutover/rollback runbook: one route at a time, drain, restore direct dispatch | `docs/devops/OPERATIONS.md` | rehearsal in Compose |

Acceptance — **offline:** everything in Compose on a CI runner (no cloud keys). **Keys:** VPS/host, broker and Redis credentials, TEST Appwrite for the durable side. **Device:** none.

## Phase 6 — Social + practice modes

| # | Task | Files / areas | Tests |
|---|---|---|---|
| 6.1 | Social callers: `listActivity`, `followUser`, `unfollowUser`, `getPublicProfile`, `reportUser`, `joinLeague`, `optInFriendQuest`, `leaveClassroom`; remove fixtures from `league_ranking_provider`, `league_result_controller`, `social_controller`, `profile_lists_controller`, `profile_achievements_provider`, `profile_actions_controller` | `features/progress/*`, `features/profile/*`, `features/account/*` (schools) | block hides both directions; CHILD age band rejects social writes; pagination |
| 6.2 | Family/referral/year review/gift: `createFamily`, `joinFamily`, `removeFamilyMember`, `getReferral`, `redeemReferral`, `getYearReview`; gift = non-monetary decision | same + `features/gift/*` | membership limits, duplicate redeem, code hash never returned |
| 6.3 | League settlement on TEST via signed `/internal/jobs/league-settlement` after Learning watermark = 0 | `services/progress/src/application/leagues.ts` | settlement waits for watermark; one result per week |
| 6.4 | Practice modes (uses C5): Stories, Adventure, Radio, Side quests, Clash, Unit review, Rapid via new session modes + `listActivityProgress` | `services/learning/src/application/*`, `features/practice/*` (`journey_repository`, `stories_repository`) | progress counted once; stars/best score monotonic |

Acceptance — **offline:** backend privacy tests, widget tests, fake-transport two-account tests. **Keys:** two real accounts follow/block/report; one settled week on TEST. **Device:** none required.

## Phase 7 — Real AI / providers

| # | Task | Files / areas | Tests |
|---|---|---|---|
| 7.1 | Contract batch C — C9 Gemini text capability, capability provenance/quota fields | `[OPENAPI]`; capability config (P8-AI-001 exclusive) | fixtures |
| 7.2 | Gemini adapter (text explanations + roleplay generation) behind `COC_GEMINI_ENABLED` with budget; key `COC_GEMINI_API_KEY` | `services/ai/src/application/*`, `[OPS]` lift the forced-false rule only with an approved budget | fake HTTP provider: timeout, 429, malformed output, quota exhaustion → authored fallback |
| 7.3 | Speech: Azure pronunciation + STT fallback; `getAssessment` polling, `heartbeatVoiceSession`, `getCapabilities` callers; cancel/timeout/quota | `services/ai/src/application/speech.ts`, `features/{call,practice,learning}/*` speaking files | scores null when unassessed; cancel releases slot; daily seconds cap |
| 7.4 | Recording UX: permission denied, interruption, Bluetooth route | `core/audio/*`, `features/call/*` | widget + platform-channel fakes |

Acceptance — **offline:** fake-provider tests, quota/timeout tests. **Keys:** Azure Speech key/region, Gemini key, budget. **Device:** real microphone recordings, Bluetooth/interruption.

## Phase 8 — Android acceptance + release

| # | Task | Files / areas | Tests |
|---|---|---|---|
| 8.1 | Device matrix: reminders/notifications, streak widget, audio focus, lesson-activity resume, launcher icon aliases (native bridge for `app_icon`) | Android platform files, `features/{app_icon,reminders}/*` | instrumented tests on emulator; manual device checklist |
| 8.2 | CI: make backend/contracts/schema/mobile jobs required (branch protection), pin actions by SHA, signed release APK from a keystore secret | `.github/workflows/*` (coordinate with the CI/golden streams) | workflow dry runs |
| 8.3 | Backup/restore + rollback: encrypted export of content/profile/ledgers, restore rehearsal, redeploy previous bundle | `docs/devops/OPERATIONS.md`, `tools/scripts/*` | restore into a scratch project |

Acceptance — **offline:** emulator instrumented tests, CI green. **Keys:** release keystore, GitHub environment secrets, backup storage. **Device:** physical Android for notifications/widget/audio/performance.

---

## Parallelism

| Area | Touched by |
|---|---|
| `[OPENAPI]` | 2.1 (batch A incl. 3.1, 4.1), 5.1 (batch B), 7.1 (batch C) |
| `[SCHEMA]` | 2.1 (M005), 5.1 (M006) |
| `[SHARED]` | 5.2 only |
| `[LOCK]` | 5.3, 5.4 (7.2 if an SDK is chosen — prefer plain `fetch`) |
| `[ROUTER]` | none planned (all routes exist); any new route goes through one owner |
| `[OPS]` | 2.0 (pre-declares everything later phases need), 7.2 (budget flip) |

Recommended order:

1. **2.0 setup wiring** and **contract batch A** first, sequentially (both are single-owner areas). They unblock everything else.
2. Then run **Phase 2, Phase 3 and Phase 4** in parallel: they live in disjoint feature folders and service modules (auth/account/profile ↔ learning/practice-lesson/report ↔ shop/streak/promo/boost/journal) against the same contract revision. Watch the two shared files: `features/progress/presentation/*` (Phase 3 courses/score vs Phase 4 streak) — split by file.
3. **Phase 5** can run in parallel with 2–4 from the start: it touches `services/shared`, runtimes, `infra/docker` and the lockfile, none of which 2–4 need. Its contract batch B must wait until batch A is merged.
4. **Phase 7** can run in parallel with 2–6 (`services/ai`, `features/call`, `roleplay`, speaking files); its batch C waits for batch A/B.
5. **Phase 6** code can start after batch A, but its live acceptance needs Phase 2 identities and Phase 4 ledger; practice modes need 3.1.
6. **Phase 8** device work last; 8.2/8.3 can start any time once the current CI/golden streams have landed (they own `.github/workflows` now).

Never run two Flutter test/build commands in the same checkout at once (see [setup plan §4](REAL_FEATURES_SETUP_PLAN_20261025.md)).
