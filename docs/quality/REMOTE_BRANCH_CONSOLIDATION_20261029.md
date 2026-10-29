# Remote branch consolidation — 2026-10-29

The human requested a complete remote-branch review, integration into main and deletion of unnecessary branches. The checkout was clean, but initially shallow and configured to fetch only main. Full history and all heads were fetched before comparing ancestry. This task does not advance any product phase gate.

## Branch analysis

There were 23 remote heads: main, 20 branches already included in its history, the hardening branch with 16 new commits, and the orange-brand branch with one new commit. Commit date alone was not used to select code. Every branch tip was compared through ancestry and unique commits; final deletion requires the recorded tip to be reachable from the published main and unchanged on the remote.

Original main: `52526771df15eb3b52950b54a0f09d50416e7671`.
Integration merge: `fd9311b` (parents include hardening `b290957` and orange branding `4beb299`).

| Remote branch | Original tip | Disposition |
|---|---|---|
| `codex/ci-green-integration` | `08307ab2d2962c05993762bb69480f5b07ad1b1f` | Already an ancestor of original main |
| `codex/flutter-onboarding-login` | `49f9097378ebc7b2b8dd30eb3a67217fb3f2fc35` | Already an ancestor of original main |
| `docs/phase1-real-features-inventory` | `f53eaba3ec957312b0cd297643c6024af257b330` | Already an ancestor of original main |
| `feat/cocenglish-orange-brand` | `4beb299835936775f713f2273830ed96b1e2ea03` | 1 new commit integrated |
| `feat/payment` | `6b511c04b7d3b3d9d6e889176a8186b5b83c509d` | Already an ancestor of original main |
| `feat/persistent-mistake-review` | `5554fd9578d7fb1a4ce67a3a6813fce5b61cdec7` | Already an ancestor of original main |
| `feat/personal-vocabulary-srs` | `537ca75d65b5dc3cc1574a33f55c770eb434a5b3` | Already an ancestor of original main |
| `feat/phase5-amqp-redis` | `5a0770ec5eac37e28aec7bcf1d3b61973313f59f` | Already an ancestor of original main |
| `feat/pronunciation-assessment` | `9763dd91cf14235b68dd7dfbfa19d89f011b1073` | Already an ancestor of original main |
| `feat/real-learning-flow` | `f2ffe88ea6f2a9a50fda680cc15ca42babf229f2` | Already an ancestor of original main |
| `feat/real-learning-stats` | `a9407cb5041c248d0ce0f404578b51a7da2c4bb9` | Already an ancestor of original main |
| `feat/real-placement-test` | `8dd54507755702e1de663547d2151f8a5f9d23b7` | Already an ancestor of original main |
| `fix/mobile-ci-baseline` | `192ccebb27a05f22c45971ee5914a5bc80ae63ad` | Already an ancestor of original main |
| `fix/mobile-pixel-perfect-screens` | `d585b6a92422050287bca80659895e032c6995c5` | Already an ancestor of original main |
| `hark/int-phaseA` | `dbe5a7645bb3428caf1bb524cde9380de1960ba2` | Already an ancestor of original main |
| `hark/master-i1-i2` | `965b184aa5721c679a0da575f6b7f6946c8270c7` | Already an ancestor of original main |
| `int/phaseA` | `dbe5a7645bb3428caf1bb524cde9380de1960ba2` | Already an ancestor of original main |
| `main` | `52526771df15eb3b52950b54a0f09d50416e7671` | Original main |
| `pb/notify` | `1902950174f9b61e6df0d70a3c59352f0cf9b372` | Already an ancestor of original main |
| `pb/notify-merged` | `1a5e8369b860e062175dfdaebbbba35bd8c29725` | Already an ancestor of original main |
| `pb/progress2` | `4c8e998734d619d81f7b48ecda9905ae071fe5bb` | Already an ancestor of original main |
| `wip/codex-20261027-hardening` | `b2909578540ffaad69acd2dcb6463296ecc0a3cc` | 16 new commits integrated |
| `wip/phase5-amqp-adapter` | `6eec88c5d20e7e43d1b9045c3db9fe15055c1bbb` | Already an ancestor of original main |

## Integration corrections

