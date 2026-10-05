# UI reference assets

Source snapshot2026-10-04. Reference illustrations/logotype/icons are sampled by explicit source rectangles at paint time from local Gummble onboarding PNGs. No whole screenshot is rendered as app UI; all text/options/actions/layout/state are Flutter widgets. Original references and IDs live in docs/design/references/onboarding/manifest.json. Atlas inputs retain their original bytes, avoiding image editing/resampling during asset preparation.

Font inputs are publicly served by the official Duolingo web client, discovered in www.duolingo.com's FontFace loader:

- DuolingoSans: https://d35aaqx5ub95lt.cloudfront.net/vendor/f2331bbfd902cdf8971c4d3184a44283.woff2; variable wght100–900. Converted with fontTools into static TTF weights400/700 for deterministic native Flutter rendering.
- Feather: https://d35aaqx5ub95lt.cloudfront.net/vendor/68d22534874c554b0c9ebabea379fc60.woff2; Feather Bold, converted to TTF.

Current web fonts are not asserted byte-identical to the2025iOS capture. These are reference-fidelity development assets selected by the user; the user authorized uploading this development snapshot to a private GitHub repository on 2026-10-05. No app/store publication was performed. Runtime has no font/image network dependency. A future asset atlas/export can remove unused screenshot pixels after layout review without altering the interactive widget implementation.

Login reference PNGs `login-03`, `login-07`, and `login-17` also retain their original bytes. Explicit illustration/icon rectangles supply Google/Facebook/Apple, the hidden-password eye, saved-account Duo and password-reset success Duo. The complete source IDs and first-party Gummble image URLs are in `docs/design/references/login/manifest.json`; per-screen interpretation is in `docs/design/flows/02_LOGIN.md`. Form fields, text, sheets and buttons are native Flutter widgets.

The seventh language option uses a native Chinese flag, verified against supplementary Gummble Courses screen `sc_54ac81fcb5d64f50ac5cf38f31009de2`. The partially visible seventh row in the onboarding source does not establish its complete icon; this evidence gap is explicit.

Original motion files are bundled byte-intact under `assets/motion/`. URLs, composition dimensions and source frame ranges are in `docs/design/flows/03_DUO_MOTION.md`. SHA-256: wave `cb03c88d8ee661673f726c7ad21e59f466ddf032298882ca144ba8fca74ca382`; idle `69c5fe0196e526ec30c8d24cdad8a2eb8a8a4bf71aec8865c6b83388e56409ca`; pencil `a4a326b63eb899154e5dae0aea41300c24a72841632ec87ed72f6cc5658da34a`; celebrate `7a78cc0560590eb007a74561d36042afbb3de3b8f30f3e9f3740ab9ed97c5bc7`; reading `b05fa8add7ffb3ea083f20c5358080a9f9a65c0a5b56d90321c7ae1ac27ff2a0`. Local `lottie`3.6.1 renders the authored vector timelines; current web files are not asserted identical to archived iOS timelines. Special login/phone mascots retain original still ROIs.

2026-10-04 full frontend continuation: lesson, results, courses, guide, practice, quests, league, profile, settings, shop, signup, friends, delete and call assets are copied byte-intact from ordered `docs/design/references/<family>/manifest.json` source URLs. Only `ArtRegion` illustration/icon rectangles are drawn. All controls, text, calendars, lesson answers, cards, dialogs and navigation remain native widgets. Sample identities/rewards are mock data.

Two additional first-party compositions were located in the public Duolingo web character mapping: `DUO_JUMPFLAP` → https://d35aaqx5ub95lt.cloudfront.net/lottie/8bb6c897c3f01efa2cbd0c138772ef67.json, bundled as `duo-path-jump.json`, 1080×1080, 60fps, frames0–220, SHA-256 `dfb3214aded4eccc6e9e8dcd05abe669c0fe5937a6278df9fab72767a5bda9de`; `DUO_TWIRL` → https://d35aaqx5ub95lt.cloudfront.net/lottie/01a1427cc5613179ea3d7568a5f7445b.json, `duo-path-twirl.json`, 1080×1080, 60fps, frames0–280, SHA-256 `05a27ddbef48568ddf0d82da727322a0b2b1879d9997aba17e6283a93708f793`. The path currently uses jump/flap. Twirl is retained as an identified source asset, not asserted active everywhere. Archived character call lip-sync remains a still source, not a reproduced phoneme timeline.

