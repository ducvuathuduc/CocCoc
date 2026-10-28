import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/client/api_providers.dart';
import '../../../core/config/app_config.dart';
import '../domain/family_models.dart';
import 'api_family_repository.dart';

/// Family Plan owner API: create, join by invite code, remove a member.
abstract interface class FamilyRepository {
  /// `POST /v1/family`; the manager needs an active paid entitlement.
  Future<FamilyGroup> create({required String plan});

  /// `POST /v1/family/{groupId}/members` with the group's invite code.
  Future<FamilyGroup> join({
    required String groupId,
    required String inviteCode,
  });

  /// `DELETE /v1/family/{groupId}/members/{userId}`; the manager cannot leave.
  Future<FamilyGroup> removeMember({
    required String groupId,
    required String userId,
  });
}

/// In-memory stand-in: one group per learner, six seats, owner-only removal.
class MockFamilyRepository implements FamilyRepository {
  MockFamilyRepository({
    this.managerId = 'demo-manager',
    this.managerName = 'You',
    this.viewerId = 'member-demo',
    this.viewerName = 'Invited member',
    this.inviteCode = 'FAMILY-DEMO',
    this.latency = Duration.zero,
  });

  final String managerId, managerName, viewerId, viewerName, inviteCode;
  final Duration latency;
  FamilyGroup? _group;
  int _revision = 0;
  int _joined = 0;

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  @override
  Future<FamilyGroup> create({required String plan}) async {
    await _wait();
    if (plan != 'SUPER' && plan != 'MAX') {
      throw ArgumentError.value(plan, 'plan', 'SUPER or MAX');
    }
    if (_group != null) {
      throw const FamilyException(FamilyFailure.alreadyInFamily);
    }
    _revision = 0;
    return _group = FamilyGroup(
      groupId: 'family-demo',
      ownerUserId: managerId,
      plan: plan,
      status: 'ACTIVE',
      revision: _revision,
      inviteCode: inviteCode,
      members: [
        FamilyMember(
          userId: managerId,
          nickname: managerName,
          role: FamilyRole.manager,
          joinedAt: DateTime.now().toUtc().toIso8601String(),
        ),
      ],
    );
  }

  @override
  Future<FamilyGroup> join({
    required String groupId,
    required String inviteCode,
  }) async {
    await _wait();
    final group = _group;
    if (group == null ||
        !group.isActive ||
        group.groupId != groupId ||
        group.inviteCode != inviteCode) {
      throw const FamilyException(FamilyFailure.notFound);
    }
    if (group.memberOf(viewerId) != null) return group;
    if (!group.hasRoom) throw const FamilyException(FamilyFailure.familyFull);
    _joined++;
    final members = [
      ...group.members,
      FamilyMember(
        userId: viewerId,
        nickname: '$viewerName $_joined',
        role: FamilyRole.member,
        joinedAt: DateTime.now().toUtc().toIso8601String(),
      ),
    ];
    return _group = FamilyGroup(
      groupId: group.groupId,
      ownerUserId: group.ownerUserId,
      plan: group.plan,
      status: group.status,
      revision: ++_revision,
      inviteCode: group.inviteCode,
      members: members,
    );
  }

  @override
  Future<FamilyGroup> removeMember({
    required String groupId,
    required String userId,
  }) async {
    await _wait();
    final group = _group;
    if (group == null || !group.isActive || group.groupId != groupId) {
      throw const FamilyException(FamilyFailure.notFound);
    }
    if (userId == group.ownerUserId) {
      throw const FamilyException(FamilyFailure.managerCannotLeave);
    }
    final members = group.members.where((m) => m.userId != userId).toList();
    if (members.length == group.members.length) return group;
    return _group = FamilyGroup(
      groupId: group.groupId,
      ownerUserId: group.ownerUserId,
      plan: group.plan,
      status: group.status,
      revision: ++_revision,
      inviteCode: group.inviteCode,
      members: members,
    );
  }
}

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  if (!ref.watch(appConfigProvider).isApi) return MockFamilyRepository();
  return ApiFamilyRepository(ref.watch(apiEndpointsProvider));
});
