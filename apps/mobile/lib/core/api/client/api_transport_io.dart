import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'api_transport.dart';

ApiTransport createPlatformTransport() => IoApiTransport();

/// dart:io transport (Android/iOS/desktop/tests).
final class IoApiTransport implements ApiTransport {
  IoApiTransport([HttpClient? client]) : _client = client ?? HttpClient();

  final HttpClient _client;

  @override
  Future<ApiHttpResponse> send(
    ApiHttpRequest request, {
    Duration? timeout,
  }) async {
    final limit = timeout ?? const Duration(seconds: 15);
    try {
      final req = await _client
          .openUrl(request.method, request.uri)
          .timeout(limit);
      request.headers.forEach(req.headers.set);
      final body = request.body;
      if (body != null) req.add(utf8.encode(body));
      final res = await req.close().timeout(limit);
      final text = await res.transform(utf8.decoder).join().timeout(limit);
      final headers = <String, String>{};
      res.headers.forEach((name, values) => headers[name] = values.join(','));
      return ApiHttpResponse(res.statusCode, text, headers: headers);
    } on TimeoutException {
      throw const ApiTransportException('Request timed out', timeout: true);
    } on SocketException catch (error) {
      throw ApiTransportException(error.message);
    } on HttpException catch (error) {
      throw ApiTransportException(error.message);
    } on HandshakeException catch (error) {
      throw ApiTransportException(error.message);
    }
  }
}
