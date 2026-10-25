# Main integration and CI repair plan — 2026-10-25

**Goal:** integrate every outstanding remote commit into `main` and verify the resulting candidate on GitHub, preserving reference-backed UI and real-feature boundaries.

**Architecture:** retain the three owner services and the approved [runtime ADR](../architecture/adr/0018-container-event-cache-runtime.md). AMQP/cache remain opt-in; no deployment, schema apply or paid provider activation.

**Spec:** [approved feature plan](REAL_FEATURES_SETUP_PLAN_20261025.md), [design](../design/DESIGN.md), [release gates](../quality/RELEASE_GATE.md).

## Constraints and review focus

- Preserve actual test assertions; do not skip failures, add blanket pixel tolerance or regenerate unreviewed screenshots.
- Distinguish platform/font rasterization from changed geometry, fixture state and asynchronous native asset loading.
- Keep broker confirmation distinct from durable application acceptance; malformed/foreign deliveries must fail closed.
- One Flutter process at a time; backend repair owns shared transport interfaces and the pnpm lock exclusively.
- Only report a workflow green from its completed run on the final candidate SHA.

## Tasks

- [x] Fetch all refs; fast-forward the clean checkout to `76221b5`, including the merged Phase 1 inventory.
- [x] Integrate `fix/mobile-ci-baseline`, `fix/mobile-pixel-perfect-screens` and `wip/phase5-amqp-adapter` on `codex/ci-green-integration`; the WIP includes `feat/phase5-amqp-redis`.
- [ ] Reproduce backend failures; repair AMQP dependency/type/test defects in `services/shared` and validate `pnpm backend:verify`, smokes and runtime checks.
- [ ] Reproduce merged Flutter failures; inspect failing screenshot artifacts against existing source references. Repair fonts/fixtures/layout/lifecycle at their cause and add targeted regressions where behavior changes.
- [ ] Validate source-backed baseline changes individually; retain strict comparisons and document platform-specific evidence if required.
- [ ] Run contracts, API lint, schema dry-run/tests, seeds, content, blueprint/audit, secret scan, Flutter analyzer/full tests and Android build.
- [ ] Push the integration candidate, inspect actual GitHub workflow results and repair remaining CI/Android native failures.
- [ ] Merge the verified integration into `main`, push normally, verify remote identity and final required workflows, and record actual remaining release limitations.

Starting CI failures: mobile has historical screenshot mismatches; the unfinished AMQP branch fails TypeScript on an undeclared `amqplib` import and an explicitly undefined optional `messageId`. These are diagnoses to verify, not declarations of completion.
