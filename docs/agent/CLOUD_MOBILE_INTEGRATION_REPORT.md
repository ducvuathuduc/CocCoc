# CocEnglish — Cloud & Mobile Integration & Release Validation

**Date:** 2026-11-09
**Scope:** Verify CMS → Appwrite → Learning API → Flutter Mobile works correctly, consistently and safely under realistic operation.
**Hard constraints honored:** no production deploy, no writes to the shared TEST project, no secret changes, no new feature phase opened. Safe checks completable in this environment were run; everything blocked by staging / Flutter SDK / browser access is marked **BLOCKED** and not self-declared as PASS.

---

## Section 1 — Flutter cache & version consistency audit

Audit of `apps/mobile`: API client + generated contracts, Learning/Practice/Path repositories, `SnapshotCache`, `ActiveCourse`, manifest/bundle version handling, local persistence/offline.

| # | Question | Finding | Evidence |
|---|----------|---------|----------|
| a | Does cached data depend on `courseId`/`version`? | No. `SnapshotCache` is keyed per **user-namespace + feature** (`snapshot.v1.$namespace.$key`), not per course/version. Cached features are cross-course progress/social (path, practice, progress, social, quests, achievements, notifications, roleplay) — none are course content. | `lib/core/cache/snapshot_cache.dart` |
| b | Can course A's content show while B is open? | No. `ActiveCourse` resolves the first `available` course from `GET /v1/courses` and caches it process-wide (`_resolved`). Content is fetched per-request with `courseId` in the URL/response. | `lib/core/api/client/active_course.dart` |
| c | Can a v2 bundle be served when the manifest is at v3? | No, by construction. `getManifest(courseId)` returns the **LIVE** manifest; `getCourseBundle`/`getBundle` resolve bundles *within that manifest*. A different version is only ever read via an explicit `version` pin (offline replay), never a mismatched pair. | `api_learning_repository.dart`, `api_endpoints.g.dart` |
| d | When admin rolls back, how does Mobile detect/handle? | The course pointer moves to the prior version; `listCourses` returns it as PUBLISHED and the next manifest fetch returns the rolled-back version. An **in-progress** session stays pinned to its original `lessonVersion`+`bundleHash`, so a rollback cannot swap a v2 bundle into a v3 session. | `api_learning_repository.dart` (`JournalSession`), `content.ts` `rollbackCourse` |
| e | Is an in-progress session pinned to a version? | Yes. `JournalSession` carries `lessonVersion`, `bundleHash` (manifest hash), `enrollmentRevision` and `session.revision`. Grade/complete/journal all reference the pinned bundle. | `api_learning_repository.dart`, `lesson_journal.dart` |
| f | On unpublish, what cache policy applies? | `listCourses` drops unpublished (`status != PUBLISHED`). `syncOfflineCompletion` blocks new distribution on unpublish (`NOT_FOUND`) and on retire (`CONTENT_VERSION_RETIRED`) while an in-flight journaled lesson still finishes locally and replays. `SnapshotCache` (progress/social) is unaffected by unpublish. | `content.ts:13`, `offline.ts`, `repository.ts:82,131` |

**Conclusion:** No collision risk is demonstrated. The recommendation to add `courseId`/`version` to `SnapshotCache` keys is **rejected as unnecessary** — content is never placed in `SnapshotCache`; it is fetched per-request and the session is version-pinned. **No code change to `SnapshotCache` is warranted.** Verdict: **PASS (analysis, no change)**.

---

## Section 2 — Flutter CI validation

`mobile.yml` static review (the only thing runnable here — no Flutter SDK on this machine, `which flutter/dart` → not found):

