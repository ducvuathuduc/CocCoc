# Slice: in-lesson exercises (lesson_exercises)

Refs: docs/design/references/lesson/03–11.png (Gummble flow "Completing a lesson").
Compare sheet: tickets/par/compare/lesson_exercises.png (ref | ours, 430×932).
Golden test: apps/mobile/test/lesson_exercises_sprint_test.dart → goldens/ui_master/sprint_lesson_*_430.png.

| Ref | State | Golden |
|---|---|---|
| 03/04 | Select image, ready | sprint_lesson_select_image_ready_430 |
| 05 | Select image, tile selected (blue) | sprint_lesson_select_image_selected_430 |
| 06 | Select image, correct (green tile + "Excellent!" sheet) | sprint_lesson_select_image_correct_430 |
| 07 | Select translation, selected | sprint_lesson_translation_selected_430 |
| 08 | First mistake: hearts sheet "Each mistake costs 1 heart…" KEEP GOING | sprint_lesson_hearts_warning_430 |
| 09 | Incorrect feedback sheet | sprint_lesson_translation_incorrect_430 |
| 10 | Tap the matching pairs (audio left / meaning right), CAN'T LISTEN NOW + disabled CONTINUE | sprint_lesson_match_pairs_430 |
| 11 | Skip listening yellow sheet "We'll skip listening for 15 minutes." | sprint_lesson_cant_listen_430 |
| — | Fill blank / type answer (no ref in flow; existing renderer) | sprint_lesson_fill_blank_430, sprint_lesson_type_answer_430 |
| — | Quit-lesson sheet (existing) | sprint_lesson_quit_sheet_430 |
| — | Out of hearts — UNKNOWN in refs; reuses lesson/08 sheet layout | sprint_lesson_out_of_hearts_430 |

Geometry measured with PIL on refs (scale 430/1179): match tiles x 18–202 / 229–412 (gap 27),
face ≈70 + 3–4 edge, row gap ≈14–18; hearts sheet top ≈561, hearts row 621–648, button 825–878;
barrier renders #999999 (black 40%); skip sheet fill #FFF5D3, title #CD7900, button #FFC700 edge #E7A601.

Motion (all skip under MediaQuery.disableAnimations):
- Choice tile press-down 90 ms (face sinks 3 px onto edge), select bounce 240 ms (1→.94→1.04→1).
- Wrong match: red flash + 320 ms shake; correct match: green flash 420 ms then fade to 50 % disabled.
- Word-bank tile flies from bank slot to answer line (280 ms easeOutBack).
- Existing: progress bar fill+shine 300 ms, feedback sheet slide-up 250 ms, heart-loss shake 300 ms.
- Empty heart pops (elastic) in hearts sheet.

Known deltas (minor): ref 08 lifts the header heart counter above the barrier in a white pill (not done);
"EXPLAIN MY MISTAKE" copy and share icon in feedback sheet belong to the existing feedback slice (unchanged);
mock data differs from ref (English course, hearts count, lesson length).
