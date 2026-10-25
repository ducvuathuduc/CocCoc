import 'dart:async';

import 'package:cocenglish/core/config/app_config.dart';
import 'package:cocenglish/core/cache/lesson_journal.dart';
import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/features/account/application/account_sync_controller.dart';
import 'package:cocenglish/features/account/data/account_sync_repository.dart';
import 'package:cocenglish/features/account/presentation/account_screens.dart';
import 'package:cocenglish/features/auth/application/auth_controller.dart';
import 'package:cocenglish/features/auth/domain/auth_state.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/data/learning_repository.dart';
import 'package:flutter/material.dart';
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
  void logout() => state = const AuthState();
}

class _Sync implements AccountSyncRepository {
  int calls = 0;
  Future<void> Function(String)? run;
  @override
  Future<void> synchronize(String userId) async {
    calls++;
    await run?.call(userId);
  }
}

ProviderContainer _container(InMemoryLessonJournal journal, _Sync repo) =>
    ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(realTestConfig),
        authControllerProvider.overrideWith(_Identity.new),
        lessonJournalProvider.overrideWithValue(journal),
        accountSyncRepositoryProvider.overrideWithValue(repo),
      ],
    );

Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Offline implements OfflineLearningSync {
  int calls = 0;
  @override
  Future<int> syncPending() async {
    calls++;
    return 0;
  }
}

void main() {
  testWidgets('real recovery retries the API before showing ready', (
    tester,
  ) async {
    final pending = Completer<void>();
    final repo = _Sync()..run = (_) => pending.future;
    final container = _container(InMemoryLessonJournal(), repo);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RecoveryScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    final retry = find.text('RETRY');
    if (retry.evaluate().isNotEmpty) await tester.tap(retry);
    await tester.pump();
    expect(find.text('You’re ready to continue'), findsNothing);
    pending.complete();
    await tester.pumpAndSettle();
    expect(repo.calls, 1);
    expect(find.text('You’re ready to continue'), findsOneWidget);
  });
  test('pending or rejected answers never report current', () async {
    final journal = InMemoryLessonJournal();
    await journal.enqueueCompletion({
      'operationId': 'p',
      'answers': <Object?>[],
    });
    final repo = _Sync();
    final container = _container(journal, repo);
    addTearDown(container.dispose);
    container.read(accountSyncProvider);
    await _settle();
    expect(container.read(accountSyncProvider).current, isFalse);
    expect(container.read(accountSyncProvider).pending, 1);
    await journal.rejectCompletion('p', 'CONTENT_STALE');
    await container.read(accountSyncProvider.notifier).refresh();
    expect(container.read(accountSyncProvider).pending, 0);
    expect(container.read(accountSyncProvider).rejected, 1);
    expect(container.read(accountSyncProvider).current, isFalse);
  });

  test(
    'failed synchronization preserves answers and retry settles once',
    () async {
      final journal = InMemoryLessonJournal();
      await journal.enqueueCompletion({
        'operationId': 'p',
        'answers': <Object?>[],
      });
      final repo = _Sync()
        ..run = (_) async => throw StateError('private response');
      final container = _container(journal, repo);
      addTearDown(container.dispose);
      container.read(accountSyncProvider);
      await _settle();
      expect(container.read(accountSyncProvider).current, isFalse);
      expect(
        container.read(accountSyncProvider).error,
        'We couldn’t sync your progress. Please try again.',
      );
      expect(await journal.pendingCompletions(), hasLength(1));
      repo.run = (_) => journal.removeCompletion('p');
      await container.read(accountSyncProvider.notifier).refresh();
      expect(container.read(accountSyncProvider).current, isTrue);
      expect(repo.calls, 2);
    },
  );

  test('duplicate refresh dispatches one operation', () async {
    final pending = Completer<void>();
    final repo = _Sync()..run = (_) => pending.future;
    final container = _container(InMemoryLessonJournal(), repo);
    addTearDown(container.dispose);
    container.read(accountSyncProvider);
    await _settle();
    await container.read(accountSyncProvider.notifier).refresh();
    expect(repo.calls, 1);
    pending.complete();
    await _settle();
    expect(container.read(accountSyncProvider).current, isTrue);
  });

  test('late failed A response cannot replace verified account B', () async {
    final pending = Completer<void>();
    final repo = _Sync()
      ..run = (id) => id == 'a' ? pending.future : Future.value();
    final container = _container(InMemoryLessonJournal(), repo);
    addTearDown(container.dispose);
    container.read(accountSyncProvider);
    await _settle();
    (container.read(authControllerProvider.notifier) as _Identity)
        .switchAccount();
    container.read(accountSyncProvider);
    await _settle();
    expect(container.read(accountSyncProvider).current, isTrue);
    pending.completeError(StateError('old account response'));
    await _settle();
    expect(container.read(accountSyncProvider).current, isTrue);
    expect(container.read(accountSyncProvider).error, isNull);
  });

  test('logout before the scheduled task prevents private work', () async {
    final repo = _Sync();
    final container = _container(InMemoryLessonJournal(), repo);
    addTearDown(container.dispose);
    container.read(accountSyncProvider);
    (container.read(authControllerProvider.notifier) as _Identity).logout();
    container.read(accountSyncProvider);
    await _settle();
    expect(repo.calls, 0);
    expect(container.read(accountSyncProvider).current, isFalse);
  });

  test(
    'API sync verifies fresh owner reads and rejects another identity',
    () async {
      final transport = FakeApiTransport()
        ..json('GET /base/v1/me', {...fixtures.profile(), 'userId': 'b'})
        ..json('GET /base/v1/me/rewards', fixtures.rewards());
      final learning = _Offline();
      final repo = ApiAccountSyncRepository(
        learning,
        ApiEndpoints(fakeClient(transport)),
      );
      await expectLater(repo.synchronize('a'), throwsA(anything));
      expect(transport.to('GET /base/v1/me/rewards'), isEmpty);
      transport.json('GET /base/v1/me', {...fixtures.profile(), 'userId': 'a'});
      await repo.synchronize('a');
      expect(transport.to('GET /base/v1/me/rewards'), hasLength(1));
      expect(learning.calls, 2);
    },
  );
  testWidgets('API Sync never reports current before actual synchronization', (
    tester,
  ) async {
    final journal = InMemoryLessonJournal();
    final pending = Completer<void>();
    final repo = _Sync()..run = (_) => pending.future;
    final container = _container(journal, repo);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SyncScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Your progress is up to date'), findsNothing);
    pending.complete();
    await tester.pumpAndSettle();
    expect(repo.calls, 1);
    expect(find.text('Your progress is up to date'), findsOneWidget);
  });
}
