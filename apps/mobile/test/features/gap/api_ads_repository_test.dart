import 'package:cocenglish/core/api/client/access_token.dart';
import 'package:cocenglish/core/api/client/api_client.dart';
import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/core/api/client/api_exception.dart';
import 'package:cocenglish/core/api/client/api_operation.dart';
import 'package:cocenglish/core/api/client/idempotency.dart';
import 'package:cocenglish/features/ads/data/api_ads_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_api_transport.dart';

void main() {
  test(
    'API events use stable UUIDs and retries keep completion identity',
    () async {
      final transport = FakeApiTransport();
      transport.on('POST /v1/ad-events', (request) {
        final body = bodyOf(request);
        return jsonResponse({
          ...body,
          'learningDay': '2026-10-12',
          'dailyIndex': 1,
          'remainingToday': 2,
          'rewardGems': 0,
          'rewardEnergy': 5,
          'gems': 475,
          'energyGrantPending': true,
        });
      });
      final api = ApiEndpoints(
        ApiClient(
          transport: transport,
          baseUrls: {ApiService.progress: Uri.parse('https://progress.test')},
          tokens: const StaticTokenProvider('test-jwt'),
          maxRetries: 0,
        ),
      );
      final repository = ApiAdsRepository(api);
      const id = '00000000-0000-4000-8000-000000000001';
      await repository.impression(id, 'REWARDED_ENERGY_REFILL');
      await repository.impression(id, 'REWARDED_ENERGY_REFILL');
      await repository.complete(id, 'REWARDED_ENERGY_REFILL');
      await repository.complete(id, 'REWARDED_ENERGY_REFILL');
      final requests = transport.requests;
      final impression = bodyOf(requests[0])['adEventId'] as String;
      expect(uuidPattern.hasMatch(impression), isTrue);
      expect(bodyOf(requests[1])['adEventId'], impression);
      expect(bodyOf(requests[2])['adEventId'], id);
      expect(requests[2].headers['Idempotency-Key'], id);
      expect(bodyOf(requests[3])['adEventId'], id);
      expect(requests[2].headers['Authorization'], 'Bearer test-jwt');
      transport.json(
        'POST /v1/ad-events',
        errorEnvelope('AD_NOT_ELIGIBLE'),
        status: 403,
      );
      await expectLater(
        repository.complete(id, 'REWARDED_ENERGY_REFILL'),
        throwsA(isA<ApiException>()),
      );
    },
  );
}
