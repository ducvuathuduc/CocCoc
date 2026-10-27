/// Family Plan sharing (SRS family subscription). Wire shapes:
/// `POST /v1/family`, `POST /v1/family/{groupId}/members`,
/// `DELETE /v1/family/{groupId}/members/{userId}` → FamilyGroup.
enum FamilyRole { manager, member }

/// Server cap on a family group, manager included.
const familyMaxMembers = 6;

class FamilyMember {
  const FamilyMember({
    required this.userId,
    required this.nickname,
    required this.role,
    required this.joinedAt,
  });
  final String userId;
  final String nickname;
  final FamilyRole role;

  /// Server timestamp (`date-time`).
  final String joinedAt;
}

class FamilyGroup {
  const FamilyGroup({
    required this.groupId,
    required this.ownerUserId,
    required this.plan,
    required this.status,
    required this.members,
    required this.revision,
    this.inviteCode,
  });
  final String groupId;
  final String ownerUserId;

  /// `SUPER` or `MAX`.
  final String plan;

  /// `ACTIVE` or `ENDED`.
  final String status;
  final List<FamilyMember> members;

  /// Only the manager sees the invite code; null for members.
  final String? inviteCode;
  final int revision;

  bool get isActive => status == 'ACTIVE';
  int get slotsLeft => familyMaxMembers - members.length;
  bool get hasRoom => slotsLeft > 0;

  FamilyMember? memberOf(String userId) =>
      members.where((m) => m.userId == userId).firstOrNull;
  FamilyRole? roleOf(String userId) => memberOf(userId)?.role;
}

enum FamilyFailure {
  entitlementRequired,
  notFound,
  forbidden,
  familyFull,
  alreadyInFamily,
  managerCannotLeave,
  offline,
  failed,
}

class FamilyException implements Exception {
  const FamilyException(this.failure);
  final FamilyFailure failure;

  @override
  String toString() => 'FamilyException(${failure.name})';
}
