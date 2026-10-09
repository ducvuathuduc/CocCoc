# English lesson verification — 2026-10-09

Scope: UI-LESSON-044, UI-LESSON-045 and UI-LESSON-QA-046. Existing English
lesson engine, Lily reply, speech fallback and first result screen only.

UI-LESSON-044, UI-LESSON-045 and UI-LESSON-QA-046 are complete in the assigned
native mock scope. Root owned lesson state, controller, content, routing
composition and checks; one isolated worker owned the stateless summary and
its five tests. Existing completed work is retained.

Lily uses the original exported Rive file and its verified reset/correct/
incorrect triggers. Ready, audio unavailable, typed alternative, wrong answer,
retry and correct Vietnamese meaning connect to the existing lesson engine.
Speaking uses native stacked cards, audio-wave action and explicit unavailable
speech/text alternative. Media taps do not grade an answer or advance progress.
The same retry now clears both visible editor and stored answer. Pausing retains
the draft and alternative. A failed grade preserves input and streak. New
exercises reset the alternative. Consecutive successful grades control the
streak counter and orange progress; values are not copied from a screenshot.

The result component uses original medal/completed art with preserved aspect,
actual XP/accuracy/time, correct singular/plural mistakes and reader labels.
Metric cards have uniform bounds and stack at 320px or large text. Guest and
placement copy reads “Practice complete”. Source-backed UI contains no demo
credentials or engineering reward disclaimer.

| Command / check | Actual result |
| --- | --- |
| Existing-screen tests before implementation | Three RED cases: [baseline](english-lesson-red.log) |
| Same-question retry and source heading alignment before corrections | RED: [retry](english-lesson-retry-red.log), [alignment](english-lesson-alignment-red.log) |
| flutter test --dart-define=ENABLE_MASCOT_MOTION=false test/english_spoken_lesson_test.dart test/lesson_summary_test.dart test/learning_flow_test.dart test/learning_controller_test.dart test/english_content_test.dart | 31 PASS: [scoped log](english-lesson-targeted.log) |
| flutter test --dart-define=ENABLE_MASCOT_MOTION=false --dart-define=CAPTURE_ENGLISH_LESSON=true test/english_lesson_capture_test.dart | 1 PASS; 15 native PNG states: [log](english-lesson-capture.log), [hash manifest](english-lesson-captures.json) |
| flutter test --dart-define=CAPTURE_ENGLISH_LESSON=true --dart-define=CAPTURE_ENGLISH_LILY_MOTION=true test/english_lesson_capture_test.dart | 1 PASS; active original Rive, different idle frames, correct/incorrect bindings, reduced-motion still: [log](english-lesson-motion.log) |
| node tools/scripts/mobile-check.mjs --with-blueprint | Blueprint PASS, 216 Dart files formatted without changes, fatal-info analyzer clean, 439 tests PASS: [gate](english-lesson-gate.log) |
| node tools/scripts/reference-asset-audit.mjs | 951 saved originals / 239 bundled PNGs match bytes: [asset receipt](reference-assets.json) |
| node tools/scripts/mobile-web-build.mjs | Release Flutter web build PASS: [build log](english-lesson-web-build.log) |
| HTTP delivery of release and lesson assets | Nine HTTP200/no-store checks; served main.dart.js equals latest build: [HTTP proof](english-lesson-http.json) |

Visual review corrected duplicate speech fallback, wrong bubble-tail direction,
narrow-column heading alignment, unequal result card bounds and distortion of
non-perfect art. Reduced-motion feedback bypasses AnimatedSize to avoid a
zero-duration layout assertion. Fifteen native captures include ready, media
unavailable, typed, wrong/correct, retry meaning, both result variants, actual
five-answer streak, guest result and 320/text2 layouts. Source-art decode is
asserted before capturing; result routes assert the real LessonResults.

Lily's exported artboard initially painted its body at about half the still
height. Native measurement and five final [enabled frames](english-lesson-motion/)
verify a 2× render scale with vertical alignment .19 in the lesson only; other
characters retain their defaults. [Static states](english-lesson-native/) use the
unchanged source still for reduced motion. The original Rive loader logs failed
DLL candidates before resolving a working candidate; the active controller,
rendered character, different frames and reaction assertions establish this run.

These checks verify authored English/Vietnamese lesson UI and mock transitions.
They do not certify private original frame timing, live audio/recording,
production services, physical-device performance or browser interaction.
HTTP delivery is recorded separately. Four selected source occurrences are
marked verified_mock; the partial source PERFECT/confetti composition retains
its separate state. Existing archive marks are preserved. Archive journey
counts are not product-flow counts.

Preview: [Flutter web](http://127.0.0.1:4173/preview.html#/home).

References and adaptation decisions:
[English spoken lesson analysis](../flows/30_ENGLISH_SPOKEN_LESSON.md).
