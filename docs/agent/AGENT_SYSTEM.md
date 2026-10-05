# Agent engineering system

Official mechanisms: [Codex guidance](https://developers.openai.com/codex/guides/agents-md), [skills](https://developers.openai.com/codex/skills), [Claude skills](https://code.claude.com/docs/en/skills), [agents](https://code.claude.com/docs/en/sub-agents), [hooks](https://code.claude.com/docs/en/hooks). Research checked2026-10-03; versions/features change, recheck exact CLI behavior before configuration changes.

Root AGENTS short; mobile and three service AGENTS add only differences. Codex chain is built root→current directory; workers launched at repository root explicitly read nearest module guidance. No AGENTS.override shadow file is needed. CLAUDE imports root AGENTS and likewise reads nested instructions; no duplicated full SRS.

Four canonical skills in .agents/skills: coc-flutter-feature (layering/behavior tests), coc-service-change (transactions/ownership/contracts), coc-ai-provider (adapter/null scoring/limits), gummble-ui-research (reference/state/visual QA). .claude/skills entrypoints only link canonical body because Claude's documented project discovery is .claude/skills. Avoid symlink privilege requirements on Windows; wrappers have no copied procedure. No skill demands a hundred-file reading pass.

Two Claude agents: architecture-reviewer covers ownership/contracts/auth/distribution/test gaps; design-qa covers references/state/semantics/device visual evidence. Read-only; no swarm per small task. Root human policy cap2totalnative contexts and targeted main-thread search persists.

## Hooks

.claude/settings.json defines command hooks:
- PostToolUse matcher Edit|Write: format only changed Dart file using a resolved Dart executable. Never run all tests after each edit.
- PreToolUse matcher Bash: before a git commit command, require the workspace's own Git root and run staged gitleaks; missing scanner/Git or scanner error log fails closed even if scanner returns0. CI secret scan remains final defense; string detection is not a complete shell security parser.
- Stop: if stop_hook_active skip recursion; validate docs/contracts; after application code exists run verified package gate at task completion. No automatic deployment or external messaging.

Commands call tools/agent/hooks.mjs. Input file path must resolve inside repository; tools use argument arrays/constant commands, not interpolated shell source. Hooks skip app tests during Phase0 and explicitly report that only blueprint checks ran. P1 installs/pins gitleaks and verifies hook paths on Windows/macOS. Hook formatting is a local reversible action; explicit broader test commands and CI own acceptance evidence.

MCP templates .codex/config.example.toml and .mcp.example.json contain public Gummble endpoint only, not active project registration or OAuth secrets. Use setup [GUMMBLE_RESEARCH](../design/GUMMBLE_RESEARCH.md), verify existing global server before adding. Existing Exa/browser/Memory are development tools, not app dependencies. Read-only Appwrite docs tooling optional; do not register cloud administrative keys broadly in an agent MCP.

Claude-Mem hooks are session layer; local Memory is project-scoped durable decisions, no secrets/conversations. Failed memory must not block work; no server integration install in Phase0. Main task claims/evidence reside in repository, not private memory.
