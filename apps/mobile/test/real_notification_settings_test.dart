import 'dart:async';

import 'package:cocenglish/core/config/app_config.dart';
import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/core/api/client/api_exception.dart';
import 'package:cocenglish/core/api/client/api_transport.dart';
import 'package:cocenglish/features/account/presentation/account_screens.dart';
import 'package:cocenglish/features/notifications/data/api_notification_repository.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/domain/preview_state.dart';
import 'package:flutter/material.dart';
import 'package:cocenglish/features/auth/application/auth_controller.dart';
import 'package:cocenglish/features/auth/domain/auth_state.dart';
import 'package:cocenglish/features/notifications/application/notification_settings_controller.dart';
import 'package:cocenglish/features/notifications/data/notification_repository.dart';
import 'package:cocenglish/features/notifications/domain/notification_models.dart';
import 'package:cocenglish/features/reminders/application/reminder_coordinator.dart';
import 'package:cocenglish/features/reminders/services/notification_gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/real_profile.dart';
import 'support/fake_api_transport.dart';
import 'features/api_snapshot_repositories_test.dart' as fixtures;

class _Identity extends AuthController {
  @override
  AuthState build() => const AuthState(
    user: AuthUser(id: 'a', email: 'a@example.test', name: 'A'),
  );
  void switchAccount() => state = const AuthState(
    user: AuthUser(id: 'b', email: 'b@example.test', name: 'B'),
  );
}

class _Repository extends NotificationRepository {
  final pending = Completer<void>();
  NotificationPrefs saved = const NotificationPrefs();
  Future<NotificationPrefs> Function()? fetcher;
  Future<void> Function()? writer;
  int saves = 0;
  @override
  List<NotificationCategory> get categories => notificationCatalog;
  @override
  NotificationPrefs get defaults => const NotificationPrefs();
  @override
  NotificationPrefs load() => saved;
  @override
  Future<NotificationPrefs> fetch() async =>
      fetcher == null ? saved : await fetcher!();
  @override
  Future<void> save(NotificationPrefs prefs) async {
    saves++;
    if (writer == null) {
      await pending.future;
    } else {
      await writer!();
    }
    saved = prefs;
  }
}

class _NoPreview extends PreviewController {
  @override
  PreviewState build() => throw StateError('API reminders used preview');
}

class _Permission extends NoopNotificationGateway {
  final pending = Completer<bool>();
  int requests = 0;
  @override
  Future<bool> requestPermission() {
    requests++;
    return pending.future;
  }
}

ProviderContainer _container(_Repository repository) => ProviderContainer(
  overrides: [
    appConfigProvider.overrideWithValue(realTestConfig),
    authControllerProvider.overrideWith(_Identity.new),
    notificationRepositoryProvider.overrideWithValue(repository),
    previewControllerProvider.overrideWith(_NoPreview.new),
  ],
);

