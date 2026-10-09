# Professor demo and honest evidence sequence

The local sequence below is runnable now with restored dependencies. Cloud deployment and a signed/physical Android presentation are a later admitted task. [Windows setup](../devops/LOCAL_SETUP_WINDOWS.md) contains prerequisite commands.

1. `git status --short`; identify candidate commit and dirty refresh diff. Show [entry](../00_START_HERE.md), three owners and current capability gates.
2. `pnpm install --frozen-lockfile`; restore Flutter dependencies without upgrading the lock. `pnpm backend:verify`, `pnpm contracts:check`, `pnpm api:lint`, `pnpm audit:check`.
3. `pnpm backend:smoke`: show pending before delivery, failed receiver commit, lost ack/redelivery, one inbox effect and ledger XP. Explain that fixture state is in memory; no cloud claim.
4. `pnpm mobile:verify`; `pnpm build:web`; `pnpm preview:web`. Demonstrate onboarding/login fixtures, English path, CHECK/feedback/pause/results, mistakes/listen/speak simulation, settings and account recovery.
5. Android debug compilation now has a fresh [artifact/hash receipt](../audit/BUILD_ARTIFACTS.json). The default global-cache build failed; the repo-local Gradle user-home retry passed. Use the environment command in [Windows setup](../devops/LOCAL_SETUP_WINDOWS.md) when rebuilding. Before a device demo, review SDK licenses, connect device, then install/run the APK with native Flutter/device tooling. Record checksum/device/video separately; no Android device test was run in this refresh.
6. For an authorized Cloud rehearsal, complete [Appwrite admission](../devops/APPWRITE_SETUP.md), deploy three separately built revisions and seeded immutable content, then exercise real auth/lesson/reward. Show actual project resource IDs/revisions/log trace rather than descriptors.
7. Inject Progress outage; complete lesson; show pending reward, retained outbox, recovery, dedupe and authoritative convergence. Demonstrate cross-user read/write rejection and old JWT revocation.
8. Disable AI/force quota429; demonstrate authored/typed/shadowing fallback and null pronunciation metrics. Actual live audio only after P8 benchmark; no provider keys on mobile or in logs.
9. Show a real GitHub run/artifact if executed by the project owner; local successful checks and committed workflow files alone are not green GitHub evidence. Demonstrate test failure/recovery in a fixture branch rather than breaking production.
10. Show previous artifact/rollback plan, encrypted backup/restore receipt, plan expiry/cost admission, unresolved limits and optional iOS simulator/signing evidence. Do not deploy/publish during an unauthorized demo setup.

Offline mid-lesson and app kill require durable journal gate, currently pending. Subscription preview is simulation, not checkout. Real voice, push, outbox Cloud delivery, signed iOS and restoration must be shown only when their receipts exist.
