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
copy receipt are native.

2026-10-05 avatar continuation: `assets/avatar/` bundles the byte-intact original
Duolingo `avatar_builder_25_sept2025.riv`, 16 original category SVGs from
`avatars.duolingo.com/avatar-builder/`, and the published default configuration
discovered through `wishflow/wishflow-tools`. Exact URLs, byte counts and SHA-256
are in `docs/design/references/AVATAR_ASSETS.json`; the source/input contract and
282 configured choices are in `docs/design/flows/24_AVATAR_ASSET_RESEARCH.md`.
Native controls render the actual original rig. Profile/editor/own QR share the
saved configuration. No third-party app code or private avatar endpoint was copied
or requested. These public assets do not establish historical iOS frame timing.

2026-10-06 Profile source reconciliation adds byte-intact
`reference_art/profile-score-source.png` from Gummble screen
`sc_e3a715a73ff94c63a01613c03db9fe13`. Only original mascot/icon ROIs are reused;
card copy, controls and overview rows are native widgets. The empty-avatar and
complete-profile illustrations reuse the existing byte-identical `profile-04.png`.
Friends Alex portrait reuses the existing `friends-02.png`. Current hashes/source
receipts remain in `docs/design/qa/reference-assets.json`.

2026-10-06 Score information adds byte-intact `score-information.png`
(`sc_b0a8a3f37157451783e5135f760faa0f`) and `score-unavailable.png`
(`sc_2a653020036145dca923b9a6629a92fb`). Only small original portraits/lock ROIs
are reused; English/Vietnamese examples, tabs, speech bubbles and controls are
native. These stills do not provide audio or viseme timelines.

2026-10-08 lower foreign Profile adds byte-intact `profile-foreign-source.png`
from archived Gummble screen `sc_9042f4fee7a6438e9757c1115227cc15`, source URL
`https://storage.gummble.com/prod/content/app_screens/a51eefee-363f-4683-9dc4-8cdb5cc27682.png`.
Only the three illustration regions above source tier numerals are painted;
native owner counters, borders and actions remain independent. SHA-256:
`896b82a21687bad5cdc32445b9206a7ebe4451f2c3c852f827337ed83fc30ba6`.
Foreign hero/QR portraits use authored catalog choices with the same original
Rive file, never another person's saved avatar. Original display metadata governs
hero background/icon colors. These choices do not certify archived identities.
# League ranking source — 2026-10-08

`reference_art/league-ranking-source.png` is byte-identical to Gummble iOS screen
`sc_720ee9469bde455f992879eb3973facf`, retrieved through the live Leaderboard MCP
flow. Source: https://storage.gummble.com/prod/content/app_screens/647f99f5-07d0-431c-a492-dfae6a707c4e.png
SHA256: `bde11536c47851613b08c6a317b31027071293c34539cc9be9926541ede961c4`.
Only the three original rank medals are displayed; text, rows and interactions
remain native. See `docs/design/flows/27_LEAGUE_SOURCE_RECONCILIATION.md` for crops,
authored English fixtures and separately open archived variants.

`reference_art/league-welcome-source.png` preserves the original podium Duo from
screen `sc_98120696dc1a45b4a33fa1ebf0599891` in the same live MCP journey.
Source: https://storage.gummble.com/prod/content/app_screens/66920d1d-b618-4b3c-96ee-85840c508aaf.png
SHA256: `438027a97fbc2b7ce9155887e126551e499e39381bace604be067857bcc873b8`.
It is a source still, not evidence of the original podium animation timeline.

# League history, Year in Review and widgets — 2026-10-08

Seventeen byte-intact Gummble sources. Flutter paints only illustration regions; copy/controls are native. Source hashes are independently audited.

