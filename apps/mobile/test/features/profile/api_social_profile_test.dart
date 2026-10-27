// P1-SOCIAL: public profile, follow, report, activity, classroom leave and the
// friends route data source. Mocks keep the archived offline fixtures.
import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/core/api/client/api_providers.dart';
import 'package:cocenglish/core/cache/snapshot_cache.dart';
import 'package:cocenglish/core/config/app_config.dart';
import 'package:cocenglish/features/profile/application/friends_provider.dart';
import 'package:cocenglish/features/profile/data/friends_repository.dart';
import 'package:cocenglish/features/profile/presentation/friends_screen.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/application/profile_actions_controller.dart';
import 'package:cocenglish/features/progress/application/profile_activity_provider.dart';
import 'package:cocenglish/features/progress/application/profile_summary_provider.dart';
import 'package:cocenglish/features/progress/data/social_repository.dart';
import 'package:cocenglish/features/progress/domain/profile_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_api_transport.dart';
import '../../support/real_profile.dart';

Map<String, Object?> publicProfile({
  String userId = 'u1',
  String nickname = 'Linh',
  int studyXp = 1200,
  int streak = 30,
  String followStatus = 'following',
}) => {
  'userId': userId,
  'nickname': nickname,
  'avatarId': null,
  'studyXp': studyXp,
  'streak': streak,
  'achievementIds': <String>['first-lesson'],
  'followStatus': followStatus,
};

Map<String, Object?> activity(String eventId, String summary) => {
  'eventId': eventId,
  'userId': 'u1',
  'kind': 'MILESTONE',
  'summary': summary,
  'createdAt': isoNow,
};

Map<String, Object?> receipt() => {
  'operationId': 'op-1',
  'status': 'accepted',
  'requestId': 'req-1',
};

Map<String, Object?> friendPage() => {
  'items': [
    publicProfile(userId: 'a', nickname: 'Linh', studyXp: 1200),
    publicProfile(
      userId: 'b',
      nickname: 'Minh',
      studyXp: 40,
      followStatus: 'none',
    ),
  ],
  'nextCursor': null,
  'asOf': isoNow,
};

Future<void> until(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(condition(), isTrue, reason: 'request did not arrive');
}

