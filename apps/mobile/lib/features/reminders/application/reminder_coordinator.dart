import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/config/app_config.dart';
import '../../learning/application/learning_controller.dart';
import '../../learning/domain/learning_models.dart';
import '../../notifications/application/notification_settings_controller.dart';
import '../../onboarding/application/onboarding_controller.dart';
import '../../progress/data/progress_snapshot.dart';
import '../../progress/data/social_repository.dart';
import '../../progress/application/streak_widgets_controller.dart';
import '../../progress/domain/streak_widget.dart';
import '../data/reminder_store.dart';
import '../domain/reminder_models.dart';
import '../domain/reminder_planner.dart';
import '../domain/streak_home_widget.dart';
import '../services/device_zone.dart';
import '../services/home_widget_gateway.dart';
import '../services/notification_gateway.dart';

/// True only on a real Android/iOS runtime. Widget tests run on the host VM,
/// where every reminder dependency is a no-op.
final reminderPlatformSupportedProvider = Provider<bool>(
  (ref) => !kIsWeb && (Platform.isAndroid || Platform.isIOS),
);

final notificationGatewayProvider = Provider<NotificationGateway>(
  (ref) => ref.watch(reminderPlatformSupportedProvider)
      ? LocalNotificationGateway()
      : NoopNotificationGateway(),
);

final homeWidgetGatewayProvider = Provider<HomeWidgetGateway>(
  (ref) => ref.watch(reminderPlatformSupportedProvider)
      ? PluginHomeWidgetGateway()
      : NoopHomeWidgetGateway(),
);

final reminderStoreProvider = Provider<ReminderStore>(
  (ref) => ref.watch(reminderPlatformSupportedProvider)
      ? PreferencesReminderStore()
      : MemoryReminderStore(),
);

final deviceZoneProvider = Provider<DeviceZone>(
  (ref) => ref.watch(reminderPlatformSupportedProvider)
      ? PluginDeviceZone()
      : FixedDeviceZone('Asia/Ho_Chi_Minh'),
);

final reminderClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final reminderCoordinatorProvider = Provider<ReminderCoordinator>((ref) {
  final c = ReminderCoordinator(ref);
  ref.onDispose(c.dispose);
  return c;
});

/// Learner facts the planner needs, read from the app's existing state.
class ReminderFacts {
  const ReminderFacts({
    this.streak = 0,
    this.freezeSlots = 0,
    this.goalMinutes = 10,
    this.leagueWeekId,
    this.lastLeagueWeekId,
    this.lastLeagueOutcome,
    this.friendStreakNames = const [],
  });
  final int streak, freezeSlots, goalMinutes;
  final String? leagueWeekId, lastLeagueWeekId, lastLeagueOutcome;
  final List<String> friendStreakNames;
}

/// Reads [ReminderFacts] from Progress (API mode) or the local ledger.
final reminderFactsProvider = Provider<ReminderFacts Function()>((ref) {
  return () {
    final friends = [
      for (final l
          in ref.read(socialRepositoryProvider).friendStreaks() ??
              const <FriendStreakLink>[])
        if (l.state == FriendStreakState.active) l.name.split(' ').first,
    ];
    final goal = ref.read(onboardingControllerProvider).goal;
    if (ref.read(appConfigProvider).isApi) {
      final s = ref.read(progressSnapshotSourceProvider).value;
      if (s != null) {
        return ReminderFacts(
          streak: s.rewards.currentStreak,
          freezeSlots: s.rewards.freezeSlots,
          goalMinutes: s.profile.dailyGoal,
          leagueWeekId: s.league?.weekId,
          lastLeagueWeekId: s.leagueResult.lastResult?.weekId,
          lastLeagueOutcome: s.leagueResult.lastResult?.outcome,
          friendStreakNames: friends,
        );
      }
    }
    final local = ref.read(learningStateProvider);
    return ReminderFacts(
      streak: local.streak,
      goalMinutes: goal,
      friendStreakNames: friends,
    );
  };
});

String _day(DateTime local) =>
    '${local.year.toString().padLeft(4, '0')}-'
    '${local.month.toString().padLeft(2, '0')}-'
    '${local.day.toString().padLeft(2, '0')}';

/// Owns every local reminder and the home-screen widget. Planning is pure
/// ([ReminderPlanner]); this class only gathers inputs and does the I/O.
class ReminderCoordinator {
  ReminderCoordinator(this._ref);
  final Ref _ref;
  StreamSubscription<String?>? _taps;
  Future<void> _queue = Future.value();
  bool _started = false;

  NotificationGateway get _notes => _ref.read(notificationGatewayProvider);
  HomeWidgetGateway get _widget => _ref.read(homeWidgetGatewayProvider);
  ReminderStore get _store => _ref.read(reminderStoreProvider);

