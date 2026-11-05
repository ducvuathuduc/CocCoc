import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/features/promo/data/api_referral_repository.dart';
import 'package:cocenglish/features/promo/data/referral_repository.dart';
import 'package:cocenglish/features/promo/domain/referral.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_api_transport.dart';

Map<String, Object?> referral({
  String code = 'ABCD1234EFGH5678',
  int accepted = 2,
  int qualified = 1,
  int rewarded = 1,
}) => {
  'code': code,
  'accepted': accepted,
  'qualified': qualified,
  'rewarded': rewarded,
  'asOf': isoNow,
};

Map<String, Object?> receipt() => {
  'operationId': 'op-1',
  'status': 'completed',
  'requestId': 'req-1',
};

ApiReferralRepository apiReferralRepository(FakeApiTransport transport) =>
    ApiReferralRepository(ApiEndpoints(fakeClient(transport)));

void main() {
  test('API load reads GET /v1/me/referral', () async {
    final transport = FakeApiTransport()
      ..json('GET /base/v1/me/referral', referral());
    final status = await apiReferralRepository(transport).load();

    expect(status.code, 'ABCD1234EFGH5678');
    expect(status.accepted, 2);
    expect(status.qualified, 1);
    expect(status.rewarded, 1);
    expect(status.asOf, DateTime.utc(2026, 10, 12, 8));
    expect(
      transport.requests.single.headers['Authorization'],
      'Bearer jwt-test',
    );
  });

  test(
    'API redeem posts the normalized code with an idempotency key',
    () async {
      final transport = FakeApiTransport()
        ..json('POST /base/v1/referrals/redeem', receipt());
      final result = await apiReferralRepository(transport).redeem('abcd-1234');

      expect(result.accepted, isTrue);
      expect(result.failure, isNull);
      final request = transport.requests.single;
      expect(bodyOf(request), {'code': 'ABCD-1234'});
      expect(request.headers['Idempotency-Key'], isNotEmpty);
    },
  );

  test('API redeem reuses a caller supplied idempotency key', () async {
    final transport = FakeApiTransport()
      ..json('POST /base/v1/referrals/redeem', receipt());
    await apiReferralRepository(transport)
        .redeem('ABCD-1234', idempotencyKey: 'key-1');

    expect(transport.requests.single.headers['Idempotency-Key'], 'key-1');
  });

  test(
    'API redeem maps unknown codes to notFound and offline to offline',
    () async {
      final notFound = FakeApiTransport()
        ..json(
          'POST /base/v1/referrals/redeem',
          errorEnvelope('NOT_FOUND'),
          status: 404,
        );
      final rejected = await apiReferralRepository(notFound)
          .redeem('ZZZZ-9999');
      expect(rejected.accepted, isFalse);
      expect(rejected.failure, ReferralFailure.notFound);

      final offline = FakeApiTransport()..offline = true;
      final result = await apiReferralRepository(offline).redeem('ABCD-1234');
      expect(result.failure, ReferralFailure.offline);
    },
  );

  test('client rejects codes outside the 4-16 character contract', () async {
    final transport = FakeApiTransport();
    final result = await apiReferralRepository(transport).redeem('a b');

    expect(result.failure, ReferralFailure.invalidFormat);
    expect(transport.requests, isEmpty);
  });

  test('mock issues one code and refuses self redemption', () async {
    final repo = MockReferralRepository();
    final status = await repo.load();
    expect(status.code, isNotEmpty);
    expect(status.accepted, 0);
    expect((await repo.redeem(status.code)).failure, ReferralFailure.notFound);
    final accepted = await repo.redeem('FRIEND-2026');
    expect(accepted.accepted, isTrue);
    final replay = await repo.redeem('FRIEND-2026');
    expect(replay.accepted, isTrue);
    expect((await repo.load()).accepted, 1);
  });
}
