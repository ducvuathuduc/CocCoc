// On-device E2E for local reminders, the permission explainer and the streak
// widget (FR-NOTIFY-001). Runs with Patrol on a real Android device or
// emulator; every notification here is a real system notification posted by
// the production `LocalNotificationGateway` and read back from the shade.
//
// Test hooks live only in this file (a dev-only target): reminders are built
// from the production copy pools/planner and re-timed ~10 s ahead so the test
// does not have to wait for 20:30. Nothing here ships in the app.
//
// Build/run: see work/qa/notify/README.md (patrol build android, then Firebase
// Test Lab or `patrol test`).
import 'dart:io' show Platform;

import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/learning/presentation/lesson_screen.dart';
import 'package:cocenglish/features/onboarding/data/onboarding_repository.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/progress/presentation/streak_screen.dart';
import 'package:cocenglish/features/reminders/application/reminder_coordinator.dart';
import 'package:cocenglish/features/reminders/domain/reminder_copy.dart';
import 'package:cocenglish/features/reminders/domain/reminder_models.dart';
import 'package:cocenglish/features/reminders/domain/reminder_planner.dart';
import 'package:cocenglish/features/reminders/services/home_widget_gateway.dart';
import 'package:cocenglish/features/reminders/services/notification_gateway.dart';
import 'package:cocenglish/main.dart';
import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

const _pathTitle = 'Use basic phrases';
const _explainerTitle = 'Make learning a habit';

void _log(String m) => debugPrint('[notify-e2e] $m');

/// Native screenshot (pulled by `patrol test` into patrol_test/screenshots).
/// Evidence only: a capture failure never fails the test.
Future<void> _shot(PatrolIntegrationTester $, String tag) async {
  try {
    await $.takeNativeScreenshot(tag);
    _log('screenshot $tag');
  } catch (e) {
    _log('screenshot $tag failed: $e');
  }
}

/// pumpAndSettle that tolerates never-ending idle animations.
Future<void> _settle(WidgetTester t, [int seconds = 6]) async {
  try {
    await t.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      Duration(seconds: seconds),
    );
  } catch (_) {
    await t.pump(const Duration(milliseconds: 500));
  }
}

Future<bool> _waitFor(
  WidgetTester t,
  Finder f, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 250));
    if (f.evaluate().isNotEmpty) return true;
  }
  return false;
}

Future<void> _tapText(WidgetTester t, String text) async {
  final f = find.text(text).hitTestable();
  expect(await _waitFor(t, f), isTrue, reason: 'missing "$text"');
  await t.ensureVisible(f.last);
  await t.tap(f.last);
  await _settle(t);
}

/// Boots the real app (local mode, production providers) with onboarding
/// already finished, exactly as a learner who reached the path.
Future<void> _launchApp(PatrolIntegrationTester $) async {
  final repository = PreferencesOnboardingRepository(SharedPreferencesAsync());
  // Must survive OnboardingState.fromJson validation (allowed language and
  // every required answer), otherwise the app resumes at an earlier step.
  await repository.save(
    OnboardingState(
      step: OnboardingStep.lessonEntry,
      language: 'Spanish',
      knowledge: 0,
      reasonIds: const {0},
      goal: 10,
      reminders: true,
      widgetRequested: false,
      plan: 0,
      startPoint: 0,
    ),
  );
  await $.tester.pumpWidget(AppBootstrap(repository: repository));
  expect(await _waitFor($.tester, find.text(_pathTitle)), isTrue);
  await _settle($.tester);
}

ProviderContainer _container(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(Navigator).first));
GoRouter _router(WidgetTester t) =>
    GoRouter.of(t.element(find.byType(Navigator).last));
String _location(WidgetTester t) =>
    _router(t).routerDelegate.currentConfiguration.uri.path;

