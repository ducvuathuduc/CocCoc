# Status and English learning feed

Analyzed2026-10-05 before implementation. Live Gummble: Setting a status `0e653f8e-e529-4dd7-ba84-0589fd9b7b82` (4screens), Adding a status `3a8e4927-efd3-42b6-b471-845c2353e9a5` (3screens), Feed `2b077547-fa9f-4d10-8e57-1a87d32e1745` (5screens). All original PNGs inspected; source dimensions1179/1180×2556, preview dimensions are resized and must not be used directly as ROI coordinates.

## Source decomposition

- `sc_26810b55b72e4cf8bc77980a286ac892`: native bottom sheet, gray scrim,24px rounded top/drag handle, right gem balance,24px centered title, dashed profile preview with online dot. Twelve status cells in6columns×2rows,2px border/3px base, selected light-blue fill/blue outline. Four first-row cells have gem markers; Done and Clear Status below.
- `sc_a00463fd98c346f3a4b4327335eb5cae`: popcorn selection changes both cell and profile bubble. `sc_f1f6297729414f5ebc7da15b0b08942f`: committed popcorn bubble in highlighted current-user league row. `sc_bab2062a58b2442998924dd6618c5442`/`sc_b4959eab28de4c909618d3ae49fb9c36`: same controls with original Alex avatar and angry Duo selection.
- `sc_545c0af64c0d4c5ea1071c765ce53367`: empty feed onboarding, three illustrated friend portraits, blue phrase in centered title, two native selected suggestion rows, Find more friends, fixed add-count CTA. First capture has Home as entry context.
- `sc_defc6fb35f614adba0b09b2d1fcd871f`: native Feed header, follow-back event and View Profile; blue cartoon learning illustration, Learning tag/time/text and Tell Me More. `sc_b044186d4e544e50918dd23ce1a8f5e1`: two native shared-sentence bubbles with original Oscar/Eddy, heart counts, share and liked-by row.
- `sc_3693b963fca048e0899964e3c3a7b526`: first-friend event with original Lin/Bea scene, native heart/comment/share controls, orange streak learning card/Start a Lesson, next green learning illustration partly visible.

## Implementation contract

Native text, buttons, grid, sheet, list and editable comments; screenshots supply bounded illustration-only ROIs. English flag and English/Vietnamese sentences replace archived French. Feed follow/add operations share the existing preview following set, never toggle an already-followed friend off. Empty/all-followed suggestions are disabled safely. Hearts toggle once per post and update native count; comments validate trimmed1–280characters, retain invalid drafts, stay local. Share is a local sheet. Public profile preserves requested fixture identity. Back returns safely from direct routes.

Status editing separates committed selection from draft; dismiss/Back discards draft, Done commits unlocked selection, Clear removes committed selection. Premium icons validate the same internal wallet as Shop, debit once per icon, remain unlocked after clearing. A500gem historical mobile price is corroborated by [Duoplanet's status guide](https://duoplanet.com/duolingo-status-icons/), not shown in the supplied Gummble sheet; this is a mock tariff, not current billing proof. Do not invent an original purchase popup. Present a native local confirmation and preserve choice on insufficient funds. No real account, social message or payment.

Learning-card content summarizes [Duolingo's children's-materials article](https://blog.duolingo.com/childrens-materials-for-language-learning/): familiar cartoons help follow the plot, subtitles support different practice goals. Local detail layout is an authored continuation; the actual article screen is absent from this flow. Static status icons and joint feed illustrations have no verified original timelines; do not invent their motion. Original Oscar/Eddy lesson Rive exports may provide existing reaction/idle inputs, but do not establish archive pose/timing equivalence.

Checks: meaningful state/wallet regressions, routed sheet dismissal/selection/commit/comments,360/430×text1/2, source-resolution captures, analyzer/full gate and local web review before reporting the slice complete.
