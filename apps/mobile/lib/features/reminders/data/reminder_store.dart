import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/reminder_models.dart';

/// Device-local reminder state. Nothing here is authoritative learning data:
/// it only decides when to nudge and what the home widget shows.
class ReminderLocalState {
  const ReminderLocalState({
    this.lastPracticeDay,
    this.todayMinutesDay,
    this.todayMinutes = 0,
    this.practiceMinutes = const [],
    this.permissionPrompted = false,
    this.permissionDenied = false,
    this.timezoneId,
    this.snapshot,
  });

  /// Local `YYYY-MM-DD` of the last completed lesson.
  final String? lastPracticeDay;
  final String? todayMinutesDay;
  final int todayMinutes;

  /// Minutes after local midnight of recent lesson completions (newest last).
  final List<int> practiceMinutes;
  final bool permissionPrompted, permissionDenied;
  final String? timezoneId;
  final ReminderSnapshot? snapshot;

  static const maxSamples = 14;

  ReminderLocalState copyWith({
    String? lastPracticeDay,
    String? todayMinutesDay,
    int? todayMinutes,
    List<int>? practiceMinutes,
    bool? permissionPrompted,
    bool? permissionDenied,
    String? timezoneId,
    ReminderSnapshot? snapshot,
  }) => ReminderLocalState(
    lastPracticeDay: lastPracticeDay ?? this.lastPracticeDay,
    todayMinutesDay: todayMinutesDay ?? this.todayMinutesDay,
    todayMinutes: todayMinutes ?? this.todayMinutes,
    practiceMinutes: practiceMinutes ?? this.practiceMinutes,
    permissionPrompted: permissionPrompted ?? this.permissionPrompted,
    permissionDenied: permissionDenied ?? this.permissionDenied,
    timezoneId: timezoneId ?? this.timezoneId,
    snapshot: snapshot ?? this.snapshot,
  );

  /// Keeps permission answers but forgets the learner's practice history
  /// (sign-out or account switch).
  ReminderLocalState forgetLearner() => ReminderLocalState(
    permissionPrompted: permissionPrompted,
    permissionDenied: permissionDenied,
    timezoneId: timezoneId,
  );

  Map<String, Object?> toJson() => {
    'lastPracticeDay': lastPracticeDay,
    'todayMinutesDay': todayMinutesDay,
    'todayMinutes': todayMinutes,
    'practiceMinutes': practiceMinutes,
    'permissionPrompted': permissionPrompted,
    'permissionDenied': permissionDenied,
    'timezoneId': timezoneId,
    'snapshot': snapshot?.toJson(),
  };

  static ReminderLocalState fromJson(Object? json) {
    if (json is! Map) return const ReminderLocalState();
    String? s(String k) => json[k] is String ? json[k] as String : null;
    final minutes = json['practiceMinutes'];
    return ReminderLocalState(
      lastPracticeDay: s('lastPracticeDay'),
      todayMinutesDay: s('todayMinutesDay'),
      todayMinutes: json['todayMinutes'] is int
          ? json['todayMinutes'] as int
          : 0,
      practiceMinutes: minutes is List
          ? [
              for (final m in minutes)
                if (m is int && m >= 0 && m < 1440) m,
            ]
          : const [],
      permissionPrompted: json['permissionPrompted'] == true,
      permissionDenied: json['permissionDenied'] == true,
      timezoneId: s('timezoneId'),
      snapshot: ReminderSnapshot.fromJson(json['snapshot']),
    );
  }
}

abstract class ReminderStore {
  Future<ReminderLocalState> load();
  Future<void> save(ReminderLocalState state);
}

class MemoryReminderStore implements ReminderStore {
  MemoryReminderStore([this.state = const ReminderLocalState()]);
  ReminderLocalState state;
  @override
  Future<ReminderLocalState> load() async => state;
  @override
  Future<void> save(ReminderLocalState next) async => state = next;
}

class PreferencesReminderStore implements ReminderStore {
  PreferencesReminderStore([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();
  final SharedPreferencesAsync _prefs;
  static const _key = 'coc.reminders.v1';

  @override
  Future<ReminderLocalState> load() async {
    final raw = await _prefs.getString(_key);
    if (raw == null) return const ReminderLocalState();
    try {
      return ReminderLocalState.fromJson(jsonDecode(raw));
    } on FormatException {
      return const ReminderLocalState();
    }
  }

  @override
  Future<void> save(ReminderLocalState state) =>
      _prefs.setString(_key, jsonEncode(state.toJson()));
}
