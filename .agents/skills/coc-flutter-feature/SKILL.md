---
name: coc-flutter-feature
description: Implement a scoped CocEnglish Flutter feature using its frozen MVVM, typed repository and screen-state contracts.
---

Trigger: assigned Flutter behavior task in an open implementation phase.
Inputs: task ID, SRS/screen IDs, claimed feature paths and predecessor gate.
Read: nearest AGENTS; assigned task; relevant DESIGN/COMPONENT_STATES; OpenAPI schema and STACK when data/dependencies touched.
Procedure: inspect targeted symbols; choose View/ViewModel/repository/service responsibilities; write meaningful failing acceptance case; implement typed state and fake/live repository contract; preserve entered state on error; dispose subscriptions/audio; run targeted unit/widget tests and needed analyzer/generated checks. Major screens use gummble-ui-research before layout.
Output: scoped diff, command evidence, state screenshots when required, task status.
Validation: auth/offline/error/disabled/text-scale2 semantics for touched interaction; deterministic tests; no direct SDK call in view.
Prohibited: replacing Riverpod/Flutter; pass-through use-case ceremony; provider keys; client-authoritative XP; unrelated routing/lock edits; claiming real device proof from fakes.
