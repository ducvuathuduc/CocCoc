# Language content and deterministic checking

[OpenAPI](../api/openapi.yaml) owns DTO shape; [data model](../data/DATA_MODEL.md) owns storage; [migration protocol](../data/MIGRATIONS.md) owns publish/retirement. Language is explicit: source `vi-VN`, target `en-US`, course `vi_en`, authored A1/CEFR reference metadata. Course → immutable version → section → unit → ordered node → lesson → discriminated Exercise. Level metadata is curriculum guidance, not certified learner assessment.

V1 has 12 wire exercise variants covering all requested categories; translation/typed answer share textTranslation and short comprehension uses storyQuestion. Do not add a duplicate thirteenth renderer to satisfy a wording count. Common DTOs include stable ID/skill/prompt/media/hint/typed content/check key; unknown type/version blocks publishing and offers client update, never `dynamic` best-effort grading.

| Requested category / schema variant | Answer and checking | Interaction / accessible focus / partial / hint/skip |
|---|---|---|
| Multiple choice / ChoiceExercise | selected authored option ID, exact key | radio semantics; selection label; CHECK only after selection; no partial credit |
| Matching / MatchPairsExercise | PairAnswer complete leftId/rightId connections; reject reused endpoints | announce selected/matched pair; keyboard traverses both lists; partially matched remains editing |
| Word bank / WordBankExercise | token ID sequence including duplicate word identities | selectable chip + ordered answer semantics; remove/reorder restores focus; complete shape needed |
| Reorder / SentenceOrderExercise | TokenAnswer exact authored sequence | move-left/right buttons as drag alternative; announce ordinal; no partial credit |
| Gap-fill / FillBlankExercise | TextAnswer for one authored blank | text keyboard and focus on blank; label surrounding sentence; one exact normalized alternative |
| Translation + typed answer / TextTranslationExercise | TextAnswer against curated variants | text entry, submit does not dismiss error/focus unexpectedly; no semantic LLM grading |
| Image recognition / ImageChoiceExercise | ChoiceAnswer ID | meaningful authored image description for accessibility; equivalent nonvisual item when image indispensable |
| Listen/select / ListenChoiceExercise | ChoiceAnswer ID plus immutable audio asset | play/replay/slow; loading/disabled audio controls; authored text equivalent on unavailable capability |
| Dictation / DictationExercise | TextAnswer, normalized exact variants | text keyboard, playback independent of answer edits; interrupted audio preserves draft |
| Repeat-after-me + speaking / SpeakRepeatExercise | transcript/text fallback in deterministic lesson; separate Assessment job for metrics | explicit simulated/unassessed label; permission/record/stop/retry; no invented pronunciation score |
| Short dialogue / DialogueTurnExercise | authored TextAnswer/accepted variants | conversational prompt; bounded response; empty tutor fallback independent of accepted key |
| Short comprehension / StoryQuestionExercise | authored TextAnswer after passage/audio | accessible passage + question focus; preserve playback/read position; equivalent item for missing media |

Normalization: Unicode NFC, trim/collapse whitespace, defined case fold and explicitly ignored terminal punctuation. Vietnamese accents remain meaningful; do not strip diacritics globally. Token/pair exercises compare identifiers, not labels. Optional alternatives are authored and validated; a hint marks assisted and removes perfect bonus. Core V1 grading is binary per item; display attempt counts/feedback instead of fabricated fractional semantic confidence. Retry accuracy and original-first accuracy are distinct. Media capability substitution carries the same skill tags and no ordinary skip penalty.

Content pins schemaVersion, courseVersion, lessonVersion, gradingRulesVersion, rewardIdentity and hashes/signature. Asset identifies locale, voice, speed, content hash/type/size; verify before cache use. Republished equivalent lesson retains rewardIdentity. Session snapshot survives content pointer changes; retired versions readable under canonical retention window; rejected pending sync explains repeat action. N/N-1 mobile DTO compatibility uses expand/migrate/contract, not silent key changes.

## Smallest future subject seam

Future schema version adds `learning_domain` at catalog/course boundary with language as default for legacy V1. It is not added to existing frozen wire DTOs now. Register a future subject's versioned renderer/validator table at app composition and its server owner; stable session/answer/result/event interfaces remain subject-aware through the versioned union. Translation/listening/speaking stay language modules. Unsupported renderer version blocks start with update/help; old cached bundles retain their language decoder. No math/chess/music scaffold or unused everything-engine is created.

Synthetic seed validation command is `pnpm seed:check`. The seed is a catalog starter; the full two-section/six-unit/24-node/48-lesson content gate remains P4 and requires authored media/keys/signature checks. No competitor user data or live inference is imported during CI.
