import 'package:timezone/timezone.dart' as tz;

import '../../notifications/domain/notification_models.dart';
import 'reminder_copy.dart';
import 'reminder_models.dart';

/// Pure, deterministic reminder scheduling (no plugin, no clock).
///
/// The coordinator calls [plan] on app start, resume, timezone change,
/// preference change and lesson completion, cancels every id in
/// [managedIds] and schedules the result. Because ids are stable per
/// kind/day, replanning replaces rather than duplicates (FR-NOTIFY-001
/// "duplicate schedule key user+day+reminder").
abstract final class ReminderPlanner {
  /// How many days of daily reminders stay queued while the app is closed.
  /// After a week of silence the reminders stop, like a polite friend.
  static const dailyHorizonDays = 7;

  /// Days of silence after which daily copy switches to "come back" lines.
  static const comebackAfterDays = 3;

  static const atRiskTime = ReminderTime(20, 30);
  static const friendStreakTime = ReminderTime(19, 0);
  static const leagueLeadTime = Duration(hours: 6);

  /// Every id the planner may use for scheduled reminders.
  static List<int> get managedIds => [
    for (var d = 0; d < dailyHorizonDays; d++) ReminderKind.daily.baseId + d,
    ReminderKind.streakAtRisk.baseId,
    ReminderKind.friendStreak.baseId,
    ReminderKind.leagueEnding.baseId,
  ];

  /// Ids to cancel immediately after a lesson completes today.
  static List<int> get cancelOnLessonComplete => [
    ReminderKind.daily.baseId,
    ReminderKind.streakAtRisk.baseId,
    ReminderKind.friendStreak.baseId,
  ];

  static int daySerial(DateTime local) => DateTime.utc(
    local.year,
    local.month,
    local.day,
  ).difference(DateTime.utc(1970)).inDays;

  static tz.TZDateTime _at(tz.TZDateTime day, ReminderTime t, [int add = 0]) =>
      tz.TZDateTime(
        day.location,
        day.year,
        day.month,
        day.day + add,
        t.hour,
        t.minute,
      );

  /// Delivery time of the daily reminder: the chosen time, or the learned
  /// time when Smart scheduling is on (kept out of quiet hours).
  static ({ReminderTime time, bool userChosen}) dailyTime(ReminderInputs i) {
    if (i.prefs.smartScheduling && i.smartTime != null) {
      return (time: i.smartTime!, userChosen: false);
    }
    return (time: i.prefs.reminderTime, userChosen: true);
  }

  static List<PlannedReminder> plan(ReminderInputs i) {
    final out = <PlannedReminder>[];
    final now = i.now;
    bool future(tz.TZDateTime t) =>
        t.isAfter(now.add(const Duration(minutes: 1)));

    // Daily reminders: today (if not practised and still ahead) + the next days.
    if (ReminderKind.daily.enabledIn(i.prefs)) {
      final d = dailyTime(i);
      for (var day = 0; day < dailyHorizonDays; day++) {
        if (day == 0 && i.practicedToday) continue;
        var at = _at(now, d.time, day);
        // A user-chosen time is honoured as chosen; a learned time is not
        // allowed to land in quiet hours.
        if (!d.userChosen) at = i.quiet.after(at);
        if (!future(at)) continue;
        final line = _dailyLine(i, day, daySerial(at));
        out.add(
          PlannedReminder(
            id: ReminderKind.daily.baseId + day,
            kind: ReminderKind.daily,
            at: at,
            title: line.title,
            body: line.body,
            link: ReminderLinks.lesson,
          ),
        );
      }
    }

    // Streak at risk: this evening, only while today is still unpractised.
    if (i.streak > 0 &&
        !i.practicedToday &&
        ReminderKind.streakAtRisk.enabledIn(i.prefs)) {
      final daily = _at(now, dailyTime(i).time);
      var at = _at(now, atRiskTime);
      final afterDaily = daily.add(const Duration(hours: 1));
      if (afterDaily.isAfter(at) && afterDaily.day == now.day) at = afterDaily;
      at = i.quiet.before(at);
      if (future(at) && at.day == now.day) {
        final pool = i.freezeSlots > 0
            ? ReminderCopy.streakAtRiskWithFreeze
            : ReminderCopy.streakAtRisk;
        final line = ReminderCopy.pick(
          pool,
          ReminderKind.streakAtRisk,
          daySerial(at),
          streak: i.streak,
        );
        out.add(
          PlannedReminder(
            id: ReminderKind.streakAtRisk.baseId,
            kind: ReminderKind.streakAtRisk,
            at: at,
            title: line.title,
            body: line.body,
            link: ReminderLinks.streak,
          ),
        );
      }
    }

    // Friend streak: early evening, while today is unpractised.
    if (i.friendStreakNames.isNotEmpty &&
        !i.practicedToday &&
        ReminderKind.friendStreak.enabledIn(i.prefs)) {
      final at = i.quiet.before(_at(now, friendStreakTime));
      if (future(at) && at.day == now.day) {
        final serial = daySerial(at);
        final friend = i.friendStreakNames[serial % i.friendStreakNames.length];
        final line = ReminderCopy.pick(
          ReminderCopy.friendStreak,
          ReminderKind.friendStreak,
          serial,
          friend: friend,
        );
        out.add(
          PlannedReminder(
            id: ReminderKind.friendStreak.baseId,
            kind: ReminderKind.friendStreak,
            at: at,
            title: line.title,
            body: line.body,
            link: ReminderLinks.streak,
          ),
        );
      }
    }

    // League ending soon: six hours before the week closes (Monday 00:00
    // UTC), pulled back before quiet hours.
    final weekEnd = leagueWeekEnd(i.leagueWeekId);
    if (weekEnd != null && ReminderKind.leagueEnding.enabledIn(i.prefs)) {
      final at = i.quiet.before(
        tz.TZDateTime.from(weekEnd.subtract(leagueLeadTime), now.location),
      );
      if (future(at) && at.isBefore(weekEnd)) {
        final line = ReminderCopy.pick(
          ReminderCopy.leagueEnding,
          ReminderKind.leagueEnding,
          daySerial(at),
        );
        out.add(
          PlannedReminder(
            id: ReminderKind.leagueEnding.baseId,
            kind: ReminderKind.leagueEnding,
            at: at,
            title: line.title,
            body: line.body,
            link: ReminderLinks.league,
          ),
        );
      }
    }
    return out;
  }

