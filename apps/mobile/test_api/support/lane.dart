import 'dart:convert';
import 'dart:io';

import 'package:cocenglish/core/api/client/access_token.dart';
import 'package:cocenglish/core/api/client/api_client.dart';
import 'package:cocenglish/core/api/client/api_operation.dart';
import 'package:cocenglish/core/api/client/api_transport.dart';

/// Where the lane backend (tools/scripts/api-lane-backend.mjs) wrote its address, tokens and
/// fixture publications. Set by tools/scripts/mobile-api-lane.mjs; a lane test that is run any
/// other way fails here instead of quietly testing nothing.
const _stateFile = String.fromEnvironment('API_LANE_STATE');

/// The Learning backend the lane started, as the tests need to see it.
final class LaneState {
  LaneState._(
    this.url,
    this.learnerToken,
    this.maintainerToken,
    this._fixtures,
  );

  final String url;

  /// `Bearer user-<id>`: the test router's stand-in for an Appwrite JWT.
  final String learnerToken;

  /// May publish, roll back and unpublish.
  final String maintainerToken;
  final Map<String, Map<String, String>> _fixtures;

  Uri get uri => Uri.parse(url);

  /// Publish body (without `expectedPublishedVersion`) of a fixture course version.
  Map<String, String> publication(String version) {
    final body = _fixtures[version];
    if (body == null) throw StateError('No fixture publication $version');
    return body;
  }

  /// Turns the backend's injected faults on or off (error-path tests).
  Future<void> setFaults({bool? missingMedia, bool? storageOutage}) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri.replace(path: '/__lane/faults'));
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'missingMedia': ?missingMedia,
          'storageOutage': ?storageOutage,
        }),
      );
      final response = await request.close();
      await response.drain<void>();
      if (response.statusCode != 200) {
        throw StateError('Could not set lane faults: ${response.statusCode}');
      }
    } finally {
      client.close(force: true);
    }
  }
}

LaneState laneState() {
  if (_stateFile.isEmpty) {
    throw StateError(
      'API_LANE_STATE is not set. Run this lane with '
      '`node tools/scripts/mobile-api-lane.mjs`.',
    );
  }
  final json =
      jsonDecode(File(_stateFile).readAsStringSync()) as Map<String, Object?>;
  final courses = json['fixtures']! as Map<String, Object?>;
  final fixtures = <String, Map<String, String>>{};
  for (final entry in (courses['vi_en_mini']! as Map).entries) {
    fixtures[entry.key as String] = Map<String, String>.from(
      entry.value as Map,
    );
  }
  return LaneState._(
    json['url']! as String,
    json['learnerToken']! as String,
    json['maintainerToken']! as String,
    fixtures,
  );
}

/// The app's own [ApiClient] and dart:io transport, pointed at the lane backend.
ApiClient laneClient(
  LaneState lane, {
  AccessTokenProvider? tokens,
  Uri? baseUrl,
  int maxRetries = 0,
  Duration timeout = const Duration(seconds: 30),
  void Function()? onUnauthenticated,
}) => ApiClient(
  transport: ApiTransport.platformDefault(),
  baseUrls: {ApiService.learning: baseUrl ?? lane.uri},
  tokens: tokens ?? StaticTokenProvider(lane.learnerToken),
  timeout: timeout,
  maxRetries: maxRetries,
  retryDelay: const Duration(milliseconds: 20),
  onUnauthenticated: onUnauthenticated,
);

Map<String, Object?> _asMap(Object? json) =>
    Map<String, Object?>.from(json! as Map);

const _publish = ApiOperation(
  'publishContent',
  'POST',
  '/v1/admin/content-versions',
  ApiService.learning,
  idempotent: true,
);
const _unpublish = ApiOperation(
  'unpublishCourse',
  'POST',
  '/v1/admin/courses/{courseId}/unpublish',
  ApiService.learning,
  idempotent: true,
);
const _rollback = ApiOperation(
  'rollbackCourse',
  'POST',
  '/v1/admin/courses/{courseId}/rollback',
  ApiService.learning,
  idempotent: true,
);
const _history = ApiOperation(
  'listContentVersions',
  'GET',
  '/v1/admin/courses/{courseId}/content-versions',
  ApiService.learning,
  idempotent: false,
);

/// Maintainer routes, called through the same client and error mapping the app uses. They are not
/// part of the app's generated endpoints (learners never call them), so they are declared here.
final class LaneAdmin {
  const LaneAdmin(this.client);

  final ApiClient client;

  Future<Map<String, Object?>> publish(
    Map<String, String> publication, {
    required String? expected,
  }) => client.call(
    _publish,
    decode: _asMap,
    body: {...publication, 'expectedPublishedVersion': expected},
  );

  Future<Map<String, Object?>> unpublish(
    String courseId, {
    required String? expected,
  }) => client.call(
    _unpublish,
    decode: _asMap,
    pathParams: {'courseId': courseId},
    body: {'expectedPublishedVersion': expected},
  );

  Future<Map<String, Object?>> rollback(
    String courseId, {
    required String target,
    required String? expected,
  }) => client.call(
    _rollback,
    decode: _asMap,
    pathParams: {'courseId': courseId},
    body: {'targetVersionId': target, 'expectedPublishedVersion': expected},
  );

  /// `versionId -> LIVE | SUPERSEDED | RETIRED`.
  Future<Map<String, String>> statuses(String courseId) async {
    final body = await client.call(
      _history,
      decode: _asMap,
      pathParams: {'courseId': courseId},
    );
    return {
      for (final item in body['items']! as List)
        (item as Map)['versionId'] as String: item['status'] as String,
    };
  }
}
