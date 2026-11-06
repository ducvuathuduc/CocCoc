# Branding PR CI repair — 2026-11-06

Scope: [PR #6](https://github.com/ducvuathuduc/CocCoc/pull/6), original head `02b20e5`, integrated with main `12b1222`. The user's final direction is CI/CD only: retain the new branding and removal of proprietary assets; simplify unnecessary pipeline gates. No product phase advances.

## Repairs

- Original backend [run 41983359837](https://github.com/ducvuathuduc/CocCoc/actions/runs/41983359837) stopped at stale generated Dart contracts. Original mobile [run 41983359878](https://github.com/ducvuathuduc/CocCoc/actions/runs/41983359878) stopped at twenty unformatted Dart files. Merge main's contract/format fixes and resolve ten conflicts while retaining its current dark palettes, shared score dialog, promo handling and Drift dependencies.
- Keep the branding branch's current artwork and code-drawn avatar. No archived vocabulary artwork, proprietary fonts or rigs are restored. CI tests use the open licensed Roboto test font from the pinned Flutter SDK, without adding font files to the app bundle.
- Repair the missing illustration blend API, preload the current owned poses for deterministic tests, replace the stale Super background asset reference with a native gradient, and fix the translation action's large-text overflow. These are build/test compatibility repairs.
- Replace retired Rive/font-specific assertions with tests of the current static mascot, avatar repainting, lifecycle/reduced motion and retained interaction behavior. Update Linux golden baselines explicitly; ordinary CI still compares them normally.
- [CI/CD](../devops/CI_CD.md) now keeps code checks, tests, builds and secret scanning automatic. Extended documentation/schema/Postman/load/fixture checks and duplicate container builds run manually. PR + main triggers remove duplicate feature-push runs. Remove obsolete Rive host-runtime installation from mobile verification.

## Evidence

| Check | Result |
|---|---|
| Frozen pnpm install | PASS; locks unchanged |
| `pnpm backend:verify` | 332 tests: 320 pass, 12 explicitly gated live skips |
| `pnpm backend:smoke`; `pnpm dev:smoke` | PASS; fixture delivery and real local HTTP/HMAC cases |
| `pnpm contracts:check`; `pnpm api:lint` | PASS; 157 schemas, 110 fixtures, generated Dart current |
| Workflow regression tests | First failed on duplicate triggers and mandatory extended checks; 2 pass after simplification |
| Extended commands run during diagnosis | local tests 32 pass; Postman tests 5 pass and all 91 baseline operations / 408 assertions pass; schema tests 24 pass; blueprint/audit/seed/runtime/load/voice fixture checks pass |
| Targeted mobile compatibility tests | PASS |
| Dart format and analyzer | PASS; zero format drift and no analyzer issues |
| Full pinned Linux Flutter suite with explicit golden maintenance | 1,641 pass, 1 configured skip; 30 targeted tests also pass with ordinary golden comparison; complete GitHub frontend verification and Android APK build also pass |

Linux uses Ubuntu 24.04, Flutter 3.47.0 and Dart 3.13.0. Local WSL settings are restored after verification. Palette scanning remains informational; the repair retains the original branding palette rather than imposing another design gate.

## GitHub

Verified code candidate: `75f5c9311c0c7b12dbfa569fe725be5f8c0a0bab`. PR #6 is mergeable.

- [Backend](https://github.com/ducvuathuduc/CocCoc/actions/runs/42077189163): SUCCESS.
- [Secret scan](https://github.com/ducvuathuduc/CocCoc/actions/runs/42077189155): SUCCESS.
- [Mobile / Android](https://github.com/ducvuathuduc/CocCoc/actions/runs/42077189174): SUCCESS; frontend verification and APK build passed.

The separate .NET migration repair passed [its workflow](https://github.com/ducvuathuduc/CocCoc/actions/runs/42068811813), including 750 tests, seven gated live skips, Linux tests and three-host smoke, and remains on its separate feature branch.

No deployment, publication, schema apply, main merge, live provider calls or physical-device/iOS acceptance is part of this task.
