# Repository cleanup and teammate handoff

> Follow the existing task protocol. Root owns cleanup, root ignore rules and
> handoff documentation; one isolated reviewer checks backend specification
> readiness without editing canonical contracts.

**Goal:** remove confirmed temporary/generated clutter and provide an accurate
entry point for a teammate without losing source, original assets or evidence.

**Architecture:** preserve the frozen Flutter frontend, Learning/Progress/AI
service boundaries and canonical documentation owners. This task does not
implement backend services or advance production phase gates.

**Spec:** [reading order](../00_READ_ME_FIRST.md),
[implementation plan](IMPLEMENTATION_PLAN.md),
[task protocol](TASK_PROTOCOL.md). Date: 2026-10-09, Asia/Saigon.

- [x] MAINT-HANDOFF-047: inventory tracked and ignored files, sizes and references;
  identify generated cache/temp/build candidates. Preserve configuration,
  canonical documents, source, locks, original reference assets and linked QA.
- [x] MAINT-DOCS-048: verify backend design coverage versus implemented services;
  add a concise teammate entry point linking canonical owners and real commands.
- [x] MAINT-CLEAN-049: delete only confirmed generated/temp candidates using
  native PowerShell literal paths, after checking each absolute target stays
  inside the workspace and does not traverse a reparse point. Preserve active
  preview delivery. Record exact categories/counts/bytes without secret contents.
- [x] MAINT-QA-050: run applicable blueprint/schema/link/asset-ledger checks and
  inspect Git diff; confirm no source/config/reference loss. Record evidence
  before marking completion and update the root README for the handoff.

## Evidence

[Cleanup receipt](REPOSITORY_CLEANUP.json): 9,112 files / 3,549,031,985 bytes
removed; all 2,346 tracked file hashes matched before/after deletion. No tracked
temporary files were found. Original source/assets/evidence were preserved.
Backend implementation boundaries and canonical links are in the
[developer handoff](DEVELOPER_HANDOFF.md).

Fresh checks: blueprint/document links PASS; 94 schemas compiled and 30 contract
fixtures PASS; 951 saved source PNGs / 239 bundled PNGs match; existing source
completion evidence validates; Git diff whitespace is clean. Ignore rules reject
disposable editor/OS/backup files. This documentation/generated-state cleanup
does not claim a new Flutter build, device run or backend runtime test.

The auxiliary pinned AJV verifier was installed outside the repository in a
task-specific Windows Temp directory. Automatic approval review blocked its
recursive removal with only “blocked by policy”; it remains outside Git and the
handoff. No deletion boundary was bypassed.
