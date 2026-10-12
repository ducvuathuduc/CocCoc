import 'dart:async';
import 'dart:convert';

import '../api_contracts.dart' as wire;
import 'access_token.dart';
import 'api_exception.dart';
import 'api_operation.dart';
import 'api_transport.dart';
import 'idempotency.dart';

/// Typed HTTP client for the OpenAPI services.
///
/// * Authorization: `Bearer <Appwrite JWT>`; on 401 the token is re-minted and
///   the request retried once.
/// * Idempotent operations carry an `Idempotency-Key` (UUID v4). Callers pass
///   their own key to make a user command replay-safe across app restarts;
///   automatic retries always reuse the same key.
/// * Non-2xx responses are mapped from the `Error` envelope to [ApiException].
/// * Responses are validated against the OpenAPI schema by the generated DTO
///   `fromJson` passed as [decode].
final class ApiClient {
  ApiClient({
    required this.transport,
    required this.baseUrls,
    required this.tokens,
    IdGenerator? ids,
    this.timeout = const Duration(seconds: 15),
    this.maxRetries = 2,
    this.retryDelay = const Duration(milliseconds: 300),
  }) : ids = ids ?? UuidV4Generator();

  final ApiTransport transport;
  final Map<ApiService, Uri> baseUrls;
  final AccessTokenProvider tokens;
  final IdGenerator ids;
  final Duration timeout;
  final int maxRetries;
  final Duration retryDelay;

  /// Calls [operation] and decodes a 2xx JSON body with [decode].
  Future<T> call<T>(
    ApiOperation operation, {
    required T Function(Object? json) decode,
    Map<String, String> pathParams = const {},
    Map<String, Object?> query = const {},
    Object? body,
    String? idempotencyKey,
  }) async {
    final base = baseUrls[operation.service];
    if (base == null) {
      throw ApiException(
        code: 'NOT_CONFIGURED',
        message: 'No base URL for ${operation.service.name}',
      );
    }
    final key = operation.idempotent ? (idempotencyKey ?? ids.next()) : null;
    final uri = _resolve(base, operation.path(pathParams), query);
    final encoded = body == null ? null : jsonEncode(_toJson(body));
    var attempt = 0;
    var reauthenticated = false;
    while (true) {
      try {
        final response = await _send(operation, uri, encoded, key);
        final T result = _decode(response, decode);
        return result;
      } on ApiException catch (error) {
        if (error.isUnauthenticated && !reauthenticated) {
          reauthenticated = true;
          tokens.invalidate();
          continue;
        }
        final canRetry =
            error.retryable &&
            attempt < maxRetries &&
            (operation.method == 'GET' || key != null);
        if (!canRetry) rethrow;
        attempt += 1;
        await Future<void>.delayed(retryDelay * attempt);
      }
    }
  }

  Future<ApiHttpResponse> _send(
    ApiOperation operation,
    Uri uri,
    String? body,
    String? key,
  ) async {
    final token = await tokens.token();
    if (token == null || token.isEmpty) {
      throw const ApiException(
        code: 'UNAUTHENTICATED',
        message: 'No signed-in session',
        statusCode: 401,
      );
    }
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'X-Request-ID': ids.next(),
      if (body != null) 'Content-Type': 'application/json; charset=utf-8',
      'Idempotency-Key': ?key,
    };
    try {
      return await transport.send(
        ApiHttpRequest(
          method: operation.method,
          uri: uri,
          headers: headers,
          body: body,
        ),
        timeout: timeout,
      );
    } on ApiTransportException catch (error) {
      throw ApiException(
        code: error.timeout ? 'TIMEOUT' : 'NETWORK',
        message: error.message,
        retryable: true,
      );
    }
  }

  T _decode<T>(ApiHttpResponse response, T Function(Object? json) decode) {
    final status = response.statusCode;
    Object? json;
    try {
      json = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      json = null;
    }
    if (status >= 200 && status < 300) {
      try {
        return decode(json);
      } on wire.ContractViolation catch (violation) {
        throw ApiException(
          code: 'BAD_RESPONSE',
          message: violation.toString(),
          statusCode: status,
          requestId: response.headers['x-request-id'],
        );
      }
    }
    try {
      throw ApiException.fromEnvelope(status, wire.Error.fromJson(json));
    } on wire.ContractViolation {
      throw ApiException(
        code: 'HTTP_$status',
        message: 'HTTP $status',
        statusCode: status,
        requestId: response.headers['x-request-id'],
        retryable: status == 429 || status == 503 || status == 504,
      );
    } on TypeError {
      throw ApiException(
        code: 'HTTP_$status',
        message: 'HTTP $status',
        statusCode: status,
        retryable: status == 503 || status == 504,
      );
    }
  }

  static Uri _resolve(Uri base, String path, Map<String, Object?> query) {
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final params = <String, String>{
      for (final entry in query.entries)
        if (entry.value != null) entry.key: '${entry.value}',
    };
    return base.replace(
      path: '$basePath$path',
      queryParameters: params.isEmpty ? null : params,
    );
  }

  static Object? _toJson(Object body) {
    if (body is Map || body is List || body is String || body is num) {
      return body;
    }
    // Generated DTOs all expose toJson().
    return (body as dynamic).toJson();
  }
}
