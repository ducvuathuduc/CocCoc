import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/reminders/application/reminder_coordinator.dart';
import 'package:cocenglish/features/reminders/data/reminder_store.dart';
import 'package:cocenglish/features/reminders/domain/reminder_models.dart';
import 'package:cocenglish/features/reminders/domain/streak_home_widget.dart';
import 'package:cocenglish/features/reminders/presentation/reminder_permission_sheet.dart';
import 'package:cocenglish/features/reminders/services/device_zone.dart';
import 'package:cocenglish/features/reminders/services/home_widget_gateway.dart';
import 'package:cocenglish/features/reminders/services/notification_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeNotes implements NotificationGateway {
  ReminderPermission granted = ReminderPermission.granted;
  bool grantOnRequest = true;
  int requests = 0;
  final scheduled = <int, PlannedReminder>{};
  final shown = <PlannedReminder>[];
  final cancelled = <int>[];
  @override
  Future<void> init({required void Function(String? payload) onTap}) async {}
  @override
  Future<String?> launchPayload() async => null;
  @override
  Future<ReminderPermission> permission() async => granted;
  @override
  Future<bool> requestPermission() async {
    requests++;
    if (grantOnRequest) granted = ReminderPermission.granted;
    return grantOnRequest;
  }

  @override
  Future<void> schedule(PlannedReminder r) async => scheduled[r.id] = r;
  @override
  Future<void> show(PlannedReminder r) async => shown.add(r);
  @override
  Future<void> cancel(Iterable<int> ids) async {
    for (final id in ids) {
      cancelled.add(id);
      scheduled.remove(id);
    }
  }
}

class FakeWidget implements HomeWidgetGateway {
  final published = <StreakHomeWidgetData>[];
  @override
  Future<void> init() async {}
  @override
  Future<String?> launchLink() async => null;
  @override
  Future<void> publish(StreakHomeWidgetData data) async => published.add(data);
  @override
  Stream<String?> get taps => const Stream.empty();
}

SessionReceipt receipt(String id) => SessionReceipt(
  id: id,
  nodeId: 'n1',
  xp: 10,
  accuracy: 1,
  elapsed: const Duration(minutes: 4, seconds: 10),
  firstCompletion: true,
  guest: false,
  placement: false,
);

