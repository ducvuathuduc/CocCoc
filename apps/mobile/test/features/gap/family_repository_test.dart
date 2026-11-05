import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/features/family/data/api_family_repository.dart';
import 'package:cocenglish/features/family/data/family_repository.dart';
import 'package:cocenglish/features/family/domain/family_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_api_transport.dart';

Map<String, Object?> member(String userId, String nickname, String role) => {
  'userId': userId,
  'nickname': nickname,
  'role': role,
  'joinedAt': isoNow,
};

Map<String, Object?> familyGroup({
  List<Map<String, Object?>>? members,
  String? inviteCode = 'ABCD-1234',
  int revision = 0,
}) => {
  'groupId': 'g-1',
  'ownerUserId': 'u-1',
  'plan': 'SUPER',
  'status': 'ACTIVE',
  'members':
      members ??
      [member('u-1', 'An', 'MANAGER'), member('u-2', 'Binh', 'MEMBER')],
  'inviteCode': inviteCode,
  'revision': revision,
};

Map<String, Object?> error(
  String code, {
  Map<String, Object?> details = const {},
}) => {
  'error': {
    'code': code,
    'message': 'failure',
    'requestId': 'req-1',
    'details': details,
    'retryable': false,
  },
};

ApiFamilyRepository apiFamilyRepository(FakeApiTransport transport) =>
    ApiFamilyRepository(ApiEndpoints(fakeClient(transport)));

void main() {
  test('API create posts the plan and maps the group', () async {
    final transport = FakeApiTransport()
      ..json(
        'POST /base/v1/family',
        familyGroup(
          members: [member('u-1', 'An', 'MANAGER')],
          inviteCode: 'ABCD-1234',
        ),
      );
    final group = await apiFamilyRepository(transport).create(plan: 'SUPER');

    expect(group.groupId, 'g-1');
    expect(group.ownerUserId, 'u-1');
    expect(group.roleOf('u-1'), FamilyRole.manager);
    expect(group.inviteCode, 'ABCD-1234');
    expect(group.slotsLeft, 5);
    final request = transport.to('POST /base/v1/family').single;
    expect(bodyOf(request), {'plan': 'SUPER'});
    expect(request.headers['Authorization'], 'Bearer jwt-test');
    expect(request.headers['Idempotency-Key'], isNotEmpty);
  });

  test('API join posts the invite code to the group path', () async {
    final transport = FakeApiTransport()
      ..json('POST /base/v1/family/g-1/members', familyGroup(revision: 1));
    final group = await apiFamilyRepository(transport)
        .join(groupId: 'g-1', inviteCode: 'ABCD-1234');

    expect(group.revision, 1);
    expect(bodyOf(transport.requests.single), {'inviteCode': 'ABCD-1234'});
    expect(transport.requests.single.uri.path, '/base/v1/family/g-1/members');
  });

  test('API remove deletes the member and maps the remaining group', () async {
    final transport = FakeApiTransport()
      ..json(
        'DELETE /base/v1/family/g-1/members/u-2',
        familyGroup(members: [member('u-1', 'An', 'MANAGER')], revision: 2),
      );
    final group = await apiFamilyRepository(transport)
        .removeMember(groupId: 'g-1', userId: 'u-2');

    expect(group.members.map((m) => m.userId), ['u-1']);
    expect(transport.requests.single.method, 'DELETE');
  });

  test('API errors map to family failures', () async {
    final notFound = FakeApiTransport()
      ..json(
        'POST /base/v1/family/g-1/members',
        error('NOT_FOUND'),
        status: 404,
      );
    await expectLater(
      apiFamilyRepository(notFound).join(groupId: 'g-1', inviteCode: 'WRONG'),
      throwsA(
        isA<FamilyException>().having(
          (e) => e.failure,
          'failure',
          FamilyFailure.notFound,
        ),
      ),
    );

    final full = FakeApiTransport()
      ..json(
        'POST /base/v1/family/g-1/members',
        error('REVISION_CONFLICT', details: {'reason': 'FAMILY_FULL'}),
        status: 409,
      );
    await expectLater(
      apiFamilyRepository(full).join(groupId: 'g-1', inviteCode: 'ABCD-1234'),
      throwsA(
        isA<FamilyException>().having(
          (e) => e.failure,
          'failure',
          FamilyFailure.familyFull,
        ),
      ),
    );

    final noPlan = FakeApiTransport()
      ..json(
        'POST /base/v1/family',
        error('ENTITLEMENT_REQUIRED'),
        status: 403,
      );
    await expectLater(
      apiFamilyRepository(noPlan).create(plan: 'SUPER'),
      throwsA(
        isA<FamilyException>().having(
          (e) => e.failure,
          'failure',
          FamilyFailure.entitlementRequired,
        ),
      ),
    );

    final offline = FakeApiTransport()..offline = true;
    await expectLater(
      apiFamilyRepository(offline).create(plan: 'SUPER'),
      throwsA(
        isA<FamilyException>().having(
          (e) => e.failure,
          'failure',
          FamilyFailure.offline,
        ),
      ),
    );
  });

  test('mock keeps the six-seat family rules locally', () async {
    final repo = MockFamilyRepository();
    final created = await repo.create(plan: 'SUPER');
    expect(created.members.single.role, FamilyRole.manager);
    expect(created.inviteCode, isNotNull);
    await expectLater(
      repo.create(plan: 'MAX'),
      throwsA(
        isA<FamilyException>().having(
          (e) => e.failure,
          'failure',
          FamilyFailure.alreadyInFamily,
        ),
      ),
    );
    await expectLater(
      repo.join(groupId: created.groupId, inviteCode: 'NOPE-0000'),
      throwsA(
        isA<FamilyException>().having(
          (e) => e.failure,
          'failure',
          FamilyFailure.notFound,
        ),
      ),
    );
    final joined = await repo.join(
      groupId: created.groupId,
      inviteCode: created.inviteCode!,
    );
    expect(joined.members, hasLength(2));
    await expectLater(
      repo.removeMember(groupId: created.groupId, userId: created.ownerUserId),
      throwsA(
        isA<FamilyException>().having(
          (e) => e.failure,
          'failure',
          FamilyFailure.managerCannotLeave,
        ),
      ),
    );
    final removed = await repo.removeMember(
      groupId: created.groupId,
      userId: 'member-demo',
    );
    expect(removed.members, hasLength(1));
  });
}
