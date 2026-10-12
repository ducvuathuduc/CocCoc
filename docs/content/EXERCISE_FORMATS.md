# Exercise formats (canonical content spec)

Owner: content (`content/**`, `tools/content/**`, `docs/content/**`). Wire shapes are owned by
[OpenAPI](../api/openapi.yaml) (`Exercise` union, `LessonBundle`, `CourseManifest`); grading by
Learning ([grading.ts](../../services/learning/src/domain/grading.ts)); publish validation by
[validate.ts](../../services/learning/src/content/validate.ts); product rules by
[CONTENT_MODEL](../product/CONTENT_MODEL.md). This page says how **authored content** must fill
those shapes so that every item renders in the frozen mobile UI and grades deterministically. It
adds no wire fields and no thirteenth type.

Generator: [`tools/content/build-course.mjs`](../../tools/content/build-course.mjs) (v2) ·
lint: [`tools/content/lint-course.mjs`](../../tools/content/lint-course.mjs) ·
authored tables: [`content/vi_en/source/v2/`](../../content/vi_en/source/v2/course.mjs).

## 1. The 12 types at a glance

| # | `type` | OpenAPI schema | `content` | Answer kind → key | UI renderer (frozen) |
|---|---|---|---|---|---|
| 1 | `textTranslation` | `TextTranslationExercise` | `TextContent` | `text` → `acceptedText[]` | `lesson_screen` text field (`ExerciseKind.textTranslation`) |
| 2 | `choice` | `ChoiceExercise` | `ChoiceContent` | `choice` → `correctChoiceId` | choice tiles (`ExerciseKind.choice`) |
| 3 | `wordBank` | `WordBankExercise` | `TokenContent` | `tokens` → `correctTokenIds[]` (subset, ordered) | chip bank + answer line (`ExerciseKind.wordBank`) |
| 4 | `sentenceOrder` | `SentenceOrderExercise` | `TokenContent` | `tokens` → `correctTokenIds[]` (all tokens) | same chip renderer (`ExerciseKind.sentenceOrder`) |
| 5 | `fillBlank` | `FillBlankExercise` | `TextContent` | `text` → `acceptedText[]` | text field, hint "Type the missing word" |
| 6 | `matchPairs` | `MatchPairsExercise` | `PairContent` | `pairs` → `correctPairIds[]` | `MatchPairsExercise` widget (two columns) |
| 7 | `imageChoice` | `ImageChoiceExercise` | `ChoiceContent` (+`imageAssetId`) | `choice` → `correctChoiceId` | 2×2 picture tiles (`ExerciseKind.imageChoice`) |
| 8 | `listenChoice` | `ListenChoiceExercise` | `ChoiceContent` | `choice` → `correctChoiceId` | choice tiles + speaker button |
| 9 | `dictation` | `DictationExercise` | `TextContent` | `text` → `acceptedText[]` | text field + speaker button |
| 10 | `speakRepeat` | `SpeakRepeatExercise` | `SpeechContent` | `text`/`speech` → `acceptedText[]` | `SpeakingWordsExercise`; "CAN'T SPEAK NOW" → alternative |
| 11 | `dialogueTurn` | `DialogueTurnExercise` | `SpeechContent` | `text`/`speech` → `acceptedText[]` | `LilyDialogueExercise`; "CAN'T SPEAK NOW" → alternative |
| 12 | `storyQuestion` | `StoryQuestionExercise` | `StoryContent` | `choice` → `correctChoiceId` | rendered as a choice item with passage + question as the prompt (wire mapper) |

## 2. Fields every exercise carries (`ExerciseBase`)

