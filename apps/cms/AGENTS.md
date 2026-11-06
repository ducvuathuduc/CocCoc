<!-- BEGIN:nextjs-agent-rules -->

## This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->

## CocEnglish CMS boundaries

- Server actions are the only write path; each one starts with `assertAdmin()`. Identity comes only
  from the Appwrite session secret in the `coc_cms_session` cookie, never from a client-supplied
  userId, and there is no dev shortcut: with no Appwrite configured nobody can sign in.
- Login has two Appwrite calls and neither alone is enough: `Account.createEmailPasswordSession`
  proves the password but **never returns a secret for a server-side call**, so `Users.createSession`
  mints the one the cookie can hold, and the proof session is deleted right after. Do not "simplify"
  this to a single call — dropping the first silently turns the password check off.
- The CMS writes `c_*` tables only. Published content (`l_*`) stays Learning's, through
  `POST /v1/admin/content-versions`.
- `src/cms/` (schema, tables, lint, render) must stay lossless against `tools/content/course-lib.mjs`.
  After touching it, run `node apps/cms/scripts/roundtrip.mjs`.
- Course section membership keys on **theme**, and `build-course.mjs` renumbers `uNN` by position, so
  an unassigned theme breaks the build and a deleted middle unit orphans saved progress. Keep
  `structureIssues()` empty: the structure panel, `exportCourseToRepo` and publish readiness all call it,
  and `node apps/cms/scripts/structure-check.mjs` proves the rendered `course.mjs` still builds.
- Media asset ids are **derived, never stored**: `src/cms/media.ts` rebuilds `a.<uNN>.s<k>|d<k>.n|.s` and
  `i.<uNN>.<wordId>` from the draft, so it must keep matching `docs/content/EXERCISE_FORMATS.md` §5 and the
  generator. Tap-to-hear **word clips are the exception**: `a.w.<slug>.n` is a slug of the text printed on
  an exercise tile (`build-course.mjs:166`), which no authored field names — the row id is a different
  string (`oclock` vs `o_clock`) and tiles also hold function words that are not vocabulary rows. So
  `media-service.ts` reads `dist/<version>/bundles/*.json` (each lists the assets its `unitId` ships) and
  appends only the `a.w.*` keys the draft cannot produce, flagged `fromBuild`. Never start guessing those
  ids from the draft again. Take **only** `a.w.*` from a bundle: a u10 review lesson also ships `i.u3.apple`
  and `a.u5.night.n`, and those files stay the debt of the unit that introduces the word — the draft
  already lists them there. Word clips are shared the other way too (410 of the 498 appear in several
  units' bundles, one in all 16), so the same clip is one row per using unit and exactly one `--only` key.
  `/api/media` is read-only and confined to `content/<courseId>/media/`. After touching either, run
  `node apps/cms/scripts/media-check.mjs` (compares against the built catalog, the bundle asset lists and
  the files on disk).
- Unit **position is the id the app sees**: `build-course.mjs:39` renders `uNN` from order, so
  `moveUnitDraft` re-reads `store.listUnits` instead of trusting the client index, renumbers densely,
  and saves only rows whose order changed — each with its own `expectedRevision`. Export never deletes,
  so a move leaves the moved units' previous `uNN-*.mjs` names in the source folder; `staleUnitFiles()`
  reports them because `scripts/read-authored.mjs` globs that folder and would re-import them as extra
  units. After touching order or export, run `node apps/cms/scripts/order-check.mjs`.
- Uploads fill that tree, they do not name it: `uploadMedia` accepts a file only when the base of its
  name is a key `courseAssets()` already derived for this course, the extension matches the key, the
  bytes really are ADTS AAC or a 512×512 WebP (`src/cms/media-format.ts` — `build-course.mjs:216`
  declares every image as 512×512 whatever the file holds), and an existing file was confirmed for
  overwrite. Never delete a media file from the CMS, and never write `audio-manifest.json`: duration and
  voice belong to `tools/content/generate-audio.mjs`, so the panel reports "file present, manifest
  missing/stale" instead of pretending the bundle picked the clip up. After touching any of this, run
  `node apps/cms/scripts/media-upload-check.mjs`.
- The course report and the unit panel are **one derivation**: `courseMediaReport()` and `unitAssets()`
  both feed `deriveAssets(loadMediaContext(...))`, so the course page cannot disagree with the unit page,
  and `/api/media/owed` publishes the same gaps as `generate-audio.mjs --only` keys. A clip is owed in
  three ways: no file, no matching manifest entry, or **catalog drift** — `generate-audio.mjs` records the
  transcript `dist/<version>/audio-catalog.json` held at build time (`build-course.mjs:1119` copies
  `sentence.en` / `dialogue.line` into it), so after an edit or a reorder a clip can be on disk with a
  matching manifest entry and still speak the previous sentence. Report that as drift instead of green;
  word clips are excluded because their catalog text comes from exercise tiles, not the vocab row. After
  touching any of this, run `node apps/cms/scripts/media-report-check.mjs`.
- **The draft does not decide what the app shows — the last build does.** `build-course.mjs:918-925`
  swaps `imageChoice` for a text choice while fewer than four introduced words carry `img`, and
  `:928-944` swaps `dialogueTurn` for `speakRepeat` until three distinct replies exist, so a panel that
  only reads the draft reports "enough" for content the app never receives. `builtAssets()` therefore also
  tallies `exercises[].type` per bundle (`exerciseTypes`) and marks each picture `drilledWithPicture`
  from the `vocabularyIds` of the real `imageChoice` drills — `i.u1.student` and `u1.student` are the same
  id by the generator's own naming rule. Exclude the placement test (`build-course.mjs:1035` gives it
  `unitId: "u1"` with `lessonId: "placement"`) from every drill tally, but keep its assets as shipped:
  the app does show them. Never infer these from the recipe tables — read the bundles.
