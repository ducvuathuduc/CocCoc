import 'dart:async';

import '../../../core/api/client/api_exception.dart';
import '../../../core/api/client/api_transport.dart';
import '../domain/connectivity_copy.dart';
import 'connectivity_repository.dart';

/// An observed API reachability signal, not a hardware network monitor.
/// A completed HTTP response proves reachability even when auth/business fails.
class ApiConnectivityRepository implements ConnectivityRepository {
  final _changes = StreamController<bool>.broadcast();
  bool _current = true;
  @override
  bool get currentOnline => _current;
  @override
  Stream<bool> get online => _changes.stream;
  @override
  ConnectivityCopy get copy => const ConnectivityCopy();

  void _set(bool value) {
    if (_current == value || _changes.isClosed) return;
    _current = value;
    _changes.add(value);
  }

  void reportFailure(ApiException error) {
    if (error.isOffline) _set(false);
  }

  ApiTransport observe(ApiTransport transport) =>
      _ObservedTransport(transport, this);
  Future<void> dispose() => _changes.close();
}

class _ObservedTransport implements ApiTransport {
  _ObservedTransport(this.delegate, this.repository);
  final ApiTransport delegate;
  final ApiConnectivityRepository repository;

  @override
  Future<ApiHttpResponse> send(
    ApiHttpRequest request, {
    Duration? timeout,
  }) async {
    try {
      final response = await delegate.send(request, timeout: timeout);
      repository._set(true);
      return response;
    } on ApiTransportException catch (error) {
      repository.reportFailure(
        ApiException(
          code: error.timeout ? 'TIMEOUT' : 'NETWORK',
          message: error.message,
        ),
      );
      rethrow;
    }
  }
}