void main() {
  late FakeNotes notes;
  late FakeWidget widget;
  late MemoryReminderStore store;
  late DateTime clock;
  late ProviderContainer container;

  ProviderContainer make({int streak = 6}) => ProviderContainer(
    overrides: [
      reminderPlatformSupportedProvider.overrideWithValue(true),
      notificationGatewayProvider.overrideWithValue(notes),
      homeWidgetGatewayProvider.overrideWithValue(widget),
      reminderStoreProvider.overrideWithValue(store),
      deviceZoneProvider.overrideWithValue(FixedDeviceZone('Asia/Ho_Chi_Minh')),
      reminderClockProvider.overrideWithValue(() => clock),
      reminderFactsProvider.overrideWithValue(
        () => ReminderFacts(streak: streak, goalMinutes: 10),
      ),
    ],
  );

  setUp(() {
    notes = FakeNotes();
    widget = FakeWidget();
    store = MemoryReminderStore();
    clock = DateTime.utc(2026, 10, 12, 3); // 10:00 in Ho Chi Minh City
    container = make();
  });
  tearDown(() => container.dispose());

  ReminderCoordinator c() => container.read(reminderCoordinatorProvider);

  test(
    'sync schedules today\'s daily and at-risk reminders, publishes widget',
    () async {
      await c().sync();
      expect(notes.scheduled.keys, containsAll([100, 101, 200]));
      expect(notes.scheduled[200]!.at.hour, 20);
      expect(widget.published.last.flame, WidgetFlame.atRisk);
      expect(widget.published.last.streak, 6);
      expect(store.state.timezoneId, 'Asia/Ho_Chi_Minh');
    },
  );

  test(
    'lesson completion cancels today\'s at-risk + daily and lights the flame',
    () async {
      await c().sync();
      await c().onLessonCompleted(receipt('r1'));
      expect(notes.cancelled, containsAll([100, 200]));
      expect(notes.scheduled.containsKey(200), isFalse);
      expect(notes.scheduled.containsKey(100), isFalse);
      expect(notes.scheduled.containsKey(101), isTrue);
      expect(store.state.lastPracticeDay, '2026-10-12');
      expect(store.state.todayMinutes, 5);
      expect(store.state.practiceMinutes, [600]);
      expect(widget.published.last.flame, WidgetFlame.lit);
      expect(widget.published.last.goalPercent, 50);
    },
  );

  test('replanning twice never duplicates (stable ids replace)', () async {
    await c().sync();
    final first = Map.of(notes.scheduled);
    await c().sync();
    expect(notes.scheduled.keys.toSet(), first.keys.toSet());
  });

  test('nothing is scheduled without permission', () async {
    notes.granted = ReminderPermission.notDetermined;
    await c().sync();
    expect(notes.scheduled, isEmpty);
    expect(widget.published, isNotEmpty);
  });

  test('freeze used is shown once, from the stored snapshot', () async {
    store.state = const ReminderLocalState(
      snapshot: ReminderSnapshot(streak: 6, freezeSlots: 2),
    );
    container.dispose();
    container = ProviderContainer(
      overrides: [
        reminderPlatformSupportedProvider.overrideWithValue(true),
        notificationGatewayProvider.overrideWithValue(notes),
        homeWidgetGatewayProvider.overrideWithValue(widget),
        reminderStoreProvider.overrideWithValue(store),
        deviceZoneProvider.overrideWithValue(
          FixedDeviceZone('Asia/Ho_Chi_Minh'),
        ),
        reminderClockProvider.overrideWithValue(() => clock),
        reminderFactsProvider.overrideWithValue(
          () => const ReminderFacts(streak: 6, freezeSlots: 1),
        ),
      ],
    );
    await c().sync();
    await c().sync();
    expect(notes.shown.map((r) => r.kind), [ReminderKind.streakFreezeUsed]);
  });

  test('timezone change replans to the new wall clock', () async {
    await c().sync();
    expect(notes.scheduled[100]!.at.location.name, 'Asia/Ho_Chi_Minh');
    container.dispose();
    container = ProviderContainer(
      overrides: [
        reminderPlatformSupportedProvider.overrideWithValue(true),
        notificationGatewayProvider.overrideWithValue(notes),
        homeWidgetGatewayProvider.overrideWithValue(widget),
        reminderStoreProvider.overrideWithValue(store),
        deviceZoneProvider.overrideWithValue(FixedDeviceZone('Europe/London')),
        reminderClockProvider.overrideWithValue(() => clock),
        reminderFactsProvider.overrideWithValue(() => const ReminderFacts()),
      ],
    );
    await c().sync();
    final daily = notes.scheduled[100]!;
    expect(daily.at.location.name, 'Europe/London');
    expect(daily.at.hour, 17);
    expect(store.state.timezoneId, 'Europe/London');
  });

  test('permission offer: only after the first lesson, never again after an answer', () async {
    notes.granted = ReminderPermission.notDetermined;
    expect(await c().shouldOfferPermission(), isFalse);
    await c().onLessonCompleted(receipt('r1'));
    expect(await c().shouldOfferPermission(), isTrue);
    notes.grantOnRequest = false;
    expect(await c().acceptPermissionOffer(), isFalse);
    expect(store.state.permissionDenied, isTrue);
    expect(await c().shouldOfferPermission(), isFalse);
    expect(notes.requests, 1);
  });

  test('sign-out cancels reminders and forgets practice history', () async {
    await c().onLessonCompleted(receipt('r1'));
    await c().onSignedOut();
    expect(notes.cancelled, containsAll([100, 200, 300, 400, 500, 600]));
    expect(store.state.lastPracticeDay, isNull);
    expect(store.state.practiceMinutes, isEmpty);
    expect(widget.published.last.streak, 0);
  });

  group('permission sheet', () {
    Future<void> pumpHost(WidgetTester tester, {double scale = 1}) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Consumer(
                builder: (context, ref, _) => Scaffold(
                  body: TextButton(
                    onPressed: () => maybeOfferReminders(context, ref),
                    child: const Text('done'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('denied permission keeps learning usable and is not re-asked', (
      tester,
    ) async {
      notes.granted = ReminderPermission.notDetermined;
      notes.grantOnRequest = false;
      store.state = const ReminderLocalState(lastPracticeDay: '2026-10-12');
      await pumpHost(tester);
      await tester.tap(find.text('done'));
      await tester.pumpAndSettle();
      expect(find.text('Make learning a habit'), findsOneWidget);
      expect(find.textContaining('5:00 PM'), findsOneWidget);
      await tester.tap(find.text('TURN ON REMINDERS'));
      await tester.pumpAndSettle();
      expect(notes.requests, 1);
      expect(find.text('Make learning a habit'), findsNothing);
      await tester.tap(find.text('done'));
      await tester.pumpAndSettle();
      expect(find.text('Make learning a habit'), findsNothing);
    });

    testWidgets('"Not now" at text scale 2 records the answer, no OS dialog', (
      tester,
    ) async {
      notes.granted = ReminderPermission.notDetermined;
      store.state = const ReminderLocalState(lastPracticeDay: '2026-10-12');
      await pumpHost(tester, scale: 2);
      await tester.tap(find.text('done'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Make learning a habit'), findsOneWidget);
      semantics.dispose();
      await tester.ensureVisible(find.text('NOT NOW'));
      await tester.tap(find.text('NOT NOW'));
      await tester.pumpAndSettle();
      expect(notes.requests, 0);
      expect(store.state.permissionPrompted, isTrue);
    });
  });
}
