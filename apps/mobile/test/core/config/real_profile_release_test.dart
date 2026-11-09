import 'dart:convert';
import 'dart:io';

import 'package:cocenglish/core/api/client/api_operation.dart';
import 'package:cocenglish/core/config/app_config.dart';
import 'package:cocenglish/core/config/real_profile_validation.dart';
import 'package:flutter_test/flutter_test.dart';

// The rule: the profile a release APK is built from (`config/real.public.json`) is a complete,
// https-only, API-backed, real-auth profile that the app's own validator admits as a release
// profile. The API test lane (test_api/) compiles its own defines and never replaces this file.
final Directory _repoRoot = Directory.current.parent.parent;

AppConfig _configFrom(Map<String, Object?> profile) => AppConfig(
  dataSource: AppConfig.parseDataSource(profile['DATA_SOURCE']! as String),
  appwriteEndpoint: profile['APPWRITE_ENDPOINT']! as String,
  appwriteProjectId: profile['APPWRITE_PROJECT_ID']! as String,
  serviceUrls: {
    ApiService.learning: profile['LEARNING_API_URL']! as String,
    ApiService.progress: profile['PROGRESS_API_URL']! as String,
    ApiService.ai: profile['AI_API_URL']! as String,
  },
  mockAuthOverride: AppConfig.parseOptionalBool(
    profile['USE_MOCK_AUTH'] as String? ?? '',
  ),
  allowInsecureLocalEndpoints:
      AppConfig.parseOptionalBool(
        profile['ALLOW_INSECURE_LOCAL_ENDPOINTS'] as String? ?? '',
      ) ??
      false,
);

void main() {
  final profile = jsonDecode(
    File('${_repoRoot.path}/apps/mobile/config/real.public.json')
        .readAsStringSync(),
  ) as Map<String, Object?>;

  test('real.public.json is an API, real-auth profile', () {
    final config = _configFrom(profile);

    expect(config.isApi, isTrue);
    expect(config.useMockAuth, isFalse);
    expect(config.declaredDataSource, isTrue);
    expect(config.allowInsecureLocalEndpoints, isFalse);
    expect(config.buildProblem, isNull);
  });

  test('the app admits real.public.json as a release-native profile', () {
    expect(
      validateRealProfile(
        _configFrom(profile),
        target: RealProfileTarget.releaseNative,
      ),
      isEmpty,
    );
  });

  test('the release profile points at no local or emulator endpoint', () {
    for (final key in const [
      'APPWRITE_ENDPOINT',
      'LEARNING_API_URL',
      'PROGRESS_API_URL',
      'AI_API_URL',
    ]) {
      final uri = Uri.parse(profile[key]! as String);
      expect(uri.scheme, 'https', reason: key);
      expect(
        uri.host,
        isNot(matches(RegExp(r'^(localhost|127\.|10\.|192\.168\.)'))),
        reason: key,
      );
    }
  });

  test('the local profile is the only one that allows plain http', () {
    final local = jsonDecode(
      File('${_repoRoot.path}/apps/mobile/config/local.android.public.json')
          .readAsStringSync(),
    ) as Map<String, Object?>;

    expect(local['ALLOW_INSECURE_LOCAL_ENDPOINTS'], 'true');
    expect(
      validateRealProfile(
        _configFrom(local),
        target: RealProfileTarget.releaseNative,
      ),
      isNotEmpty,
      reason: 'a local profile must never pass the release gate',
    );
  });
}
