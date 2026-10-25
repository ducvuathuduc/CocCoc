import 'dart:async';

import 'package:cocenglish/core/api/client/api_exception.dart';
import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/core/config/app_config.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/account/application/profile_editor_controller.dart';
import 'package:cocenglish/features/account/data/profile_editor_repository.dart';
import 'package:cocenglish/features/account/presentation/account_screens.dart';
import 'package:cocenglish/features/auth/domain/auth_state.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/domain/preview_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_api_transport.dart';

const userA = AuthUser(
  id: 'user-a',
  email: 'ada@example.test',
  name: 'Appwrite Ada',
);
const userB = AuthUser(
  id: 'user-b',
  email: 'grace@example.test',
  name: 'Appwrite Grace',
);

ProfileEditorRecord record(String userId, String nickname, int revision) =>
    ProfileEditorRecord(userId: userId, nickname: nickname, revision: revision);

ProviderContainer _apiContainer(
  _ProfileRepository repository, {
  AuthUser user = userA,
}) {
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(dataSource: DataSource.api),
      ),
      profileEditorIdentityProvider.overrideWithValue(user),
      profileEditorRepositoryProvider.overrideWithValue(repository),
      previewControllerProvider.overrideWith(_ForbiddenPreview.new),
    ],
  );
  container.listen(profileEditorProvider, (_, _) {}, fireImmediately: true);
  return container;
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('API repository PATCHes nickname with expectedRevision', () async {
    final transport = FakeApiTransport()
      ..json('GET /base/v1/me', _wireProfile('Ada Lovelace', 7))
      ..json('PATCH /base/v1/me', _wireProfile('Grace Hopper', 8));
    final repository = ApiProfileEditorRepository(
      ApiEndpoints(fakeClient(transport)),
    );

    expect((await repository.load('user-a')).revision, 7);
    final updated = await repository.updateNickname(
      userId: 'user-a',
      nickname: 'Grace Hopper',
      expectedRevision: 7,
    );

    expect(updated.nickname, 'Grace Hopper');
    expect(bodyOf(transport.to('PATCH /base/v1/me').single), {
      'nickname': 'Grace Hopper',
      'expectedRevision': 7,
    });
  });

  test(
    'API details combine Progress nickname with verified Auth identity',
    () async {
      final repository = _ProfileRepository()
        ..completeLoad(record('user-a', 'Ada Lovelace', 7));
      final container = _apiContainer(repository);
      addTearDown(container.dispose);
      await settle();

      final details = container.read(profileEditorProvider);
      expect(details.first, 'Ada');
      expect(details.last, 'Lovelace');
      expect(details.email, 'ada@example.test');
      expect(details.username, isEmpty);
      expect(details.phone, isEmpty);
      expect(details.loaded, isTrue);
    },
  );

  test('successful API save sends nickname with expected revision', () async {
    final repository = _ProfileRepository()
      ..completeLoad(record('user-a', 'Ada Lovelace', 7))
      ..saveResult = record('user-a', 'Grace Hopper', 8);
    final container = _apiContainer(repository);
    addTearDown(container.dispose);
    await settle();

    final error = await container
        .read(profileEditorProvider.notifier)
        .save(
          const ProfileDetails(
            first: 'Grace',
            last: 'Hopper',
            username: '',
            email: 'ada@example.test',
          ),
        );

    expect(error, isNull);
    expect(repository.saves, [
      const _SaveCall(userId: 'user-a', nickname: 'Grace Hopper', revision: 7),
    ]);
    expect(container.read(profileEditorProvider).first, 'Grace');
  });

  test(
    'failed API save retains authoritative state and never reads preview',
    () async {
      final repository = _ProfileRepository()
        ..completeLoad(record('user-a', 'Ada Lovelace', 7))
        ..saveError = const ApiException(
          code: 'REVISION_CONFLICT',
          message: 'conflict',
          statusCode: 409,
        );
      final container = _apiContainer(repository);
      addTearDown(container.dispose);
      await settle();

      final error = await container
          .read(profileEditorProvider.notifier)
          .save(
            const ProfileDetails(
              first: 'Edited',
              last: 'Name',
              username: '',
              email: 'ada@example.test',
            ),
          );

      expect(error, 'That changed on another device. Please try again.');
      expect(container.read(profileEditorProvider).first, 'Ada');
      expect(container.read(profileEditorProvider).error, error);
    },
  );

  test('unsupported API fields reject before any write', () async {
    final repository = _ProfileRepository()
      ..completeLoad(record('user-a', 'Ada Lovelace', 7));
    final container = _apiContainer(repository);
    addTearDown(container.dispose);
    await settle();
    final controller = container.read(profileEditorProvider.notifier);

    expect(
      await controller.save(
        const ProfileDetails(
          first: 'Ada',
          last: 'Lovelace',
          username: 'invented.handle',
          email: 'ada@example.test',
        ),
      ),
      'Username changes aren’t supported yet.',
    );
    expect(
      await controller.save(
        const ProfileDetails(
          first: 'Ada',
          last: 'Lovelace',
          username: '',
          email: 'changed@example.test',
        ),
      ),
      'Email changes aren’t supported here.',
    );
    expect(
      await controller.save(
        const ProfileDetails(
          first: 'Ada',
          last: 'Lovelace',
          username: '',
          email: 'ada@example.test',
          phone: '+84 912 345 678',
        ),
      ),
      'Phone number changes aren’t supported here.',
    );
    expect(repository.saves, isEmpty);
  });

  test('late account A load cannot replace account B', () async {
    final repository = _ProfileRepository();
    final container = _apiContainer(repository);
    addTearDown(container.dispose);
    await settle();

    container.updateOverrides([
      appConfigProvider.overrideWithValue(
        const AppConfig(dataSource: DataSource.api),
      ),
      profileEditorIdentityProvider.overrideWithValue(userB),
      profileEditorRepositoryProvider.overrideWithValue(repository),
      previewControllerProvider.overrideWith(_ForbiddenPreview.new),
    ]);
    container.read(profileEditorProvider);
    repository.completeLoad(
      record('user-b', 'Grace Hopper', 3),
      user: 'user-b',
    );
    await settle();
    expect(container.read(profileEditorProvider).first, 'Grace');

    repository.completeLoad(record('user-a', 'Late Ada', 7), user: 'user-a');
    await settle();
    expect(container.read(profileEditorProvider).first, 'Grace');
    expect(container.read(profileEditorProvider).accountId, 'user-b');
  });

  test('duplicate save taps issue one request', () async {
    final repository = _ProfileRepository()
      ..completeLoad(record('user-a', 'Ada Lovelace', 7))
      ..pendingSave = Completer<ProfileEditorRecord>();
    final container = _apiContainer(repository);
    addTearDown(container.dispose);
    await settle();
    final controller = container.read(profileEditorProvider.notifier);
    const draft = ProfileDetails(
      first: 'Grace',
      last: 'Hopper',
      username: '',
      email: 'ada@example.test',
    );

    final first = controller.save(draft);
    expect(await controller.save(draft), 'A save is already in progress.');
    expect(repository.saves, hasLength(1));
    repository.pendingSave!.complete(record('user-a', 'Grace Hopper', 8));
    expect(await first, isNull);
  });

  test('failed API load can retry without preview fallback', () async {
    final repository = _ProfileRepository()..loadError = StateError('offline');
    final container = _apiContainer(repository);
    addTearDown(container.dispose);
    await settle();
    expect(container.read(profileEditorProvider).loaded, isFalse);
    expect(container.read(profileEditorProvider).error, isNotNull);

    repository
      ..loadError = null
      ..completeLoad(record('user-a', 'Ada Lovelace', 7));
    await container.read(profileEditorProvider.notifier).retry();
    expect(container.read(profileEditorProvider).loaded, isTrue);
    expect(container.read(profileEditorProvider).first, 'Ada');
  });

  testWidgets('failed API save keeps edits and profile route visible', (
    tester,
  ) async {
    final repository = _ProfileRepository()
      ..completeLoad(record('user-a', 'Ada Lovelace', 7))
      ..saveError = const ApiException(
        code: 'UNAVAILABLE',
        message: 'offline',
        statusCode: 503,
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(dataSource: DataSource.api),
          ),
          profileEditorIdentityProvider.overrideWithValue(userA),
          profileEditorRepositoryProvider.overrideWithValue(repository),
          previewControllerProvider.overrideWith(_ForbiddenPreview.new),
        ],
        child: MaterialApp(
          theme: referenceTheme(),
          home: const EditProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('profile-first')),
      'Edited',
    );
    final firstController = tester
        .widget<TextField>(find.byKey(const ValueKey('profile-first')))
        .controller!;
    await tester.enterText(find.byKey(const ValueKey('profile-last')), 'Name');
    await tester.drag(
      find.byKey(const ValueKey('profile-editor-scroll')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE CHANGES'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(find.textContaining('complete that request'), findsOneWidget);
    expect(firstController.text, 'Edited');
  });

  test('mock save behavior remains local and unchanged', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final error = await container
        .read(profileEditorProvider.notifier)
        .save(
          const ProfileDetails(
            first: 'Alice',
            last: 'Nguyen',
            username: 'alice.nguyen',
            email: 'alice@example.test',
            phone: '+84 912 345 678',
          ),
        );

    expect(error, isNull);
    expect(container.read(previewControllerProvider).name, 'Alice Nguyen');
    expect(container.read(profileEditorProvider).username, 'alice.nguyen');
  });
}