2026-10-04 English continuation: Words, Sections, Energy and Super illustration/icon regions retain original PNG bytes from `docs/design/references/expanded/manifest.json` and `catalog-cache/manifest.json`. All text, cards, plan selection, sort sheets, forms and actions are native Flutter widgets. English/Vietnamese exercise text is authored mock content.

Ten original `makerInLesson` character Rive exports were identified in the public first-party client bundle. Verified URLs, byte counts and SHA-256 are in `docs/design/qa/original-character-assets.json`. Native inspection verified artboard `character`, state machine `character_statemachine`, triggers `correct_trig`, `incorrect_trig`, `reset_trig`, and booleans `darkmode_bool`, `rtl_bool` for every file. Falstaff is active in lessons; Oscar/Junior are active in Rapid/Legendary. Bea s'mores is active in Rapid introduction. Whistling/headphones are identified source assets with inspected timeline frames, not asserted active everywhere. These exports do not supply archived Radio/Max call lip-sync, Adventure walking or certify source timing.

Rive0.14.11 uses rive_native0.1.11. Web runtime44.0.0 is bundled locally from its official jsDelivr package paths; hashes are in `docs/design/qa/rive-web-runtime.json`. Build with the repository `build:web` command so `RIVE_NATIVE_WASM_HOST=rive/` selects these local files.

English Story/Radio/Roleplay, challenges, Adventure airport scenes/object icons and Explain My Answer badge use byte-intact catalog-cache sources. As audited 2026-10-05, 201 bundled PNGs match saved MCP hashes in `docs/design/qa/reference-assets.json`. The latest 26 additions cover streak/social/family/Clash (14), achievements (six) and status/feed (six), following the prior Stories/Max/Timer Boost additions. Source OS chrome/text/panels are excluded from illustration ROIs. Authored English phrases and native interactive cards remain separate from the illustrations. ReferenceArt uses bounded Flutter ImageCache with explicit per-widget image ownership; original PNG bytes are unchanged.

Stories covers, Max offer/reminder/plans/welcome/call/benefits/invite/completion/app-icon artwork and Timer Boost clock/basket/barrel/rays retain byte-identical Gummble sources. Their per-screen IDs and native-state interpretation are in `docs/design/flows/13_STORIES_LIBRARY.md`, `14_MAX_SUBSCRIPTION.md` and `15_TIMER_BOOST.md`. Max call and black Duo artwork are original stills; their original speech/flight rigs were not obtained. Timer Boost illustrations do not establish a proprietary animation timeline. UI text, prices, trial confirmation and store-stock controls are native widgets with local mock state.

Streak/family, achievement/monthly badge, Friends Clash and status/feed sources are mapped in `docs/design/flows/16_STREAK_SOCIAL.md` through `19_STATUS_FEED.md`. Clash uses the original Eddy coach and Zari/Oscar exercise exports; feed detail uses original Oscar/Eddy exports where mapped. Their verified state machine inputs are reused without invented speech inputs. Actual native Rive frames are captured separately from layout stills. Joint character scenes, premium status symbols and other unmatched source illustrations remain stills; these exports do not establish identical archived pose/frame timing.

Course-removal continuation adds the202nd byte-intact bundled PNG,
`reference_art/course-remove.png`, from Gummble screen
`sc_39a18bbd6e52469ea53842c8e2f55829`. SHA-256:
`7b0e84798f3461e4b4fc820778c1e004945972d6ad044903a6da83c247d10bec`.
The earlier201-file audit above is the published snapshot; the current audit is202.
The crying-Duo ROI includes the original rounded ground shadow, with native
sheet copy/controls outside it. Its animation rig/timing remains unresolved.
Profile QR reuses the existing avatar and logotype ROIs; QR modules, controls and
copy receipt are native. No avatar-builder layers were fabricated.