| Bundle file | Source screen | SHA-256 | Source |
| --- | --- | --- | --- |
| league-result-source.png | sc_8218b579af9644988b58eabc20dd1501 | dec962ed3a3da97b82099c509b09050cc8b61f283b503711accc4869962ca711 | [source](https://storage.gummble.com/prod/content/app_screens/c1348dee-2409-42c7-80be-b127950a6756.png) |
| league-promotion-source.png | sc_66df6038334b48a4b752bd9d9e9a0eb4 | 500f7b113ad93a0f8f0ca006a5e0f2d21343367b852d0038d2a4cf21745a9214 | [source](https://storage.gummble.com/prod/content/app_screens/4f2640e5-c6b0-4ea3-953c-f00f5d3b86b6.png) |
| league-reward-source.png | sc_859527b88dda4524aa4131de8fa2a9aa | b34ddb9c09bcecb99bc8a3688af766e1562a67d4395b677bb03d0c204b81300a | [source](https://storage.gummble.com/prod/content/app_screens/8f72de48-0a04-424b-b110-6c9227df13eb.png) |
| year-review-intro.png | sc_47217322c3cb414b8783db58808b8c14 | 8977d6673a166047734e96029edbff214655308f4a2388e6e8abdbe901510d46 | [source](https://storage.gummble.com/prod/content/app_screens/3177234c-7dbf-4d0b-8d1b-ffe15713086c.png) |
| year-review-lessons.png | sc_1c9cf548ba4143b1a71215cddda6500f | dc3579311bb100b85324e88b198f54dcfa669d1a512fc93dad871b4bbb6fa5b9 | [source](https://storage.gummble.com/prod/content/app_screens/138b2836-7e4a-4330-9754-334c1d5b7d6a.png) |
| year-review-xp.png | sc_8343646f584e43e2a005c09f96ecfcc7 | 7e99925f0967440995ffa1b713a3aa30edf4a21d3b23911c3084597496675d80 | [source](https://storage.gummble.com/prod/content/app_screens/25ca31e5-9bcc-430d-9a1e-6757e45b4bb2.png) |
| year-review-league.png | sc_128197cbf369407e85334a3bacb480c9 | 48f7d6b36f43e965957231d3cc92b2d5535261c2439b18d937a640fa422493fc | [source](https://storage.gummble.com/prod/content/app_screens/e93dc85b-77c0-4031-89fc-7e1c7c3f8404.png) |
| year-review-gate.png | sc_97eda01c4d2f4865874939d203d937a9 | dd9f204a6b7986bc697ace61ab4135f07589c340c5ff8d46fac326b708063515 | [source](https://storage.gummble.com/prod/content/app_screens/95884c30-5c17-49da-8050-f02287d8408f.png) |
| year-review-student.png | sc_41d083b87dc1495d9016c28db9380714 | e244ab5ce934e3f9d33a64bbfc3a74ea2f19c0e37fdc40e63c89c51c28ee83b9 | [source](https://storage.gummble.com/prod/content/app_screens/103d1580-950d-4d08-828c-6a3f5dad5630.png) |
| year-review-summary.png | sc_d7a91cc434dc4de89b68b045621ece32 | c6bb583a74482db28704f253f461efdd206c4c1165698a54c496cee8406e1f7b | [source](https://storage.gummble.com/prod/content/app_screens/06ffd6da-bfac-45ec-9d27-0df2e7aa5d36.png) |
| widget-ready.png | sc_62f2ea4ee11a4a7dac490720619ddd52 | 33c6b152ff1e20cdffcb5bfd5cce5c9af1e8f7704f20a49749ff1674f51ce5ef | [source](https://storage.gummble.com/prod/content/app_screens/f3e6449c-4b62-487f-9996-dcda83b33d26.png) |
| widget-early.png | sc_34f5bed1fed74391a676815ac4845015 | 918ed4c8679aa6f4dae81786880807ff1891b00257d116164164455129da48ab | [source](https://storage.gummble.com/prod/content/app_screens/eafd781d-9640-4a80-a2de-e54e44e39b13.png) |
| widget-practice.png | sc_ad6b6bf61f8f47ba89554c805037fcc5 | fe32cf367742876e8c7042cab7860f39eacacad5d284af67e0f4c4fc599062ef | [source](https://storage.gummble.com/prod/content/app_screens/d2179a32-6faa-45a3-9465-762cc7ac2bb8.png) |
| widget-last-chance.png | sc_3a7f89d1de424653861d828ac8ee3166 | 28ff0b164b52678f7d3fae20acea5237b617f6bb96c94f3a3b70ade0e0feb029 | [source](https://storage.gummble.com/prod/content/app_screens/cd0a1d09-fe82-4a3d-8e09-8e48c571b854.png) |
| widget-save.png | sc_4dc34672e5184cd8944a853d5f0c0128 | e7224b72b0d13c117a25a9703bdb8e6b358e4d55cb92b26ecfbff86e1441741c | [source](https://storage.gummble.com/prod/content/app_screens/f161f33d-6018-4c65-b8a6-a4c3e531219b.png) |
| widget-six.png | sc_4ff8cd48ef8f4473b5208256d2b77020 | 8fc0549a98222ec8434e96e8b8a6b82bd0532f7276f54f88b8c16132ba345ccd | [source](https://storage.gummble.com/prod/content/app_screens/0eec81aa-e3d3-43b6-a704-2db0f1845ac3.png) |
| widget-seven.png | sc_808b0fa527354f1eb806ddbdd20e0c52 | b7d329a220b7363bf042182271dbe156b6b76935bb846489e56e7bb6b47b731a | [source](https://storage.gummble.com/prod/content/app_screens/67e38256-e03e-49ea-a0d5-3f93530945e8.png) |

# English speaking source — 2026-10-09

`reference_art/lesson-lily-source.png` is the untouched source screen
`sc_c7b79d960e9c48caabd606f79268d1cf`, SHA-256
`c099ab140786234050011c32332c71479e6ae20e0fc7d6c4fe4834570bc43579`.
[Original](https://storage.gummble.com/prod/content/app_screens/598cc547-5ac1-4b9a-8a62-e594b6e2ec2a.png).
Only the full-body Lily region is painted. Text and actions are native Flutter.
Motion reuses the existing original `motion/character-lily.riv`, with its hash
and verified exported inputs in `docs/design/qa/original-character-assets.json`.
See [English lesson analysis](../../../docs/design/flows/30_ENGLISH_SPOKEN_LESSON.md).

# English section, guidebook and unit-check sources — 2026-10-09

Thirteen byte-intact sources from five live Gummble language-learning flows. Native Flutter text and controls are drawn independently; only illustration regions use these originals. Still images do not establish private animation timelines. See [course analysis](../../../docs/design/flows/29_ENGLISH_COURSE_NAVIGATION.md).

Unit checks also activate the previously inspected original `character-lin.riv`, using its verified reset/correct/incorrect inputs. Its URL/hash remain in `docs/design/qa/original-character-assets.json`. New native frame evidence is in `docs/design/qa/course-finish-motion/`; the complete exported artboard preserves its own padding and does not certify every archived mascot-frame bound.

| Bundle file | Source screen | SHA-256 | Source |
| --- | --- | --- | --- |
| section-list-source.png | sc_1c03dd48361a43689ca89bc28e5c3f5a | fab8f4f98c2ea3bcce87abf22548979cf2995440b69fabfcfff0c8fa42764de1 | [source](https://storage.gummble.com/prod/content/app_screens/8b76c60d-dbc2-4d70-b85e-a3b37e2cc35e.png) |
| section-more-source.png | sc_74d81cafda0248b7bae7c3343f614438 | c5d9f83664c3501a8ad6834a076275e07fcbc0f691e6a1cee5bfe6fae4d04b30 | [source](https://storage.gummble.com/prod/content/app_screens/a5aefbbd-c080-4dcb-b5c4-b01dcd34a512.png) |
| section-detail-source.png | sc_4be0b51beca84327bcdb1e06d8e32114 | 0c2030d7aab276a2afb902d3120ec1223833852b9bc00e1c3f9977491b3336d0 | [source](https://storage.gummble.com/prod/content/app_screens/9e05ae5d-a1ae-4376-9011-c9c92cac64ac.png) |
| section-cefr-source.png | sc_9e00ad56c0c04a23908bdc68bbf8f539 | b587100b4ac99ac327400be3eb2333d43f2dbf830415496158b98e464c3fd335 | [source](https://storage.gummble.com/prod/content/app_screens/e68978f6-40a8-403b-a0ef-b418006f5481.png) |
| section-grammar-source.png | sc_f3a5853ab0ff47b09ffe9503734be57d | 8e93d7c35c469c280c820490e5836e8bc79b8e29c5c0342df1055fa56451c805 | [source](https://storage.gummble.com/prod/content/app_screens/d8e1ecf0-5090-4ca3-9562-a8b90706072a.png) |
| guide-header-source.png | sc_f28417a221944a5aa8982866a518d31c | 662cbbafc56ab7741ed8b7c3bd88d11da3d3dbdf73b55cb2fe433214af300cb3 | [source](https://storage.gummble.com/prod/content/app_screens/eecee649-8139-405f-ba2a-f2f497e67ae0.png) |
| guide-phrases-source.png | sc_31d2548aeb9745718647676508480309 | fecfaa4a8756479385126b223870e7e52f726e15fb6ff0839ea7e38f206acff8 | [source](https://storage.gummble.com/prod/content/app_screens/d96a7b5c-df96-42d4-86bd-b93c812ba474.png) |
| guide-tips-source.png | sc_f43473c096cf47bda671a5a2363c59bb | 4ce3a50c145efbdc6a6fedefbe0c7948ee97fa41a5384f87f57d435ca081a24f | [source](https://storage.gummble.com/prod/content/app_screens/244cb4e6-9fce-4842-b721-a27fc9365573.png) |
| unit-skip-intro.png | sc_93b9780a134742a49ef9315b33c8b714 | e6588fb02cc0918544250f4943d98f480f8fe59bd6cc3c4b51ba01963b069456 | [source](https://storage.gummble.com/prod/content/app_screens/2fbd9993-28e4-4c9c-b0cb-6663c24bcfab.png) |
| unit-skip-exercise.png | sc_c26c069dd4a84cbc8c0c030b9f436085 | e55836959a9503a2abb268f0bfbff825546811614b49da2f0279cd09460ebb6c | [source](https://storage.gummble.com/prod/content/app_screens/da1e2443-d0b1-4976-a0a2-8a1e36bef9ef.png) |
| unit-skip-warning.png | sc_0e8d2cbe798c4f52bb675b1c196ce631 | d229d963d603b0f51f0bfabedd831ae1a4bad82ede36be57b3ac5c4980112159 | [source](https://storage.gummble.com/prod/content/app_screens/5b43adbe-b81e-46d7-975d-34ac7a053c86.png) |
| unit-skip-failed.png | sc_8975ffca8e1f44cebb67878c4dcbd5cb | 1ed29ea7ce99d658617705bbd1461f1f967461d1ed34a4b55a68c82b6c10f23c | [source](https://storage.gummble.com/prod/content/app_screens/1ab882d5-337f-432d-8b78-7d3aeb32b354.png) |
| unit-skip-result.png | sc_1b1f74944fc643ae966c450854f6f45d | edd2628a77ed0a731141f140c11035349b846494ae05bd1bd85bbdc9219aeb0f | [source](https://storage.gummble.com/prod/content/app_screens/f6fccedf-27ff-407b-835e-5db2a2bef4e8.png) |