- **The placement test has no editor; it has positions.** `build-course.mjs:1005-1028` harvests ten items
  out of the first unit *by index* (`vocab[3]`, `sentences[4|9|13|17|21]`, `vocab.slice(8)`, `vocab[14]`,
  `story.questions[2]`, and the second `img` word once four exist), so shortening that unit does not drop a
  question — it throws (`choiceVocab` reads `v.vocabularyId` of `undefined`, `matchPairs` reads
  `picked[0].en`), and reordering silently rewrites what the app asks at install. `src/cms/placement.ts`
  mirrors those slots and `placement-service.ts` compares each with the shipped
  `dist/<version>/bundles/placement.json`; the course page shows both columns. Compare by `vocabularyIds`
  only where the generator itself names them (items 1, 5, 7, 10 — item 5 is the same dedupe-and-cap-five the
  generator does at `:347-357`), otherwise by the text it prints into the prompt: sentence `vocabularyIds`
  come from `vocabMatcher` (`:70`), and re-implementing that matcher in the CMS would be a second source of
  truth. If the generator's slots move, `node apps/cms/scripts/placement-check.mjs` fails against the real
  bundle. The first unit's editor states the same thing while typing: `placementMarks(draft)` walks the very
  slots `placementItems` uses and badges those rows `#N` (item 5 marks the whole five-row sweep, item 10 the
  real index of the **second picture row**, not row 2). A badge belongs to the *position*, never to the row,
  so swapping two rows leaves `#1` behind and changes what the test asks — that is the consequence the author
  has to see before pressing Save, and why the panel's "khác bản nháp" is not a bug report about the badge.
  A row that is gone un-marks itself and the editor says the build stops there.
