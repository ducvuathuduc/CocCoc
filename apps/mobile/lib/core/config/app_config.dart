import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client/api_operation.dart';

/// Where repositories read their data from.
///
/// [mock] (default) keeps the app fully runnable offline with local fixtures.
/// [api] selects the HTTP repositories backed by the OpenAPI services and
/// Appwrite Account auth: `--dart-define=DATA_SOURCE=api`.
enum DataSource { mock, api }

/// Single runtime switch for the data layer plus public service endpoints.
///
/// Every value is a public, non-secret build define. API keys never ship in the
/// app; identity comes from an Appwrite JWT minted by the signed-in Account.
final class AppConfig {
  const AppConfig({
    this.dataSource = DataSource.mock,
    this.appwriteEndpoint = defaultAppwriteEndpoint,
    this.appwriteProjectId = defaultAppwriteProjectId,
    this.serviceUrls = const <ApiService, String>{},
    this.mockAuthOverride,
    this.allowInsecureLocalEndpoints = false,
    this.requestTimeout = const Duration(seconds: 15),
  });

  factory AppConfig.fromEnvironment() {
    const source = String.fromEnvironment('DATA_SOURCE', defaultValue: 'mock');
    const endpoint = String.fromEnvironment(
      'APPWRITE_ENDPOINT',
      defaultValue: defaultAppwriteEndpoint,
    );
    const project = String.fromEnvironment(
      'APPWRITE_PROJECT_ID',
      defaultValue: defaultAppwriteProjectId,
    );
    const learning = String.fromEnvironment(
      'LEARNING_API_URL',
      defaultValue: 'http://127.0.0.1:4101',
    );
    const progress = String.fromEnvironment(
      'PROGRESS_API_URL',
      defaultValue: 'http://127.0.0.1:4102',
    );
    const ai = String.fromEnvironment(
      'AI_API_URL',
      defaultValue: 'http://127.0.0.1:4103',
    );
    const mockAuth = String.fromEnvironment('USE_MOCK_AUTH');
    const allowInsecureLocalEndpoints = String.fromEnvironment(
      'ALLOW_INSECURE_LOCAL_ENDPOINTS',
      defaultValue: 'false',
    );
    return AppConfig(
      dataSource: parseDataSource(source),
      appwriteEndpoint: endpoint,
      appwriteProjectId: project,
      serviceUrls: const {
        ApiService.learning: learning,
        ApiService.progress: progress,
        ApiService.ai: ai,
      },
      mockAuthOverride: parseOptionalBool(mockAuth),
      allowInsecureLocalEndpoints: parseOptionalBool(
        allowInsecureLocalEndpoints,
      )!,
    );
  }

  static const defaultAppwriteEndpoint = 'https://sgp.cloud.appwrite.io/v1';
  static const defaultAppwriteProjectId = '6acc656d0025cc57bd81';

  /// Compile-time configuration of this build.
  static final AppConfig current = AppConfig.fromEnvironment();

  final DataSource dataSource;
  final String appwriteEndpoint;
  final String appwriteProjectId;
  final Map<ApiService, String> serviceUrls;

  /// Explicit `USE_MOCK_AUTH` define; null follows [dataSource].
  final bool? mockAuthOverride;

  /// Admits HTTP only for explicit loopback/private-network local profiles.
  ///
  /// This is a public build switch, not a transport-security bypass for
  /// release builds. Set with `ALLOW_INSECURE_LOCAL_ENDPOINTS=true` only when
  /// the service URLs already contain the emulator or device-reachable host.
  final bool allowInsecureLocalEndpoints;
  final Duration requestTimeout;

  bool get isApi => dataSource == DataSource.api;

  /// Mock auth unless the data source is the API or `USE_MOCK_AUTH=false`.
  bool get useMockAuth => mockAuthOverride ?? !isApi;

  Uri? baseUrl(ApiService service) {
    final raw = serviceUrls[service];
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    return uri;
  }

  static DataSource parseDataSource(String value) =>
      switch (value.trim().toLowerCase()) {
        'mock' => DataSource.mock,
        'api' => DataSource.api,
        _ => throw FormatException('Invalid DATA_SOURCE value.'),
      };

  /// Parses an optional public boolean build define without permissive truthy
  /// coercion. The exception deliberately omits the input value.
  static bool? parseOptionalBool(String value) =>
      switch (value.trim().toLowerCase()) {
        '' => null,
        'true' => true,
        'false' => false,
        _ => throw FormatException('Invalid boolean build define.'),
      };
}

/// Override in tests (or a flavor entrypoint) to switch the data layer.
final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.current);
