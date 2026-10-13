import 'dart:async';

import '../domain/connectivity_copy.dart';

abstract class ConnectivityRepository {
  Stream<bool> get online;
  bool get currentOnline;
  ConnectivityCopy get copy;
}

class MockConnectivityRepository implements ConnectivityRepository {
  MockConnectivityRepository({
    bool initialOnline = true,
    this.copy = const ConnectivityCopy(),
  }) : _current = initialOnline;
  final _changes = StreamController<bool>.broadcast();
  bool _current;
  @override
  final ConnectivityCopy copy;
  @override
  bool get currentOnline => _current;
  @override
  Stream<bool> get online => _changes.stream;

  void setOnline(bool value) {
    if (_current == value || _changes.isClosed) return;
    _current = value;
    _changes.add(value);
  }

  Future<void> dispose() => _changes.close();
}
