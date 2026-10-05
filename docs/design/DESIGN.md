# CocEnglish design system

This is **our engineering DESIGN.md**, derived from public [Duolingo brand colors](https://design.duolingo.com/identity/color), [typography guidance](https://design.duolingo.com/identity/typography), and inspected [Gummble references](GUMMBLE_RESEARCH.md). No official downloadable Duolingo engineering DESIGN.md was established. Exact app spacing/radii below are our chosen tokens, not extracted source constants.

2026-10-04 frontend override: the user explicitly chose the original Duolingo screenshot appearance for onboarding/login, including Duo, icons, fonts and tactile controls. The active implementation uses locally bundled DuolingoSans/Feather, archived illustration regions, and measured reference-specific tokens in `apps/mobile/lib/core/design/`. [Onboarding](flows/01_ONBOARDING.md) and [login](flows/02_LOGIN.md) own screen deconstruction; [asset provenance](../../apps/mobile/assets/PROVENANCE.md) owns input sources. The adaptation tokens below remain the planned product baseline, not the active reference-reproduction palette. Reference fidelity is not a contrast certification or proof of identical motion.

## Visual direction

Bright learning path, round illustrated exercises, thick outlines, tactile bottom-edge buttons, generous space, one clear next action. Flat surface hierarchy; avoid generic KPI cards, gradients, glass effects and desktop-dashboard composition. Use our CocEnglish character illustration, no production dependency on proprietary fonts/assets.

Typography: bundle Nunito Sans for Vietnamese+Latin UI and Nunito for short headings if glyph coverage is verified; system sans fallback during font load. Do not fetch fonts at runtime. Heading28/32 weight800; title22/28 weight800; body18/26 weight600; caption14/20 weight600; button16/20 weight800. Text scaling is respected; no fixed height for multi-line text. Proprietary Feather/DIN are not required.

## Tokens (logical pixels)

| Token | Value / role |
|---|---|
| brand.green | #58CC02; icon/illustration/accent, not small white text background without contrast check |
| action.green | #237A00; accessible primary filled control with white text |
| action.edge | #185900; 4px tactile lower edge |
| accent.blue | #1CB0F6; audio accent; dark text/outline for legibility |
| success.surface / text | #D7FFB8 / #235B00 |
| error.surface / text | #FFE1E1 / #A41414 |
| warning.surface / text | #FFF3B0 / #704D00 |
| surface / subtle / border / text | #FFFFFF / #F7F7F7 / #E5E5E5 / #4B4B4B |
| selected.surface / border | #DDF4FF / #1577A4 |
| disabled.surface / text | #E5E5E5 / #626262; never the sole state signal |
| dark.surface / subtle / text / border | #131F24 / #202F36 / #F1F4F6 / #49616B |
| spacing | 4,8,12,16,24,32,48; screen horizontal20; prompt-to-options24 |
| radius | button16, choice16, sheet24, node999 |
| stroke | default2, selected3, focus3 |
| size | touch≥48; primary min56; path node64; icon24/32; tab64+safe inset |
| width | mobile body max480; lesson bottom action pinned above keyboard/safe area |
| shadow | 4px solid lower edge for buttons/nodes; ordinary surfaces no soft elevation |

White on #58CC02 is not assumed to meet small-text contrast. Accent fidelity yields to readable controls; phase2 records contrast ratio for every text/control pairing and uses dark text or action.green where needed.

## Components / assets

Required components: TactileButton, ChoiceTile, WordToken, PairTile, LessonHeader, AnswerFeedback, PathNode, UnitBanner, StatPill, SkillTile, ProgressRing, QuestRow, LeaderboardRow, Avatar, EmptyState, RetryPanel, OfflineBanner, SyncBadge, PermissionSheet, AudioControl, RecordingMeter, ConversationAvatar, ScoreWordRow, SettingsRow, BottomNavigation. Behavior is canonical in [COMPONENT_STATES](COMPONENT_STATES.md).

Images use authored WebP sizes suited to display; keep semantic labels on vocabulary artwork. SVG only if adding its parser is justified; otherwise Flutter Canvas/PNG/WebP. Course asset manifest includes alt text, dimensions, hash and content version. Never use a flag as the only label for a language.

## Motion / sound / haptics

Button press120ms downward2px; choice selection120ms; feedback panel160ms; path unlock250ms; celebration600ms max then skippable. Use explicit AnimationController/Tween or implicit widgets; pause/dispose on route changes. Reduced-motion mode replaces spatial movement with immediate state/short fade≤100ms; no autoplay mascot looping in background.

Success/error sound≤300ms bundled and respects user toggle/system audio; haptic short on answer outcome and primary press, no redundant vibration every word token. Do not force sound during microphone recording. Correct/error panel announces via semantics and includes text/icon. Motion is decoration, never the only completion signal.

## Visual QA gate

For every major screen: reference date/version/OS/course/plan → component decomposition → project token mapping → fixture for all interactive states → screenshot on narrow/wide + text scale2 → diff → intentional deviation recorded. Font rasterization differences require one pinned Linux golden environment; platform-native font/permission/audio QA is separate. No exact pixel similarity score claimed until measured.
