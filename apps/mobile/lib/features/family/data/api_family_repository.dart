import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/api_exception.dart';
import '../domain/family_models.dart';
import 'family_repository.dart';

/// [FamilyRepository] backed by the Progress family owner API. The generated
/// client attaches one `Idempotency-Key` per mutation and reuses it on retry.
class ApiFamilyRepository implements FamilyRepository {
  ApiFamilyRepository(this.api);
  final ApiEndpoints api;

  @override
  Future<FamilyGroup> create({required String plan}) =>
      _guard(() => api.createFamily(wire.FamilyCreateRequest(plan: plan)));

  @override
  Future<FamilyGroup> join({
    required String groupId,
    required String inviteCode,
  }) => _guard(
    () =>
        api.joinFamily(groupId, wire.FamilyJoinRequest(inviteCode: inviteCode)),
  );

  @override
  Future<FamilyGroup> removeMember({
    required String groupId,
    required String userId,
  }) => _guard(() => api.removeFamilyMember(groupId, userId));

  static Future<FamilyGroup> _guard(
    Future<wire.FamilyGroup> Function() call,
  ) async {
    try {
      return _map(await call());
    } on ApiException catch (error) {
      throw FamilyException(_failure(error));
    }
  }

  static FamilyFailure _failure(ApiException error) {
    if (error.isOffline) return FamilyFailure.offline;
    if (error.code == 'ENTITLEMENT_REQUIRED') {
      return FamilyFailure.entitlementRequired;
    }
    if (error.code == 'FORBIDDEN') return FamilyFailure.forbidden;
    switch (error.details['reason']) {
      case 'FAMILY_FULL':
        return FamilyFailure.familyFull;
      case 'ALREADY_IN_FAMILY':
        return FamilyFailure.alreadyInFamily;
      case 'MANAGER_CANNOT_LEAVE':
        return FamilyFailure.managerCannotLeave;
    }
    if (error.isNotFound ||
        error.code == 'NOT_FOUND' ||
        error.code == 'PROFILE_UNAVAILABLE') {
      return FamilyFailure.notFound;
    }
    return FamilyFailure.failed;
  }

  static FamilyGroup _map(wire.FamilyGroup group) => FamilyGroup(
    groupId: group.groupId,
    ownerUserId: group.ownerUserId,
    plan: group.plan,
    status: group.status,
    inviteCode: group.inviteCode,
    revision: group.revision,
    members: List.unmodifiable([
      for (final member in group.members)
        FamilyMember(
          userId: member.userId,
          nickname: member.nickname,
          role: member.role == 'MANAGER'
              ? FamilyRole.manager
              : FamilyRole.member,
          joinedAt: member.joinedAt,
        ),
    ]),
  );
}
