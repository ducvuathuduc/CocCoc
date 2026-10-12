import '../api_contracts.dart' as wire;

/// A failed API call, mapped from the OpenAPI `Error` envelope when present.
///
/// [code] is the server's stable error code (`UNAUTHENTICATED`,
/// `REVISION_CONFLICT`, ...) or a client code: `NETWORK`, `TIMEOUT`,
/// `NOT_CONFIGURED`, `UNAUTHENTICATED`, `BAD_RESPONSE`, `HTTP_<status>`.
final class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.requestId,
    this.retryable = false,
    this.details = const <String, Object?>{},
  });

  factory ApiException.fromEnvelope(int status, wire.Error envelope) =>
      ApiException(
        code: envelope.error.code,
        message: envelope.error.message,
        statusCode: status,
        requestId: envelope.error.requestId,
        retryable: envelope.error.retryable,
        details: envelope.error.details,
      );

  final String code;
  final String message;
  final int? statusCode;
  final String? requestId;
  final bool retryable;
  final Map<String, Object?> details;

  bool get isUnauthenticated => statusCode == 401 || code == 'UNAUTHENTICATED';
  bool get isConflict => statusCode == 409;
  bool get isNotFound => statusCode == 404;
  bool get isOffline => code == 'NETWORK' || code == 'TIMEOUT';

  /// Copy safe to show on screen: never echoes server internals.
  String get userMessage => switch (code) {
    'NETWORK' ||
    'TIMEOUT' => 'You’re offline. Check your connection and try again.',
    'UNAUTHENTICATED' => 'Your session ended. Please sign in again.',
    'NOT_CONFIGURED' => 'This feature isn’t connected yet.',
    _ when statusCode == 409 =>
      'That changed on another device. Please try again.',
    _ when statusCode == 429 => 'Too many requests. Please wait a moment.',
    _ => 'We couldn’t complete that request. Please try again.',
  };

  @override
  String toString() =>
      'ApiException($code, status: $statusCode, requestId: $requestId)';
}
