# MASTER PROMPT — Wave 2: Session Modes + Clean-Code / Microservice / Pixel Hardening

> Paste this whole block to DeepSeek as one task. It is contract-first, then a
> 4-team parallel fan-out. Read it fully before writing any code.

---

## ROLE

You are the lead implementer for CocEnglish (Flutter + 3 Node/TS microservices on
Appwrite). You will run this as **sub-agent teams working in parallel**, each team
owning ONE exclusive directory so no two teams ever touch the same file. Spawn the
teams as described in EXECUTION. Do not hand the whole job to one worker.

## GROUND TRUTH — read these first, never duplicate them

- Requirements: `docs/product/SRS.md`
- Wire format (JSON, read as JSON): `docs/api/openapi.yaml`
- Storage: `docs/data/DATA_MODEL.md`
- Phases: `docs/agent/IMPLEMENTATION_PLAN.md`
- Repo rules: root `AGENTS.md` + nearest nested `AGENTS.md`
- Current session modes live in `services/learning/src/content/types.ts`:
  `SESSION_MODES = ['LESSON','REVIEW','MASTERY','PLACEMENT']`

## GOAL (one sentence)

Add the 8 missing session modes end-to-end and harden the codebase to production
clean-code / microservice / pixel standards, WITHOUT breaking the 4 existing modes
or any existing golden.

Missing modes: `STORIES`, `ADVENTURE`, `RADIO`, `SIDE_QUEST`, `CLASH`,
`UNIT_REVIEW`, `TEST_OUT`, `CHECKPOINT`.

---

## HARD CONSTRAINTS (violating any = reject your own work)

1. **One owner per exclusive area.** `openapi.yaml`, the root router, lockfiles,
   `appwrite/schema`, and `services/shared` interfaces are single-owner. Never let
   two teams edit the same file.
2. **Contract-first, serialized.** `openapi.yaml` changes happen in PHASE 0 by ONE
   agent, additively (add to the mode enum + new DTO + new error codes — never
   change the meaning of an existing field). Generate DTOs with
   `pnpm contracts:generate`. Only AFTER phase 0 commits do the 4 teams start.
3. **No service writes another service's tables.** Learning owns `l_*`, Progress
   owns `p_*`, AI owns `a_*`.
4. **TDD.** For every behavior change write a meaningful FAILING test first, then
   implement, then make it pass. Paste the red output and the green output.
5. **Never run `--update-goldens`. Never edit a golden image.** Golden is a Linux
   CI gate, not a Windows local gate. On Windows, Rive needs VC++ runtime +
   `rive_native.dll` on PATH (already set up on this machine).
6. **Hosted entrypoints stay fail-closed with disabled adapters.** In-memory stores
   only in `src/testing/`, `src/dev.ts`, tests.
7. **No deploy, no schema:apply, no merge to main, no force-push, no paid plan.**
   Push only to the feature branch `wip/codex-20261027-hardening` by explicit name.

## DEFINITION OF DONE (the only thing that counts as finished)

Run from repo root after `pnpm install --frozen-lockfile`, paste all output:

```
pnpm backend:verify
pnpm backend:smoke
pnpm dev:smoke
pnpm contracts:check
pnpm postman:check && pnpm postman:test && pnpm postman:run:local
pnpm api:lint
pnpm schema:plan && pnpm schema:test && pnpm seed:check
pnpm blueprint:check && pnpm audit:check
cd apps/mobile && flutter analyze --no-pub && flutter test --no-pub
```

A document check is NOT evidence. Only a pasted command result is.

---

## EXECUTION — phases and parallel teams

### PHASE 0 — Contract-first (ONE agent, no parallelism)

Owner: a single agent. Nobody else runs yet.

For EACH of the 8 modes, in `docs/product/SRS.md` first define: the rule (what the
mode does), reward policy (XP-eligible? placement-style no-XP? review-style?), and
error codes. Then in `docs/api/openapi.yaml` ADD the mode to the session mode enum,
add any new request/response DTO fields behind the new mode, and add new error
codes — all additive. Then:

```
pnpm contracts:generate
pnpm contracts:check
pnpm api:lint
```

Commit as: `feat(contract): add 8 session modes to OpenAPI (additive)`.
STOP. Hand off to the 4 teams only after this commit is green.

### PHASE 1 — 4 teams in parallel (spawn 4 sub-agents, one per area)

Each team owns exactly one directory tree. They never touch each other's files.

| Team | Owns (exclusive) | Job |
|---|---|---|
| **A — Learning** | `services/learning/**` | Add the 8 modes to `SESSION_MODES`, add a handler branch + writer per mode in `src/application/sessions.ts` (and `review.ts`/`practice.ts` where the mode is review/practice-shaped). Behavioral test per mode. Keep LESSON/REVIEW/MASTERY/PLACEMENT untouched. |
| **B — Progress** | `services/progress/**` | Reward/XP projection for the new modes in `src/application/rewards.ts` + `domain/lesson-xp.ts`. Respect each mode's reward policy from SRS (e.g. TEST_OUT/CHECKPOINT reward rules). Behavioral test per rule. |
| **C — AI** | `services/ai/**` | Only if a mode needs AI (e.g. STORIES/RADIO narration, CLASH prompts). Wire through the capability gate; live adapters stay disabled. Behavioral test. If no AI needed, report "no AI work" and stop. |
| **D — Mobile** | `apps/mobile/**` | A typed renderer per new mode (feature-first Riverpod MVVM). Reuse existing exercise widgets. Widget test per renderer. Do NOT touch goldens; add new tests only. |

Each team, before finishing, runs its OWN targeted checks:
- A/B/C: `pnpm --filter <service> test` (or the repo's service test command) + `pnpm backend:verify`
- D: `cd apps/mobile && flutter analyze --no-pub && flutter test --no-pub <new test files>`

### PHASE 2 — Hardening pass (same 4 teams, same ownership, after Phase 1 green)

Within each team's OWN directory only:

- **Clean code:** no dead code, no TODO/FIXME, no `any` in TS, no unused Dart. One
  responsibility per function; split functions over ~40 lines where it clarifies.
  Match the file's existing style exactly — do not reformat unrelated lines.
- **Microservice discipline:** no cross-service table writes; shared layer holds
  only transport/auth/HMAC; each service owns its writes; fail-closed hosted paths.
- **Per-function optimization:** remove redundant allocations/loops in hot paths
  (grading, projection, journal sync). Prove with the existing tests still green —
  never trade correctness for speed.
- **Pixel fidelity (Mobile only):** match the reference design exactly; new
  renderers reuse existing spacing/typography tokens; no new hardcoded colors —
  use the reference palette. Do not alter existing golden-covered screens.

### PHASE 3 — Full gate + report

One agent runs the full DEFINITION OF DONE list from root, pastes every result,
and writes a short report: files changed per team, tests added, any mode that
needed a product decision (list it, do not guess).

---

## OUTPUT FORMAT (every team, every step)

- Show the failing test output, then the passing test output.
- Show `flutter analyze` / `backend:verify` result verbatim.
- List files changed, grouped by team.
- If a mode's rule is ambiguous in SRS, STOP and ask — never invent a reward rule.