Map<String, Object?> _wireProfile(String nickname, int revision) => {
  'userId': 'user-a',
  'nickname': nickname,
  'avatarId': null,
  'publicOptIn': false,
  'dailyGoal': 10,
  'learningZone': 'Asia/Ho_Chi_Minh',
  'pendingZone': null,
  'zoneEffectiveAt': null,
  'revision': revision,
  'achievementIds': <String>[],
};

final class _ProfileRepository implements ProfileEditorRepository {
  final Map<String, Completer<ProfileEditorRecord>> _loads = {};
  final saves = <_SaveCall>[];
  ProfileEditorRecord? saveResult;
  Object? saveError;
  Object? loadError;
  Completer<ProfileEditorRecord>? pendingSave;

  @override
  Future<ProfileEditorRecord> load(String userId) {
    if (loadError case final error?) return Future.error(error);
    return (_loads[userId] ??= Completer<ProfileEditorRecord>()).future;
  }

  void completeLoad(ProfileEditorRecord value, {String? user}) {
    (_loads[user ?? value.userId] ??= Completer<ProfileEditorRecord>())
        .complete(value);
  }

  @override
  Future<ProfileEditorRecord> updateNickname({
    required String userId,
    required String nickname,
    required int expectedRevision,
  }) async {
    saves.add(
      _SaveCall(userId: userId, nickname: nickname, revision: expectedRevision),
    );
    if (saveError case final error?) throw error;
    if (pendingSave case final pending?) return pending.future;
    return saveResult!;
  }
}

final class _ForbiddenPreview extends PreviewController {
  @override
  PreviewState build() => throw StateError('preview state read in API mode');
}

final class _SaveCall {
  const _SaveCall({
    required this.userId,
    required this.nickname,
    required this.revision,
  });

  final String userId;
  final String nickname;
  final int revision;

  @override
  bool operator ==(Object other) =>
      other is _SaveCall &&
      other.userId == userId &&
      other.nickname == nickname &&
      other.revision == revision;

  @override
  int get hashCode => Object.hash(userId, nickname, revision);
}
