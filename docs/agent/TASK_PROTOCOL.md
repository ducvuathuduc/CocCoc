# Task, definition-of-done and change policy

Before edits: root/nearest AGENTS → current phase gate → task row → SRS/screen/contract/storage → relevant ADR → targeted code navigation → dependency/change-area claim → test plan. Do not load every document for a small task.

Task claim record: taskId, phase, owner, branch/worktree, dependency gate receipts, exclusive paths, requirements, interfaces, test command, status QUEUED/CLAIMED/IN_PROGRESS/VERIFYING/DONE/BLOCKED, evidence links. Store records in docs/agent/task-status.json during P1; no user/private credentials. BLOCKED records a concrete external prerequisite; never means “hard”.

Behavior work: write failing acceptance test, run red, implement minimal slice, run targeted tests, broader gate only as needed; update canonical changed spec only if behavior/decision changed; attach artifact/check identity; record DONE only after evidence. Docs/copy changes validate references/semantics without pointless implementation-mirroring tests.

Definition of Done: assigned SRS/edge cases implemented; wire/storage/ownership unchanged or approved ADR; targeted and required checks pass; accessibility/offline/error state documented; no keys/billing drift; dependency lock/generated diffs intentional; screenshots/device/live capability evidence when required; task evidence recorded; no unrelated edits. Build/lint/unit/device/load/live-provider evidence are distinct.

Phase exit: all required phase tasks DONE, evidence reproducible, no unresolved P0 behavior/security issue, updated phase state and all predecessor gates. Optional external capability can remain disabled with reason if phase explicitly permits that baseline. Agent cannot self-certify a physical test never run.

## Architecture freeze / ADR change

Frozen languages, frontend layering/state manager, business boundaries, API conventions, data owners/auth, repository layout and journal. Change requires problem, current evidence, alternatives, chosen change, consequences, migration/rollback, affected canonical docs and approvalStatus. Minor details within specified bounds do not require a new ADR. An agent records PROPOSED and continues independent work; implementation of an architectural deviation awaits human approval. Current task authorizes the V1 blueprint, not future production external actions.

## Parallel work and Git

SAFE_PARALLEL only within same open phase and disjoint paths. DEPENDS_ON gates block downstream task; BLOCKS labels identify held dependents. EXCLUSIVE_CHANGE_AREA: openapi, root router, pubspec/pnpm locks, infrastructure schema/migrations, shared backend-core interfaces and phase state. One owner at a time. Use ordinary Git branches/worktrees for isolated task execution after repository exists; don't fabricate remote branch/ref. Review integration against same contract commit before merging. Native fork cap2total per user quota policy; bulk reading stays targeted main-thread rg/AST.

Completion report shape: task IDs and outcome; changed paths; test commands with counts/status; artifacts; limitations; next gated task. No fabricated performance or “production ready” claim from mock tests.