- **Flutter SDK**: pinned to `FLUTTER_VERSION: 3.47.0`, installed via `git clone --depth 1 --branch "3.47.0"` (reproducible, not a moving tag). ✔
- **Dependencies**: `flutter pub get --enforce-lockfile` (lockfile drift fails the build). ✔
- **Verification step**: `node tools/scripts/mobile-check.mjs` runs `dart format --set-exit-if-changed`, `flutter analyze --fatal-infos`, then `flutter test --dart-define=ENABLE_MASCOT_MOTION=false`. ⚠ See gap below.
- **Release build**: Android debug APK built with `--dart-define-from-file=config/real.public.json`, which sets `DATA_SOURCE=api`. iOS simulator build is `workflow_dispatch`-only (unsigned). ✔

**Critical gap (not a failure, a coverage limitation):** the CI `flutter test` step passes **only** `ENABLE_MASCOT_MOTION=false` and does **not** declare `DATA_SOURCE`. Per `lib/core/config/app_config.dart:58`, an undeclared `DATA_SOURCE` defaults to **`mock`**, and `test/core/config/data_source_declaration_test.dart` explicitly asserts that CI's test run is the undeclared case (`declaredDataSource == false`). Therefore **CI's unit/widget tests exercise the mock path, not the generated OpenAPI clients or `ApiLearningRepository`/`ApiPracticeContentRepository`/`ApiPathRepository` call sites.** The release *build* is API-mode, and `contracts:check` (162 schemas / 173 Dart classes, passed earlier) keeps Dart DTOs in sync with OpenAPI, but the API call sites are **not executed in CI**. The only runtime exercise of the API path is the manual integration test `integration_test/local_backend_offline_test.dart`, which requires an emulator + the three local dev services and is **not** part of `mobile.yml`. `android_completion_test.dart` uses mocked repositories (UI/screenshot only).

**Verdict:** Static pipeline **PASS**; actual build/analyze/test **BLOCKED** (no Flutter SDK in this environment — not self-declared PASS). **Recommendation:** add a CI job that runs `integration_test/local_backend_offline_test.dart` against `pnpm dev:services` on an Android emulator, or a mock-server unit test of the repositories, so the API path is regression-tested.

---

## Section 3 — Appwrite staging readiness

**Finding:** There is **no independent staging Appwrite project.** The only declared project is `6acc656d0025cc57bd81` (`coccoc-test`, endpoint `https://sgp.cloud.appwrite.io/v1`) and its `ops/project.json` ships the **dev content key** (`dev-content-1`) in `COC_CONTENT_PUBLIC_KEYS`. Per `appwrite/AGENTS.md` and the user's constraint, the shared TEST project must **not** be co-opted as staging.

Because no staging exists and I am not authorized to create one, I prepared a reproducible **checklist + sample config (no secrets) + deploy process** rather than applying anything.

**Staging checklist (reproducible, no secrets):**
1. Provision a dedicated staging project (new `projectId`/`projectName` e.g. `coccoc-staging`, separate from `6acc656d0025cc57bd81`). Keep endpoint/keys in environment, never in files.
2. Create a staging `ops/project.staging.json` mirroring `ops/project.json` but with: distinct `projectId`, staging function domains (`coccoc-staging-learning.sgp.appwrite.run` …), and **a real Ed25519 content key replacing `dev-content-1`** in `COC_CONTENT_PUBLIC_KEYS` (staging must verify manifests against its own key, not the dev key).
3. Generate the signing key via the content tooling; never reuse `dev-content-1` in staging/prod.
4. `COC_SERVICE_KEYS` (service-to-service HMAC) generated by `appwrite:apply`, stored only as a secret function variable — never committed.
5. Set `COC_LEARNING_ADMITTED`/`COC_AI_ADMITTED` to a reviewed **staging** gate value (not `reviewed-cloud-gate`).
6. Apply schema: `pnpm schema:plan && pnpm schema:test && pnpm seed:check`, then `pnpm schema:apply` (guarded by `ALLOW_SCHEMA_APPLY=reviewed-staging-project`).
7. Apply ops: `pnpm appwrite:plan && pnpm appwrite:test`, then `pnpm appwrite:apply` (`ALLOW_APPWRITE_APPLY=…`), `pnpm appwrite:deploy -- --service learning|progress|ai`, `pnpm appwrite:check-live`, `pnpm appwrite:health`, `pnpm appwrite:probe` (`ALLOW_LIVE_PROBE=…`).
8. Create the three Functions (`coc-learning`/`coc-progress`/`coc-ai`) over `services/<svc>/dist/function.mjs` (already declared in `appwrite.config.json`).
9. Provision maintainer accounts + maintainer team (publish/rollback/unpublish/retire require `deps.maintainers.has(userId)`).
10. Add a `config/staging.public.json` for the mobile build pointing at staging domains; verify `DATA_SOURCE=api`.
11. Run the Section 4 twelve-step lifecycle against staging before any production claim.

