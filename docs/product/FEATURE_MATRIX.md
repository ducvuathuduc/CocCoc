# Current Duolingo feature matrix and V1 scope

Checked 2026-10-03. **Confirmed** means source documents the feature, not universal account availability. **Observed** means an inspected Dec 2025 iOS Gummble capture. **UNVERIFIED** means current exact behavior was not established. This matrix separates competitor evidence from our prescriptive behavior. Sources R13–R22 are in [research register](../research/RESEARCH_EVIDENCE.md).

| Area / current feature | Evidence / availability / confidence | CocEnglish V1 / phase |
|---|---|---|
| Welcome, start, returning login | Gummble onboarding flow exists, 20 steps; welcome image inspected. Exact current steps/order UNVERIFIED | Welcome → language → purpose → experience → goal → first demo → account; P2/P3 |
| Language selection | Current store courses and captured language selector; course list varies | vi→en only populated; other course rows unavailable with clear status; P4 |
| Reason and goal questions | Onboarding reference flow; exact current options UNVERIFIED | travel/study/work/other, 5/10/15 min; optional questions; P2 |
| Experience/placement | Exact current test rules UNVERIFIED | beginner or 10-question placement; 8/10 unlocks unit 2; P4 |
| Account/sign in/OAuth | Current store account product, specific timing UNVERIFIED | email/password + Google; Apple conditional iOS configuration; local guest demo; P3 |
| Permission prompts | Exact current notification timing UNVERIFIED | ask reminders after first completion; mic on first speaking use; no launch permission barrage |
| Sections/units/nodes | Observed path with section/unit header, active ring and grey locked nodes | 2 sections / 6 units / 24 nodes / 48 lessons; P4/P5 |
| Locked/unlocked path | Observed active/locked visual state; exact current mastery rules UNVERIFIED | monotonic frontier, two completed lessons unlock next node |
| Guidebooks | Notebook action observed in unit header; current course coverage varies | static unit guide bundled with examples; P4 |
| Legendary/mastery | Three-star character/mastery visual observed; exact earning rule UNVERIFIED | one optional node mastery challenge; first-attempt ≥80%, no hints |
| Stories | Gummble story flow; official practice article conditional by course | authored storyQuestion chain at one node/unit; P5 |
| Radio/listening content | Gummble radio flow; official practice article course-dependent | audio comprehension lesson, no streaming radio service; P7 |
| Adventures/games | Gummble game flow and official conditional practice | optional story branching with typed dialogue steps; P5 |
| Typed translation | Store lesson description; official speaking article | textTranslation, normalization and curated alternatives; P5 |
| Multiple choice | Store description; observed choice screen | choice and imageChoice; P5 |
| Image vocabulary | Inspected four-option image choice, selected blue border and CHECK | imageChoice; P5 |
| Word bank / ordering | Exact current subtype inventory UNVERIFIED beyond language lesson patterns | wordBank and sentenceOrder explicitly in our typed engine; P5 |
| Fill blank | Exact current subtype inventory UNVERIFIED | fillBlank with authored alternatives; P5 |
| Matching | Inspected audio-to-word matching screen | matchPairs; P5/P7 |
| Listening / dictation | Official listen practice and microphone writing input; observed audio matching | listenChoice, dictation, repeat/slow toggle; P7 |
| Speaking/pronunciation prompt | Official repeat, speak translation and short dialogues | speakRepeat; assessment when available; honest unscored shadowing otherwise; P8 |
| Conversation | Official Roleplay/Video Call, Max limited languages/platforms | dialogueTurn + guided/free tutor; no plan paywall; bounded quotas; P8 |
| Story comprehension | Gummble story lesson; conditional course coverage | storyQuestion, choice/typed response; P5 |
| Vocabulary/flashcards | Official 2026 speaking/practice articles | review screen uses textTranslation/wordBank; P6 |
| Session progress / exit | Observed top progress/close control | fixed lesson reducer, confirmation and resume; P5 |
| CHECK / CONTINUE | Observed CHECK primary, disabled CONTINUE in unmatched pairs | explicit state machine; no double submit; P5 |
| Correct / incorrect feedback | Current exact animations/text UNVERIFIED in inspected set | answer panel, explanation, retry queue, accessible sound/haptic; P5 |
| Hints / skip / report | Exact current conditions UNVERIFIED | hints lose perfect bonus; skips need typed alternative; report nonblocking |
| “Can't listen now” | Directly observed audio matching | replace by bundled non-audio alternative, no penalty |
| “Can't speak now” | Exact current copy/rules UNVERIFIED | same local capability substitution; no microphone required to progress |
| XP result / quests feedback | Inspected quest update after lesson; exact XP formula UNVERIFIED | server-computed formula in SRS; pending reward indicator |
| Mistake recovery | Practice article includes mistakes | two retry passes then mark needs-review; no infinite session |
| Streak / freeze | Official handbook + store streak product; exact current economy UNVERIFIED | server calendar, two freeze slots, local reminders; P6 |
| Hearts and Energy | Hearts in Dec 2025 capture; Energy official active experiment; current global state UNVERIFIED | energy presentation with unlimited learning default; no mandatory paywall/ad gating |
| Gems / reward chests | Gems and chests observed | virtual gems, quests/freeze only; no payments; P6/P9 |
| Achievements / milestones | Store tracking rewards; exact current set UNVERIFIED | 5/20/50 completions, 3/7/30-day streak; P6 |
| Daily quests | Captured two-lesson quest update | three daily deterministic quests; P9 |
| Monthly/friend quests | Exact current rules UNVERIFIED in sources reviewed | monthly 20-day participation; optional cooperative 10-lesson weekly quest; P9 |
| Leagues/promotion/demotion | Current store competitive leaderboard; exact brackets UNVERIFIED | 10 league tiers, cohorts ≤30; top/bottom 5; P9 |
| Practice hub | Official 2026 free mistakes/words/speak/listen iOS+Android | free hub with cached/speech-capability states; P7/P8 |
| Personalized practice | Official product mentions practice; algorithm undisclosed | deterministic due-item + mistake selection, no claimed AI personalization |
| Profile/stats/following | Exact current detailed flow UNVERIFIED | opt-in public profile, reciprocal friends, stats; P3/P9 |
| Social feed / sharing | Exact current feed availability UNVERIFIED | small friend activity list from opted-in milestone summaries; share system sheet; P9 |
| Explain My Answer | Official Feb 2026 article says free | authored explanation first, optional text tutor; P5/P8 |
| Roleplay | Max mobile selected course pairs, official help | authored scenarios; no invented Vietnam course availability in competitor |
| Video Call with Lily | Official help iOS/Android supported languages; Max | animated avatar + audio conversation, no camera/video capture |
| Guided Falstaff calls | Official Jan 2026 iOS Max selected languages; expanding rollout announced | guided A1 tutor using constrained turn plan |
| Math/music/chess | Current store listing | out of language-learning scope |

Current competitor exact XP values, energy depletion formula, onboarding ordering, quest counts, node mastery thresholds and social feed deployment are **not copied as facts**. Our choices below are university-product rules. Before fidelity work in phase 2, collect target-account Android and iOS references, record OS/app version/date/plan/course and flag every deviation.