- **Word ids keep their unit prefix, because a unit's review lessons ask other units' words.**
  `/courses/<courseId>/units/<unitId>/lesson` (`src/cms/lessons.ts` + `src/server/lesson-service.ts`) is the
  built-lesson screen: it reads `content/<course>/dist/<version>/manifest.json` and every
  `dist/<version>/bundles/<lessonId>.json` — the frozen files the phone plays — rather than re-deriving
  exercises from the draft. The version comes from the course record (`draft.version`, fallback `v2`) and the
  `uNN` from position (`generatorUnitId(order)`), never guessed from a directory listing. Answer text is read
  from the field the generator grades with (`correctChoiceId` → that choice's text, `referenceText`, the first
  `acceptedText`, then `correctPairIds` / `correctTokenIds` order, so the screen shows the order the app
  expects and not the shuffle) — and pair drills print their bullets instead of a duplicate answer line.
  `vocabularyIds` arrive as `u11.taxi`, and **unit 16's build reviews words other units taught** — 275 of its
  399 exercises, spread over thirteen other units, so `lesson-service` merges `wordIndex(draft, uNN)` across
  *every* unit in the course and returns `unitIds` (`uNN` → the editor's unit id); a borrowed chip is
  labelled with its owning unit and links into that editor. Stripping the prefix and re-adding the current
  unit, which is what an index built from one draft does, turns every review word into a false "lost" report
  (17–53 per unit for units 2–16); `staleWordIds` means only "no draft in this course owns this id". Do not
  re-narrow that index.
  `node apps/cms/scripts/lesson-check.mjs` is the falsifier: fixture exercises for all 12 drill types the
  generator emits (`grep -oE "type: '[a-zA-Z]+'" tools/content/build-course.mjs`) plus the real u1 and u16
  bundles, so a new drill type, a moved field or a re-narrowed index fails loudly instead of printing a
  plausible screen.
- **The readiness checklist re-derives, it never re-implements.** `/courses/<id>/readiness` exists because
  `publishReadiness().blocking` is a single sentence: fix reason 1 and the button then reports reason 2. Each
  row of `src/server/readiness.ts` calls the *same* function as the screen that owns the number —
  `structureIssues` (course panel), `lintUnit` (editor), `placementReport`, `courseLessonDrift` (which shares
  `readBundles` with the built-lesson screen, so "512 bài · 6384 câu" here and the per-unit totals are one
  computation), `courseMediaReport`, and the three repeat lists of the search screen — while `publishable` and
  `publishBlocking` are copied verbatim from `publishReadiness()`. Writing a second loop over drafts or
  bundles is the exact bug this page is meant to prevent. Two asymmetries are deliberate: media debt is only
  `warn` because publish uploads files that exist, and a course with no `manifest.json` is `block` here even
  though the Publish button stays enabled (it inspects unit count, structure and gate freshness only). `units` is the one row
  with `debt: false` — a size, not work — so every other `ok` row must count 0.
  `node apps/cms/scripts/readiness-check.mjs` is the falsifier: it breaks and repairs one condition at a time
  on a scratch three-unit course, checks that every `sửa →` href is a real screen of that course, then
  repeats the equalities against the real `vi_en` build and all 16 authored units.
- **Search answers "is this already taught, and where" — from drafts, never from a build.** A 16-unit course
  is 3771 strings, so `src/cms/search.ts` folds NFD marks away, lowercases and collapses whitespace on *both*
  sides of the comparison while keeping the source index of every character it emits: the highlight is sliced
  out of the text as authored, so a draft with a stray double space is still found and still prints correctly.
  Each hit carries the `tab`/`row`/`field` the editor actually shows, and `/courses/<id>/search` links to
  `?tab=` — keep those names in sync with `unit-editor.tsx` or the click lands on the wrong table. The three
  duplicate lists are three different questions: `repeatedWords` needs `unitCount > 1`, `repeatsInsideUnit`
  looks within one unit (and is a guard for drafts saved before `lintUnit` started rejecting `Trùng từ với dòng
  j` at save time), `repeatedSentences` matches English sentences anywhere. What the app ships stays the media
  report's business; a hit count over the limit is announced, not silently truncated.
  `node apps/cms/scripts/search-check.mjs` measures all of it against the real course.
- **Two actions shell out, and one of them writes to a shared project.** `runContentGates` runs the repo's
  own `build-course` / `lint-course` / `check-content` with `cwd = CMS_REPO_ROOT`, and stops at the first red
  gate instead of running the rest; `publishCourseVersion` runs `tools/content/publish-appwrite.mjs` and is
  `--dry-run` unless the operator both set `CMS_ALLOW_PUBLISH=1` and confirmed the dialog. One run is one
  `c_build_runs` row, written `RUNNING` first and overwritten by the same `runId` — never a new row per
  status. `publishReadiness()` returns only the first blocking reason, in order (no draft → structure →
  no green gate → a unit `updatedAt` after that gate), because the publisher ships `dist/` and an edit after
  the gate means the app would get a build nobody checked. The CMS hands its Appwrite pair **only** to the
  publisher, never to the gates, and never writes `l_*`.
  After touching either action, run `node apps/cms/scripts/publish-check.mjs` — it stubs `node:child_process`
  (including `execFile`'s `promisify.custom`, which a plain callback stub does not reproduce, and which
  silently turns a green gate into a caught TypeError) and records every invocation instead of running it.
- **A server action that fails must not throw.** Next answers a thrown action with a 500 and replaces the
  message with a digest, so the client `catch` shows "có lỗi xảy ra" and the operator loses the sentence that
  told them which folder, row or revision was at fault. Return `{ ok: false, message }` and let the control
  render it; keep the original error for the log with `console.error` (a subprocess traceback belongs there,
  never in a toast). `check:lifecycle` asserts both halves of that contract for the import action.
- Never store a key in a file under this app; `.env.example` lists names only.
- A screen is only proven in a browser. Server-side HTML can render perfectly while the client never
  hydrates (a dev origin outside `allowedDevOrigins`, or `proxy.ts` matching `/_next/*`), which leaves
  every button inert — POSTing a Server Action by hand does not catch it. Drive the control and check
  that state changes.
