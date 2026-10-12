# Reminders, nudges and the streak widget

Local-first study reminders (SRS `FR-NOTIFY-001`, [SRS](../../../../../docs/product/SRS.md)) and the
home-screen streak widget. No server push: Appwrite Messaging stays unconfigured
([APPWRITE_SETUP](../../../../../docs/devops/APPWRITE_SETUP.md) checks "0 Messaging providers/topics").

## Layers

| Layer | File | Job |
|---|---|---|
| domain | `reminder_models.dart` | kinds, stable ids, channels, deep links, quiet hours |
| domain | `reminder_copy.dart` | original Vietnamese copy pools + deterministic daily rotation |
| domain | `reminder_planner.dart` | pure planning: daily/at-risk/friend/league + snapshot events |
| domain | `streak_home_widget.dart` | widget payload (flame state, goal %) |
| data | `reminder_store.dart` | device-local state (last practice day, practice times, permission answer, zone, last snapshot) |
| services | `notification_gateway.dart`, `home_widget_gateway.dart`, `device_zone.dart` | plugin I/O (`flutter_local_notifications`, `home_widget`, `flutter_timezone`/`timezone`) |
| application | `reminder_coordinator.dart` | gathers inputs, replans, cancels, publishes widget |
| presentation | `reminder_permission_sheet.dart` | one-time explainer built from existing components |

## Behaviour

- **Daily reminder** at the time from Settings > Notifications > Reminders (`reminderMinute`),
  or the learned time when Smart scheduling is on (15 min before the median of the last 14
  completion times, ≥3 samples). Queued for today (if not practised) and the next 6 days; ids
  `100..106`. After 3 silent days the copy switches to "come back" lines; after 7 nothing is queued.
- **Streak at risk** (`200`): 20:30, or one hour after a later daily reminder, never inside quiet
  hours; only while the streak is > 0 and today has no lesson. Cancelled the moment a lesson completes.
- **Friend streak** (`300`) at 19:00 when a friend streak is active and today is unpractised.
- **League ending** (`400`): 6 h before the week closes (Monday 00:00 UTC, mirrors
  `services/progress/src/domain/time.ts`), pulled back before quiet hours.
- **Events** from comparing the last stored Progress snapshot with the current one: Streak
  Freeze used (`500`) and league promotion (`600`); shown now, or at the end of quiet hours.
- **Milestones** (3, 7, 14, 30, 50, 100, …) appear in the daily copy ("one lesson to 30 days",
  "30 days! today is day 31") instead of a separate notification.
- Every kind is gated by its Settings item's **push** toggle (`practice`, `streak_saver`,
  `friend_nudge`, `league_overtaken`, `streak_freeze`, `league_results`).
- **Quiet hours** 22:00–08:00 apply to automatic nudges. A daily time the learner picked
  explicitly is honoured as picked.
- **Copy rotation**: line = `(daySerial + kindSalt) % pool.length`, so consecutive days differ
  and replanning on the same day never changes the line.
- **Taps** open `/home` (learning path, next lesson), `/streak` or `/league`; any other payload
  falls back to `/home`. Ignored until onboarding has reached the path.
- **Replanning** happens on app start, resume, preference change, Progress snapshot refresh and
  lesson completion. Ids are stable, so a replan replaces instead of duplicating.
- **Reboot / app update**: `ScheduledNotificationBootReceiver` re-registers pending alarms.
  **Timezone change**: alarms keep their absolute instant until the next resume, when the
  coordinator replans in the new zone's wall clock (no native time-zone receiver yet).
- **Sign-out / account switch** cancels everything and forgets local practice history.

## Permission (Duolingo timing)

Nothing is requested at launch (iOS init passes `request*Permission: false`). After the first
completed lesson, when the results chain finishes, `maybeOfferReminders` shows the explainer once.
"Turn on reminders" triggers Android 13+ `POST_NOTIFICATIONS` / iOS authorization; "Not now" or
a denial is remembered and never re-asked; learning is unaffected either way.

## Android

Channels: `coc_reminders`, `coc_streak` (high), `coc_league`, `coc_social`. Small icon
`ic_stat_coc` (monochrome vector), accent palette green, large icon `ic_notification_mascot`.
Exact alarms only when `canScheduleExactNotifications()` is true (`SCHEDULE_EXACT_ALARM`, never
prompted); otherwise `inexactAllowWhileIdle`, and an exact failure retries inexact.

## Widget

Android: `StreakWidgetProvider.kt` + `res/layout/streak_widget.xml`. iOS: see
[ios/StreakWidget/README.md](../../../../ios/StreakWidget/README.md) (Xcode target still to add).
Updated after each lesson and on every sync (app start/resume).

## Next step: server push (not implemented)

Local reminders cannot react to things that happen while the app is closed (a friend passing you
in the league, a friend nudge). When that is wanted: add an FCM provider + APNs key in Appwrite
Messaging, register the device token as an Appwrite push target after sign-in, and send from the
Progress service on the relevant outbox events, honouring the same `notificationsOff` keys and
quiet hours server-side. That is an architecture change (new provider, secrets) and needs an ADR.
