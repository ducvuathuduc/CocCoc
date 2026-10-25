import 'dart:convert';

import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/api_exception.dart';
import '../../../core/cache/snapshot_cache.dart';

import '../domain/notification_models.dart';
import 'notification_repository.dart';

/// [NotificationRepository] backed by `GET/PATCH /v1/me/preferences`.
///
/// `notificationsOff` holds `<item>.<channel>` keys exactly as the screen
/// toggles them; reminder time is `reminderMinute` (minutes after midnight).
/// Saves retain the exact command/revision across uncertain retries. Conflicts
/// require a refreshed state and a new user decision.
class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository(this.api, {SnapshotHost? host})
    : cache = SnapshotCache<wire.Preferences>(
        key: 'preferences',
        host: host ?? SnapshotHost.detached(),
        decode: wire.Preferences.fromJson,
        encode: (p) => p.toJson(),
      );

  final ApiEndpoints api;
  final SnapshotCache<wire.Preferences> cache;
  wire.PreferencesPatch? _pending;
  String? _pendingKey, _pendingValues;

  Future<wire.Preferences> _fetch() => api.getPreferences();

  Future<void> refresh() => cache.refresh(_fetch);

  @override
  Future<NotificationPrefs> fetch() async {
    final prefs = await cache.refresh(_fetch);
    if (prefs == null) {
      throw const ApiException(
        code: 'SERVICE_NOT_CONFIGURED',
        message: 'Preferences unavailable.',
      );
    }
    return _fromWire(prefs);
  }

  @override
  List<NotificationCategory> get categories => notificationCatalog;

  @override
  final NotificationPrefs defaults = const NotificationPrefs();

  @override
  NotificationPrefs load() {
    cache.ensureLoaded(_fetch);
    final prefs = cache.value;
    if (prefs == null) return defaults;
    return _fromWire(prefs);
  }

  static NotificationPrefs _fromWire(wire.Preferences prefs) =>
      NotificationPrefs(
        off: prefs.notificationsOff.toSet(),
        smartScheduling: prefs.smartScheduling,
        reminderTime: ReminderTime(
          prefs.reminderMinute ~/ 60,
          prefs.reminderMinute % 60,
        ),
      );

  @override
  Future<void> save(NotificationPrefs prefs) async {
    final values = jsonEncode(_patch(prefs, 0).toJson());
    if (_pendingValues != null && _pendingValues != values) {
      throw const ApiException(
        code: 'CONFLICT',
        message: 'Retry the pending change first.',
      );
    }
    final current = cache.value ?? await cache.refresh(_fetch);
    if (current == null) {
      throw const ApiException(
        code: 'SERVICE_NOT_CONFIGURED',
        message: 'Preferences unavailable.',
      );
    }
    _pending ??= _patch(prefs, current.revision);
    _pendingKey ??= api.client.ids.next();
    _pendingValues = values;
    try {
      cache.put(
        await api.updatePreferences(_pending!, idempotencyKey: _pendingKey),
      );
      _clearPending();
    } on ApiException catch (error) {
      if (error.isConflict) _clearPending();
      rethrow;
    }
  }

  void _clearPending() {
    _pending = null;
    _pendingKey = null;
    _pendingValues = null;
  }

  static wire.PreferencesPatch _patch(NotificationPrefs prefs, int revision) {
    final off = prefs.off.toList()..sort();
    return wire.PreferencesPatch(
      notificationsOff: off.take(32).toList(),
      smartScheduling: prefs.smartScheduling,
      reminderMinute: prefs.reminderTime.hour * 60 + prefs.reminderTime.minute,
      expectedRevision: revision,
    );
  }
}
