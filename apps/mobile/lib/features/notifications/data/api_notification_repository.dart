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
/// Saves carry `expectedRevision`; a 409 refetches and reapplies once.
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

  Future<wire.Preferences> _fetch() => api.getPreferences();

  Future<void> refresh() => cache.refresh(_fetch);

  @override
  List<NotificationCategory> get categories => notificationCatalog;

  @override
  final NotificationPrefs defaults = const NotificationPrefs();

  @override
  NotificationPrefs load() {
    cache.ensureLoaded(_fetch);
    final prefs = cache.value;
    if (prefs == null) return defaults;
    return NotificationPrefs(
      off: prefs.notificationsOff.toSet(),
      smartScheduling: prefs.smartScheduling,
      reminderTime: ReminderTime(
        prefs.reminderMinute ~/ 60,
        prefs.reminderMinute % 60,
      ),
    );
  }

  @override
  Future<void> save(NotificationPrefs prefs) async {
    final current = cache.value ?? await cache.refresh(_fetch);
    if (current == null) return;
    try {
      cache.put(await api.updatePreferences(_patch(prefs, current.revision)));
    } on ApiException catch (error) {
      if (!error.isConflict) rethrow;
      final latest = await api.getPreferences();
      cache.put(await api.updatePreferences(_patch(prefs, latest.revision)));
    }
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
