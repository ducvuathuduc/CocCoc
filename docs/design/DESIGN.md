# CocEnglish design system

Current audit preserves actual tokens/fonts/components/assets and UI. This is the project's engineering specification derived from references, not an official downloadable Duolingo DESIGN.md. [UI gaps](../audit/UI_IMPLEMENTATION_GAP.md), [behavior map](../product/SCREEN_BEHAVIOR_MAP.md) and existing QA receipts separate source/capture evidence from fresh device proof.

This is **our engineering DESIGN.md**, derived from public [Duolingo brand colors](https://design.duolingo.com/identity/color), [typography guidance](https://design.duolingo.com/identity/typography), and inspected [Gummble references](GUMMBLE_RESEARCH.md). No official downloadable Duolingo engineering DESIGN.md was established. Exact app spacing/radii below are our chosen tokens, not extracted source constants.

2026-10-04 frontend override: the user explicitly chose the original Duolingo screenshot appearance for onboarding/login, including Duo, icons, fonts and tactile controls. The active implementation uses locally bundled DuolingoSans/Feather, archived illustration regions, and measured reference-specific tokens in `apps/mobile/lib/core/design/`. [Onboarding](flows/01_ONBOARDING.md) and [login](flows/02_LOGIN.md) own screen deconstruction; [asset provenance](../../apps/mobile/assets/PROVENANCE.md) owns input sources. The adaptation tokens below remain the planned product baseline, not the active reference-reproduction palette. Reference fidelity is not a contrast certification or proof of identical motion.

## Visual direction

2026-10-29 remote consolidation adopts the existing orange CocEnglish branding
branch: the speech-bubble C mark replaces mapped owl artwork and `duo-*` motion,
and supplies the splash, welcome and platform icons. The native screen layouts,
ordinary icons and other lesson characters keep their established rendering.
The branch's existing mapping replaces a whole composite illustration when it
contains owl artwork; gift backgrounds and the decorative path-return preview
therefore lose their illustrated scene context. Native controls remain in place,
including the path-return banner action to `/home`.
The [brand assets and mapping](../../apps/mobile/assets/brand/README.md) and
[integration receipt](../quality/REMOTE_BRANCH_CONSOLIDATION_20261029.md) record
the scope and canonical Linux visual checks. Archived reference images retain
their provenance role.

Bright learning path, round illustrated exercises, thick outlines, tactile bottom-edge buttons, generous space, one clear next action. Flat surface hierarchy; avoid generic KPI cards, gradients, glass effects and desktop-dashboard composition. Use our CocEnglish character illustration, no production dependency on proprietary fonts/assets.

Typography: bundle Nunito Sans for Vietnamese+Latin UI and Nunito for short headings if glyph coverage is verified; system sans fallback during font load. Do not fetch fonts at runtime. Heading28/32 weight800; title22/28 weight800; body18/26 weight600; caption14/20 weight600; button16/20 weight800. Text scaling is respected; no fixed height for multi-line text. Proprietary Feather/DIN are not required.

## Tokens (logical pixels)

| Token | Value / role |
|---|---|
| brand.orange / brand.surface | #F47721 / #FFF7EF; CocEnglish mark and launch surface |
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

2026-10-09 active mock lesson refinement: `LessonMotionTokens` in
`apps/mobile/lib/core/design/lesson_motion.dart` owns the 16px track/inset
highlight, 300ms ease-out fill, 250ms feedback entrance and 300ms damped heart
shake. Feedback overlays stable exercise geometry and extends its color through
the bottom safe inset. Each successful grade emits one light/correction medium
haptic. Reduced motion displays the final state; backgrounding stops heart
motion without replay. The timing values are authored UI targets; archived
Gummble stills do not prove exact iOS timing. [Evidence](qa/UI_MASTER_LOG.md).

The completion mock uses `RewardMotionTokens` for a 500ms ease-out count and
600ms finite geometric confetti. It interpolates immutable receipt XP/accuracy
and existing mock streak values without awarding from animation callbacks.
Semantics retain final metrics. Reduced motion displays final counts; confetti
stops on background and leaves Continue actionable. Original bundled character
art is unchanged. Particle paths are authored motion approximations.

## Visual QA gate

The current English mock frontend extends the core inventory with
[League history](flows/27_LEAGUE_SOURCE_RECONCILIATION.md) and
[Year in Review/widget looks](flows/28_YEAR_REVIEW_WIDGETS.md).
Their source mappings, state fixtures, deliberate adaptations and final receipts
live in those analyses and [the finish report](qa/SESSION_FINISH_REPORT.md).

For every major screen: reference date/version/OS/course/plan → component decomposition → project token mapping → fixture for all interactive states → screenshot on narrow/wide + text scale2 → diff → intentional deviation recorded. Font rasterization differences require one pinned Linux golden environment; platform-native font/permission/audio QA is separate. No exact pixel similarity score claimed until measured.
