# GitHub development snapshot

2026-10-05. The user explicitly requested uploading the entire current CocEnglish
project to the private repository [ducvuathuduc/CocCoc](https://github.com/ducvuathuduc/CocCoc).

The Git snapshot includes Flutter source/platform scaffolds, dependency locks,
local fonts/Lottie/Rive assets and web runtime, service scaffolds, infrastructure
examples, project instructions/skills, tools, tests, design analysis, ordered
Gummble references and QA captures/logs. The Android Gradle wrapper JAR and both
launchers are included so another checkout has the wrapper needed to build.

[File inventory](github-upload-manifest.json) records every project file in this
snapshot with byte counts and SHA-256. Its own file is excluded from its hash
list to avoid a recursive checksum. Git's tree identifies the complete committed
set, including the inventory itself. No local source/asset/document family is
intentionally omitted.

The private GitHub Release `mock-preview-2026-10-05` packages the complete built
web directory and all three current Android release APKs, with a checksum receipt.
These are local mock builds, not a store release. The source archive is available
from GitHub alongside the repository. Runtime uses mock authentication by default.

Regenerable SDK/package/build caches, machine-specific IDE/runtime state,
credentials, signing keys and private exports stay excluded by the committed
ignore rules. Build outputs are delivered as Release downloads rather than
duplicated in source history. Public environment/config examples remain included.

Verification: [239-test gate and build evidence](ENGLISH_EXTENDED_REPORT.md),
[build hashes](english-current-artifacts.json) and staged redacted secret scanning.
Run `pnpm verify` from the repository root. Set `FLUTTER_ROOT`, then use
`pnpm build:web` / `pnpm preview:web` for the local browser preview; Android release
build command is recorded in the current QA receipt.

This upload preserves the current implementation. Catalog reconciliation,
exact archived pixel/motion timing, backend/production phase gates and physical
device/iOS verification remain open in the frontend plan.
