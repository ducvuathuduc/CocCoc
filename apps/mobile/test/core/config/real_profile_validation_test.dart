import 'package:cocenglish/core/api/client/api_operation.dart';
import 'package:cocenglish/core/config/app_config.dart';
import 'package:cocenglish/core/config/real_profile_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const httpsServices = <ApiService, String>{
    ApiService.learning: 'https://learning.example.test',
    ApiService.progress: 'https://progress.example.test',
    ApiService.ai: 'https://ai.example.test',
  };

  AppConfig config({
    Map<ApiService, String> serviceUrls = httpsServices,
    String appwriteEndpoint = 'https://appwrite.example.test/v1',
    String appwriteProjectId = 'project-test',
    bool? mockAuthOverride = false,
    bool allowInsecureLocalEndpoints = false,
  }) => AppConfig(
    dataSource: DataSource.api,
    appwriteEndpoint: appwriteEndpoint,
    appwriteProjectId: appwriteProjectId,
    serviceUrls: serviceUrls,
    mockAuthOverride: mockAuthOverride,
    allowInsecureLocalEndpoints: allowInsecureLocalEndpoints,
  );

  test('real profile rejects mixed API data and mock identity', () {
    final issues = validateRealProfile(
      config(mockAuthOverride: true),
      target: RealProfileTarget.releaseNative,
    );

    expect(issues, contains('MOCK_AUTH_FOR_REAL_PROFILE'));
  });

  test('real profile requires Appwrite identity configuration', () {
    expect(
      validateRealProfile(
        config(appwriteEndpoint: '', appwriteProjectId: ' '),
        target: RealProfileTarget.releaseNative,
      ),
      containsAll(<String>[
        'APPWRITE_ENDPOINT_MISSING',
        'APPWRITE_PROJECT_ID_MISSING',
      ]),
    );
  });

  test('real profile reports each missing owner service URL', () {
    final issues = validateRealProfile(
      config(serviceUrls: const <ApiService, String>{}),
      target: RealProfileTarget.releaseNative,
    );

    expect(
      issues,
      containsAll(<String>[
        'LEARNING_API_URL_MISSING',
        'PROGRESS_API_URL_MISSING',
        'AI_API_URL_MISSING',
      ]),
    );
  });

  test('release profile requires HTTPS for every endpoint', () {
    final issues = validateRealProfile(
      config(
        appwriteEndpoint: 'http://127.0.0.1/v1',
        serviceUrls: const <ApiService, String>{
          ApiService.learning: 'http://127.0.0.1:4101',
          ApiService.progress: 'http://127.0.0.1:4102',
          ApiService.ai: 'http://127.0.0.1:4103',
        },
        allowInsecureLocalEndpoints: true,
      ),
      target: RealProfileTarget.releaseNative,
    );

    expect(issues, contains('APPWRITE_ENDPOINT_HTTPS_REQUIRED'));
    expect(issues, contains('LEARNING_API_URL_HTTPS_REQUIRED'));
    expect(issues, contains('PROGRESS_API_URL_HTTPS_REQUIRED'));
    expect(issues, contains('AI_API_URL_HTTPS_REQUIRED'));
  });

  test('URLs reject credentials, queries, and fragments', () {
    final issues = validateRealProfile(
      config(
        appwriteEndpoint: 'https://user:secret@appwrite.test/v1',
        serviceUrls: const <ApiService, String>{
          ApiService.learning: 'https://learning.test?token=secret',
          ApiService.progress: 'https://progress.test/#fragment',
          ApiService.ai: 'ftp://ai.test',
        },
      ),
      target: RealProfileTarget.releaseNative,
    );

    expect(issues, contains('APPWRITE_ENDPOINT_USER_INFO_FORBIDDEN'));
    expect(issues, contains('LEARNING_API_URL_QUERY_FORBIDDEN'));
    expect(issues, contains('PROGRESS_API_URL_FRAGMENT_FORBIDDEN'));
    expect(issues, contains('AI_API_URL_SCHEME_INVALID'));
  });

  test('local HTTP endpoints require an explicit local mapping switch', () {
    final local = config(
      appwriteEndpoint: 'http://10.0.2.2:8080/v1',
      serviceUrls: const <ApiService, String>{
        ApiService.learning: 'http://10.0.2.2:4101',
        ApiService.progress: 'http://10.0.2.2:4102',
        ApiService.ai: 'http://10.0.2.2:4103',
      },
    );

    final issues = validateRealProfile(
      local,
      target: RealProfileTarget.localNative,
    );
    expect(issues, contains('LOCAL_HTTP_ENDPOINTS_NOT_EXPLICIT'));

    final admitted = validateRealProfile(
      config(
        appwriteEndpoint: local.appwriteEndpoint,
        serviceUrls: local.serviceUrls,
        allowInsecureLocalEndpoints: true,
      ),
      target: RealProfileTarget.localNative,
    );
    expect(admitted, isEmpty);
  });

  test('explicit local switch cannot admit a public insecure host', () {
    final issues = validateRealProfile(
      config(
        serviceUrls: const <ApiService, String>{
          ApiService.learning: 'http://api.example.test',
          ApiService.progress: 'https://progress.example.test',
          ApiService.ai: 'https://ai.example.test',
        },
        allowInsecureLocalEndpoints: true,
      ),
      target: RealProfileTarget.localNative,
    );

    expect(issues, contains('LEARNING_API_URL_LOCAL_HOST_REQUIRED'));
  });

  test('valid HTTPS release profile is admitted', () {
    expect(
      validateRealProfile(config(), target: RealProfileTarget.releaseNative),
      isEmpty,
    );
  });

  test('environment values use strict non-secret parsing', () {
    expect(
      () => AppConfig.parseDataSource('unexpected'),
      throwsFormatException,
    );
    expect(AppConfig.parseOptionalBool(''), isNull);
    expect(AppConfig.parseOptionalBool('FALSE'), isFalse);
    expect(() => AppConfig.parseOptionalBool('yes'), throwsFormatException);
  });

  test('the default preview remains a mock profile without validation', () {
    const preview = AppConfig();
    expect(preview.isApi, isFalse);
    expect(preview.useMockAuth, isTrue);
  });
}
