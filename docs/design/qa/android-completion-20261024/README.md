# Android completion captures — 2026-10-24

Eighteen screenshots from the instrumented API 34 x86_64 emulator run, at 1080×2154.
The test mounts production widgets with injected confirmed access and chest receipts; it does not
contact a store or cloud backend. [Full receipt](../ANDROID_NONPAYMENT_COMPLETION_20261024.md).
[Sources and transformations](../../references/android-free-20261024/completion-assets.json).

| Appearance | Chest | Super |
|---|---|---|
| [Light settings](android-completion-settings-light.png) | [Common](android-completion-chest-common.png) | [Comparison](android-completion-super-comparison.png) |
| [Source radio dialog](android-completion-dark-dialog.png) | [Mid-motion](android-completion-chest-motion.png) | [Access reminder](android-completion-super-reminder.png) |
| [Dark settings](android-completion-settings-dark.png) | [Rare](android-completion-chest-rare.png) | [Plans](android-completion-super-plans.png) |
| | [Epic](android-completion-chest-epic.png) | [All plans](android-completion-super-all-plans.png) |
| | [Mega](android-completion-chest-mega.png) | [Confirmed access](android-completion-super-confirmed.png) |
| | [Gem reveal, Continue enabled](android-completion-chest-reward.png) | [Welcome](android-completion-super-welcome.png) |
| | | [Brand transition](android-completion-super-brand.png) |
| [Real MainApp dark home](android-completion-home-dark.png) | | [Home coachmark](android-completion-super-coachmark.png) |

The [web home](web-home-dark.png) is a separate browser capture of the release preview with mock
auth/data. The native test disables mascot loops for deterministic capture; the dark static fallback
retains original Duo pixels with only its edge-connected light background removed. Five original
Rive poses were separately tested with native motion enabled.

Common and Super have Android references. Later chest tiers retain original iOS corroborating art
and are explicitly adapted to Android. A screenshot proves a rendered state, not source timing,
physical-device performance or authenticated backend integration. See
[machine verification](verification.json) for command results and final artifact hashes.
