import 'api_transport_stub.dart'
    if (dart.library.io) 'api_transport_io.dart'
    as platform;

/// Raw HTTP request handed to an [ApiTransport].
final class ApiHttpRequest {
  const ApiHttpRequest({
    required this.method,
    required this.uri,
    this.headers = const <String, String>{},
    this.body,
  });

  final String method;
  final Uri uri;
  final Map<String, String> headers;

  /// UTF-8 JSON body, or null.
  final String? body;
}

/// Raw HTTP response returned by an [ApiTransport].
final class ApiHttpResponse {
  const ApiHttpResponse(
    this.statusCode,
    this.body, {
    this.headers = const <String, String>{},
  });

  final int statusCode;
  final String body;
  final Map<String, String> headers;
}

/// Thrown by a transport when the request never produced an HTTP response.
final class ApiTransportException implements Exception {
  const ApiTransportException(this.message, {this.timeout = false});

  final String message;
  final bool timeout;

  @override
  String toString() => 'ApiTransportException($message)';
}

/// Sends HTTP requests. Tests inject a fake; the app uses [ApiTransport.platform].
abstract interface class ApiTransport {
  Future<ApiHttpResponse> send(ApiHttpRequest request, {Duration? timeout});

  /// Native (dart:io) transport; on web it reports API mode as unavailable.
  static ApiTransport platformDefault() => platform.createPlatformTransport();
}