void main() {
  late FakeApiTransport transport;
  late ApiEndpoints api;

  setUp(() {
    transport = FakeApiTransport();
    api = ApiEndpoints(fakeClient(transport));
  });

  ProviderContainer apiContainer() {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(realTestConfig),
        apiEndpointsProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('ApiSocialRepository', () {
    late ApiSocialRepository repository;

    setUp(() {
      repository = ApiSocialRepository(api, host: SnapshotHost.detached());
    });

    test('maps the public profile projection', () async {
      transport.json('GET /base/v1/profiles/u1', publicProfile());
      final profile = await repository.publicProfile('u1');
      expect(profile, isNotNull);
      expect(profile!.userId, 'u1');
      expect(profile.nickname, 'Linh');
      expect(profile.studyXp, 1200);
      expect(profile.streak, 30);
      expect(profile.achievementIds, ['first-lesson']);
      expect(profile.isFollowing, isTrue);
    });

    test('pages the friend activity feed', () async {
      transport
        ..once(
          'GET /base/v1/activity',
          (_) => jsonResponse({
            'items': [activity('e1', 'Linh finished a lesson')],
            'nextCursor': 'next',
            'asOf': isoNow,
          }),
        )
        ..json('GET /base/v1/activity', {
          'items': [activity('e2', 'Minh finished a lesson')],
          'nextCursor': null,
          'asOf': isoNow,
        });
      final entries = await repository.activity();
      expect(entries.map((entry) => entry.summary), [
        'Linh finished a lesson',
        'Minh finished a lesson',
      ]);
      expect(entries.first.createdAt, DateTime.parse(isoNow));
      expect(
        transport
            .to('GET /base/v1/activity')
            .last
            .uri
            .queryParameters['cursor'],
        'next',
      );
    });

    test('follows and unfollows by user id', () async {
      transport
        ..json('POST /base/v1/follows', receipt())
        ..json('DELETE /base/v1/follows/u2', receipt());
      await repository.follow('u2');
      expect(bodyOf(transport.to('POST /base/v1/follows').single), {
        'targetUserId': 'u2',
      });
      await repository.unfollow('u2');
      expect(transport.to('DELETE /base/v1/follows/u2'), hasLength(1));
    });

    test('reports with an OpenAPI reason, never the UI label', () async {
      transport.json('POST /base/v1/user-reports', receipt());
      await repository.report('u2', reason: 'Spam');
      expect(bodyOf(transport.to('POST /base/v1/user-reports').single), {
        'targetUserId': 'u2',
        'reason': 'SPAM',
        'note': null,
      });
    });

    test('leaves a classroom membership', () async {
      transport.json(
        'DELETE /base/v1/classrooms/class-1/membership',
        receipt(),
      );
      await repository.leaveClassroom('class-1');
      expect(
        transport.to('DELETE /base/v1/classrooms/class-1/membership'),
        hasLength(1),
      );
    });

    test('mock keeps every social command local and offline', () async {
      const mock = MockSocialRepository();
      expect(await mock.publicProfile('u1'), isNull);
      expect(await mock.activity(), isEmpty);
      await mock.follow('u1');
      await mock.unfollow('u1');
      await mock.report('u1', reason: 'Spam');
      await mock.leaveClassroom('class-1');
    });
  });

  group('profile summary projection', () {
    test('mock mode keeps the authored fixture without network', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final summary = container.read(profileSummaryProvider('Alex'));
      expect(summary, isNotNull);
      expect(summary!.xp, 120);
      expect(summary.streak, 7);
    });

    test(
      'api mode replaces the summary with GET /v1/profiles/{userId}',
      () async {
        final container = apiContainer();
        transport.json(
          'GET /base/v1/profiles/u1',
          publicProfile(nickname: 'Linh', studyXp: 1200, streak: 30),
        );
        ProfileSummary? latest;
        container.listen(
          profileSummaryProvider('u1'),
          (_, next) => latest = next,
          fireImmediately: true,
        );
        expect(latest, isNull, reason: 'no authored fixture for u1');
        await container.read(publicProfileProvider('u1').future);
        await until(() => latest != null);
        expect(latest!.userId, 'u1');
        expect(latest!.name, 'Linh');
        expect(latest!.username, 'linh');
        expect(latest!.xp, 1200);
        expect(latest!.streak, 30);
        expect(latest!.joinedYear, greaterThan(2020));
        expect(
          transport.to('GET /base/v1/profiles/u1'),
          hasLength(1),
          reason: 'one server read',
        );
      },
    );

    test('api failure keeps the authored fixture', () async {
      final container = apiContainer();
      transport.json(
        'GET /base/v1/profiles/Alex',
        errorEnvelope('NOT_FOUND'),
        status: 404,
      );
      AsyncValue<SocialProfile?>? state;
      container.listen(
        publicProfileProvider('Alex'),
        (_, next) => state = next,
        fireImmediately: true,
      );
      await until(() => state?.hasError ?? false);
      expect(transport.to('GET /base/v1/profiles/Alex'), hasLength(1));
      final summary = container.read(profileSummaryProvider('Alex'));
      expect(summary, isNotNull);
      expect(summary!.name, 'Alex');
      expect(summary.xp, 120);
    });
  });

  group('social activity feed', () {
    test('api mode maps GET /v1/activity', () async {
      final container = apiContainer();
      transport.json('GET /base/v1/activity', {
        'items': [activity('e1', 'Linh reached a 30 day streak')],
        'nextCursor': null,
        'asOf': isoNow,
      });
      final entries = await container.read(socialActivityProvider.future);
      expect(entries.single.kind, 'MILESTONE');
      expect(entries.single.summary, 'Linh reached a 30 day streak');
    });

    test('mock mode keeps the feed offline', () async {
      final container = ProviderContainer(
        overrides: [apiEndpointsProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      expect(await container.read(socialActivityProvider.future), isEmpty);
      expect(transport.requests, isEmpty);
    });
  });

  group('ProfileActionsController', () {
    test('api mode mirrors follow toggles to /v1/follows', () async {
      final container = apiContainer();
      transport
        ..json('POST /base/v1/follows', receipt())
        ..json('DELETE /base/v1/follows/friend-1', receipt());
      container.read(profileActionsProvider);
      container.read(previewControllerProvider.notifier).follow('friend-1');
      await until(() => transport.to('POST /base/v1/follows').isNotEmpty);
      expect(bodyOf(transport.to('POST /base/v1/follows').single), {
        'targetUserId': 'friend-1',
      });
      container.read(previewControllerProvider.notifier).follow('friend-1');
      await until(
        () => transport.to('DELETE /base/v1/follows/friend-1').isNotEmpty,
      );
    });

    test('api mode reports a public user with the wire reason', () async {
      final container = apiContainer();
      transport
        ..json('POST /base/v1/user-reports', receipt())
        ..json('POST /base/v1/blocks', receipt());
      container.read(profileActionsProvider);
      final accepted = container
          .read(profileActionsProvider.notifier)
          .reportAndBlock('friend-1', 'Spam');
      expect(accepted, isTrue);
      await until(() => transport.to('POST /base/v1/user-reports').isNotEmpty);
      expect(bodyOf(transport.to('POST /base/v1/user-reports').single), {
        'targetUserId': 'friend-1',
        'reason': 'SPAM',
        'note': null,
      });
      expect(container.read(profileActionsProvider).blocked, {'friend-1'});
    });

    test('mock mode keeps sample-only reports and sends nothing', () async {
      final container = ProviderContainer(
        overrides: [apiEndpointsProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      container.read(profileActionsProvider);
      expect(
        container
            .read(profileActionsProvider.notifier)
            .reportAndBlock('friend-1', 'Spam'),
        isFalse,
      );
      container.read(previewControllerProvider.notifier).follow('friend-1');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(transport.requests, isEmpty);
      expect(container.read(profileActionsProvider).blocked, isEmpty);
    });
  });

  testWidgets('FriendsScreen renders GET /v1/friends in api mode', (
    tester,
  ) async {
    transport.json('GET /base/v1/friends', friendPage());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(realTestConfig),
          apiEndpointsProvider.overrideWithValue(api),
        ],
        child: const MaterialApp(home: FriendsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Linh'), findsOneWidget);
    expect(find.text('FOLLOWING'), findsOneWidget);
    expect(find.text('FOLLOWERS'), findsOneWidget);
  });

  testWidgets('FriendsScreen keeps demo fixtures offline', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          friendsRepositoryProvider.overrideWithValue(
            const MockFriendsRepository(),
          ),
        ],
        child: const MaterialApp(home: FriendsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Alex Smith'), findsOneWidget);
    expect(find.text('Linh Nguyen'), findsOneWidget);
  });
}
