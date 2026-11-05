# Remaining UI screens — 2026-10-11

Scope: compare the current mock frontend at `df2a387` with the saved Duolingo
language/shared references, to choose the next UI slice. This is a screen audit,
not authorization to enable SMS, purchases, notifications or cloud adapters.

The [ordered reference index](../../design/references/ORDERED_FLOW_INDEX.json) contains
148 journeys / 912 screen occurrences, including repeated screens and versions.
The [coverage ledger](../../design/qa/FLOW_COVERAGE.json), last dated 2026-10-09, records 33
reusable families, 14 fully reconciled mock journeys and 105 verified occurrences.
Its 120 pending journeys are **not** 120 missing features: many already have
native UI and only lack reconciliation against that particular source variant.
These figures are tracking evidence, not a percentage of the app cloned.

## Confirmed missing or partial surfaces

| Order | Surface | Current implementation | Remaining UI | Evidence |
| --- | --- | --- | --- | --- |
| 1 | Notifications / Reminders | Notifications links only to Practice reminders; the reminder page already has a daily toggle and time picker. | Friends, Leaderboards and Announcements subpages; source-shaped notification category list; reminder push/email selections, smart scheduling, streak/reward categories and restore-default state. | [current views](../../../apps/mobile/lib/features/account/presentation/account_screens.dart), source `895e5cfc-9b69-4563-bd92-a2d666d52c37` and `16e51c8c-fa3e-41a3-aac9-47d0bcdd3f1e` |
| 2 | Phone verification | Profile accepts a phone string. `/auth/verify` is email/link verification. | Dedicated phone entry, Country/Region selector, verification code entry, resend/error and verified states. No OTP journey or route was found. | [profile editor](../../../apps/mobile/lib/features/account/presentation/account_screens.dart), source `e61ea8df-b1fa-4059-b929-dc0cf9770359` and `1df4ff54-d0aa-47cb-9694-2148a2776aae` |
| 3 | Roleplay topics | An existing restaurant entry, typed conversation and feedback are implemented. | Topic library with category cards and review state; category detail with scenario list and mastery stars. The existing restaurant session can be reused after selection. | [journey entry](../../../apps/mobile/lib/features/practice/presentation/journey_screens.dart), source `44028dbd-e044-467b-a923-6bba91b94669` |
| 4 | App icon selection | Streak opens an icon illustration / DONE sheet; Max tour has a local switch. | The selectable Streak Society / Max icon cards and restore-original selection state. The entry and illustration are already present. Actual launcher icon switching is a separate platform task. | [Streak sheet](../../../apps/mobile/lib/features/progress/presentation/streak_screen.dart), [Max tour](../../../apps/mobile/lib/features/progress/presentation/max_screen.dart), source `3b649d91-2d55-41c1-9621-9ebe42f510d6` |
| 5 | Gift a Super subscription | Super offer, plan/tour and family screens exist. Friends Quest also has a GIFT action, which is a different feature. | Gift offer and gift purchase/receipt preview journey. No Super gift view, command or route was found. The archived Apple purchase sheet belongs to the platform, not a Flutter screen to copy into the app. | [router](../../../apps/mobile/lib/main.dart), [Super views](../../../apps/mobile/lib/features/progress/presentation/super_screen.dart), source `9006b2f6-2538-45f7-a645-a3c0d343057c` |
| 6 | Settings document destinations | TERMS, PRIVACY POLICY and ACKNOWLEDGEMENTS are rendered by a helper returning plain Text. | Defined document destinations and working open/back actions. This is an observed navigation gap; the reference archive does not establish the destination document layout or CocEnglish legal copy. | [Settings textLink helper](../../../apps/mobile/lib/features/account/presentation/account_screens.dart) |

The phone and gift gaps are new journeys. Notifications, Roleplay and app-icon
work should extend existing families rather than replace their controllers or
completed views. Orders above are the proposed UI sequence, not P1/P2 backend
phase numbers.

## Device-owned and older-version references

- Dynamic Island and Live Activities have archived iOS references but no
  matching Flutter routes, Swift implementation or extension in the inspected
  app sources. Keep them in the iOS backlog; a browser preview cannot certify
  these OS surfaces.
- Streak widget selection and OS instructions already exist. Actual Android/iOS
  widget extensions are a platform implementation gap, not a wholly missing
  Flutter gallery.
- The older “Practicing to get a heart” journey is not implemented as a heart
  recovery flow. Lesson heart feedback and an out-of-hearts sheet exist; the
  default mock repository disables heart enforcement and the main path uses
  Energy. Reconcile this archived variant before adding another resource loop.
  References do not authorize changing frozen product rules.

## Existing screens to reuse

Current routes and views already cover onboarding/login/recovery, Home/path,
sections/guide/skip, lessons/results, Practice/Words/Mistakes, Stories/Radio,
typed Roleplay, speaking/call preview, quests/league/results, profiles/avatar/
friends/feed, achievements/monthly badges, shop/energy, streak/year review,
Super/Max/family/cancellation, settings/password/course management, Schools,
social accounts, Feedback, sync and recovery. Their source variants, motion,
error states and visual QA may still be open. Do not infer missing screens
solely from a pending ledger row or missing standalone route: sheets and
multi-state views share routes.

Help Center is currently a landing page for recovery/sync; Privacy settings has
one private-profile switch. These are thin pages, but a complete replacement
layout is not established by the target references inspected here. Existing
Feedback and lesson report flows mean “Reporting an issue” is not wholly absent.

## Evidence and limits

- Targeted `rg` searches inspected route builders in `main.dart`, relevant
  screen/controller symbols and Android/iOS source paths. No app code changed.
- Parsed the ordered index and coverage ledger; did not count duplicated
  occurrences as independent screens or change existing completion marks.
- Opened nine saved reference PNGs: phone entry/country selector, Super gift
  offer, Roleplay library/category detail, Notifications/Reminders and app-icon
  picker, plus the lesson-report variant used to avoid a false missing claim.
- Live browser observation at `http://127.0.0.1:4173/preview.html` verified Home
  navigation, own Profile, Settings, Notifications and Practice reminders. The
  Notifications page exposes only one destination, matching the code finding.
- A bounded independent reviewer checked phone, Super gift, notification/help/
  privacy and app-icon findings. Full runtime traversal of all 148 reference
  journeys, device QA and exact archived pixel/motion parity were not performed.
- No new app build or regression-test result is claimed for this audit.
- `pnpm audit:check` passed: 83 JSON files, 4 YAML files, 858 local links,
  13 Mermaid diagrams and 1 event example. All 12 report links also resolve.

Next bounded implementation: Notifications/Reminders mock UI, with source
analysis, meaningful behavior tests, retained selections on Back, narrow/wide
text-scale checks and current preview comparison. Continue under
[UI-EXTENDED-009](../../agent/FRONTEND_FLOW_PLAN.md), preserving the existing
[remaining plan](../../agent/FRONTEND_REMAINING_PLAN.md).
