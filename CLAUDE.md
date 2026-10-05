# Claude Code

@AGENTS.md

Follow docs/agent/TASK_PROTOCOL.md. Read nearest module AGENTS.md manually when working from the root. Canonical skills are .agents/skills; .claude/skills entrypoints point to them. Use one reviewer only when an isolated review improves correctness; architecture-reviewer and design-qa are read-only. Do not start a swarm or invoke every skill.

Project hooks format edited Dart, scan staged secrets before a commit tool call, and validate completion at Stop. They do not establish deployment approval or physical-device evidence. Read docs/agent/AGENT_SYSTEM.md for hook/MCP behavior.
