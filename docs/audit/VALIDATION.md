# Validation receipt — 2026-10-09–10, Asia/Saigon

Baseline commit `8b64cdcff3365e0ae4c5401bf2e799abd3dca649`. Fresh commands in this task; no historical receipt reused. Final gate results and capability limits are recorded below. No cloud/paid provider calls or GitHub workflow dispatch were performed.

| Command | Actual result / meaning |
|---|---|
| node tools/audit/inventory.mjs | PASS; baseline 2,358 files / 101 docs / 126 mobile sources; metadata and text inspection, binary sample distinction |
| flutter --version / flutter doctor -v | Flutter3.47.0/Dart3.13.0; Android SDK36, JBR25.0.3; unaccepted Android licenses; no attached Android device; Windows desktop components missing |
| npm view / pnpm install | Registry checks and lock generated. Latest TS7.0.2 failed openapi-typescript factory and peer ranges; corrected to compatible TS5.9.3, no toolchain upgrade assumed |
| node --experimental-strip-types --test (initial Learning fixture) | Expected RED: 5 tests failed NOT_IMPLEMENTED after correcting first missing-artifact invocation; meaningful missing behavior proven |
| node --test services/progress/test/events.test.mjs | RED: unsupported REVIEW fixture mode wrongly accepted; fixed to fail closed with MODE_NOT_IMPLEMENTED |
| pnpm backend:verify | PASS: strict TS, ESLint, Prettier, three independent Function bundles and 16 tests; business adapters deliberately disabled. Additional red-first session-key reuse test corrected the fixture scope |
| pnpm backend:smoke | PASS: three delivery attempts with receiver failure/lost ack, one applied event, one 18-XP fixture award, zero provider calls; in-memory only |
| pnpm contracts:check | PASS: 94 compiled schemas, 30 positive/negative fixture cases |
| pnpm api:lint | PASS: Redocly validates OpenAPI3.1; no warnings shown |
| node tools/blueprint/validate.mjs | RED after audit/toolchain caches existed: old scanner checked generated copies as source and reported broken links. Corrected scanner excludes generated cache/build/install folders and symlinks; fresh result below |
| pnpm mobile:verify | PASS: 216 Dart files formatted with zero changes, analyzer no issues, 439 tests passed. Initial format emitted missing-lint resolution warnings before analyzer restored dependencies; no lock upgrade |
| Gummble search_apps | Success: real Duolingo iOS catalog match; no current app parity inference |

## Additional fresh receipts

- Portable official Node22.23.3 download matched published SHA-256; actual binary passed backend16 tests, fake async smoke and audit. npm exec first resolved global Node24; pnpm dlx failed node-bin-setup; neither was claimed as Node22 proof. Cloud runtime remains unproven.
- pnpm build:web passed release compilation in 76.2s; existing main.dart and mobile lock unchanged.
- pnpm audit:check passed JSON/YAML/local-link checks and 13 Mermaid diagrams parsed; generated type SHA-256 remained identical after re-generation.
- Final blueprint scanner correction passed39 FR/19 NFR/42 screen IDs/39 edge cases/38 tasks/37 tables/94 schemas/42 operations/17 ADRs. Cache copies are excluded instead of deleted. AJV also validates the new lesson.completed.v1 example.
- Actual Node22 executed `.cache/health-smoke.mjs`: three separate local service processes on4301/4302/4303 returned200 health with their own owner,401 ready and503 business; processes exited afterward. No database/cloud protocol inferred.
- Isolated SDK declaration/official-reference review confirmed node-appwrite29.2.0 object-style TablesDB methods, TablesDBIndexType.Key/Unique, per-request Client.setJWT and Account.get. This verifies exact API signatures only; apply/runtime/permissions/conflicts remain untested in Cloud.
- pnpm schema:plan passed four declared tables/36 columns/nine indexes, no network. Remaining33 canonical tables are not implemented by this foundation. pnpm seed:check passed typed unavailable catalog; full48-lesson curriculum not generated/published.
- voice-harness fixture validated metadata with p50/p95 null and zero provider calls. No natural learner audio benchmark was performed.
- Gitleaks8.30.1 scanned changed repository text with full redaction and passed; git diff --check passed. No mobile source/asset/pubspec-lock or OpenAPI wire changes.

Source/config files are not a deployment, account setup, iOS build, physical audio test, benchmark or signed release. Independent voice-source review corrections fixed the token-guide URL and made180s/project policies distinct from vendor limits.

## Android build investigation

`pnpm build:android` passed format/analyze/439 tests again, then failed Gradle9.3.1 `:app:mergeExtDexDebug` after393.6s. The global Gradle transforms cache reported a modified immutable workspace for Flutter embedding. No mobile source, lock or Gradle configuration change preceded it. The log does not establish whether an external process, disk state or Gradle caused that cache change.

One-variable diagnostic retry: set PowerShell `$env:GRADLE_USER_HOME` to the new repo-local `.cache/gradle-android-refresh`, then run Flutter's existing tools snapshot with `build apk --debug`. PASS, exit0: `assembleDebug`504.8s; built `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`. The old global cache is preserved; no deletion/reset occurred. A successful fresh-cache build establishes compilation and isolates the observed failure to the old-cache build path; it does not identify which process changed the old workspace. [Gradle directory documentation](https://docs.gradle.org/current/userguide/directory_layout.html) defines the separate user-home cache. [Artifact hashes](BUILD_ARTIFACTS.json) record current outputs. The isolated Gradle daemon was stopped after the receipt.

Warnings observed: Rive native DLL load warnings in some Windows test cases (tests still passed); plugins flutter_web_auth_2/rive_native still use Kotlin Gradle Plugin; Android SDK XML tooling versions differ. These need future toolchain/device checks. Some Android SDK licenses remain unaccepted in doctor output; no terms were accepted automatically. No physical Android execution was performed.

All17 new/changed mjs files passed `node --check`. No mobile source/assets/pubspec.lock or original OpenAPI wire diff exists. Final doc/contract/secret results follow the changed-file manifest; no GitHub/cloud run is inferred.

## Final gate counts

Actual Node22.23.3 final blueprint: PASS,2436 scanned source/spec files,145 Markdown,839 internal links,39 FR/19 NFR/42 screen IDs/39 edge cases/38 tasks/37 table owners/94 schemas/42 operations/17 ADRs. Current Git-aware disk tree:2417 files; scanners use different metadata/config exclusions, so neither count is a screen count.

Actual Node22.23.3 final audit: PASS,82 JSON,4 YAML,839 local links,13 parsed Mermaid diagrams,one AJV-validated event example. Generated types remain SHA256 `16bf2e221c7551993a3e3e25713db0f7e69e5f031de9f374cbba42792419bd88`.

Final Gitleaks: PASS,98 changed text files,full redaction. `git diff --check`: PASS. No tracked mobile/OpenAPI diff. The98-file manifest and scoped research task status are complete; full production phase gates remain pending.
