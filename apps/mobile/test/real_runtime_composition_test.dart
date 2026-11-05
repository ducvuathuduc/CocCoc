import 'dart:async';
import 'dart:convert';

import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/core/api/client/api_providers.dart';
import 'package:cocenglish/core/api/client/api_transport.dart';
import 'package:cocenglish/core/api/client/api_exception.dart';
import 'package:cocenglish/core/cache/snapshot_cache.dart';
import 'package:cocenglish/core/config/app_config.dart';
import 'package:cocenglish/features/account/data/account_repository.dart';
import 'package:cocenglish/features/auth/application/auth_controller.dart';
import 'package:cocenglish/features/auth/domain/auth_state.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/data/progress_snapshot.dart';
import 'package:cocenglish/features/progress/domain/preview_state.dart';
import 'package:cocenglish/features/shell/data/api_app_shell_repository.dart';
import 'package:cocenglish/features/shell/domain/app_shell_models.dart';
import 'package:cocenglish/features/session/application/real_learning_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_api_transport.dart';
import 'support/real_profile.dart';
import 'features/api_snapshot_repositories_test.dart' as fixtures;

class _Account extends AuthController {
  @override
  AuthState build() => const AuthState(
    user: AuthUser(id: 'a', email: 'a@test.invalid', name: 'A'),
  );
  void switchAccount() => state = const AuthState(
    user: AuthUser(id: 'b', email: 'b@test.invalid', name: 'B'),
  );
}

class _DelayedTransport implements ApiTransport {
  final inner = FakeApiTransport();
  final pending = Completer<void>();
  @override
  Future<ApiHttpResponse> send(
    ApiHttpRequest request, {
    Duration? timeout,
  }) async {
    await pending.future;
    return inner.send(request, timeout: timeout);
  }
}

void _progress(FakeApiTransport transport, String user, int gems) => transport
  ..json('GET /base/v1/me', {...fixtures.profile(), 'userId': user})
  ..json('GET /base/v1/me/rewards', fixtures.rewards(gems: gems))
  ..json('GET /v1/me/energy', fixtures.energy())
  ..json('GET /base/v1/league', fixtures.league())
  ..json('GET /base/v1/league/result', fixtures.leagueResult())
  ..json('GET /base/v1/quests', fixtures.page([]));

class _ForbiddenPreview extends PreviewController {
  @override
  PreviewState build() =>
      throw StateError('Real composition read preview state');
}

void main() {
  test(
    'invalid real config blocks authentication startup before SDK I/O',
    () async {
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(dataSource: DataSource.api, mockAuthOverride: true),
          ),
        ],
      );
      addTearDown(container.dispose);
      await expectLater(
        container.read(authStartupProvider.future),
        throwsA(
          isA<ProviderException>().having(
            (error) => error.exception,
            'cause',
            isA<ApiException>().having(
              (error) => error.code,
              'code',
              'NOT_CONFIGURED',
            ),
          ),
        ),
      );
    },
  );

  const fixture = AppShellSnapshot(
    score: 12,
    streak: 5,
    gems: 999,
    energy: 25,
    unlimited: true,
    streakActive: true,
  );

  test('cold or failed API snapshot never renders fixture balances', () async {
    final source = ProgressSnapshotSource(
      ApiEndpoints(fakeClient(FakeApiTransport())),
    );
    final repository = ApiAppShellRepository(source);
    final stats = repository.stats(fixture);
    expect(stats.map((stat) => stat.value), ['', '—', '—', '—']);
    await source.refresh();
    expect(source.cache.error, isNotNull);
    expect(repository.stats(fixture)[2].value, '—');
  });

  test(
    'disposed account cache cannot hydrate or persist a late response',
    () async {
      final store = MemorySnapshotStore();
      final pendingA = Completer<int>();
      var changes = 0;
      final a = SnapshotCache<int>(
        key: 'a',
        host: SnapshotHost(store: store, onChanged: () => changes++),
        decode: (json) => json['gems']! as int,
        encode: (value) => {'gems': value},
      );
      final requestA = a.refresh(() => pendingA.future);
      await Future<void>.delayed(Duration.zero);
      a.dispose();
      final b = SnapshotCache<int>(
        key: 'b',
        host: SnapshotHost.detached(store),
        decode: (json) => json['gems']! as int,
        encode: (value) => {'gems': value},
      );
      await b.refresh(() async => 42);
      pendingA.complete(999);
      await requestA;
      expect(a.value, isNull);
      expect(b.value, 42);
      expect(changes, 0);
      expect(store.values.containsKey('a'), isFalse);
      expect(jsonDecode(store.values['b']!), {'gems': 42});
    },
  );

  test(
    'account B finishes first and cannot be overwritten by delayed A',
    () async {
      final a = _DelayedTransport();
      final b = FakeApiTransport();
      _progress(a.inner, 'a', 999);
      _progress(b, 'b', 42);
      final stores = <String, SnapshotStore>{};
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(realTestConfig),
          authControllerProvider.overrideWith(_Account.new),
          apiEndpointsProvider.overrideWith((ref) {
            final id = ref.watch(
              authControllerProvider.select((state) => state.user?.id),
            );
            return ApiEndpoints(fakeClient(id == 'a' ? a : b));
          }),
          snapshotStoreProvider.overrideWith((ref) {
            final id = ref.watch(
              authControllerProvider.select((state) => state.user?.id),
            )!;
            return stores.putIfAbsent(id, MemorySnapshotStore.new);
          }),
        ],
      );
      addTearDown(container.dispose);
      final sourceA = container.read(progressSnapshotSourceProvider);
      final requestA = sourceA.refresh();
      await Future<void>.delayed(Duration.zero);
      (container.read(authControllerProvider.notifier) as _Account)
          .switchAccount();
      final sourceB = container.read(progressSnapshotSourceProvider);
      await sourceB.refresh();
      a.pending.complete();
      await requestA;
      expect(sourceA.cache.value, isNull);
      expect(sourceB.value!.profile.userId, 'b');
      expect(sourceB.value!.rewards.gems, 42);
      expect(ApiAppShellRepository(sourceB).stats(fixture)[2].value, '42');
      expect((stores['a']! as MemorySnapshotStore).values, isEmpty);
    },
  );

  for (final status in [401, 503, 202]) {
    test(
      'API deletion $status uses real receipt without preview state',
      () async {
        final transport = FakeApiTransport()
          ..json(
            'POST /base/v1/me/deletion',
            status == 202
                ? {
                    'requestId': '00000000-0000-4000-8000-000000000009',
                    'status': 'REQUESTED',
                    'requestedAt': isoNow,
                  }
                : errorEnvelope(
                    status == 401 ? 'UNAUTHENTICATED' : 'UNAVAILABLE',
                  ),
            status: status,
          );
        final container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(dataSource: DataSource.api),
            ),
            apiEndpointsProvider.overrideWithValue(
              ApiEndpoints(fakeClient(transport)),
            ),
            authSessionRepositoryProvider.overrideWithValue(null),
            previewControllerProvider.overrideWith(_ForbiddenPreview.new),
          ],
        );
        addTearDown(container.dispose);
        expect(container.read(deletionRequestedProvider), isFalse);
        final error = await container
            .read(accountRepositoryProvider)
            .requestDeletion();
        expect(error == null, status == 202);
        expect(container.read(deletionRequestedProvider), status == 202);
      },
    );
  }
}
