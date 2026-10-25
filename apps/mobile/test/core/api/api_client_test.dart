import 'dart:convert';

import 'package:cocenglish/core/api/api_contracts.dart' show QuestClaimRequest;
import 'package:cocenglish/core/api/client/access_token.dart';
import 'package:cocenglish/core/api/client/api_exception.dart';
import 'package:cocenglish/core/api/client/api_operations.g.dart';
import 'package:cocenglish/core/api/client/api_transport.dart';
import 'package:cocenglish/core/api/client/idempotency.dart';
import 'package:cocenglish/core/api/client/service_apis.dart';
import 'package:cocenglish/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_api_transport.dart';

Map<String, Object?> rewards({String status = 'credited', int gems = 120}) => {
  'completionId': null,
  'status': status,
  'studyXp': 340,
  'leagueXp': 90,
  'gems': gems,
  'freezeSlots': 2,
  'currentStreak': 12,
  'awardXp': null,
  'revision': 7,
  'asOf': isoNow,
};

void main() {
  late FakeApiTransport transport;

  setUp(() => transport = FakeApiTransport());

  test('sends JWT, request id and idempotency key; routes to owner', () async {
    transport.json('POST /base/v1/me/freezes', rewards(gems: 80));
    final api = ProgressApi(fakeClient(transport));

    final result = await api.buyFreeze(
      idempotencyKey: '11111111-1111-4111-8111-111111111111',
    );

    expect(result.gems, 80);
    final request = transport.requests.single;
    expect(request.uri.host, 'progress.test');
    expect(request.headers['Authorization'], 'Bearer jwt-test');
    expect(
      request.headers['Idempotency-Key'],
      '11111111-1111-4111-8111-111111111111',
    );
    expect(uuidPattern.hasMatch(request.headers['X-Request-ID']!), isTrue);
  });

  test('GET operations carry no idempotency key and drop null query', () async {
    transport.json('GET /base/v1/me/rewards', rewards());
    await ProgressApi(fakeClient(transport)).getRewards();
    final request = transport.requests.single;
    expect(request.headers.containsKey('Idempotency-Key'), isFalse);
    expect(request.uri.query, isEmpty);
  });

  test('maps the Error envelope to ApiException', () async {
    transport.json(
      'POST /base/v1/me/freezes',
      errorEnvelope('INSUFFICIENT_GEMS', message: 'Need gems'),
      status: 409,
    );
    final api = ProgressApi(fakeClient(transport));
    await expectLater(
      api.buyFreeze(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'INSUFFICIENT_GEMS')
            .having((e) => e.statusCode, 'status', 409)
            .having((e) => e.requestId, 'requestId', 'req-1')
            .having((e) => e.isConflict, 'conflict', isTrue),
      ),
    );
  });

  test('retries retryable failures with the same idempotency key', () async {
    transport
      ..once(
        'POST /base/v1/me/freezes',
        (_) => ApiHttpResponse(
          503,
          jsonEncode(errorEnvelope('UNAVAILABLE', retryable: true)),
        ),
      )
      ..json('POST /base/v1/me/freezes', rewards());
    await ProgressApi(fakeClient(transport)).buyFreeze();
    final keys = transport.requests
        .map((r) => r.headers['Idempotency-Key'])
        .toSet();
    expect(transport.requests, hasLength(2));
    expect(keys, hasLength(1));
  });

  test('re-mints the JWT once after a 401', () async {
    var minted = 0;
    final tokens = CachingTokenProvider(() async => 'jwt-${++minted}');
    transport
      ..once(
        'GET /base/v1/me',
        (_) =>
            ApiHttpResponse(401, jsonEncode(errorEnvelope('UNAUTHENTICATED'))),
      )
      ..json('GET /base/v1/me', {
        'userId': 'u1',
        'nickname': 'Sam',
        'avatarId': null,
        'publicOptIn': true,
        'dailyGoal': 10,
        'learningZone': 'Asia/Ho_Chi_Minh',
        'pendingZone': null,
        'zoneEffectiveAt': null,
        'revision': 3,
        'achievementIds': <String>[],
      });
    final me = await ProgressApi(fakeClient(transport, tokens: tokens)).getMe();
    expect(me.nickname, 'Sam');
    expect(transport.requests.map((r) => r.headers['Authorization']), [
      'Bearer jwt-1',
      'Bearer jwt-2',
    ]);
  });

  test('no session -> UNAUTHENTICATED without hitting the network', () async {
    final client = fakeClient(
      transport,
      tokens: const StaticTokenProvider(null),
    );
    await expectLater(
      ProgressApi(client).getRewards(),
      throwsA(
        isA<ApiException>().having((e) => e.isUnauthenticated, 'unauth', true),
      ),
    );
    expect(transport.requests, isEmpty);
  });

  test('transport failure maps to NETWORK (offline)', () async {
    transport.offline = true;
    final client = fakeClient(transport);
    await expectLater(
      ProgressApi(client).getRewards(),
      throwsA(isA<ApiException>().having((e) => e.isOffline, 'offline', true)),
    );
    // GET is retried, so 1 + maxRetries attempts.
    expect(transport.requests, hasLength(3));
  });

  test('a response violating the contract is BAD_RESPONSE', () async {
    transport.json('GET /base/v1/me/rewards', {'status': 'credited'});
    await expectLater(
      ProgressApi(fakeClient(transport)).getRewards(),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'BAD_RESPONSE'),
      ),
    );
  });

  test('path params are encoded and the base path is kept', () async {
    transport.json('POST /base/v1/quests/q%201/claim', rewards());
    final api = ProgressApi(fakeClient(transport));
    final result = await api.claimQuest(
      'q 1',
      const QuestClaimRequest(periodKey: '2026-10-12'),
    );
    expect(result.status, 'credited');
    expect(transport.requests.single.uri.path, '/base/v1/quests/q%201/claim');
    expect(bodyOf(transport.requests.single), {'periodKey': '2026-10-12'});
  });

  test('UuidV4Generator emits RFC 4122 v4 ids', () {
    final ids = UuidV4Generator();
    for (var i = 0; i < 50; i++) {
      expect(uuidPattern.hasMatch(ids.next()), isTrue);
    }
  });

  test('AppConfig defaults to MOCK and parses the flag', () {
    expect(const AppConfig().isApi, isFalse);
    expect(const AppConfig().useMockAuth, isTrue);
    expect(AppConfig.parseDataSource('API'), DataSource.api);
    expect(() => AppConfig.parseDataSource('anything'), throwsFormatException);
    const api = AppConfig(dataSource: DataSource.api);
    expect(api.useMockAuth, isFalse);
    expect(
      const AppConfig(
        dataSource: DataSource.api,
        mockAuthOverride: true,
      ).useMockAuth,
      isTrue,
    );
    expect(
      AppConfig.defaultAppwriteEndpoint,
      'https://sgp.cloud.appwrite.io/v1',
    );
    expect(AppConfig.defaultAppwriteProjectId, '6acc656d0025cc57bd81');
    expect(AppConfig.current.isApi, isFalse, reason: 'tests run MOCK');
  });

  test('every generated operation path expands', () {
    for (final op in ApiOperations.all) {
      final params = {
        for (final m in RegExp(r'\{(\w+)\}').allMatches(op.pathTemplate))
          m.group(1)!: 'x',
      };
      expect(op.path(params), isNot(contains('{')));
    }
  });
}
