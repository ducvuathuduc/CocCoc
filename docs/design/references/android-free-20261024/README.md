# Free Duolingo reference collection — 2026-10-24

Collected for the Android-first CocEnglish task after Gummble access expired. No account,
subscription or paywall bypass was used. Original source images are unchanged; these are research
references, not a product asset license. The [manifest](manifest.json) records page URL, image URL,
screen index, actual decoded dimensions and SHA-256. Unknown capture dates and versions remain null.

## Original Android captures

| Source flow | Screens | Use and limits |
|---|---:|---|
| [Mobbin: onboarding](https://mobbin.com/explore/flows/afd9076d-2599-44fe-962f-fc723a7a7b6b) | 23 | Welcome, questions, selection and disabled/selected actions; Korean cohort, adapt course text explicitly. |
| [Mobbin: first lesson](https://mobbin.com/explore/flows/660efd18-17ad-4c57-8a32-540352e55b63) | 27 | Lesson feedback, skip listening, streak/results; Korean phonics are outside the English scope. |
| [Mobbin: lesson](https://mobbin.com/explore/flows/43d3b0b8-cb53-443e-918f-aaa7d445196e) | 18 | Translation, selected tokens, correct/wrong feedback, completion. |
| [Mobbin: promo](https://mobbin.com/explore/flows/098f538c-5fa6-4506-8164-e71764f66d1a) | 4 | Shop → entry → typed code → processing. No success/error reference in this flow. |
| [Mobbin: Super](https://mobbin.com/explore/flows/2b062804-06ea-48be-898e-e77c163bfc72) | 12 | Comparison → reminder → plans → Google Play → processing → trial/welcome → brand → home. Store sheet is OS-owned. |
| [Mobbin: dark mode](https://mobbin.com/explore/flows/7f7f386a-bb6b-4835-8490-ada04ebc4d67) | 15 | System Default/On/Off, dark account, home, lesson, practice, league, quests and feed. |
| [Mobbin: Friend Streaks](https://mobbin.com/explore/flows/9739cac1-c512-4083-ba60-e388ea244ca9) | 5 | Empty, invite, invited, pending and active/nudge. Observed invite counts are a fixture, not a business rule. |
| [Mobbin: leveling up](https://mobbin.com/explore/flows/c2a18d3e-9279-48b6-983c-8fb682822a29) | 14 | Level intro, correction/hard feedback, results, gems and Legendary offer; Korean cohort. |

Total: **118 Mobbin Android frames**, 360×900 including the Mobbin footer. The app screenshot is
360×780; status/navigation bars are part of the captured OS context. Preserve attribution and exclude
the footer when comparing app geometry. This archived set does not establish the current universal
Duolingo rollout or measured animation timing.

[BestLanguageApp's own capture](https://bestlanguageapp.com/reviews/duolingo) supplies five additional
Android frames: home, word bank, listening, Score unlock and upgradeable chest. The review states
version 6.90.3, 2026-07-31, Moto G Power (2021), Android 11, a free account learning Vietnamese.
The platform/version metadata is a single-source claim; UI was visually inspected. It establishes
screen existence in that cohort, not reward probabilities or the English course's complete flow.

## Additional platforms checked

| Platform | Public result | Decision |
|---|---|---|
| [Pageflows Android browsing](https://pageflows.com/post/android/general-browsing/duolingo/) | Public 5:12.54 video plays; page explicitly labels **April 2024**. 19 flows listed, most still thumbnails require signup. | Android motion/order reference for that archive. [Metadata](pageflows-source.json); not evidence of current rollout. |
| [Lazyweb Duolingo](https://www.lazyweb.com/company/duolingo) | Five of 187 images public, page updated August 2026. The five saved images show iOS chrome/App Store and dated source paths. | Saved five originals for cross-checking only; excluded from Android pixel acceptance. |
| [Pinterest pin](https://in.pinterest.com/pin/906279124994143458/) | Pin points to UI Sources/ScreensDesign and explicitly describes iOS research. Other search results include fan redesigns. | Discovery only; no verified original Android screen accepted from these pins. |
| [ScreensDesign](https://screensdesign.com/showcase/duolingo-language-lessons) | Public sample; full library/video requires access. | Sample only; no locked material fetched. |
| [Templateshake](https://templateshake.com/product/duolingo-language-lessons/) | Public viewer identifies iPhone screenshots. | Excluded from Android acceptance. |
| [Dezzayn](https://dezzayn.com/apps/duolingo) | Web/iOS samples. | Excluded from Android acceptance. |
| [Revyl Atlas](https://revyl.com/atlas/duolingo/) | iOS sample library. | Excluded from Android acceptance. |
| [60fps chest interaction](https://60fps.design/shots/duolingo-chest-open-interaction) | Public 22.33-second clip plays; visible iPhone/Dynamic Island frame. Common → Rare → Epic → gems. | Motion corroboration only; [metadata](motion-sources.json). Android timing/probabilities remain open. |
| [Google Play listing](https://play.google.com/store/apps/details?id=com.duolingo&hl=en_US) | Official marketing screenshots. | Android identity/features; not full interactive states. |
| [Official widget article](https://blog.duolingo.com/widget-feature/) | Android widget instructions and mood examples. | Widget semantics/context; device layout still needs capture. |

## Acceptance boundaries

- A source URL and still image do not prove a button's backend, reward policy or animation curve.
- English learning content is CocEnglish-authored. French/Korean/Vietnamese sample text is not
  copied into the English curriculum to satisfy a visual match.
- The Android offer sequence differs from the archived iOS pre-trial brand interstitial. Do not
  place the iOS-only ordering in Android based solely on that iOS capture.
- Current implementation gaps and validation are tracked in the
  [Android comparison receipt](../../qa/ANDROID_REFERENCE_AUDIT_20261024.md).


## Non-payment implementation supplement

[Completion asset ledger](completion-assets.json) records the Android Super crops, Common chest crop, exact dark-mode palette coordinates and the source-derived gradient. It also records the 60fps video frame requests (8/15/20 seconds) and the public Android Authority chest captures. The latter show iOS status-bar icons: Rare/Epic/Mega art is corroboration and adaptation, with Android appearance/timing parity still unproven. The chest odds in the app are versioned CocEnglish rules, not inferred Duolingo odds.