**Verdict:** **NOT READY** — staging does not exist; checklist + sample config prepared. No apply/deploy performed.

---

## Section 4 — Real publishing lifecycle validation

The 12-step runtime sequence (create course → content → media → export/build/lint/check → publish v1 → mobile fetch → update+publish v2 → mobile detects → rollback v1 → mobile correct data → unpublish → verify online/offline + cache + audit/version status) **requires the independent staging project from Section 3**, which does not exist.

What is proven statically (no runtime): the state machine, CAS, idempotency, integrity and version-status derivation are unit-tested against the real router with in-memory persistence (Section 5, 19 tests). What remains to prove with real requests/responses: end-to-end timing of mobile fetch after publish, rollback detection on-device, offline-cache behavior against a live backend, and audit/version history surfaced through the CMS.

**Verdict:** **BLOCKED** (no staging). Not self-declared PASS.

---

## Section 5 — Publishing concurrency & security

**Design review (code-level):**
- **Maintainer-only:** every mutation (`publishContent`, `unpublishCourse`, `retireVersion`, `rollbackCourse`, `listContentVersions`) throws `MAINTAINER_REQUIRED` unless `deps.maintainers.has(userId)` (or `options.system`). ✔
- **HTTP boundary:** all admin routes are `auth: 'user'`; `userId(c)` throws `AUTH_REQUIRED` when there is no verified subject (JWT). ✔
- **Optimistic concurrency (CAS):** every write compares `expectedPublishedVersion !== current` → `REVISION_CONFLICT`, so two admins cannot roll/publish past each other. ✔
- **Idempotency:** `commitWithReceipt` keys by `(userId, operation, key)`; same key + same body → replayed (effect not re-run); same key + different body → `IDEMPOTENCY_CONFLICT`. ✔
- **Content integrity:** `verifyPublication` enforces SHA-256 (`MANIFEST_HASH_MISMATCH`) + Ed25519 signature + structure hash; keyring is empty → fail closed. ✔
- **Retire vs unpublish:** unpublish → `DRAFT`, pointer cleared, history intact (stops new distribution). Retire → permanent flag; if it was live, also takes the course offline. A retired target is refused by rollback (`CONTENT_VERSION_RETIRED`). Correctly distinguishes "stop distribution" from "revoke downloaded content." ✔
- **CLI `--expect` auto-resolve:** `lifecycle-appwrite.mjs` `resolveExpect()` reads the live `l_courses.publishedVersion` when `--expect` is omitted and passes it as a concrete `expectedPublishedVersion` — it does **not** weaken the overwrite guard. ✔ (Caveat: passing the literal string `--expect null` is passed through verbatim and will never match a real version → over-protective `REVISION_CONFLICT`, not a security hole; document this for operators.)

**New regression tests added** (`services/learning/test/content-lifecycle.test.mjs`, now **19 tests, all passing**): idempotent publish replay, idempotency conflict, two-admin rollback race, two-admin publish race, manifest SHA-256 tamper refusal, manifest Ed25519-signature tamper refusal.

**Gap (hardening, not a defect):** `validateBundle` (`content/validate.ts`) checks that referenced asset IDs are *declared* in `bundle.assets`, but it does **not** verify the asset bytes actually exist in the `learning-assets` Storage bucket. `verifyPublication` reads the bundle JSON files (and fails on `BUNDLE_FILE_MISSING`) but never HEADs the media assets. A published lesson could therefore reference an un-uploaded media file and cause a runtime 404 on Mobile. **Recommendation:** add a media-existence probe in `verifyPublication` (HEAD each declared `assets[].fileId` in the bucket) before the pointer flips.

