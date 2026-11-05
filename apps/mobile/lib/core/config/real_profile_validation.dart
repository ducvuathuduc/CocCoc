import '../api/client/api_operation.dart';
import 'app_config.dart';

/// Native runtime profiles admitted by the real-data composition boundary.
enum RealProfileTarget { localNative, releaseNative }

/// Returns stable, non-secret issue codes for an API-backed native profile.
///
/// Callers must refuse private session preparation when this list is nonempty.
/// Mock preview builds do not pass through this gate.
List<String> validateRealProfile(
  AppConfig config, {
  required RealProfileTarget target,
}) {
  final issues = <String>[];
  if (!config.isApi) issues.add('REAL_PROFILE_REQUIRES_API_DATA_SOURCE');
  if (config.useMockAuth) issues.add('MOCK_AUTH_FOR_REAL_PROFILE');

  final project = config.appwriteProjectId.trim();
  if (project.isEmpty) issues.add('APPWRITE_PROJECT_ID_MISSING');

  final endpoints = <({String code, String value})>[
    (code: 'APPWRITE_ENDPOINT', value: config.appwriteEndpoint),
    for (final service in ApiService.values)
      (
        code: '${service.name.toUpperCase()}_API_URL',
        value: config.serviceUrls[service] ?? '',
      ),
  ];
  var containsHttp = false;
  for (final endpoint in endpoints) {
    final raw = endpoint.value.trim();
    if (raw.isEmpty) {
      issues.add('${endpoint.code}_MISSING');
      continue;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      issues.add('${endpoint.code}_INVALID');
      continue;
    }
    if (uri.userInfo.isNotEmpty) {
      issues.add('${endpoint.code}_USER_INFO_FORBIDDEN');
    }
    if (uri.hasQuery) issues.add('${endpoint.code}_QUERY_FORBIDDEN');
    if (uri.hasFragment) issues.add('${endpoint.code}_FRAGMENT_FORBIDDEN');

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') {
      issues.add('${endpoint.code}_SCHEME_INVALID');
      continue;
    }
    if (target == RealProfileTarget.releaseNative && scheme != 'https') {
      issues.add('${endpoint.code}_HTTPS_REQUIRED');
      continue;
    }
    if (target == RealProfileTarget.localNative && scheme == 'http') {
      containsHttp = true;
      if (!_isLocalHost(uri.host)) {
        issues.add('${endpoint.code}_LOCAL_HOST_REQUIRED');
      }
    }
  }
  if (target == RealProfileTarget.localNative &&
      containsHttp &&
      !config.allowInsecureLocalEndpoints) {
    issues.add('LOCAL_HTTP_ENDPOINTS_NOT_EXPLICIT');
  }
  return List<String>.unmodifiable(issues);
}

bool _isLocalHost(String value) {
  final host = value.toLowerCase();
  if (host == 'localhost' || host == '::1') return true;
  if (host.contains(':') &&
      (host.startsWith('fc') ||
          host.startsWith('fd') ||
          host.startsWith('fe80:'))) {
    return true;
  }
  final parts = host.split('.');
  if (parts.length != 4) return false;
  final octets = parts.map(int.tryParse).toList(growable: false);
  if (octets.any((part) => part == null || part < 0 || part > 255)) {
    return false;
  }
  final first = octets[0]!;
  final second = octets[1]!;
  return first == 10 ||
      first == 127 ||
      (first == 169 && second == 254) ||
      (first == 172 && second >= 16 && second <= 31) ||
      (first == 192 && second == 168);
}
