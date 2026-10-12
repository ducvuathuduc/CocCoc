import 'dart:collection';
import 'dart:convert';

import 'package:cocenglish/core/api/client/access_token.dart';
import 'package:cocenglish/core/api/client/api_client.dart';
import 'package:cocenglish/core/api/client/api_operation.dart';
import 'package:cocenglish/core/api/client/api_transport.dart';
import 'package:cocenglish/core/api/client/idempotency.dart';

typedef FakeHandler = ApiHttpResponse Function(ApiHttpRequest request);

/// Scriptable in-memory HTTP transport. Routes are matched by
/// `METHOD /path` (no query); unmatched requests return 404 envelopes.
final class FakeApiTransport implements ApiTransport {
  final Map<String, Queue<FakeHandler>> _queued = {};
  final Map<String, FakeHandler> _routes = {};
  final List<ApiHttpRequest> requests = [];

  /// Fails every request with a transport error while true.
  bool offline = false;

  void on(String route, FakeHandler handler) => _routes[route] = handler;

  /// One-shot handler consumed before any [on] route.
  void once(String route, FakeHandler handler) =>
      (_queued[route] ??= Queue()).add(handler);

  void json(String route, Object? body, {int status = 200}) =>
      on(route, (_) => ApiHttpResponse(status, jsonEncode(body)));

  List<ApiHttpRequest> to(String route) => [
    for (final r in requests)
      if ('${r.method} ${r.uri.path}' == route) r,
  ];

  @override
  Future<ApiHttpResponse> send(
    ApiHttpRequest request, {
    Duration? timeout,
  }) async {
    requests.add(request);
    if (offline) throw const ApiTransportException('offline');
    final key = '${request.method} ${request.uri.path}';
    final queue = _queued[key];
    if (queue != null && queue.isNotEmpty) return queue.removeFirst()(request);
    final handler = _routes[key];
    if (handler != null) return handler(request);
    return ApiHttpResponse(404, jsonEncode(errorEnvelope('NOT_FOUND')));
  }
}

Map<String, Object?> errorEnvelope(
  String code, {
  bool retryable = false,
  String message = 'failure',
}) => {
  'error': {
    'code': code,
    'message': message,
    'requestId': 'req-1',
    'details': <String, Object?>{},
    'retryable': retryable,
  },
};

Map<String, Object?> bodyOf(ApiHttpRequest request) =>
    Map<String, Object?>.from(jsonDecode(request.body!) as Map);

/// Deterministic ids: `00000000-0000-4000-8000-00000000000N`.
final class SequenceIds implements IdGenerator {
  int _n = 0;

  @override
  String next() {
    _n++;
    return '00000000-0000-4000-8000-${_n.toString().padLeft(12, '0')}';
  }
}

ApiClient fakeClient(
  FakeApiTransport transport, {
  AccessTokenProvider? tokens,
  IdGenerator? ids,
}) => ApiClient(
  transport: transport,
  tokens: tokens ?? const StaticTokenProvider('jwt-test'),
  ids: ids ?? SequenceIds(),
  retryDelay: Duration.zero,
  baseUrls: {
    ApiService.learning: Uri.parse('https://learning.test'),
    ApiService.progress: Uri.parse('https://progress.test/base'),
    ApiService.ai: Uri.parse('https://ai.test'),
  },
);

const isoNow = '2026-10-12T08:00:00.000Z';
