import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/notifications/application/notification_settings_controller.dart';
import 'package:cocenglish/features/notifications/data/notification_repository.dart';
import 'package:cocenglish/features/notifications/domain/notification_models.dart';
import 'package:cocenglish/features/notifications/presentation/notification_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<void> _fonts(WidgetTester t) => t.runAsync(() async {
  await (FontLoader('DuolingoSans')
        ..addFont(rootBundle.load('assets/fonts/DuolingoSans.ttf'))
        ..addFont(rootBundle.load('assets/fonts/DuolingoSans-Bold.ttf')))
      .load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
});

void _size(WidgetTester t, {double dpr = 1}) {
  t.view.physicalSize = Size(390 * dpr, 845 * dpr);
  t.view.devicePixelRatio = dpr;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

/// Router mirroring the app's routes for this slice.
GoRouter _router(String initial) => GoRouter(
  initialLocation: initial,
  routes: [
    GoRoute(
      path: '/settings',
      builder: (_, _) => const Scaffold(body: Text('settings')),
    ),
    GoRoute(
      path: '/settings/notifications',
      builder: (_, _) => const NotificationsHubScreen(),
    ),
    GoRoute(
      path: '/settings/notifications/:category',
      builder: (_, s) =>
          NotificationCategoryScreen(categoryId: s.pathParameters['category']!),
    ),
  ],
);

Future<ProviderContainer> _pump(
  WidgetTester t,
  String location, {
  MockNotificationRepository? repo,
}) async {
  final c = ProviderContainer(
    overrides: [
      notificationRepositoryProvider.overrideWithValue(
        repo ?? MockNotificationRepository(),
      ),
    ],
  );
  addTearDown(c.dispose);
  final router = _router('/settings');
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: referenceTheme(),
        routerConfig: router,
        builder: (context, child) => RepaintBoundary(
          key: const ValueKey('golden'),
          child: MediaQuery(
            // iPhone status-bar inset so layout lines up with the refs.
            data: MediaQuery.of(context)
                .copyWith(padding: const EdgeInsets.only(top: 47)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  router.push('/settings/notifications');
  await t.pumpAndSettle();
  if (location != '/settings/notifications') {
    router.push(location);
    await t.pumpAndSettle();
  }
  return c;
}

NotificationPrefs _prefs(ProviderContainer c) =>
    c.read(notificationSettingsControllerProvider);

void main() {
  group('Notifications hub', () {
    testWidgets('lists every category and opens each', (t) async {
      _size(t);
      await _pump(t, '/settings/notifications');
      for (final title in [
        'Reminders',
        'Friends',
        'Leaderboards',
        'Announcements',
        'Friend Nudges',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      expect(find.text('2 notifications turned off'), findsOneWidget);

      for (final id in ['friends', 'leaderboards', 'announcements', 'nudges']) {
        await t.tap(find.byKey(ValueKey('notif-category-$id')));
        await t.pumpAndSettle();
        expect(find.byType(NotificationCategoryScreen), findsOneWidget);
        await t.tap(find.byTooltip('Back'));
        await t.pumpAndSettle();
        expect(find.byType(NotificationsHubScreen), findsOneWidget);
      }
    });

    testWidgets('off count reflects toggles made in a category', (t) async {
      _size(t);
      await _pump(t, '/settings/notifications');
      await t.tap(find.byKey(const ValueKey('notif-category-friends')));
      await t.pumpAndSettle();
      expect(find.text('Push'), findsNothing); // labels are semantics only
      await t.tap(find.byKey(const ValueKey('chip-new_follower-email')));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Back'));
      await t.pumpAndSettle();
      expect(find.text('1 notification turned off'), findsOneWidget);
    });
  });

  group('Reminders', () {
    testWidgets('push/email chips toggle and persist', (t) async {
      _size(t);
      final repo = MockNotificationRepository();
      final c = await _pump(t, '/settings/notifications/reminders', repo: repo);
      expect(_prefs(c).isOn('streak_saver', NotificationChannel.push), isTrue);
      await t.tap(find.byKey(const ValueKey('chip-streak_saver-push')));
      await t.pumpAndSettle();
      expect(_prefs(c).isOn('streak_saver', NotificationChannel.push), isFalse);
      expect(
        repo.load().isOn('streak_saver', NotificationChannel.push),
        isFalse,
      );
      await t.tap(find.byKey(const ValueKey('chip-practice-email')));
      await t.pumpAndSettle();
      expect(_prefs(c).isOn('practice', NotificationChannel.email), isFalse);
      expect(_prefs(c).isOn('practice', NotificationChannel.push), isTrue);
    });

    testWidgets('smart scheduling disables the reminder time', (t) async {
      _size(t);
      final c = await _pump(t, '/settings/notifications/reminders');
      await t.tap(find.byKey(const ValueKey('smart-scheduling-switch')));
      await t.pumpAndSettle();
      expect(_prefs(c).smartScheduling, isTrue);
      await t.tap(find.byKey(const ValueKey('reminder-time-row')));
      await t.pumpAndSettle();
      expect(find.text('DONE'), findsNothing);
    });

    testWidgets('time picker sheet changes the reminder time', (t) async {
      _size(t);
      final c = await _pump(t, '/settings/notifications/reminders');
      expect(find.text('5:00 PM'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('reminder-time-row')));
      await t.pumpAndSettle();
      expect(find.text('DONE'), findsOneWidget);
      // Scroll the hour wheel down by one row: 5 -> 6.
      await t.drag(
        find.byKey(const ValueKey('picker-hour')),
        const Offset(0, -31),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('reminder-time-done')));
      await t.pumpAndSettle();
      expect(_prefs(c).reminderTime, const ReminderTime(18, 0));
      expect(find.text('6:00 PM'), findsOneWidget);
    });

    testWidgets('restore default appears only when changed', (t) async {
      _size(t);
      final c = await _pump(
        t,
        '/settings/notifications/reminders',
        repo: MockNotificationRepository(initial: const NotificationPrefs()),
      );
      expect(find.byKey(const ValueKey('restore-default')), findsNothing);
      await t.tap(find.byKey(const ValueKey('chip-streak_saver-push')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('restore-default')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('chip-streak_saver-push')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('restore-default')), findsNothing);

      c
          .read(notificationSettingsControllerProvider.notifier)
          .setReminderTime(const ReminderTime(9, 30));
      await t.tap(find.byKey(const ValueKey('chip-early_bird-push')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('restore-default')));
      await t.pumpAndSettle();
      expect(_prefs(c).off, isEmpty);
      expect(_prefs(c).reminderTime, const ReminderTime(17, 0));
    });

    test('ReminderTime label formats 12h', () {
      expect(const ReminderTime(17, 0).label, '5:00 PM');
      expect(const ReminderTime(0, 30).label, '12:30 AM');
      expect(const ReminderTime(12, 0).label, '12:00 PM');
    });
  });

  group('goldens', () {
    Future<void> shot(
      WidgetTester t,
      String location,
      String name, {
      Future<void> Function(WidgetTester t)? act,
    }) async {
      _size(t, dpr: 3);
      await _fonts(t);
      await _pump(t, location);
      if (act != null) await act(t);
      await expectLater(
        find.byKey(const ValueKey('golden')),
        matchesGoldenFile('goldens/notif/$name.png'),
      );
    }

    testWidgets('hub', (t) => shot(t, '/settings/notifications', 'hub'));
    testWidgets(
      'reminders',
      (t) => shot(t, '/settings/notifications/reminders', 'reminders'),
    );
    testWidgets(
      'reminders smart on',
      (t) => shot(
        t,
        '/settings/notifications/reminders',
        'reminders_smart',
        act: (t) async {
          await t.tap(find.byKey(const ValueKey('smart-scheduling-switch')));
          await t.pumpAndSettle();
        },
      ),
    );
    testWidgets(
      'reminder time picker',
      (t) => shot(
        t,
        '/settings/notifications/reminders',
        'reminders_picker',
        act: (t) async {
          await t.tap(find.byKey(const ValueKey('reminder-time-row')));
          await t.pumpAndSettle();
        },
      ),
    );
    for (final id in ['friends', 'leaderboards', 'announcements', 'nudges']) {
      testWidgets(id, (t) => shot(t, '/settings/notifications/$id', id));
    }
  });
}
