# Gummble research and connection workflow

Implementation update2026-10-04: live MCP connected and ordered local references now cover150 screens across16 selected flow families. [Full frontend receipt](qa/FULL_FRONTEND_REPORT.md) records native UI coverage,127 byte-identical bundled illustration sources, builds and remaining fidelity gaps. User explicitly chose original Duolingo art/style for this local reproduction, overriding the earlier mascot/color adaptation described below. The catalog remains an archived reference, not a current installed app or source-animation exporter.

Checked 2026-10-03; configured MCP succeeded. Official [MCP offer](https://gummble.com/mcp) requires paid access or an eligible active trial. Category PAID_ONLY / TRIAL; no “free tool” claim. Runtime app and CI do not depend on it.

Catalog resolution: Duolingo iOS app ID35a6799c-14cf-42d6-83e2-56d15a537124, slug duolingo-ios. Latest returned version800, **Dec30 2025**, 1,103 screens; previous Jan17 2025 has310. This is a reference snapshot, not a verified October2026 binary. Three flows retrieved: onboarding20 steps; completing lesson22 steps; video-call lesson10 steps. A batch response truncated its 52-screen listing; a separate lesson fetch returned all22 positions. No hidden steps were claimed as visually inspected.

| Inspected reference | Observation / adaptation | Public link |
|---|---|---|
| sc_057cfe7c098d4552bd9c2a51ef0a25ec | bright mascot welcome, sparse loading; use own character and accessible launch status | [welcome](https://gummble.com/screens/sc_057cfe7c098d4552bd9c2a51ef0a25ec) |
| sc_e793f7fdfb3349cc8a32a78d9648ee07 | section/unit header, unit guide icon, curved vertical nodes, active ring, locked grey nodes, bottom menu; hearts visible in this capture | [path](https://gummble.com/screens/sc_e793f7fdfb3349cc8a32a78d9648ee07) |
| sc_9b41633c08e24f17881574c5005298c9 | contextual Video Call popover, optional “later”, avatar and path node | [call entry](https://gummble.com/screens/sc_9b41633c08e24f17881574c5005298c9) |
| sc_b7f6add9477e4c57ba0ed0bc101a37d9 | four image choices; selected pale-blue surface and border, prompt/audio, bottom CHECK | [image choice](https://gummble.com/screens/sc_b7f6add9477e4c57ba0ed0bc101a37d9) |
| sc_ceb894f17ed14dd08762802759a22ced | audio-to-word pair tiles, “can't listen” and disabled Continue | [audio matching](https://gummble.com/screens/sc_ceb894f17ed14dd08762802759a22ced) |
| sc_558735dae0764612a6689f107c75e6cf | focused daily quest update after lesson, count/progress/Continue | [quest update](https://gummble.com/screens/sc_558735dae0764612a6689f107c75e6cf) |

Flow links: [onboarding](https://gummble.com/apps/duolingo-ios?tab=flows&flow=e6ac09f7-6131-435e-8c21-dae693af84a7), [lesson](https://gummble.com/apps/duolingo-ios?tab=flows&flow=068dbdc0-5d4a-4de2-a477-b0e5c8cdc3e8), [video call](https://gummble.com/apps/duolingo-ios?tab=flows&flow=de439dd6-fe0d-4fdd-85a9-95dd3f9d9cf9).

## Codex

Official [Codex setup](https://gummble.com/blog/gummble-mcp-in-codex-setup-oauth); local CLI0.153.4 help confirms --url.

~~~powershell
codex mcp add gummble --url https://mcp.gummble.com/mcp
codex mcp list
# Only when authorization is still required:
codex mcp login gummble
~~~

The add path can complete browser OAuth; do not start a duplicate login immediately. Alternative trusted project configuration:

~~~toml
[mcp_servers.gummble]
url = "https://mcp.gummble.com/mcp"
~~~

Use the CLI global entry or project entry once; do not duplicate both. OAuth credentials remain in the client credential store. Project config shares endpoint only. Never commit tokens. Verify a real search, not only “connected”.

## Claude Code

Official [Claude setup](https://gummble.com/mcp/claude-code):

~~~powershell
claude mcp add --transport http --scope user gummble https://mcp.gummble.com/mcp
claude mcp list
~~~

In a Claude session run /mcp → gummble → Authenticate. For repository scope use --scope project; it writes .mcp.json. Each collaborator authenticates separately. Verification prompt: “Use Gummble to search for Duolingo onboarding screens.” Registration is not entitlement proof.

Reconnect: inspect exact URL, paid/trial entitlement, login status and proxy; refresh authentication through client when needed. “Auth unsupported/no authorization support” can indicate older Codex OAuth discovery behavior; update client and retry documented login. HTTP401 means auth,403 can mean entitlement; do not loop login on403. Catalog gaps are legitimate, not proof an app lacks a feature.

## Screen workflow

Read DESIGN + screen/SRS IDs → search pattern family → exact app/flow → fetch several reference metadata/screens → compare layout, hierarchy, state, microcopy and date → map to project tokens → implement Flutter fixture states → screenshot visual QA → document deliberate differences. Use gummble_search_microcopy for error/empty wording when needed. Public official design and previously recorded references are fallback when MCP is unavailable. Gummble supplies research, not a production Flutter code generator.
