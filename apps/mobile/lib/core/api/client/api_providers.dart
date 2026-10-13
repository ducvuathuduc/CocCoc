import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/application/auth_controller.dart';
import '../../../features/connectivity/application/connectivity_provider.dart';
import '../../../features/connectivity/data/api_connectivity_repository.dart';
import '../../config/app_config.dart';
import 'access_token.dart';
import 'api_client.dart';
import 'api_endpoints.g.dart';
import 'api_operation.dart';
import 'api_transport.dart';
import 'service_apis.dart';

/// HTTP transport; tests override it with a fake.
final apiTransportProvider = Provider<ApiTransport>((ref) {
  final transport = ApiTransport.platformDefault();
  final connectivity = ref.watch(connectivityRepositoryProvider);
  return connectivity is ApiConnectivityRepository
      ? connectivity.observe(transport)
      : transport;
});

/// Bearer token source: the active auth repository's Appwrite JWT.
final accessTokenProvider = Provider<AccessTokenProvider>((ref) {
  final session = ref.watch(authSessionRepositoryProvider);
  return CachingTokenProvider(() async => session?.accessToken());
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  return ApiClient(
    transport: ref.watch(apiTransportProvider),
    tokens: ref.watch(accessTokenProvider),
    timeout: config.requestTimeout,
    baseUrls: {
      for (final service in ApiService.values)
        service: ?config.baseUrl(service),
    },
  );
});

final learningApiProvider = Provider<LearningApi>(
  (ref) => LearningApi(ref.watch(apiClientProvider)),
);

final progressApiProvider = Provider<ProgressApi>(
  (ref) => ProgressApi(ref.watch(apiClientProvider)),
);

final aiApiProvider = Provider<AiApi>(
  (ref) => AiApi(ref.watch(apiClientProvider)),
);

/// Every client-callable operation, generated from OpenAPI.
final apiEndpointsProvider = Provider<ApiEndpoints>(
  (ref) => ApiEndpoints(ref.watch(apiClientProvider)),
);
