import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/application/auth_controller.dart';

/// Durable key/value storage for last-known server snapshots.
///
/// Repositories whose interfaces are synchronous (the screens read them during
/// build) keep the newest server payload here so a cold start in API mode
/// renders the previous session's data before the network answers.
abstract interface class SnapshotStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// In-memory store for tests and the anonymous fallback.
final class MemorySnapshotStore implements SnapshotStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

/// Shared-preferences store namespaced per signed-in user, so one account never
/// renders another account's cached quests, league or preferences.
final class PreferencesSnapshotStore implements SnapshotStore {
  PreferencesSnapshotStore({
    required this.namespace,
    SharedPreferencesAsync? preferences,
    // ignore: prefer_initializing_formals
  }) : _preferences = preferences;

  final String namespace;
  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _storage =>
      _preferences ??= SharedPreferencesAsync();

  String _key(String key) => 'snapshot.v1.$namespace.$key';

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.getString(_key(key));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.setString(_key(key), value);
    } catch (_) {
      // A failed cache write only costs the next cold start a network wait.
    }
  }
}

final snapshotStoreProvider = Provider<SnapshotStore>((ref) {
  final user = ref.watch(authControllerProvider.select((s) => s.user?.id));
  return PreferencesSnapshotStore(namespace: user ?? 'anonymous');
});

/// Revision counter per snapshot feature. API repositories bump their feature
/// after a refresh lands so controllers that read the synchronous repository
/// during `build` rebuild with the new snapshot. Mock repositories never bump,
/// so offline/mock behaviour (and every golden) is unchanged.
final snapshotRevisionProvider =
    NotifierProvider<SnapshotRevisionController, Map<String, int>>(
      SnapshotRevisionController.new,
    );

class SnapshotRevisionController extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const {};

  void bump(String feature) {
    state = {...state, feature: (state[feature] ?? 0) + 1};
  }
}

/// Watches one feature's snapshot revision (0 until its first refresh).
int watchSnapshot(Ref ref, String feature) =>
    ref.watch(snapshotRevisionProvider.select((m) => m[feature] ?? 0));

/// Store + change callback bound to one provider's lifetime.
final class SnapshotHost {
  const SnapshotHost({required this.store, required this.onChanged});

  /// Host whose changes go nowhere (unit tests).
  SnapshotHost.detached([SnapshotStore? store])
    : store = store ?? MemorySnapshotStore(),
      onChanged = _noop;

  factory SnapshotHost.of(Ref ref, String feature) => SnapshotHost(
    store: ref.watch(snapshotStoreProvider),
    onChanged: () {
      if (ref.mounted) {
        ref.read(snapshotRevisionProvider.notifier).bump(feature);
      }
    },
  );

  final SnapshotStore store;
  final void Function() onChanged;

  static void _noop() {}
}

/// Last-known value of one server read behind a synchronous interface.
///
/// - [value] is what the screen renders now: the newest fetch, else the
///   persisted snapshot, else `null` (the repository then shows its empty
///   state, never fixtures).
/// - [ensureLoaded] starts one background hydrate + fetch on first read.
/// - [refresh] is single-flight; a failure keeps the previous value and
///   records [error], so offline never blanks a screen that had data.
final class SnapshotCache<T> {
  SnapshotCache({
    required this.key,
    required this.host,
    required this.decode,
    required this.encode,
    this.maxAge,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Reads after this age start one background refresh (stale-while-revalidate).
  final Duration? maxAge;
  final DateTime Function() _clock;
  DateTime? _fetchedAt; // last attempt (success or failure)

  final String key;
  final SnapshotHost host;
  final T Function(Map<String, Object?> json) decode;
  final Map<String, Object?> Function(T value) encode;

  T? _value;
  Object? _error;
  bool _started = false;
  bool _hydrated = false;
  bool _fetched = false;
  Future<T?>? _inflight;
  bool _disposed = false;

  T? get value => _value;
  Object? get error => _error;

  /// True once a fetch succeeded in this process (not just hydrated).
  bool get isFresh => _fetched;

  void ensureLoaded(Future<T> Function() fetch) {
    if (_disposed) return;
    if (_started) {
      final age = maxAge, at = _fetchedAt;
      if (age == null || at == null || _inflight != null) return;
      if (_clock().difference(at) < age) return;
    }
    _started = true;
    unawaited(refresh(fetch));
  }

  Future<T?> refresh(Future<T> Function() fetch) {
    if (_disposed) return Future.value(null);
    _started = true;
    return _inflight ??= _run(fetch).whenComplete(() => _inflight = null);
  }

  Future<T?> _run(Future<T> Function() fetch) async {
    _fetchedAt = _clock();
    await _hydrate();
    if (_disposed) return null;
    try {
      final next = await fetch();
      if (_disposed) return null;
      _error = null;
      _fetched = true;
      _set(next);
    } catch (error) {
      if (_disposed) return null;
      _error = error;
    }
    return _value;
  }

  /// Replaces the snapshot with a server-authoritative mutation result.
  void put(T value) {
    if (_disposed) return;
    _fetched = true;
    _fetchedAt = _clock();
    _set(value);
  }

  Future<void> _hydrate() async {
    if (_hydrated) return;
    _hydrated = true;
    if (_value != null) return;
    final raw = await host.store.read(key);
    if (_disposed || raw == null || _value != null) return;
    try {
      final json = jsonDecode(raw);
      if (json is Map) {
        _value = decode(Map<String, Object?>.from(json));
        host.onChanged();
      }
    } catch (_) {
      // Stale schema or corrupt bytes: ignore and wait for the network.
    }
  }

  void _set(T next) {
    _value = next;
    host.onChanged();
    unawaited(host.store.write(key, jsonEncode(encode(next))));
  }

  /// Revokes a retired account/provider's pending work before it can publish.
  void dispose() {
    _disposed = true;
    _value = null;
    _error = null;
  }
}