**Verdict:** **PASS** (design + 19 tests) with one documented hardening gap (media availability at the publish gate).

---

## Section 6 — CMS editorial acceptance

The CMS editorial flow exists and is wired: `apps/cms/src/app/(admin)/builds/page.tsx` hosts `VersionHistorySection`; `apps/cms/src/components/version-history.tsx` shows status badges (Đang live / Đã thay thế / Đã nghỉ hưu) with confirm dialogs and CAS via `liveVersion`; `apps/cms/src/server/actions/lifecycle.ts` provides `getContentVersions` + `runLifecycle`; the action is gated by appwrite mode + `CMS_ALLOW_PUBLISH` (verified by `scripts/publish-lifecycle-check.mjs`, 7/7). The full flow (create course → section/unit → author lesson → upload required media → readiness → preview → publish → version history → rollback → unpublish/retire) is implementable without CLI/DB edits in principle.

However, **no browser or admin credential is available in this environment**, so the UI itself was **not** clicked through.

**Verdict:** **UNVERIFIED (UI)** — code path present and statically consistent; runtime UI acceptance requires a browser + maintainer login (blocked here).

---

## Section 7 — Final acceptance report (10 items)

1. **Architecture diagram** — *Described.* CMS (Next.js) → Appwrite (Auth, TablesDB `c_*`, `l_*`, Storage `learning-assets`) → Learning/Progress/AI Functions (Node 22, signed internal events, Ed25519 content trust) → Flutter Mobile (Riverpod MVVM, `DataSource.api`, `SnapshotCache` per-user, `JournalSession` version-pinned). Frozen per `AGENTS.md`/`ADR-0018`/`ADR-0020`.
2. **Flutter build/analyze/test** — *Partial.* Pipeline + data-source guard: static PASS. Actual build/analyze/test: **BLOCKED** (no SDK). API call sites not run in CI: **GAP**.
3. **Cache/version findings** — *PASS (analysis).* No `SnapshotCache` change needed; no collision proven; session pinning correct.
4. **Staging readiness** — *NOT READY.* No independent staging; checklist + sample config prepared; nothing applied.
5. **Real-cloud evidence** — *NONE.* Section 4 blocked (no staging).
6. **CMS UI results** — *UNVERIFIED.* Code present; no browser run.
7. **Security/concurrency findings** — *PASS* (maintainer guard, CAS, idempotency, integrity, retire/rollback; 19 tests). One hardening gap: media availability not enforced at the publish gate.
8. **Blockers list:** (i) no independent Appwrite staging; (ii) no Flutter SDK in this environment; (iii) no browser/admin credential for CMS UI; (iv) CI does not exercise the API call-site path.
9. **Production-readiness checklist:** staging provisioned + key rotation ✗ · 12-step real lifecycle on staging ✗ · CMS UI clicked through ✗ · CI API-path coverage added ✗ · media-existence gate added (recommended) ✗ · `backend:verify` + `contracts:check` green ✔ (prior session) · lifecycle tests green ✔ (19/19 this session).
10. **Final verdict: NOT READY (conditional).** The logic, contracts and local gates are sound and tested, but production readiness cannot be asserted until an independent staging project is provisioned and the four blockers above are cleared. No deploy, no TEST writes, no secret changes were performed.

---

### Gates run this session
- `node --test services/learning/test/content-lifecycle.test.mjs` → **19/19 pass** (added 6 regression tests for Section 5).
- `prettier --check` on the modified test → formatted, clean.
- All other prior gates (`backend:verify` 344/356, `contracts:check`, `api:lint`, `backend:smoke`, CMS `check:publish-lifecycle` 7/7) were green in the prior session and are unaffected by this change.
