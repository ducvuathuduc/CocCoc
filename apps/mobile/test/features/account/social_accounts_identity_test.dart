import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/core/api/client/api_exception.dart';
import 'package:cocenglish/features/account/application/settings_extras_controller.dart';
import 'package:cocenglish/features/account/data/api_account_repositories.dart';
import 'package:cocenglish/features/account/data/settings_repository.dart';
import 'package:cocenglish/features/auth/services/appwrite_auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_api_transport.dart';

/// In-memory stand-in for Appwrite Account identities.
class FakeIdentityGateway implements SocialIdentityGateway {
  FakeIdentityGateway({Set<String> linked = const {}}) : linked = {...linked};

  final Set<String> linked;
  final List<String> linkedRequests = [];
  final List<String> unlinkedRequests = [];
  Object? linkError;
  Object? unlinkError;
  int reads = 0;

  @override
  Set<String> get configuredProviders => const {'google', 'facebook'};

  @override
  Future<Set<String>> linkedProviders() async {
    reads++;
    return {...linked};
  }

  @override
  Future<void> link(String providerId) async {
    if (linkError case final error?) throw error;
    linkedRequests.add(providerId);
    linked.add(providerId);
  }

  @override
  Future<void> unlink(String providerId) async {
    if (unlinkError case final error?) throw error;
    unlinkedRequests.add(providerId);
    linked.remove(providerId);
  }
}

ApiSettingsRepository apiSettings(
  FakeIdentityGateway? identities, {
  SettingsContent content = const BundledSettingsContent(),
}) => ApiSettingsRepository(
  api: ApiEndpoints(fakeClient(FakeApiTransport())),
  content: content,
  identities: identities,
);

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('API social switches show the identities linked on the account', () async {
    final repository = apiSettings(FakeIdentityGateway(linked: {'google'}));
    final container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    container.read(settingsExtrasControllerProvider);

    await settle();
    expect(container.read(settingsExtrasControllerProvider).connected, {
      'google',
    });
    expect(container.read(settingsExtrasControllerProvider).error, isNull);
  });

  test('linking then unlinking a provider follows the account identities', () async {
    final gateway = FakeIdentityGateway();
    final repository = apiSettings(gateway);
    final container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final vm = container.read(settingsExtrasControllerProvider.notifier);
    await settle();

    await vm.setSocial('google', true);
    expect(gateway.linkedRequests, ['google']);
    expect(container.read(settingsExtrasControllerProvider).connected, {
      'google',
    });
    expect(container.read(settingsExtrasControllerProvider).error, isNull);

    await vm.setSocial('google', false);
    expect(gateway.unlinkedRequests, ['google']);
    expect(container.read(settingsExtrasControllerProvider).connected, isEmpty);
    expect(repository.connectedSocial, isEmpty);
  });

  test('a failed link keeps the switch off with a neutral message', () async {
    final gateway = FakeIdentityGateway()
      ..linkError = const ApiException(
        code: 'UNAVAILABLE',
        message: 'raw provider detail',
      );
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(apiSettings(gateway)),
      ],
    );
    addTearDown(container.dispose);
    final vm = container.read(settingsExtrasControllerProvider.notifier);
    await settle();

    await vm.setSocial('facebook', true);
    expect(gateway.linkedRequests, isEmpty);
    expect(container.read(settingsExtrasControllerProvider).connected, isEmpty);
    final error = container.read(settingsExtrasControllerProvider).error;
    expect(error, isNotNull);
    expect(error, isNot(contains('raw provider detail')));
  });

  test('signed-out or unwired builds keep switches off and explain', () async {
    final repository = apiSettings(null);
    final container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final vm = container.read(settingsExtrasControllerProvider.notifier);
    await settle();
    expect(container.read(settingsExtrasControllerProvider).connected, isEmpty);
    expect(container.read(settingsExtrasControllerProvider).error, isNull);

    await vm.setSocial('google', true);
    expect(container.read(settingsExtrasControllerProvider).connected, isEmpty);
    expect(
      container.read(settingsExtrasControllerProvider).error,
      'This feature isn’t connected yet.',
    );
  });

  group('AppwriteSocialIdentityGateway', () {
    SocialIdentityGateway unconfigured() => AppwriteSocialIdentityGateway(
      AppwriteAuthService.withAccount(null),
    );

    test('an SDK that is not configured reports no identities', () async {
      await expectLater(
        unconfigured().linkedProviders(),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'NOT_CONFIGURED'),
        ),
      );
    });

    test('link and unlink reject providers the build did not enable', () async {
      await expectLater(
        unconfigured().link('google'),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'NOT_CONFIGURED'),
        ),
      );
      await expectLater(
        unconfigured().unlink('google'),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'NOT_CONFIGURED'),
        ),
      );
      expect(unconfigured().configuredProviders, isEmpty);
    });
  });
}
