import 'api_transport.dart';

ApiTransport createPlatformTransport() => const _UnavailableTransport();

/// Web builds run the mock data source; API mode needs a native transport.
final class _UnavailableTransport implements ApiTransport {
  const _UnavailableTransport();

  @override
  Future<ApiHttpResponse> send(ApiHttpRequest request, {Duration? timeout}) =>
      Future.error(
        const ApiTransportException(
          'API mode is not available on this platform',
        ),
      );
}
