# Lesson and result screen analysis

Analyzed 2026-10-04 before feature UI. Live Gummble MCP [22-step lesson](https://gummble.com/apps/duolingo-ios?tab=flows&flow=068dbdc0-5d4a-4de2-a477-b0e5c8cdc3e8) inspected all22frames in order; [13-step completion](https://gummble.com/apps/duolingo-ios?tab=flows&flow=238c4339-7173-4257-89c5-2716a8a68c44) frames01–06 inspected initially. Their manifests retain exact screen IDs/source URLs. The archive captures sampled states, not a complete ten-question content bundle or a source animation video.

| Reference | Deconstruction | Interaction |
|---|---|---|
| Lesson03–04 empty image | Close,16px progress, heart counter; purple New word badge;22px heading; blue40px audio button and purple term;2×2 cards r12/2px border/3px base with original character-only art; label20; disabled CTA | One stable option ID, disabled CHECK until choice. Entire card is a semantic button; audio never advances |
| Lesson05 selected | Pale blue card/stroke and blue text; green CHECK | Selection can change until submission; busy blocks repeated CHECK |
| Lesson06 correct | Pale green selected card; light green bottom panel around156h; check icon, Excellent, report; Continue | Locked answer; Continue advances only, no second grade call |
| Lesson07 translation |22px heading, seated Falstaff illustration on left, native speech bubble word; three outlined full-width choices near lower body | Stable choice; same disabled/selected/busy/feedback contract |
| Lesson08–09 error | Heart explanation sheet; then pale red panel, Incorrect, authored correction, Explain my mistake and red Got it | Mistake enters ordered retry queue; explanation does not grade. Heart rules are archived visual fixtures, not production economy |
| Lesson10–11 pairs/substitution | Four rows, audio waveform left and words right; selected/matched states; Can't listen now; yellow substitution feedback | Match stable pair IDs; mismatches reversible; text equivalent substitutes without silently skipping an original question |
| Lesson12 result | Large Lily+Duo illustration; yellow Lesson complete; three colored statistic cards; fixed blue Claim XP | Render actual local receipt accuracy/elapsed; claim once; local guest has no ranked XP |
| Lesson13–15 score | Jump transition; Duo sitting on disc; large flag+score; explanatory heading; score progress details | Native flag/text/progress; informational action; fixture progression only |
| Lesson16–17 gems | Original chest art; optional +50gems; centered reward text; blue Continue | One receipt reward, no new mutation on every tap |
| Lesson18 streak | Orange flame, large day count, seven-day strip in card; commitment CTA | Day-based fixture state; repeated lessons same date do not inflate streak |
| Lesson19 quest update | Yellow heading; quest card with star,2-lesson progress, chest | Progress derives from committed mock completions; Continue |
| Lesson20 friend offer | Original cooperative chest illustration; Add friends/Maybe later | Optional branch, never auto-send external invitations |
| Lesson21 words offer | Super mascot; vocabulary list with translations; Practice my words/Not now | Practice branch stays local; no subscription billing |
| New completion01–06 | Perfect feedback/confetti; muscular medal Duo; Flawless/actual mistake count; three stat cards; score10; gems; orange full-screen streak variant; Duo+flame variant | Illustration assets differ from earlier archive. Preserve selected source pose; do not relabel an unrelated wave as exact result animation |

Native renderers cover the12 types named by [OpenAPI](../../api/openapi.yaml): textTranslation,choice,wordBank,sentenceOrder,fillBlank,matchPairs,imageChoice,listenChoice,dictation,speakRepeat,dialogueTurn,storyQuestion. Mock answers/keys are fixture data; production grading and XP remain service-owned. Ten originals, then mistakes with at most two retry passes. Pause retains exact draft; quit explicitly discards it. Hint marks assisted; report queues a local fixture record. Speaking/listening without media uses an explicit text substitution rather than fabricated recording/audio success.

Motion implementation targets:80ms tactile buttons; progress easing; card color transition; token movement; feedback panel entrance; pair success pulse; result number/stat entrance; original vector timeline when identified. Durations beyond existing source timelines are preview choices, not verified archived iOS timing. Disable animations/TickerMode/background must stop loops and leave usable stable controls. No100% equivalence claimed.