/// Plays the next lesson on the path through the real UI with correct
/// answers, then walks the result chain until the explainer or the path.
Future<void> _completeLesson(WidgetTester t) async {
  final start = find.byWidgetPredicate(
    (w) => w is Tooltip && (w.message ?? '').startsWith('Start lesson'),
  );
  expect(await _waitFor(t, start), isTrue, reason: 'no lesson to start');
  await t.tap(start.first);
  await _settle(t);
  await _tapText(t, 'START +20 XP');
  expect(await _waitFor(t, find.byType(LessonScreen)), isTrue);
  final c = ProviderScope.containerOf(t.element(find.byType(LessonScreen)));
  for (var i = 0; i < 20; i++) {
    final e = c.read(lessonControllerProvider).current;
    if (e == null || find.text('CLAIM XP').evaluate().isNotEmpty) break;
    switch (e.kind) {
      case ExerciseKind.imageChoice ||
          ExerciseKind.choice ||
          ExerciseKind.listenChoice:
        await _tapText(
          t,
          e.choices.firstWhere((v) => v.id == e.correctIds.first).text,
        );
      case ExerciseKind.wordBank || ExerciseKind.sentenceOrder:
        for (final id in e.correctIds) {
          await _tapText(t, e.tokens.firstWhere((v) => v.id == id).text);
        }
      case ExerciseKind.matchPairs:
        for (final pair in e.pairs.entries) {
          await _tapText(t, pair.key);
          await _tapText(t, pair.value);
        }
      case ExerciseKind.textTranslation ||
          ExerciseKind.fillBlank ||
          ExerciseKind.dictation ||
          ExerciseKind.storyQuestion:
        await t.enterText(find.byType(TextField), e.correctText);
        await _settle(t);
      case ExerciseKind.dialogueTurn || ExerciseKind.speakRepeat:
        await _tapText(t, "CAN'T SPEAK NOW");
        await t.enterText(find.byType(TextField), e.correctText);
        await _settle(t);
    }
    await _tapText(t, 'CHECK');
    await _tapText(t, 'CONTINUE');
  }
  await _tapText(t, 'CLAIM XP');
  // Result chain (streak, goal, widget, friends, gems, quests, league).
  for (var i = 0; i < 16; i++) {
    await _settle(t, 3);
    if (find.text(_explainerTitle).evaluate().isNotEmpty) return;
    if (find.text(_pathTitle).hitTestable().evaluate().isNotEmpty &&
        find.byType(LessonScreen).evaluate().isEmpty) {
      return;
    }
    for (final label in ['CONTINUE', 'I CAN DO IT', 'MAYBE LATER']) {
      final f = find.text(label).hitTestable();
      if (f.evaluate().isNotEmpty) {
        await t.tap(f.last);
        break;
      }
    }
  }
}

/// Grants POST_NOTIFICATIONS through the real OS dialog (Android 13+).
Future<void> _grantViaSystemDialog(
  PatrolIntegrationTester $,
  ProviderContainer c,
) async {
  final request = c.read(notificationGatewayProvider).requestPermission();
  if (await $.platform.mobile.isPermissionDialogVisible(
    timeout: const Duration(seconds: 10),
  )) {
    await $.platform.mobile.grantPermissionWhenInUse();
  }
  expect(await request, isTrue);
}

/// A production reminder (copy, channel, id, link) re-timed [inSeconds] ahead.
Future<PlannedReminder> _reminder(
  ProviderContainer c,
  ReminderKind kind, {
  int inSeconds = 10,
  int streak = 3,
}) async {
  final location = await c.read(deviceZoneProvider).current();
  final now = tz.TZDateTime.now(location);
  final day = ReminderPlanner.daySerial(now);
  final (pool, link) = switch (kind) {
    ReminderKind.daily => (ReminderCopy.dailyWithStreak, ReminderLinks.lesson),
    ReminderKind.streakAtRisk => (
      ReminderCopy.streakAtRisk,
      ReminderLinks.streak,
    ),
    ReminderKind.leagueEnding => (
      ReminderCopy.leagueEnding,
      ReminderLinks.league,
    ),
    _ => throw UnsupportedError('$kind'),
  };
  final line = ReminderCopy.pick(pool, kind, day, streak: streak);
  return PlannedReminder(
    id: kind.baseId,
    kind: kind,
    at: now.add(Duration(seconds: inSeconds)),
    title: line.title,
    body: line.body,
    link: link,
  );
}

