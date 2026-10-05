# Toolchain, environments and CI/CD specification

This phase0 package specifies pipelines. It does not deploy services, initialize cloud projects, install SDKs, or publish apps. Actual workflow files are created by P1 after pinning toolchain and secrets. [Stack](../architecture/STACK.md) owns versions; [costs](COST_MODEL.md) owns allowances.

## Environments

local: real Flutter with fake repositories/AI; three Node demo adapters when exercising APIs. test: disposable Appwrite integration project or local compatible Appwrite instance after transaction compatibility probe. staging-demo: one active Education project,3Functions/oneDB/bucket;20invited accounts. No production project is required. Second Education project reserved for gated integration; Free fallback uses one supported project. Public config only: endpoint, project ID, three service URLs, build/version, feature flags. Secrets only server/CI: Appwrite deploy credentials, scoped keys, HMAC keys, provider keys, Grafana exporter credential, optional signing material.

Use protected main, PR checks, one deployment lock per environment. Cloud migration/deploy requires an explicitly authorized execution task; research does not authorize external writes. Pull-request/fork CI never receives deployment or provider secrets. Never use pull_request_target to run untrusted code with secrets. Pin actions to verified commit SHA in P1; pin SDK/version/runtime instead of floating latest tags.

## PR pipeline

| Job / host / trigger | Commands and verification | Artifact / limits |
|---|---|---|
| docs-contract / Linux / everyPR | node tools/blueprint/validate.mjs; OpenAPI3.1 lint+schema fixture validation; requirement/table refs; skill/hook JSON | validation report; no cloud/network AI |
| mobile-fast / Linux / mobile/shared-contract changes | flutter pub get with lock; dart format --output=none --set-exit-if-changed lib test; flutter analyze --fatal-infos; flutter test --coverage | coverage + golden diff; unit/VM/repository/widget |
| mobile-generated / Linux | dart run build_runner build --delete-conflicting-outputs; git diff --exit-code | no generated drift; generation is from declared sources |
| backend / Linux / services/shared/API changes | pnpm install --frozen-lockfile; pnpm lint; pnpm typecheck; pnpm test:unit; pnpm test:contract; pnpm build |3compiled deploy artifacts + SBOM/lock evidence |
| secret/security / Linux / everyPR | pinned gitleaks scan; lock/dependency vulnerability review; inspect diff | secret scan fatal; no suppression without reviewed reason |
| android-build / Linux / mobile native or release candidate | flutter build apk --debug; compile all native plugins | APK retention≤3days, cancel superseded builds |
| ios-simulator / standard macOS / native plugin change and candidate, weekly optional only within quota | install pinned Flutter; xcodebuild -version; flutter build ios --simulator; boot available iOS15+ simulator; run integration_test without cloudAI | unsigned .app, screenshots/test report; retain≤3days |

Quality floors: essential state-machine/grading/authorization/idempotency cases pass, coverage≥80% of hand-written domain/VM code as an auxiliary signal; do not gate generated files by artificial coverage. Goldens run pinned Linux/fonts; macOS checks build/platform behavior. Required tests follow change scope; do not launch every device matrix after copy changes.

## Main/staging pipeline

Re-use reviewed PR artifact → contract-compatible expand migration dry-run → authorized staging migration → deploy **one affected service at a time** via Appwrite server SDK/CLI current pinned version → verify active deployment/build ID → smoke login/courses/session/duplicate completion/rewards → observe5min → mark deployment receipt. No migration destructive reset. Before deploy, capability probes confirm TablesDB transaction/index API and selected Function runtime.

Integration suite uses disposable test users and synthetic assets; it may contact Appwrite only in explicit gated integration job using scoped credentials. Account API rate limits and cleanup tracked. Normal PR tests use mocks; main integration never invokes real AI. Event fault tests crash before/after commit/ack and prove reward total/ledger equality.

Rollback: select previous compatible deployment ID; published manifest pointer stays immutable or reverts; failed expand migration leaves additive schema for old writer. Freeze deploying next service until smoke passes. No API breaking change in same release without compatible old-client behavior.

## Android release

workflow_dispatch/tagged approved candidate → full prior checks → demo keystore from encrypted environment secret → flutter build apk --release and optional appbundle → SHA256/artifact manifest → installation on physical Android → offline+speech permission smoke. Keep keystore outside Git, record packageName cocenglish educational ID chosen P1, alias/store signing secrets. Demo side-load avoids Play store account/publishing cost. Artifact generation is separate from authorized external distribution.

## iOS default and fallback

Default **GitHub Actions standard macOS**. Public standard runner policy free; private owner's actual included allowance/rates controls cost. Choose explicit macOS image with compatible pinned Xcode based on image inventory in P1; do not blindly use macos-latest forever. Run simulator build and automated smoke, save video/screenshot evidence. Runner remote access is CI, not interactive iPhone debugging from Windows.

Fallback **Codemagic personal M2**,500minutes/month; mirror pinned Flutter/Xcode/env/build/test commands in codemagic.yaml during P1 when account exists. Team quota differs. Bitrise and Appcircle comparison in costs; not additional defaults.

Signed IPA requires eligible Apple team, certificate/private key, provisioning profile and bundleID; optional App Store Connect API key for automatic provisioning/TestFlight. Configure CI secure files/keychain, build ipa with explicit export method/profile, remove keychain material after job. A Personal Team expires7days and needs Xcode provisioning; do not promise a durable Windows-only free physical-iOS pipeline. Without existing team/signing access, deliver unsigned simulator .app and recorded simulator proof; physical-device audio validation remains explicitly pending for iOS.

## Script contracts to implement in P1

pnpm verify = formatting + lint + typecheck + unit/contract; pnpm build =3service artifacts; pnpm integration --env test = explicit disposable backend tests; pnpm deploy --env staging-demo --service name = reviewed artifact + deployment receipt; pnpm migrate --env name --dry-run default; pnpm content:validate =schema/assets; pnpm demo:start =3local adapters+trusted scheduler. These scripts are future P1 deliverables, not falsely present runnable commands now.
