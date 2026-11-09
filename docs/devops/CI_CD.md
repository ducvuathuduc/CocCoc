# CI/CD

GitHub Actions is the CI engine. The current workflow is deliberately small: verify code, run tests, build artifacts, and scan for secrets. This replaces the earlier aspirational pipeline checklist; product phase gates remain owned by [IMPLEMENTATION_PLAN](../agent/IMPLEMENTATION_PLAN.md).

## Automatic checks

Run once for a pull request and again after a push to `main`. Feature-branch pushes do not start a duplicate run alongside the PR.

| Workflow | Required work | Output |
|---|---|---|
| Backend foundation | Frozen pnpm install; TypeScript build/typecheck, ESLint, formatting and tests; in-process and local HTTP smoke; API contracts and OpenAPI lint; CI regression tests | Three independent service bundles |
| Mobile frontend | Pinned Flutter; locked dependency restore; Dart format, analyzer and Flutter tests; Android debug build | Debug APK, golden failure images on failure |
| Mobile API lane | Pinned Flutter; the Learning test backend (fixtures, in-memory, loopback only) is started and `apps/mobile/test_api` runs with `DATA_SOURCE=api`; Dart format of the lane tests. It is independent of the Mobile frontend workflow, which keeps the mock suite | Pass/fail of Flutter runtime against real Learning responses |
| Source secret scan | Checksum-pinned Gitleaks with redacted output | Fails when a source secret is detected |

Dependencies and action commits are pinned. Ordinary jobs have only `contents: read`, no deployment/provider secrets, timeouts, and cancellation of superseded runs. Artifacts expire after three days; diagnostic golden failures expire after seven.

`pnpm verify` runs the mobile checks. Blueprint and documentation audits are available separately instead of blocking every UI build. Golden comparisons remain real comparisons; updating baselines is an explicit maintenance operation, never an automatic fix inside CI.

## Manual checks

- **Backend foundation → extended_checks:** local tooling/load smoke, Postman scenarios, schema/seed dry run, blueprint/documentation audits and voice fixture evaluation. These commands remain available locally as well.
- **Container runtime:** build the three owner images, check startup/restart behavior, and collect logs. This duplicates backend compilation, so it runs on demand.
- **Mobile frontend:** manual dispatch with `build_ios=true` also builds the unsigned iOS simulator artifact after Linux verification succeeds; it does not rerun the Linux visual suite on macOS.
- **Android E2E:** the existing manual emulator workflow is retained for native/device changes.
- **Mobile API lane → build_release:** manual dispatch also builds the release-profile APK with `config/real.public.json` after the lane passes. `tools/tests/mobile-release-config.test.mjs` fails when any workflow builds an app without that profile.

The Mobile API lane (`.github/workflows/mobile-api.yml`) is an addition to the 2026-11-06 minimal policy that closes the gap where CI ran Flutter tests only in mock mode. It is prepared and verified locally but needs human approval before it becomes a pull-request gate. It proves the Flutter clients and parsers against the local Learning service only. It is not cloud, Appwrite, device or staging evidence.

## Deployment

The existing Appwrite test deployment remains manual and uses the `appwrite-test` environment and its scoped secret. PR builds do not deploy, publish, apply schema, enable paid adapters or contain provider credentials. A deployment requires an explicit execution request and the admitted runtime/configuration described in [operations](OPERATIONS.md). No automatic production promotion or extra CI controller is introduced.

Build/test evidence, cloud integration, emulator evidence and physical-device acceptance are different results. The pipeline reports only what actually ran. Current repair evidence: [2026-11-06 CI receipt](../quality/CI_BRANDING_REPAIR_20261106.md).