/// Waits until the reminder is in the shade, checks title and body, taps it.
Future<void> _expectInShadeAndTap(
  PatrolIntegrationTester $,
  PlannedReminder r,
) async {
  await $.platform.mobile.pressHome();
  Notification? found;
  final end = DateTime.now().add(const Duration(seconds: 150));
  while (found == null && DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(seconds: 3));
    await $.platform.mobile.openNotifications();
    final all = await $.platform.mobile.getNotifications();
    _log('shade: ${all.map((n) => '${n.title} | ${n.content}').toList()}');
    for (final n in all) {
      if (n.title == r.title) found = n;
    }
  }
  expect(found, isNotNull, reason: 'notification "${r.title}" never arrived');
  expect(found!.title, r.title);
  expect(found.content, contains(r.body));
  _log('PASS shade ${r.kind.name}: "${found.title}" / "${found.content}"');
  await _shot($, '${r.kind.name}-in-shade');
  await $.platform.mobile.tapOnNotificationBySelector(
    Selector(text: r.title),
    timeout: const Duration(seconds: 10),
  );
  await _settle($.tester);
}

Future<void> _deepLinkCase(
  PatrolIntegrationTester $,
  ReminderKind kind,
  String expected,
  Finder landed,
) async {
  await _launchApp($);
  final c = _container($.tester);
  await _grantViaSystemDialog($, c);
  // Move away from the target so the tap has to navigate.
  _router($.tester).go(expected == '/settings' ? '/home' : '/settings');
  await _settle($.tester);
  final r = await _reminder(c, kind);
  await c.read(notificationGatewayProvider).schedule(r);
  _log('scheduled ${r.kind.name} id=${r.id} at ${r.at} link=${r.link}');
  await _expectInShadeAndTap($, r);
  expect(await _waitFor($.tester, landed), isTrue);
  expect(_location($.tester), expected);
  await _shot($, '${kind.name}-landed');
  _log('PASS deep link ${kind.name} -> ${_location($.tester)}');
}