void main() {
  testWidgets(
    'denied native permission never saves enabled and duplicate taps request once',
    (tester) async {
      final repository = _Repository()
        ..saved = const NotificationPrefs(off: {'practice.push'});
      final permission = _Permission();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(realTestConfig),
          authControllerProvider.overrideWith(_Identity.new),
          notificationRepositoryProvider.overrideWithValue(repository),
          previewControllerProvider.overrideWith(_NoPreview.new),
          notificationGatewayProvider.overrideWithValue(permission),
          reminderFactsProvider.overrideWithValue(() => const ReminderFacts()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ReminderScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      await tester.tap(find.text('Daily reminder'));
      await tester.pump();
      await tester.tap(find.text('Daily reminder'));
      await tester.pump();
      expect(permission.requests, 1);
      permission.pending.complete(false);
      await tester.pumpAndSettle();
      expect(repository.saves, 0);
      expect(
        container
            .read(notificationSettingsControllerProvider)
            .isOn('practice', NotificationChannel.push),
        isFalse,
      );
      expect(
        find.text('Notifications denied. You can still practise anytime.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  test('cold preferences stay unavailable until the actual fetch', () async {
    final repository = _Repository();
    final pending = Completer<NotificationPrefs>();
    repository.fetcher = () => pending.future;
    final container = _container(repository);
    addTearDown(container.dispose);
    expect(
      container.read(notificationSettingsControllerProvider).ready,
      isFalse,
    );
    expect(
      container
          .read(notificationSettingsControllerProvider)
          .isOn('practice', NotificationChannel.push),
      isFalse,
    );
    await container
        .read(notificationSettingsControllerProvider.notifier)
        .toggle('practice', NotificationChannel.push);
    expect(repository.saves, 0);
    pending.complete(
      const NotificationPrefs(reminderTime: ReminderTime(21, 15)),
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(notificationSettingsControllerProvider).ready,
      isTrue,
    );
    expect(
      container.read(notificationSettingsControllerProvider).reminderTime,
      const ReminderTime(21, 15),
    );
  });

  test(
    'save failure keeps last accepted settings and supports retry',
    () async {
      final repository = _Repository()
        ..writer = () async => throw StateError('private detail');
      final container = _container(repository);
      addTearDown(container.dispose);
      final vm = container.read(
        notificationSettingsControllerProvider.notifier,
      );
      await Future<void>.delayed(Duration.zero);
      await vm.toggle('practice', NotificationChannel.push);
      expect(
        container
            .read(notificationSettingsControllerProvider)
            .isOn('practice', NotificationChannel.push),
        isTrue,
      );
      expect(
        container.read(notificationSettingsControllerProvider).error,
        NotificationSettingsController.requestError,
      );
      repository.writer = () async {};
      await vm.retry();
      expect(
        container
            .read(notificationSettingsControllerProvider)
            .isOn('practice', NotificationChannel.push),
        isFalse,
      );
      expect(repository.saves, 2);
    },
  );

  test('duplicate taps dispatch one save', () async {
    final repository = _Repository();
    final container = _container(repository);
    addTearDown(container.dispose);
    final vm = container.read(notificationSettingsControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    final first = vm.toggle('practice', NotificationChannel.push);
    await vm.toggle('practice', NotificationChannel.push);
    expect(repository.saves, 1);
    repository.pending.complete();
    await first;
  });

  test('late account A receipt cannot change account B settings', () async {
    final repository = _Repository();
    final container = _container(repository);
    addTearDown(container.dispose);
    final vm = container.read(notificationSettingsControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    final first = vm.toggle('practice', NotificationChannel.push);
    (container.read(authControllerProvider.notifier) as _Identity)
        .switchAccount();
    container.read(notificationSettingsControllerProvider);
    await Future<void>.delayed(Duration.zero);
    repository.pending.complete();
    await first;
    expect(
      container
          .read(notificationSettingsControllerProvider)
          .isOn('practice', NotificationChannel.push),
      isTrue,
    );
  });

  test(
    'uncertain HTTP retry retains identical body and idempotency key',
    () async {
      final transport = FakeApiTransport()
        ..json('GET /base/v1/me/preferences', fixtures.preferences(revision: 4))
        ..once(
          'PATCH /base/v1/me/preferences',
          (_) => jsonResponse(
            errorEnvelope('SERVICE_NOT_CONFIGURED'),
            status: 503,
          ),
        )
        ..on(
          'PATCH /base/v1/me/preferences',
          (_) => jsonResponse(
            fixtures.preferences(revision: 5, off: ['practice.push']),
          ),
        );
      final repository = ApiNotificationRepository(
        ApiEndpoints(fakeClient(transport)),
      );
      final original = await repository.fetch();
      final next = original.copyWith(off: {'practice.push'});
      await expectLater(repository.save(next), throwsA(isA<ApiException>()));
      expect(repository.load().off, isNot(contains('practice.push')));
      await repository.save(next);
      final requests = transport.to('PATCH /base/v1/me/preferences');
      expect(requests, hasLength(2));
      expect(bodyOf(requests.first), bodyOf(requests.last));
      String key(ApiHttpRequest r) => r.headers.entries
          .singleWhere((entry) => entry.key.toLowerCase() == 'idempotency-key')
          .value;
      expect(key(requests.first), key(requests.last));
      expect(repository.load().off, contains('practice.push'));
    },
  );

  testWidgets('real practice reminders read server settings without preview', (
    tester,
  ) async {
    final repository = _Repository()
      ..saved = const NotificationPrefs(reminderTime: ReminderTime(21, 15));
    final container = _container(repository);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ReminderScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text('21:15'), findsOneWidget);
    expect(find.text('Reminder preference saved for 21:15.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test(
    'real notification toggle stays unchanged until server acceptance',
    () async {
      final repository = _Repository();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(realTestConfig),
          authControllerProvider.overrideWith(_Identity.new),
          notificationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final vm = container.read(
        notificationSettingsControllerProvider.notifier,
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container
            .read(notificationSettingsControllerProvider)
            .isOn('practice', NotificationChannel.push),
        isTrue,
      );
      vm.toggle('practice', NotificationChannel.push);
      expect(
        container
            .read(notificationSettingsControllerProvider)
            .isOn('practice', NotificationChannel.push),
        isTrue,
      );
      repository.pending.complete();
      await Future<void>.delayed(Duration.zero);
      expect(
        container
            .read(notificationSettingsControllerProvider)
            .isOn('practice', NotificationChannel.push),
        isFalse,
      );
    },
  );
}
