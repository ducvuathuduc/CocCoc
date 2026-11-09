# CocEnglish: Release Blocker Remediation

**Date:** 2026-11-09. **Scope:** the four workstreams of the remediation task that followed [CLOUD_MOBILE_INTEGRATION_REPORT](CLOUD_MOBILE_INTEGRATION_REPORT.md). No production deploy, no write to the shared TEST project, no credential change, no commit or push.

**Final verdict: NOT READY.** Two of the three P0 blockers are fixed and verified locally. The third, an independent staging project, still does not exist, so there is no staging runtime evidence. The Flutter API lane passes on a developer machine but has not yet run in GitHub Actions.

Status vocabulary: PASS = ran and passed here; FAIL = ran and failed; BLOCKED = needs something this environment may not create or use.

## 1. Root causes

| # | Cause | Evidence |
|---|---|---|
| R1 | The publish gate verified JSON files only. `verifyPublication` read manifest and bundles but never asked Storage whether a declared media file exists, is whole, is readable by Mobile or hashes correctly, so the pointer could flip onto lessons whose audio or images were not there. | `services/learning/src/application/content.ts` before this change; `validateBundle` checks only that an asset id is *declared*. |
| R2 | The builder writes a placeholder hash and size for every clip or image that has no committed file, and the offline gate (`verify-media.mjs`) runs only for committed `dist/` folders. A placeholder therefore reaches a signed bundle. | `tools/content/build-course.mjs` (`audioAsset`, `imageAsset`). Publishing the `vi_en_mini` test course as built returned `MEDIA_SIZE_MISMATCH` and `MEDIA_MISSING` from the new gate. |
| R3 | `publish-appwrite.mjs` skipped declared assets that had no local file without saying so. | Source. Now prints a `media-warning` line. |
| R4 | Rollback re-pointed the course at an older version after reading its manifest only. Media deleted or replaced since that version was published went unnoticed. | `rollbackCourse` before this change. |
| R5 | Media file ids are neither content-addressed nor course-namespaced (`a.w.cat.n` is used by every course). Re-recording a clip under the same id changes the bytes older versions point at. | Id scheme in `build-course.mjs`. **Not changed**, see section 8. |
| R6 | CI ran Flutter tests only in mock mode. `AppConfig` defaults to `mock` when `DATA_SOURCE` is undeclared and a test pins CI to that case, so the generated API clients and repositories ran only in a manual emulator test. | `mobile.yml`; `test/core/config/data_source_declaration_test.dart`. |
| R7 | Two generated Dart files from the previous session were not `dart format` clean, so CI's format check would have failed once they were committed. | `dart format --set-exit-if-changed` listed `api_endpoints.g.dart` and `api_operations.g.dart`; HEAD's copies are clean. |
| R8 | Live Appwrite scripts accept only `APPWRITE_PROJECT_ENV=test` with `reviewed-test-project` gates and the TEST project id. The previous report's staging checklist named gate values that do not exist. | `appwrite/scripts/ops.mjs`, `schema.mjs`, `live-probe.mjs`. |

## 2. Files changed

Pre-existing uncommitted work from earlier sessions (about 80 files, mostly `apps/cms`, `docs/api/openapi.yaml`, generated Dart, `services/learning` lifecycle) was left as found, except where listed.

**Production code** (`services/learning`): new `src/content/media.ts` (the gate); `src/content/repository.ts` (`ContentFileStore` gains `stat` and `readBytes`; repository owns the verifier); `src/content/storage-files.ts` (Appwrite adapter: batched `listFiles`, byte download, error classification); `src/application/content.ts` (gate in `verifyPublication`, metadata recheck before the commit, rollback audit, `verifyVersionMedia`, bounded parallel bundle reads); `src/index.ts` (hosted wiring and two tuning variables).

**Test support:** `src/testing/local-content.ts`, `test-app.ts`, `learning-testkit.ts`, `test/helpers/media-course.mjs`, `test/helpers/authored-content.mjs`, `test/multi-course.test.mjs`, `test/content-lifecycle.test.mjs` (fixtures now carry real media bytes), new `test/media-integrity.test.mjs` (15 tests).

