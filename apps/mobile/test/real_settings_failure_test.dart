import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/features/account/application/settings_extras_controller.dart';
import 'package:cocenglish/features/account/data/api_account_repositories.dart';
import 'package:cocenglish/features/account/data/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_api_transport.dart';

void main() {
  test('unconnected API social link cannot toggle fixture identity', () async {
    final content = MockSettingsRepository(latency: Duration.zero);
    final repository = ApiSettingsRepository(
      api: ApiEndpoints(fakeClient(FakeApiTransport())),
      content: content,
    );
    final container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container
        .read(settingsExtrasControllerProvider.notifier)
        .setSocial('google', true);
    expect(content.connectedSocial, isEmpty);
    expect(container.read(settingsExtrasControllerProvider).connected, isEmpty);
    expect(container.read(settingsExtrasControllerProvider).error, isNotNull);
  });

  test(
    'failed feedback clears busy, reports error and permits retry',
    () async {
      final transport = FakeApiTransport()
        ..json(
          'POST /base/v1/feedback',
          errorEnvelope('UNAVAILABLE'),
          status: 503,
        );
      final repository = ApiSettingsRepository(
        api: ApiEndpoints(fakeClient(transport)),
        content: MockSettingsRepository(),
      );
      final container = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final vm = container.read(settingsExtrasControllerProvider.notifier);
      expect(await vm.sendFeedback('Bug report', 'Audio stops'), isFalse);
      expect(container.read(settingsExtrasControllerProvider).sending, isFalse);
      expect(container.read(settingsExtrasControllerProvider).feedbackSent, 0);
      transport.json('POST /base/v1/feedback', {
        'operationId': 'op',
        'status': 'accepted',
        'requestId': 'req',
      });
      expect(await vm.sendFeedback('Bug report', 'Audio stops'), isTrue);
      expect(container.read(settingsExtrasControllerProvider).feedbackSent, 1);
    },
  );
}
