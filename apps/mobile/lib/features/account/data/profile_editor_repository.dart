import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_endpoints.g.dart';

final class ProfileEditorRecord {
  const ProfileEditorRecord({
    required this.userId,
    required this.nickname,
    required this.revision,
  });

  final String userId;
  final String nickname;
  final int revision;
}

abstract interface class ProfileEditorRepository {
  Future<ProfileEditorRecord> load(String userId);

  Future<ProfileEditorRecord> updateNickname({
    required String userId,
    required String nickname,
    required int expectedRevision,
  });
}

final class ApiProfileEditorRepository implements ProfileEditorRepository {
  const ApiProfileEditorRepository(this.api);

  final ApiEndpoints api;

  @override
  Future<ProfileEditorRecord> load(String userId) async =>
      _record(await api.getMe());

  @override
  Future<ProfileEditorRecord> updateNickname({
    required String userId,
    required String nickname,
    required int expectedRevision,
  }) async => _record(
    await api.updateMe(
      wire.ProfilePatch(nickname: nickname, expectedRevision: expectedRevision),
    ),
  );

  static ProfileEditorRecord _record(wire.Profile profile) =>
      ProfileEditorRecord(
        userId: profile.userId,
        nickname: profile.nickname,
        revision: profile.revision,
      );
}