**Tools:** `tools/content/publish-appwrite.mjs` and `lifecycle-appwrite.mjs` (use the hosted file store, new read-only `--action verify-media`), `tools/scripts/api-lane-backend.mjs`, `mobile-api-lane.mjs`, `flutter-toolchain.mjs`, `dev-services.mjs` (one export), `staging-preflight.mjs`, `tools/content/generate-content-key.mjs`, and tests `tools/tests/mobile-release-config.test.mjs`, `staging-preflight.test.mjs`, `generate-content-key.test.mjs`.

**Mobile:** new `apps/mobile/test_api/` (lane tests), `test/core/config/real_profile_release_test.dart`, `config/staging.public.example.json`; the two generated Dart files were only reformatted with `dart format`.

**CI and docs:** `.github/workflows/mobile-api.yml`, `package.json` (`mobile:api-lane`), `docs/devops/CI_CD.md`, `docs/devops/STAGING_APPWRITE.md`, `docs/api/EVENTS_ERRORS.md`, `content/README.md`, `services/learning/AGENTS.md`, `apps/mobile/AGENTS.md`, `docs/00_START_HERE.md`, `docs/agent/REPOSITORY_TREE.md` (regenerated), `appwrite/ops/project.staging.example.json`, this report.

## 3. Media publication integrity (Workstream 1): PASS locally, BLOCKED against real Storage

**Where each property was checked before, and now**

| Property | CMS upload | Builder / offline gate | `publish-appwrite.mjs` | Learning publish (before) | Learning publish (now) | Mobile loader |
|---|---|---|---|---|---|---|
| Asset id | derived from the draft, safe-id regex | declared in bundle; safe-id regex | uploaded under the id | declared only | declared, de-duplicated, conflicting declarations refused | by id in a public URL |
| File exists | n/a (writes to repo) | local file must exist (committed dist only) | local file uploaded; missing local file skipped | not checked | batch metadata, `MEDIA_MISSING` | text fallback |
| Whole upload | n/a | n/a | n/a | not checked | `chunksUploaded >= chunksTotal`, `MEDIA_INCOMPLETE` | n/a |
| Size | byte caps, WebP 512x512 | bytes equal declared | n/a | not checked | stored size equals declared, `MEDIA_SIZE_MISMATCH`; caps 2 MiB audio, 5 MiB image like Mobile | caps at download |
| SHA-256 | computed | recomputed locally | compared for existing remote files | not checked | bytes downloaded once per stored object and hashed, `MEDIA_HASH_MISMATCH` | verified before use |
| Read permission | n/a | n/a | uploads with `read(any)` | not checked | file `$permissions` must grant `read("any")`, `MEDIA_NOT_PUBLIC` | public view URL |

**Design (requirements 2 to 9)**