| Field | Rule |
|---|---|
| `id` | `<lessonId>-eNN` (01-based, zero-padded). Alternatives: `<id>a`. Pattern `^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$`. Unique in the bundle and across the course (lessonIds are unique). |
| `prompt.text` / `prompt.locale` | Instruction or stimulus, ≤ 1024 chars. Vietnamese instructions use `vi-VN`; an English stimulus the learner must read uses `en-US`. |
| `prompt.audioAssetId` | Only on listening/speech items. Always the `.n` (normal speed) key; the `.s` (0.75×) asset is shipped beside it for the slow button. |
| `gradingRule` | All three flags always present. Text items: `{caseSensitive:false, ignorePunctuation:true, ignoreDiacritics:false}`. Key items (choice/token/pair): `{false,false,false}`. |
| `hint` | ≤ 512 chars, always Vietnamese, never the full answer for production items: a word gloss (`"tea" = trà; "hot" = nóng`), the first letter, or the word count. Using it marks the answer `assisted`. Legendary items prefix a warning that hints count as assistance. |
| `explanation` | ≤ 1024 chars, shown after checking: the model answer plus up to two accepted alternatives (`Cũng đúng: ...`). |
| `skillIds` | 1–10. Vocabulary items `<unit>.vocab`; sentence items `<unit>.grammar`; listening adds `listening`; speech adds `speaking` (+`<unit>.dialogue` for turns); stories `reading` + `<unit>.story`. An alternative carries **exactly** the same `skillIds` (validator `ALTERNATIVE_SKILLS_DIFFER`). |
| `vocabularyIds` | ≤ 20, `<unitId>.<wordId>` of every course word the item practises (drives review scheduling). `matchPairs` lists them **in pair order** (Learning's word list derives translations from it). Stories carry `[]`. |
| `nonAudioAlternative` | Required when the prompt has audio (except speech types). Same skills, no media, no nested alternative. |
| `nonSpeechAlternative` | Required on `speakRepeat` / `dialogueTurn`. Same rules. The current mobile mapper always substitutes it (speech capture not wired). |

There is **no difficulty field** on the wire (`additionalProperties: false`). Difficulty is
expressed by the item's position in the path (see §4) and by its type tier: recognition
(choice, imageChoice, matchPairs, listenChoice, storyQuestion) < assembly (wordBank,
sentenceOrder) < production (fillBlank, textTranslation, dictation, speakRepeat, dialogueTurn).
The generator records the tier only in its own recipe tables.

## 3. Per-type specification

### 3.1 `textTranslation`
- Two directions. **vi→en**: `prompt = {text: <Vietnamese sentence>, locale: vi-VN}`,
  placeholder `Viết bằng tiếng Anh`. **en→vi**: `prompt = {text: <English>, locale: en-US}`,
  placeholder `Viết bằng tiếng Việt (có dấu)`. `maxChars` 200.
- `acceptedText` (1–20): model answer first (it is what `AnswerResult.acceptedAnswer` shows), then
  curated alternatives. English closure is generated: every authored form gets contraction/expansion
  variants (`I am`↔`I'm`, `do not`↔`don't`, `will`↔`'ll`, `let us`↔`let's` …) except where the
  contraction is ungrammatical (clause-final `Yes, I am.`, `Where is it?`). Vietnamese closure adds
  `tôi`→`mình` and the optional past marker (`đã đi`→`đi`).
- Diacritics: Vietnamese accents stay significant (`ignoreDiacritics:false`, CONTENT_MODEL rule);
  typographic quotes/apostrophes, case, punctuation and NFC/NFD differences are normalized by the
  grader, so `I’m` = `I'm` and decomposed `ê` = `ê`.

### 3.2 `choice`
- 2–8 options (we author 4 for words, 3 for sentences), unique texts, ids `c1..cN`, shuffled
  deterministically. New-word intro items prefix the prompt with `Từ mới!` (lint uses this marker
  to count a word as introduced).
- Directions: en→vi (`Chọn nghĩa đúng của "tea"`) and vi→en (`"trà" trong tiếng Anh là gì?`).
- Distractors: other words already introduced, never sharing the correct text.

### 3.3 `wordBank`
- Tiles = the answer's tokens + distractors (3 for English, 4 for Vietnamese syllables). Token ids
  `t1..tN`; tiles with identical text form one identity class in grading (swapping two "the" is fine).
- `correctTokenIds` = the model answer in order. Tokenization keeps apostrophes/hyphens and drops
  `.,!?;:"()`.
- Safety rules (generator + lint): a sentence is used only if **no accepted alternative can be
  assembled from the same tiles** (otherwise a correct answer would be marked wrong), and
  distractors never include words of any alternative or optional words (`please`, `too`, `very`,
  `rất`, `nhé`, `đã` …) that could form another valid sentence.

### 3.4 `sentenceOrder`
- All tiles must be used (`ORDER_USES_ALL_TOKENS`). Same ambiguity rule as wordBank. Tiles are never
  presented already in answer order. Also used as the `nonSpeechAlternative` of `speakRepeat` (same
  sentence).

### 3.5 `fillBlank`
- `prompt.text` = English sentence with exactly one `___`, followed by ` — "<Vietnamese meaning>"`;
  locale en-US; `maxChars` 40.
- The blank is a course word of the item (preferably one of the level's new words), matched
  whole-word; `acceptedText` = that word as it appears.

### 3.6 `matchPairs`
- 2–10 pairs (we author 5): `left` = English word, `right` = Vietnamese meaning; ids `pN`, `pNl`,
  `pNr`. Left texts unique and right texts unique **case-insensitively** (the mobile mapper keys
  pairs by text). `correctPairIds` lists every pair.
- `vocabularyIds` in pair order (b-learning convention).
- The UI's "audio pairs" variant is mock-only; there is no wire flag for it, so content does not
  author it.

### 3.7 `imageChoice`
- 4 options, each with `text` (English word) and `imageAssetId` = `i.<unitId>.<wordId>`; every image
  asset is listed in the bundle `assets` (`IMAGE_ASSET_MISSING`). Only words flagged `img` in the
  vocabulary table (picturable nouns) are used. Asset metadata: `image/webp`, 512×512,
  `altText = "Hình minh họa: <vi> (<en>)"`.

### 3.8 `listenChoice`
- `prompt = {text: 'Nghe và chọn câu bạn nghe được', locale: vi-VN, audioAssetId}`; 3 sentence
  options. `nonAudioAlternative`: a `choice` with the Vietnamese meaning as prompt and the same
  options/key.

### 3.9 `dictation`
- `prompt.audioAssetId` = the sentence audio; `acceptedText` = the sentence + contraction variants +
  authored alternatives with the **same word count** (what you hear is one sentence).
  `nonAudioAlternative`: vi→en `textTranslation` of the same sentence.

### 3.10 `speakRepeat`
- `prompt.text = 'Nói câu sau: "<sentence>"'`, `content = {referenceText, locale: en-US,
  maxSeconds: min(15, 4 + ⌈words/2⌉)}`, `acceptedText` = sentence variants (used for a typed
  transcript; pronunciation metrics are a separate Assessment job and never invented here).
  `nonSpeechAlternative`: `sentenceOrder` of the same sentence.

### 3.11 `dialogueTurn`
- `prompt = {text: <partner line>, locale: en-US, audioAssetId: a.<unit>.dN.n}`;
  `content.referenceText` = model reply; `acceptedText` = model reply + authored alternative replies
  + contraction closure; hint = Vietnamese meaning of the model reply.
  `nonSpeechAlternative`: `choice` between the model reply and two replies from other turns.

### 3.12 `storyQuestion`
- `content = {passage, question, choices}`; `prompt.text` = the question (en-US); 3 options, first
  authored option is correct (shuffled on output). Passages are A1/A2 English, ≤ 4096 chars, with
  the recurring cast. The mobile mapper shows `passage + question` and answers by choice id.

## 4. Course structure (Duolingo model on the frozen wire)

```
course vi_en v2
 └ section (sec1 A1 "Nền tảng", sec2 A2 "Cuộc sống hằng ngày")
    └ unit (8 per section; guideText = guidebook tips in Vietnamese)
       └ 13 nodes: L1a L1b L2a L2b L3a L3b STORY L4a L4b L5a L5b REVIEW LEGENDARY
          └ 2 lessons per node (ContentNode.lessonIds maxItems 2), 11–15 exercises each
```

| Node | `kind` | Lessons (recipe) | Purpose |
|---|---|---|---|
| Level k, part a | `lesson` | intro, practice | New words (`Từ mới!` items, imageChoice when picturable) → recognition → assembly → first production |
| Level k, part b | `lesson` / `listening` / `speaking` (by level: lesson, listening, speaking, listening, speaking) | 2 × practice / listening / speaking | Production, listening (listenChoice + dictation), speaking (speakRepeat + dialogueTurn) |
| Story (after level 3) | `story` | story1, story2 | 6 comprehension questions over one passage, mixed with unit review |
| Unit review | `mastery` | review × 2 | All 12 types across the whole unit |
| Legendary | `mastery` | legendary × 2 | Production-only, harder; hint use is flagged as assistance |

Progression rules enforced by the generator and lint:
1. A level's 4 new words are introduced by `Từ mới!` items at the start of its first lesson; no
   exercise may test a word before that (`tests X before it is introduced`).
2. A sentence/dialogue is used only after **all** course words in it are introduced; the authored
   tables may not use a word that a later unit introduces.
3. Every lesson ends with spaced-repetition slots drawn from older material (earlier levels and
   units), chosen least-used-first so every sentence keeps coming back.
4. Placement: 10 items from unit 1 (pass ≥ 8 → Learning starts the learner at unit 2).

## 5. Asset keys

| Asset | `fileId` | Notes |
|---|---|---|
| Sentence audio | `a.<unitId>.s<N>.n` / `.s` | one key per authored sentence (normal / 0.75×) |
| Dialogue line audio | `a.<unitId>.d<N>.n` / `.s` | partner line of a `dialogueTurn` |
| Word image | `i.<unitId>.<wordId>` | picturable words only |

`content/vi_en/next/v2/audio-catalog.json` lists every audio key with its transcript (the TTS
production list for P7-AUDIO-001). Media `sha256` values are deterministic placeholders until the
files exist; every audio/speech item has a text alternative, so lessons work without media.

## 6. Authoring tables (source of truth)

`content/vi_en/source/v2/units/uNN-*.mjs`, one per unit (parser:
[`course-lib.mjs`](../../tools/content/course-lib.mjs)):

```
vocab:      <level 1-5> <en>[, <enAlt>] | <vi>[ / <viAlt>] [| img] [forms=a,b] [id=x]
sentences:  <en> [## <enAlt>] = <vi> [## <viAlt>]
dialogues:  <partner line> => <reply> [## <replyAlt>] = <Vietnamese meaning of reply>
story:      { title, passage, questions: "<question> * <correct> | <wrong> | <wrong>" }
```

A sentence's level is derived from the newest word it contains. Commands:

```sh
node tools/content/build-course.mjs          # write content/vi_en/next/v2 + source/v2/build-report.json
node tools/content/build-course.mjs --check  # fail if build-report.json is stale
node tools/content/lint-course.mjs           # full content lint (also run by content/tools/check-content.mjs)
```
