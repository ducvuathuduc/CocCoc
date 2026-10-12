# Course content (Learning-owned)

`content/<courseId>/source/` is authored input; `content/<courseId>/dist/<version>/` is the
generated, immutable, signed course version that Learning publishes (P4-LEARN-001, FR-CONTENT-001).
Wire shapes are owned by [OpenAPI](../docs/api/openapi.yaml) (`CourseManifest`, `LessonBundle`).

| Course | Version | Structure | Exercises |
|---|---|---|---|
| `vi_en` (vi-VN → en-US, A1→A2) | `v2` (**published**, `dist/v2`, committed) | 2 sections, 16 units, 128 nodes (8/unit: 5 levels × 4–6 lessons, story after level 3, unit review, Legendary), 512 lessons + 10-item placement | 6,384 path exercises, all 12 types; 320 words, 486 sentences, 96 dialogue turns, 16 stories |
| `vi_en` | `v1` (6-unit pilot) | **retired** — removed from `dist/` and no longer published | — |

v2 is generated from structured tables (`vi_en/source/v2/units/*.mjs`) by
`tools/content/build-course.mjs` into `dist/v2` and gated by `tools/content/lint-course.mjs` (run from
`check-content.mjs`), which also enforces the unit shape. Format spec:
[docs/content/EXERCISE_FORMATS.md](../docs/content/EXERCISE_FORMATS.md). Reward identities are
`v2.<lessonId>`. Learning's local publisher publishes every `dist/` version (only v2).

## Commands

```sh
node content/tools/build-content.mjs          # = node tools/content/build-course.mjs (regenerate dist/v2)
node content/tools/build-content.mjs --check  # fail if dist/v2 or build-report.json is stale
node content/tools/check-content.mjs          # OpenAPI schema + sha256 + signature + answer-key gate (+ v2 lint)
node tools/content/build-course.mjs           # regenerate content/vi_en/dist/v2 + source/v2/build-report.json
node tools/content/lint-course.mjs            # v2 content lint (intro order, grader round-trip, OpenAPI, determinism)
```

## Integrity

- `manifestHash` = SHA-256 of the canonical manifest *structure* (everything except `bundles`,
  `placementBundle`, `manifestHash`, `signature`, `signatureKeyId`). Bundles embed it.
- `manifest.signature` / `bundle.signature` = Ed25519 over the canonical JSON without the
  signature fields (base64url, 86 chars). Files are stored as canonical JSON, so
  `BundleIndex.sha256` and `publish.json` hashes are hashes of the file bytes.
- The committed `v2` is signed with the **well-known DEV key** `dev-content-1`
  (`services/learning/src/testing/dev-content-key.ts`). Dev/test keyrings trust it; a hosted
  Learning service trusts only `COC_CONTENT_PUBLIC_KEYS`. For a real release rebuild with
  `COC_CONTENT_SIGNING_SEED_HEX` + `COC_CONTENT_SIGNING_KEY_ID` (never commit the seed).

## Media

Audio (`a.<unit>.<item>.n` normal / `.s` 0.75× slow) and image (`i.<unit>.<word>`) asset keys and
metadata are present, but the media files are **not produced yet** (P7-AUDIO-001): their `sha256`
values are deterministic placeholders. Every audio prompt has an authored `nonAudioAlternative` and
every speech item a `nonSpeechAlternative`, so lessons work without media.

## Publishing

Publishing is upload-then-flip: upload every file in `publish.json` to the `learning-assets` bucket,
then call `POST /v1/admin/content-versions` (maintainer) with `courseId`, `versionId`,
`manifestFileId`, `manifestSha256`, `expectedPublishedVersion`. Learning re-reads and verifies every
file before the `l_courses` pointer and the `l_content_versions` row commit together. `pnpm
dev:services` publishes the committed versions into its in-memory store at startup. Uploading to a
cloud project is a deploy action and needs its own authorization.