void main() {
  patrolTest(
    'explainer after first lesson grants POST_NOTIFICATIONS via the OS dialog',
    ($) async {
      await _launchApp($);
      final c = _container($.tester);
      expect(
        await c.read(notificationGatewayProvider).permission(),
        isNot(ReminderPermission.granted),
      );
      await _completeLesson($.tester);
      expect(await _waitFor($.tester, find.text(_explainerTitle)), isTrue);
      await _shot($, 'explainer');
      await _tapText($.tester, 'TURN ON REMINDERS');
      expect(
        await $.platform.mobile.isPermissionDialogVisible(
          timeout: const Duration(seconds: 10),
        ),
        isTrue,
      );
      await _shot($, 'permission-dialog');
      await $.platform.mobile.grantPermissionWhenInUse();
      expect(await _waitFor($.tester, find.text(_pathTitle)), isTrue);
      expect(
        await c.read(notificationGatewayProvider).permission(),
        ReminderPermission.granted,
      );
      _log('PASS permission granted after first lesson');
    },
  );

  patrolTest('deny in the OS dialog is remembered and never re-asked', (
    $,
  ) async {
    await _launchApp($);
    await _completeLesson($.tester);
    expect(await _waitFor($.tester, find.text(_explainerTitle)), isTrue);
    await _shot($, 'explainer-deny-path');
    await _tapText($.tester, 'TURN ON REMINDERS');
    expect(
      await $.platform.mobile.isPermissionDialogVisible(
        timeout: const Duration(seconds: 10),
      ),
      isTrue,
    );
    await $.platform.mobile.denyPermission();
    expect(await _waitFor($.tester, find.text(_pathTitle)), isTrue);
    final c = _container($.tester);
    expect(
      await c.read(reminderCoordinatorProvider).shouldOfferPermission(),
      isFalse,
    );
    // Second lesson: neither the explainer nor the OS dialog comes back.
    await _completeLesson($.tester);
    expect(find.text(_explainerTitle), findsNothing);
    expect(
      await $.platform.mobile.isPermissionDialogVisible(
        timeout: const Duration(seconds: 4),
      ),
      isFalse,
    );
    expect(await _waitFor($.tester, find.text(_pathTitle)), isTrue);
    _log('PASS deny remembered, no re-ask after lesson 2');
  });

  patrolTest(
    'daily reminder fires in about 10 s and its tap opens home',
    ($) => _deepLinkCase($, ReminderKind.daily, '/home', find.text(_pathTitle)),
  );

  patrolTest(
    'streak-at-risk reminder fires and its tap opens streak',
    ($) => _deepLinkCase(
      $,
      ReminderKind.streakAtRisk,
      '/streak',
      find.byType(StreakScreen),
    ),
  );

  patrolTest(
    'league-ending reminder fires and its tap opens league',
    ($) => _deepLinkCase(
      $,
      ReminderKind.leagueEnding,
      '/league',
      find.byTooltip('Practice'),
    ),
  );

  patrolTest(
    'completing a lesson cancels the streak-at-risk reminder for today',
    ($) async {
      await _launchApp($);
      final c = _container($.tester);
      await _grantViaSystemDialog($, c);
      final r = await _reminder(c, ReminderKind.streakAtRisk, inSeconds: 75);
      await c.read(notificationGatewayProvider).schedule(r);
      final plugin = FlutterLocalNotificationsPlugin();
      Future<Set<int>> pending() async => {
        for (final p in await plugin.pendingNotificationRequests()) p.id,
      };
      expect(await pending(), contains(r.id));
      _log('pending before lesson: ${await pending()}');
      await _completeLesson($.tester);
      // First lesson may show the explainer only if permission is missing;
      // it is granted here, so we land on the path.
      expect(await _waitFor($.tester, find.text(_pathTitle)), isTrue);
      final after = await pending();
      _log('pending after lesson: $after');
      expect(after, isNot(contains(r.id)));
      // Wait past the original fire time: nothing appears in the shade.
      final wait =
          r.at.difference(DateTime.now()) + const Duration(seconds: 20);
      if (!wait.isNegative) await Future<void>.delayed(wait);
      await $.platform.mobile.openNotifications();
      final shade = await $.platform.mobile.getNotifications();
      _log('shade after fire time: ${shade.map((n) => n.title).toList()}');
      expect(shade.where((n) => n.title == r.title), isEmpty);
      await $.platform.mobile.closeNotifications();
      _log('PASS at-risk cancelled by lesson completion');
    },
  );

  patrolTest(
    'streak widget is pinned to the launcher and shows the lesson update',
    ($) async {
      await _launchApp($);
      final c = _container($.tester);
      await _completeLesson($.tester);
      if (find.text(_explainerTitle).evaluate().isNotEmpty) {
        await _tapText($.tester, 'NOT NOW');
      }
      expect(await _waitFor($.tester, find.text(_pathTitle)), isTrue);
      final streak = c.read(learningStateProvider).streak;
      // Data the app published after the lesson (production gateway).
      await c.read(reminderCoordinatorProvider).sync();
      final headline = await HomeWidget.getWidgetData<String>('coc_headline');
      final stored = (await HomeWidget.getWidgetData<Object>(
        'coc_streak',
      ) as num?)?.toInt();
      _log(
        'widget data: streak=$stored headline=$headline (app streak $streak)',
      );
      expect(stored, streak);
      if (Platform.isAndroid &&
          await HomeWidget.isRequestPinWidgetSupported() == true) {
        await HomeWidget.requestPinWidget(
          qualifiedAndroidName: PluginHomeWidgetGateway.androidProvider,
        );
        for (final label in [
          'Add to home screen',
          'Add automatically',
          'ADD AUTOMATICALLY',
          'Add',
        ]) {
          try {
            await $.platform.mobile.tap(
              Selector(text: label),
              timeout: const Duration(seconds: 6),
            );
            break;
          } catch (_) {}
        }
        await Future<void>.delayed(const Duration(seconds: 3));
        final installed = await HomeWidget.getInstalledWidgets();
        _log('installed widgets: ${installed.length}');
        expect(installed, isNotEmpty);
        await c.read(reminderCoordinatorProvider).sync();
        await $.platform.mobile.pressHome();
        await Future<void>.delayed(const Duration(seconds: 3));
        // The launcher renders the RemoteViews; find the streak count text.
        await $.platform.mobile.waitUntilVisible(
          Selector(text: '$streak'),
          timeout: const Duration(seconds: 15),
        );
        if (headline != null) {
          await $.platform.mobile.waitUntilVisible(
            Selector(text: headline),
            timeout: const Duration(seconds: 10),
          );
        }
        _log('PASS widget on launcher shows streak $streak / "$headline"');
        await _shot($, 'streak-widget-launcher');
        // Hold the home screen in the video for the evidence frame.
        await Future<void>.delayed(const Duration(seconds: 4));
      } else {
        fail('requestPinWidget unsupported on this launcher');
      }
    },
  );
}
