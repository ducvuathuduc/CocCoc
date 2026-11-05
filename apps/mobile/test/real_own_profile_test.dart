import 'dart:async';

import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/core/api/client/api_providers.dart';
import 'package:cocenglish/core/cache/snapshot_cache.dart';
import 'package:cocenglish/core/config/app_config.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/auth/application/auth_controller.dart';
import 'package:cocenglish/features/auth/domain/auth_state.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/progress/application/own_profile_projection.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/data/progress_snapshot.dart';
import 'package:cocenglish/features/progress/domain/preview_state.dart';
import 'package:cocenglish/features/progress/presentation/own_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'features/api_snapshot_repositories_test.dart' as fixtures;
import 'support/fake_api_transport.dart';
import 'support/real_profile.dart';

class _Identity extends AuthController {
  @override
  AuthState build() => const AuthState(
    user: AuthUser(id: 'a', email: 'private@example.test', name: 'Account A'),
  );

  void switchAccount() => state = const AuthState(
    user: AuthUser(id: 'b', email: 'b@example.test', name: 'Account B'),
  );
}

class _NoPreview extends PreviewController {
  @override
  PreviewState build() => throw StateError('API profile read preview');
}

class _SectionProgress extends LearningStateController {
  @override
  LearningState build() => const LearningState(xp: 321);
}

ProgressSnapshot _snapshot(String id, String nickname, int xp) =>
    ProgressSnapshot.fromJson({
      'profile': {...fixtures.profile(), 'userId': id, 'nickname': nickname},
      'rewards': {...fixtures.rewards(), 'studyXp': xp},
      'energy': fixtures.energy(),
      'league': fixtures.league(),
      'leagueResult': fixtures.leagueResult(),
      'quests': fixtures.page([]),
    });

void main() {
  late ProgressSnapshotSource source;
  late ProviderContainer container;

  setUp(() {
    final api = ApiEndpoints(fakeClient(FakeApiTransport()));
    source = ProgressSnapshotSource(api);
    container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(realTestConfig),
        authControllerProvider.overrideWith(_Identity.new),
        apiEndpointsProvider.overrideWithValue(api),
        snapshotStoreProvider.overrideWithValue(MemorySnapshotStore()),
        progressSnapshotSourceProvider.overrideWithValue(source),
        previewControllerProvider.overrideWith(_NoPreview.new),
        learningStateProvider.overrideWith(_SectionProgress.new),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    source.cache.dispose();
  });

  test('API profile uses owner nickname and rewards without preview', () {
    source.cache.put(_snapshot('a', 'Saved nickname', 321));
    final profile = container.read(ownProfileProjectionProvider);
    expect(profile.name, 'Saved nickname');
    expect(profile.xp, 321);
    expect(profile.streak, 4);
    expect(profile.userId, 'a');
    expect(profile.following, isNull);
    expect(profile.followers, isNull);
    expect(profile.score, isNull);
    expect(profile.identityLabel, '—');
    expect(profile.avatar.hasAvatar, isFalse);
    expect(profile.badge, isNull);
  });

  test('cold profile has verified identity and unavailable counters', () {
    final profile = container.read(ownProfileProjectionProvider);
    expect(profile.name, 'Account A');
    expect(profile.xp, isNull);
    expect(profile.streak, isNull);
    expect(profile.league, '—');
    expect(profile.identityLabel, isNot(contains('PRIVATE')));
    expect(profile.identityLabel, isNot(contains('2026')));
  });

  test('mismatched snapshot cannot appear in another account', () {
    source.cache.put(_snapshot('a', 'Private A', 900));
    expect(container.read(ownProfileProjectionProvider).name, 'Private A');
    (container.read(authControllerProvider.notifier) as _Identity)
        .switchAccount();
    final profile = container.read(ownProfileProjectionProvider);
    expect(profile.name, 'Account B');
    expect(profile.xp, isNull);
    expect(profile.streak, isNull);
  });

  test('snapshot revision refreshes accepted name without reopening app', () {
    source.cache.put(_snapshot('a', 'Before edit', 10));
    expect(container.read(ownProfileProjectionProvider).name, 'Before edit');
    source.cache.put(_snapshot('a', 'After edit', 20));
    container.read(snapshotRevisionProvider.notifier).bump('progress');
    expect(container.read(ownProfileProjectionProvider).name, 'After edit');
    expect(container.read(ownProfileProjectionProvider).xp, 20);
  });

  test('late A snapshot after B remains hidden', () async {
    final delayed = Completer<ProgressSnapshot>();
    final pending = source.cache.refresh(() => delayed.future);
    (container.read(authControllerProvider.notifier) as _Identity)
        .switchAccount();
    delayed.complete(_snapshot('a', 'Late A', 999));
    await pending;
    final profile = container.read(ownProfileProjectionProvider);
    expect(profile.name, 'Account B');
    expect(profile.xp, isNull);
  });

  for (final width in [320.0, 430.0]) {
    testWidgets('real own profile width=$width text2 reduced motion', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      source.cache.put(_snapshot('a', 'Saved nickname', 321));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: referenceTheme(),
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 844),
                textScaler: TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: const OwnProfileScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Saved nickname'), findsWidgets);
      expect(find.textContaining('JOINED 2026'), findsNothing);
      expect(find.text('CREATE A PROFILE'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