- The gate runs inside `verifyPublication` after the cheap structural checks, so a broken course costs no Storage call, and writes nothing when it fails.
- `confirm()` re-reads metadata immediately before `commitWithReceipt`. A file deleted, hidden or replaced while the bytes were being verified stops the publish (`MEDIA_MISSING`, or `REVISION_CONFLICT` with `MEDIA_CHANGED_DURING_PUBLISH`).
- Fail closed: a store without `stat`/`readBytes` yields `STORAGE_UNAVAILABLE` / `MEDIA_VERIFICATION_UNAVAILABLE`; Storage 5xx, network error, timeout and an exhausted deadline are `STORAGE_UNAVAILABLE` (503, retryable); a 401/403 from Storage is `MEDIA_PERMISSION_DENIED` and is not retried. No path turns an outage into a successful publish.
- Immutability: verification is read-only. A rejected publish leaves `l_courses` and `l_content_versions` untouched, so the same version id publishes once the media is fixed (tested). Rollback now audits its target the same way (tested: refused when the target's media was replaced or deleted; the pointer and the older row stay as they were). Unpublish and retire never touch Storage, so an outage cannot keep bad content online (tested).
- Race after verification: **cannot be removed** because Storage is outside the database transaction. The window is now the interval between the metadata recheck and the commit (milliseconds). A deletion after the commit is a retention matter: Mobile falls back to the text alternative every audio item has, `lifecycle-appwrite.mjs --action verify-media` audits the live version read-only (exit 1 on any defect; run it on a schedule), and rollback refuses a damaged target.

**Cost evaluation, committed `vi_en` v2** (measured with the local disk store; Appwrite figures are estimates, not measurements)

| Strategy | Storage requests | Verdict |
|---|---|---|
| HEAD or GET per reference | 14,888 | rejected |
| One metadata call per unique asset | 1,760 | rejected for metadata, kept as fallback when the server refuses the batch query |
| Batched metadata, 50 ids per `listFiles` call | 36, plus 36 for the recheck | chosen |
| Bytes for SHA-256 | 1,760 downloads, 14.5 MB, once per stored object per process | chosen, because Storage keeps only an MD5 |
| Concurrency | at most 8 calls in flight (tested), per-call timeout 10 s, one retry for transient errors, 35 s deadline per verification | chosen |

Measured locally: a full publish including the gate 357 ms; a second audit of the same version 14 ms with 0 downloads. Estimated on Appwrite Cloud: 1,760 downloads at 8 in flight and 80 to 150 ms each is roughly 18 to 33 s, inside the 35 s deadline but close to the 60 s function limit, so a first publish of a large course should go through `publish-appwrite.mjs` (no function timeout). An exhausted deadline fails closed and keeps its progress, so the retry resumes instead of restarting (tested). Rollback has the same cost on a cold instance.

**Tests added** (15, all pass): batching and concurrency limits with the real course; missing media; wrong bytes, wrong length, wrong stored size; not public, upload unfinished; Storage outage with bounded retry and recovery; permission denied without retry; call timeout; read-phase outage; deadline with resume; delete and replace between verification and the flip; rollback re-audit; takedown during an outage; offline declaration checks; tuning variables; the Appwrite adapter against a fake SDK (batch query shape, batch fallback, error reasons, bytes). Two mutation checks confirmed the tests can fail: removing the recheck breaks the race test, and bypassing the gate breaks three lane tests.

**Not proven:** behaviour against a real Storage bucket. The adapter assumes `listFiles` accepts `Query.equal('$id', [...])` (documented filter attributes do not list `$id`; the code falls back to per-file metadata on a 400) and that `$permissions` renders as `read("any")`. Both need confirmation on staging. The prepared anonymous-download step in the staging runbook proves what Mobile will actually do.

## 4. Flutter API-mode CI (Workstream 2)

| Item | Result | Evidence |
|---|---|---|
| `mobile.yml` review | PASS | Pins `FLUTTER_VERSION: 3.47.0` via `git clone --branch`, `pub get --enforce-lockfile`, `mobile-check.mjs` (format, `analyze --fatal-infos`, `flutter test`), debug APK built with `config/real.public.json`. |
| SDK version | PASS | Tag `3.47.0` exists upstream (4cf2416). `tools/toolchain.json` pins Flutter 3.47.0 and Dart 3.13.0; `pubspec.lock` requires `>=3.47.0`; all three workflows agree (guard test). Installed locally at `.cache/flutter`: `Flutter 3.47.0, Dart 3.13.0`. |
| Actual CI result | PASS (mock mode only) | `gh run view 42262673091`, push to `main`, commit f0e1a3b: job success, "No issues found", "1648 tests passed", debug APK built. Runs 872bfee and 9e71a51 failed earlier and were fixed by ddb23f5. |
| Mock tests kept | PASS | `mobile.yml`, `mobile-check.mjs`, `test/` unchanged. `test_api/` is outside `flutter test`'s default folder. Four config guard tests were added to `test/`. |
| Independent API lane | PASS locally, **CI not run** | `.github/workflows/mobile-api.yml` is a separate workflow. `node tools/scripts/mobile-api-lane.mjs` on Windows with the pinned SDK: 26 tests passed in 34 s, exit 0. Run without the lane, the tests fail with a clear message instead of skipping. |
| Backend and fixtures | PASS | Learning router and use cases in memory, 127.0.0.1 only; `vi_en` v2 with its real media published at start through the real gate; `vi_en_mini` v1 and v2 for publish, rollback and unpublish. |
| `DATA_SOURCE=api`, `LEARNING_API_URL` | PASS | Passed as `--dart-define`; a test asserts `AppConfig.current` is declared API mode, mock auth off, aimed at the lane backend, and admitted by `validateRealProfile`. |
| Auth, listing, manifest, bundle, errors | PASS | Rejected token (401 after one re-auth), no session (no network call), learner refused on maintainer routes (403); catalog, `ActiveCourse`, manifest and pinned manifest; all 513 bundles parsed and mapped by `LessonWireMapper`, all 12 exercise types seen; 404, 400, NETWORK, TIMEOUT, retryable 503; an end-to-end lesson through `ApiLearningRepository` (enroll, path, session, answers, completion). |
| Collision, version change, unpublish | PASS | Lesson ids `u1n1l1` exist in both courses: the course-less read returns `LESSON_AMBIGUOUS` with both ids, the course-scoped reads are exact; stale publish is a 409; v2 supersedes v1 and v1 stays readable by version; rollback and unpublish change what the app lists; media-missing and Storage-outage publishes are refused with the right codes. |
| Release APK keeps `real.public.json` | PASS | `tools/tests/mobile-release-config.test.mjs` (6 tests) fails if any workflow builds an app without it; Dart tests check the profile is an https, real-auth profile the app admits as a release profile and that a local profile never does; the lane never references the file. An optional `workflow_dispatch` job builds a release APK with it. |
| Node tests are not Flutter tests | PASS | The lane is a Flutter run (`flutter test` on the VM against HTTP); Node tests stay in `backend:verify`. |

**Limits.** Identity is the test router's `Bearer user-<id>` stub, not an Appwrite JWT; Progress and AI services, device behaviour and the Android emulator are not part of this lane. The previous report's recommendation was an emulator job; this lane is the cheaper alternative and does not replace the manual emulator test. `.github/workflows/mobile-api.yml` extends the human-approved minimal CI policy of 2026-11-06 and needs approval before it becomes a pull-request gate.

## 5. Staging readiness checklist (Workstream 3): prepared, BLOCKED

| Item | State |
|---|---|
| Project isolation | BLOCKED: no staging project; D2 (who creates it, cost) open |
| Schema and Storage setup | Offline plan commands documented; apply BLOCKED by D1 |
| Learning function deployment | Procedure documented; BLOCKED by D1 |
| Service environment variables | Overlay `appwrite/ops/project.staging.example.json` lists only what differs from TEST |
| Content signing keys, no dev key | `generate-content-key.mjs` (tested for compatibility with `integrity.ts`); preflight rejects the dev key id, the dev public key and a reused key |
| Maintainer authorization | Documented with proof steps; needs real staging users (D4) |
| CMS configuration | Documented, including that the CMS reads `.secrets/real.env` (the TEST pair) unless staging values are in the process environment |
| Mobile test configuration | `staging.public.example.json`; preflight checks it matches the staging project and is https |
| Smoke tests | Ordered list, including an anonymous download of one audio and one image |
| Rollback and cleanup | Content rollback and unpublish commands, function redeploy, key rotation, teardown |
| Offline preflight | `tools/scripts/staging-preflight.mjs`: 7 tests pass; exits 2 `BLOCKED` while the real files are absent |

**D1 is the first decision:** `schema.mjs`, `ops.mjs` and `live-probe.mjs` run only with `APPWRITE_PROJECT_ENV=test`, `reviewed-test-project` and the TEST project id. A staging apply needs a reviewed change to those gates in an exclusive area, which I did not make. Errata to the previous report: its step 6 names `reviewed-staging-project` and step 5 a "reviewed staging gate" value for `COC_LEARNING_ADMITTED`; the first does not exist yet and the second must stay `reviewed-cloud-gate`.

## 6. CMS browser acceptance (Workstream 4): BLOCKED

| Needed | Present |
|---|---|
| An Appwrite project that is not TEST | no |
| A maintainer account with a password credential (the CMS has no dev login by design) | no |
| A browser | yes (Edge, Playwright Chromium cache) |
| A Playwright package in the lockfile | no; adding one changes `pnpm-lock.yaml`, an exclusive area |

I did not start the CMS: it loads `.secrets/real.env` (the shared TEST pair) when the process environment lacks Appwrite values, so even a login-page smoke risks writes to TEST. Nothing was clicked and nothing is claimed as PASS. The eight-step journey, with expected results, is in the staging runbook. Supporting non-browser evidence, run with Appwrite pointed at a dead address: `check:publish-lifecycle` 7, `check:publish` 26, `check:lifecycle` 53, `check:readiness` 44 checks pass; typecheck, lint and `next build` pass (one existing Turbopack tracing warning in `media-service.ts`).

## 7. Regression evidence

| Check | Result |
|---|---|
| `node tools/scripts/backend-check.mjs` (tsc, esbuild, ESLint, Prettier, all service tests) | PASS: 377 tests, 365 pass, 0 fail, 12 skipped (live probes) |
| Content lifecycle and multi-course tests | PASS: 25 of 25 (re-run after fixture change) |
| `media-integrity.test.mjs` | PASS: 15 of 15 |
| `backend-smoke.mjs`, `dev-smoke.mjs` | PASS, PASS |
| `contracts:check` | PASS: 162 schemas, 173 classes; `api:lint` valid |
| Tool tests (`mobile-release-config`, `staging-preflight`, `generate-content-key`, `backend-workflow-paths`, `dart-contract-line-endings`, `verify-media`) | PASS: 22 of 22 |
| `dart format --set-exit-if-changed lib test integration_test test_driver`, `flutter analyze --fatal-infos` | PASS after formatting the two generated files, no issues |
| `flutter test test/core/config` | PASS: 26, including the undeclared-build guard |
| Flutter API lane | PASS: 26 of 26 |
| CMS typecheck, lint, `next build` | PASS |
| `audit:check` link and Mermaid validation | PASS (`tools/audit/validate.mjs` exit 0) |
| Existing, not caused by this work | `docs/api/API_ENDPOINT_MATRIX.md` is stale (`pnpm docs:endpoints`) and `blueprint:check` reports "API trace drift" for FR-COURSE-001, FR-CONTENT-001, FR-LISTEN-001, FR-ADMIN-001. Both come from the uncommitted `docs/api/openapi.yaml` edits (763 lines) made before this session. |
| Not run | Full Flutter mock suite locally (Windows golden baselines differ; Linux CI passed 1648 at f0e1a3b), anything against a cloud project, any device. Local Node was 26.13.0, CI pins 22.23.3. |

Local tooling added by this work and safe to delete: `.cache/flutter` (936 MB), `.cache/pub-cache` (458 MB), both git-ignored. `pubspec.lock` and `pnpm-lock.yaml` are unchanged.

## 8. Remaining blockers and risks

1. **No independent staging project** (D1, D2, D4). Without it there is no staging runtime evidence and no CMS browser result.
2. **The API lane has not run in GitHub Actions.** It needs the workflow committed on a branch and the CI-policy extension approved. The working tree holds about 80 uncommitted files from earlier sessions, so a commit needs selective staging.
3. **Real Storage behaviour of the media gate is unverified** (batch query on `$id`, permission string, download semantics). Confirm on staging.
4. **Media ids are not content-addressed or course-namespaced (R5).** Replacing a file under the same id breaks older versions' hashes until the pointer moves; two courses that ship different bytes under one id cannot both be valid. Rollback and `verify-media` detect it; only a new id scheme (for example `a.<course>.<id>.<sha8>`) removes it. This is a content-format decision for the owner.
5. **The .NET backend does not have the media gate.** `LearningPublicationController.VerifyPublicationAsync` verifies JSON only. ADR-0020 keeps Node as the baseline, so this is fine today and must be ported before any cutover.
6. Lane identity is a stub, and Progress, AI and device behaviour are outside it.
7. The two generated Dart files need `dart format` after each regeneration with `apps/mobile/tool/gen_api_operations.py`.

## 9. Release verdict

**NOT READY.** Rule applied: READY needs staging runtime evidence and Flutter API integration evidence in CI. Flutter API evidence exists locally and is prepared for CI; staging evidence does not exist. Nothing was deployed, committed or pushed.
