import 'dart:async';

import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/core/api/client/api_providers.dart';
import 'package:cocenglish/core/api/client/api_transport.dart';
import 'package:cocenglish/core/config/app_config.dart';
import 'package:cocenglish/features/account/presentation/account_screens.dart';
import 'package:cocenglish/features/account/application/account_preferences_controller.dart';
import 'package:cocenglish/features/auth/application/auth_controller.dart';
import 'package:cocenglish/features/auth/domain/auth_state.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/domain/preview_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'features/api_snapshot_repositories_test.dart' as fixtures;
import 'support/fake_api_transport.dart';
import 'support/real_profile.dart';

class _Identity extends AuthController {
  @override
  AuthState build() => const AuthState(
    user: AuthUser(id: 'a', email: 'a@example.test', name: 'A'),
  );

  void switchAccount() => state = const AuthState(
    user: AuthUser(id: 'b', email: 'b@example.test', name: 'B'),
  );
}

class _NoPreview extends PreviewController {
  @override
  PreviewState build() => throw StateError('API settings read preview');
}

String commandKey(ApiHttpRequest request) => request.headers.entries
    .singleWhere((entry) => entry.key.toLowerCase() == 'idempotency-key')
    .value;

void main() {
  late FakeApiTransport transport;
  late ProviderContainer container;
  setUp(() {
    transport = FakeApiTransport()
      ..json('GET /base/v1/me/preferences', {
        ...fixtures.preferences(revision: 4),
        'soundEffects': false,
      })
      ..json('GET /base/v1/me', {
        ...fixtures.profile(),
        'userId': 'a',
        'publicOptIn': false,
      });
    container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(realTestConfig),
        authControllerProvider.overrideWith(_Identity.new),
        apiEndpointsProvider.overrideWithValue(
          ApiEndpoints(fakeClient(transport)),
        ),
        previewControllerProvider.overrideWith(_NoPreview.new),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<void> load() async {
    container.read(accountPreferencesProvider);
    for (var attempt = 0; attempt < 10; attempt++) {
      await Future<void>.delayed(Duration.zero);
      if (!container.read(accountPreferencesProvider).loading) return;
    }
    fail('preferences did not finish loading');
  }

  test('missing snapshot does not enable fixture sound effects', () async {
    expect(container.read(soundEffectsEnabledProvider), isFalse);
    await load();
    expect(container.read(soundEffectsEnabledProvider), isFalse);
  });

  test(
    'sound uses server revision and affects actual lesson effects policy',
    () async {
      await load();
      transport.json('PATCH /base/v1/me/preferences', {
        ...fixtures.preferences(revision: 5),
        'soundEffects': true,
      });
      expect(
        await container
            .read(accountPreferencesProvider.notifier)
            .setSoundEffects(true),
        isTrue,
      );
      expect(bodyOf(transport.to('PATCH /base/v1/me/preferences').single), {
        'soundEffects': true,
        'expectedRevision': 4,
      });
      expect(container.read(soundEffectsEnabledProvider), isTrue);
      expect(
        container.read(accountPreferencesProvider).preferences!.revision,
        5,
      );
    },
  );

  test('private profile maps to public opt-in with profile revision', () async {
    await load();
    transport.json('PATCH /base/v1/me', {
      ...fixtures.profile(),
      'userId': 'a',
      'publicOptIn': true,
      'revision': 2,
    });
    expect(
      await container
          .read(accountPreferencesProvider.notifier)
          .setPrivate(false),
      isTrue,
    );
    expect(bodyOf(transport.to('PATCH /base/v1/me').single), {
      'publicOptIn': true,
      'expectedRevision': 1,
    });
    expect(
      container.read(accountPreferencesProvider).profile!.publicOptIn,
      isTrue,
    );
  });

  test(
    'uncertain failure preserves value and exact request on retry',
    () async {
      await load();
      transport.on(
        'PATCH /base/v1/me/preferences',
        (_) => jsonResponse(
          errorEnvelope('DB_UNAVAILABLE', retryable: true),
          status: 503,
        ),
      );
      final vm = container.read(accountPreferencesProvider.notifier);
      expect(await vm.setSoundEffects(true), isFalse);
      final failed = container.read(accountPreferencesProvider);
      expect(failed.preferences!.soundEffects, isFalse);
      expect(failed.busy, isFalse);
      expect(failed.error, isNotNull);
      transport.json(
        'PATCH /base/v1/me/preferences',
        fixtures.preferences(revision: 5),
      );
      await vm.retry();
      final requests = transport.to('PATCH /base/v1/me/preferences');
      expect(requests.length, greaterThanOrEqualTo(2));
      expect(requests.map((r) => r.body).toSet(), hasLength(1));
      expect(requests.map(commandKey).toSet(), hasLength(1));
      expect(
        container.read(accountPreferencesProvider).preferences!.soundEffects,
        isTrue,
      );
    },
  );

  test('duplicate tap sends only one command while pending', () async {
    await load();
    final pending = Completer<ApiHttpResponse>();
    transport.on('PATCH /base/v1/me/preferences', (_) => pending.future);
    final vm = container.read(accountPreferencesProvider.notifier);
    final first = vm.setSoundEffects(true);
    expect(await vm.setSoundEffects(true), isFalse);
    expect(transport.to('PATCH /base/v1/me/preferences'), hasLength(1));
    expect(
      container.read(accountPreferencesProvider).preferences!.soundEffects,
      isFalse,
    );
    pending.complete(jsonResponse(fixtures.preferences(revision: 5)));
    expect(await first, isTrue);
  });

  test('late write for A cannot populate B preferences', () async {
    await load();
    final pending = Completer<ApiHttpResponse>();
    transport.on('PATCH /base/v1/me/preferences', (_) => pending.future);
    final first = container
        .read(accountPreferencesProvider.notifier)
        .setSoundEffects(true);
    transport.json('GET /base/v1/me', {...fixtures.profile(), 'userId': 'b'});
    (container.read(authControllerProvider.notifier) as _Identity)
        .switchAccount();
    await load();
    pending.complete(jsonResponse(fixtures.preferences(revision: 99)));
    expect(await first, isFalse);
    final state = container.read(accountPreferencesProvider);
    expect(state.profile!.userId, 'b');
    expect(state.preferences!.soundEffects, isFalse);
    expect(state.preferences!.revision, 4);
  });

  test(
    'conflict keeps previous value and reloads revision for new command',
    () async {
      await load();
      transport.on(
        'PATCH /base/v1/me/preferences',
        (_) => jsonResponse(errorEnvelope('REVISION_CONFLICT'), status: 409),
      );
      final vm = container.read(accountPreferencesProvider.notifier);
      expect(await vm.setSoundEffects(true), isFalse);
      expect(
        container.read(accountPreferencesProvider).preferences!.soundEffects,
        isFalse,
      );
      transport.json('GET /base/v1/me/preferences', {
        ...fixtures.preferences(revision: 7),
        'soundEffects': false,
      });
      await vm.retry();
      transport.json(
        'PATCH /base/v1/me/preferences',
        fixtures.preferences(revision: 8),
      );
      expect(await vm.setSoundEffects(true), isTrue);
      final requests = transport.to('PATCH /base/v1/me/preferences');
      expect(bodyOf(requests.last)['expectedRevision'], 7);
      expect(commandKey(requests.last), isNot(commandKey(requests.first)));
    },
  );

  test('401 never changes accepted value or calls preview', () async {
    await load();
    transport.on(
      'PATCH /base/v1/me',
      (_) => jsonResponse(errorEnvelope('AUTH_EXPIRED'), status: 401),
    );
    expect(
      await container
          .read(accountPreferencesProvider.notifier)
          .setPrivate(false),
      isFalse,
    );
    expect(
      container.read(accountPreferencesProvider).profile!.publicOptIn,
      isFalse,
    );
    expect(container.read(accountPreferencesProvider).error, isNotNull);
  });

  for (final privacy in [false, true]) {
    testWidgets('API ${privacy ? 'privacy' : 'sound'} uses server state', (
      tester,
    ) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: privacy
                ? const PrivacySettingsScreen()
                : const PreferencesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final toggle = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile).first,
      );
      expect(toggle.value, privacy);
      expect(toggle.onChanged, isNotNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