  /// Serialises work so a lesson completion and a resume never interleave.
  Future<T> _serial<T>(Future<T> Function() task) {
    final next = _queue.then((_) => task());
    _queue = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  Future<tz.TZDateTime> _now() async {
    final location = await _ref.read(deviceZoneProvider).current();
    return tz.TZDateTime.from(_ref.read(reminderClockProvider)(), location);
  }

  /// App start: wire taps (notification + widget) to [navigate], route a
  /// cold-start tap, then plan.
  Future<void> start(void Function(String location) navigate) async {
    if (_started) return;
    _started = true;
    try {
      await _notes.init(onTap: (p) => navigate(ReminderLinks.sanitize(p)));
      await _widget.init();
      final launch = await _notes.launchPayload();
      if (launch != null) navigate(ReminderLinks.sanitize(launch));
      final widgetLaunch = await _widget.launchLink();
      if (widgetLaunch != null) navigate(ReminderLinks.sanitize(widgetLaunch));
      _taps = _widget.taps.listen((l) {
        if (l != null) navigate(ReminderLinks.sanitize(l));
      });
    } catch (error) {
      debugPrint('Reminder start failed: $error');
    }
    await sync();
  }

  /// Replans everything. Called on start, resume, timezone change and
  /// preference change. Never throws: reminders must not break learning.
  Future<void> sync() => _serial(() async {
    try {
      await _sync();
    } catch (error) {
      debugPrint('Reminder sync failed: $error');
    }
  });

  Future<void> _sync() async {
    final now = await _now();
    var local = await _store.load();
    final facts = _ref.read(reminderFactsProvider)();
    final prefs = _ref.read(notificationSettingsControllerProvider);
    if (!prefs.ready) {
      await _notes.cancel(ReminderPlanner.managedIds);
      return;
    }
    final today = _day(now);
    final practicedToday = local.lastPracticeDay == today;

    final snapshot = ReminderSnapshot(
      streak: facts.streak,
      freezeSlots: facts.freezeSlots,
      lastLeagueWeekId: facts.lastLeagueWeekId,
      lastLeagueOutcome: facts.lastLeagueOutcome,
    );
    final granted = await _notes.permission() == ReminderPermission.granted;

    await _notes.cancel(ReminderPlanner.managedIds);
    if (granted) {
      final plan = ReminderPlanner.plan(
        ReminderInputs(
          now: now,
          prefs: prefs,
          streak: facts.streak,
          practicedToday: practicedToday,
          freezeSlots: facts.freezeSlots,
          friendStreakNames: facts.friendStreakNames,
          leagueWeekId: facts.leagueWeekId,
          smartTime: ReminderPlanner.smartTime(local.practiceMinutes),
        ),
      );
      for (final r in plan) {
        await _notes.schedule(r);
      }
      final events = ReminderPlanner.events(
        previous: local.snapshot,
        current: snapshot,
        prefs: prefs,
        now: now,
      );
      for (final e in events) {
        e.immediate ? await _notes.show(e) : await _notes.schedule(e);
      }
    }
    local = local.copyWith(snapshot: snapshot, timezoneId: now.location.name);
    await _store.save(local);
    await _widget.publish(
      StreakHomeWidgetData.from(
        streak: facts.streak,
        practicedToday: practicedToday,
        goalMinutes: facts.goalMinutes,
        todayMinutes: local.todayMinutesDay == today ? local.todayMinutes : 0,
        mood: _ref.read(streakWidgetsProvider),
      ),
    );
  }

  /// A lesson finished: cancel today's at-risk and daily reminders at once,
  /// remember the practice time for Smart scheduling, refresh the widget.
  Future<void> onLessonCompleted(SessionReceipt receipt) async {
    await _serial(() async {
      try {
        await _notes.cancel(ReminderPlanner.cancelOnLessonComplete);
        final now = await _now();
        final local = await _store.load();
        final today = _day(now);
        final minutes = (receipt.elapsed.inSeconds / 60).ceil().clamp(1, 120);
        final samples = [...local.practiceMinutes, now.hour * 60 + now.minute];
        await _store.save(
          local.copyWith(
            lastPracticeDay: today,
            todayMinutesDay: today,
            todayMinutes:
                (local.todayMinutesDay == today ? local.todayMinutes : 0) +
                minutes,
            practiceMinutes: samples.length > ReminderLocalState.maxSamples
                ? samples.sublist(
                    samples.length - ReminderLocalState.maxSamples,
                  )
                : samples,
          ),
        );
      } catch (error) {
        debugPrint('Reminder lesson update failed: $error');
      }
    });
    await sync();
  }

  /// Duolingo asks right after the first finished lesson, once. Never again
  /// after the learner answers (FR-NOTIFY-001 "no repeated prompt after
  /// denial").
  Future<bool> shouldOfferPermission() async {
    if (!_ref.read(reminderPlatformSupportedProvider)) return false;
    try {
      final local = await _store.load();
      if (local.permissionPrompted || local.lastPracticeDay == null) {
        return false;
      }
      return await _notes.permission() != ReminderPermission.granted;
    } catch (_) {
      return false;
    }
  }

  /// "Turn on reminders" in the explainer: shows the OS dialog.
  Future<bool> acceptPermissionOffer() async {
    final local = await _store.load();
    await _store.save(local.copyWith(permissionPrompted: true));
    var granted = false;
    try {
      granted = await _notes.requestPermission();
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
    }
    if (!granted) {
      await _store.save((await _store.load()).copyWith(permissionDenied: true));
    }
    await sync();
    return granted;
  }

  /// "Not now" in the explainer. Learning stays fully usable.
  Future<void> declinePermissionOffer() async {
    final local = await _store.load();
    await _store.save(
      local.copyWith(permissionPrompted: true, permissionDenied: true),
    );
  }

  /// Sign-out or account switch: drop every reminder and the learner's
  /// practice history, blank the widget.
  Future<void> onSignedOut() => _serial(() async {
    try {
      await _notes.cancel([
        ...ReminderPlanner.managedIds,
        for (final k in ReminderKind.values) k.baseId,
      ]);
      await _store.save((await _store.load()).forgetLearner());
      await _widget.publish(
        StreakHomeWidgetData.from(
          streak: 0,
          practicedToday: false,
          goalMinutes: 10,
          todayMinutes: 0,
          mood: StreakWidgetMood.ready,
        ),
      );
    } catch (error) {
      debugPrint('Reminder sign-out cleanup failed: $error');
    }
  });

  void dispose() {
    _taps?.cancel();
  }
}