- Resolved three conflicts: retained the new orange launch/PWA identity and the newer ReferenceArt blend-mode behavior alongside mascot replacement. Automatic merges in pubspec and Super trial were reviewed.
- Restored the ReferenceArt import required by the newer Android Super comparison.
- Regenerated the Postman collection after the auth/config changes; no operation or secret was added.
- Updated two negative schedule-drift tests whose mutations had become no-ops after the Education-plan cron disablement. Configuration and validators remain unchanged.
- Canonical Linux golden candidates are reviewed for intended orange-mascot and Google-only UI changes. Windows rendering differences are not used to rewrite baselines. The temporary artifact-only candidate workflow is removed before main integration.
- Updated dark-shell mascot bounds, large-text review and capture assertions for the new decorative SVG; ordinary artwork must still decode and review text must remain unscaled by a FittedBox. The two primary nonvisual regressions were reproduced before the test-only corrections.
- The existing brand mapping intentionally replaces entire composite illustrations containing an owl, including gift backgrounds and the decorative path-return scene. This removes scene context while retaining native controls; the path-return unit banner still navigates to `/home`. Full-size comparisons found no unrelated font or control-layout drift.

## Verification

Local evidence logs are in `.cache/remote-consolidation/`.

| Command / check | Result and scope |
|---|---|
| `pnpm install --frozen-lockfile` | Passed; pinned dependencies retained |
| `pnpm backend:verify` | 332 tests: 320 passed, 12 live-gated skips, zero failures; TypeScript, builds, lint and format passed |
| `pnpm backend:smoke`, `pnpm dev:smoke` | Passed; local fixtures and real loopback HTTP/signed-event replay |
| `pnpm local:test` | 32 passed |
| `pnpm contracts:check`, `pnpm postman:check`, `pnpm api:lint` | Passed; 157 schemas, 110 fixtures, 91 operations, empty environment secrets |
| `pnpm postman:test`, `pnpm postman:run:local` | 5 tests passed; loopback execution of all 91 operations, 137 requests, 408 assertions, zero failures |
| `pnpm schema:plan`, `pnpm schema:test`, `pnpm seed:check` | Passed; 24 schema/ops tests, no cloud mutation |
| `pnpm blueprint:check`, `pnpm audit:check` | Passed; structural/link/traceability checks |
| `pnpm runtime:check`; Node tooling tests; `node tools/evals/voice-harness.mjs` | Passed; three tooling tests, fixture-only voice evaluation, no provider calls |
| `node tools/scripts/local-load.mjs --requests=100 --concurrency=10` | 100/100 local in-memory requests succeeded; not production capacity |
| `pnpm verify` on Windows | Format clean (653 Dart files), analyze zero issues; 1,370 passed and 275 failed before canonical refresh. Log review isolated two primary nonvisual assertions, now fixed; other exceptions were pixel differences or their cascades. Windows was not used to generate baselines |
| Targeted mascot/dark-shell/year-review Flutter tests | Red: 13 passed, 2 failed. Green with existing mascot tests: 22/22 passed |
| Canonical Linux candidate [run 40849796439](https://github.com/ducvuathuduc/CocCoc/actions/runs/40849796439) | 1,643 passed, the same two nonvisual assertions failed before their fixes; generated 83 changed PNG candidates. Dimensions unchanged. Reviewed at narrow/wide and text scales 1/2; changes are orange mascot replacements and Google-only controls |
| Strict canonical verification of final candidate | Pending |
| Palette check with bundled Python `-X utf8 tools/palette_check.py` | Informational: 86 unmatched legacy/brand colors including intentional new `#F47721`; 110 lesson SVGs use 36 sampled colors with zero mismatches. Brand tokens are recorded in [DESIGN](../design/DESIGN.md) |

The opt-in course capture passed all states and produced 17 screenshots only in ignored cache. The existing opt-in English lesson capture still stops at its stale `GOT IT` audio interaction in both the original and corrected capture test, before mascot assertions; this unrelated capture prerequisite remains open. Tracked historical QA captures were not rewritten.

## Publication and cleanup

Pending final canonical checks. Publish main with a normal fast-forward push, then remove only remote branches whose recorded tips are still unchanged and ancestors of main. The integration branch is removed after completion. Branch deletion removes names; original commits remain in main's Git history and can be restored using the tips above.

No cloud deployment, schema apply, live provider, payment activation, production-capacity claim or physical-device/iOS acceptance is part of this consolidation. Appwrite deployment remains manually dispatched.
