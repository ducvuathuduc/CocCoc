import 'package:timezone/timezone.dart' as tz;

import '../../notifications/domain/notification_models.dart';

/// Kind of local reminder or nudge. Each kind owns a stable notification id
/// range, an Android channel and the Settings > Notifications item that
/// gates it (FR-NOTIFY-001).
enum ReminderKind {
  /// Daily practice reminder at the user's chosen (or smart) time.
  daily(100, ReminderChannel.reminders, 'practice'),

  /// Evening "streak at risk" nudge; cancelled once a lesson completes.
  streakAtRisk(200, ReminderChannel.streak, 'streak_saver'),

  /// A friend streak is waiting for today's lesson.
  friendStreak(300, ReminderChannel.social, 'friend_nudge'),

  /// The league week closes soon.
  leagueEnding(400, ReminderChannel.league, 'league_overtaken'),

  /// A Streak Freeze protected yesterday.
  streakFreezeUsed(500, ReminderChannel.streak, 'streak_freeze'),

  /// The learner was promoted at league close.
  leaguePromoted(600, ReminderChannel.league, 'league_results');

  const ReminderKind(this.baseId, this.channel, this.prefItem);

  /// First notification id of this kind; day offsets add to it.
  final int baseId;
  final ReminderChannel channel;

  /// Settings > Notifications item id whose push toggle gates this kind.
  final String prefItem;

  bool enabledIn(NotificationPrefs prefs) =>
      prefs.isOn(prefItem, NotificationChannel.push);
}

/// Android notification channels (user-visible in system settings).
enum ReminderChannel {
  reminders('coc_reminders', 'Nhắc học hằng ngày', 'Lời nhắc học mỗi ngày'),
  streak('coc_streak', 'Chuỗi ngày học', 'Chuỗi sắp mất, Băng giữ chuỗi'),
  league('coc_league', 'Giải đấu', 'Giải đấu sắp kết thúc, kết quả thăng hạng'),
  social('coc_social', 'Bạn bè', 'Chuỗi bạn bè và lời nhắc từ bạn bè');

  const ReminderChannel(this.id, this.title, this.description);
  final String id, title, description;
}

/// Where a notification tap lands (go_router locations that exist today).
abstract final class ReminderLinks {
  /// The learning path; the next lesson starts from here.
  static const lesson = '/home';
  static const streak = '/streak';
  static const league = '/league';

  static const all = {lesson, streak, league};

  /// Accepts only known in-app locations; anything else opens the path.
  static String sanitize(String? payload) =>
      payload != null && all.contains(payload) ? payload : lesson;
}

/// A wall-clock window in which automatic nudges are not delivered. The
/// window may wrap midnight (22:00 → 08:00).
class QuietHours {
  const QuietHours({
    this.start = const ReminderTime(22, 0),
    this.end = const ReminderTime(8, 0),
  });
  final ReminderTime start, end;

  static int _m(ReminderTime t) => t.hour * 60 + t.minute;

  bool contains(DateTime local) {
    final m = local.hour * 60 + local.minute, s = _m(start), e = _m(end);
    if (s == e) return false;
    return s < e ? (m >= s && m < e) : (m >= s || m < e);
  }

  /// Latest delivery before the quiet window that [local] falls in (30 min
  /// before it opens). Returns [local] unchanged when it is not quiet.
  tz.TZDateTime before(tz.TZDateTime local) {
    if (!contains(local)) return local;
    final s = _m(start);
    final m = local.hour * 60 + local.minute;
    // A time after midnight belongs to the window that opened yesterday.
    final dayShift = s > _m(end) && m < s ? -1 : 0;
    return tz.TZDateTime(
      local.location,
      local.year,
      local.month,
      local.day + dayShift,
      start.hour,
      start.minute,
    ).subtract(const Duration(minutes: 30));
  }

  /// First delivery after the quiet window that [local] falls in.
  tz.TZDateTime after(tz.TZDateTime local) {
    if (!contains(local)) return local;
    final m = local.hour * 60 + local.minute;
    final dayShift = _m(start) > _m(end) && m >= _m(start) ? 1 : 0;
    return tz.TZDateTime(
      local.location,
      local.year,
      local.month,
      local.day + dayShift,
      end.hour,
      end.minute,
    );
  }
}

/// One notification the scheduler wants on the device.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.kind,
    required this.at,
    required this.title,
    required this.body,
    required this.link,
    this.immediate = false,
  });
  final int id;
  final ReminderKind kind;

  /// Local delivery time (ignored when [immediate]).
  final tz.TZDateTime at;
  final String title, body, link;

  /// Shown now instead of scheduled.
  final bool immediate;

  @override
  String toString() =>
      'PlannedReminder($id ${kind.name} ${immediate ? 'now' : at} "$title")';
}

/// What the planner knows about the learner when it plans.
class ReminderInputs {
  const ReminderInputs({
    required this.now,
    required this.prefs,
    this.streak = 0,
    this.practicedToday = false,
    this.freezeSlots = 0,
    this.friendStreakNames = const [],
    this.leagueWeekId,
    this.smartTime,
    this.quiet = const QuietHours(),
  });

  /// Current instant in the device zone.
  final tz.TZDateTime now;
  final NotificationPrefs prefs;
  final int streak;
  final bool practicedToday;
  final int freezeSlots;

  /// Display names of friends with an active friend streak.
  final List<String> friendStreakNames;

  /// League week id (`YYYY-MM-DD`, the Monday UTC that starts the week), or
  /// null when the learner is not in a cohort this week.
  final String? leagueWeekId;

  /// Learned practice time used when Smart scheduling is on.
  final ReminderTime? smartTime;
  final QuietHours quiet;
}

/// The part of the Progress state the event detector compares between runs.
class ReminderSnapshot {
  const ReminderSnapshot({
    required this.streak,
    required this.freezeSlots,
    this.lastLeagueWeekId,
    this.lastLeagueOutcome,
  });
  final int streak, freezeSlots;
  final String? lastLeagueWeekId, lastLeagueOutcome;

  Map<String, Object?> toJson() => {
    'streak': streak,
    'freezeSlots': freezeSlots,
    'lastLeagueWeekId': lastLeagueWeekId,
    'lastLeagueOutcome': lastLeagueOutcome,
  };

  static ReminderSnapshot? fromJson(Object? json) {
    if (json is! Map) return null;
    final streak = json['streak'], freeze = json['freezeSlots'];
    if (streak is! int || freeze is! int) return null;
    final week = json['lastLeagueWeekId'], outcome = json['lastLeagueOutcome'];
    return ReminderSnapshot(
      streak: streak,
      freezeSlots: freeze,
      lastLeagueWeekId: week is String ? week : null,
      lastLeagueOutcome: outcome is String ? outcome : null,
    );
  }
}