  static ReminderLine _dailyLine(ReminderInputs i, int day, int serial) {
    const k = ReminderKind.daily;
    if (day >= comebackAfterDays) {
      return ReminderCopy.pick(ReminderCopy.comeback, k, serial);
    }
    // Streak value that will be "in progress" on that day, if any.
    final streak = day == 0
        ? i.streak
        : (day == 1 && i.practicedToday ? i.streak : 0);
    if (streak <= 0) return ReminderCopy.pick(ReminderCopy.daily, k, serial);
    if (isStreakMilestone(streak + 1)) {
      return ReminderCopy.pick(
        ReminderCopy.milestoneNext,
        k,
        serial,
        streak: streak,
      );
    }
    if (isStreakMilestone(streak) && day == 1) {
      return ReminderCopy.pick(
        ReminderCopy.milestoneReached,
        k,
        serial,
        streak: streak,
      );
    }
    return ReminderCopy.pick(
      ReminderCopy.dailyWithStreak,
      k,
      serial,
      streak: streak,
    );
  }

  /// Exclusive end of a league week (next Monday 00:00 UTC), mirroring
  /// `services/progress/src/domain/time.ts#leagueWeekEnd`.
  static DateTime? leagueWeekEnd(String? weekId) {
    if (weekId == null) return null;
    final start = DateTime.tryParse('${weekId}T00:00:00Z');
    if (start == null) return null;
    return start.add(const Duration(days: 7));
  }

  /// Immediate events found by comparing the last seen Progress snapshot with
  /// the current one. Shown now, or at the end of quiet hours.
  static List<PlannedReminder> events({
    required ReminderSnapshot? previous,
    required ReminderSnapshot current,
    required NotificationPrefs prefs,
    required tz.TZDateTime now,
    QuietHours quiet = const QuietHours(),
  }) {
    if (previous == null) return const [];
    final out = <PlannedReminder>[];
    final at = quiet.after(now);
    final immediate = !quiet.contains(now);
    final serial = daySerial(at);

    // Freeze slots only ever drop when a freeze is consumed on a missed day
    // (FR-GAME-003); the streak surviving confirms it protected the day.
    if (current.freezeSlots < previous.freezeSlots &&
        current.streak > 0 &&
        current.streak >= previous.streak &&
        ReminderKind.streakFreezeUsed.enabledIn(prefs)) {
      final line = ReminderCopy.pick(
        ReminderCopy.streakFreezeUsed,
        ReminderKind.streakFreezeUsed,
        serial,
        streak: current.streak,
      );
      out.add(
        PlannedReminder(
          id: ReminderKind.streakFreezeUsed.baseId,
          kind: ReminderKind.streakFreezeUsed,
          at: at,
          title: line.title,
          body: line.body,
          link: ReminderLinks.streak,
          immediate: immediate,
        ),
      );
    }

    final week = current.lastLeagueWeekId;
    if (week != null &&
        week != previous.lastLeagueWeekId &&
        const {
          'PROMOTED',
          'TOURNAMENT_ADVANCED',
        }.contains(current.lastLeagueOutcome) &&
        ReminderKind.leaguePromoted.enabledIn(prefs)) {
      final line = ReminderCopy.pick(
        ReminderCopy.leaguePromoted,
        ReminderKind.leaguePromoted,
        serial,
      );
      out.add(
        PlannedReminder(
          id: ReminderKind.leaguePromoted.baseId,
          kind: ReminderKind.leaguePromoted,
          at: at,
          title: line.title,
          body: line.body,
          link: ReminderLinks.league,
          immediate: immediate,
        ),
      );
    }
    return out;
  }

  /// Learned reminder time: 15 minutes before the median of recent practice
  /// times (minutes after local midnight). Needs at least three samples.
  static ReminderTime? smartTime(List<int> practiceMinutes) {
    if (practiceMinutes.length < 3) return null;
    final sorted = [...practiceMinutes]..sort();
    final median = sorted[sorted.length ~/ 2];
    final m = (median - 15) % (24 * 60);
    return ReminderTime(m ~/ 60, m % 60);
  }
}
