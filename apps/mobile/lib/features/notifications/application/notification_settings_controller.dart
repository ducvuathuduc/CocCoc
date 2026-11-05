import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/snapshot_cache.dart';
import '../../../core/config/app_config.dart';
import '../../../core/api/client/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../data/notification_repository.dart';
import '../domain/notification_models.dart';

/// State for Settings > Notifications and its category screens.
class NotificationSettingsState extends NotificationPrefs {
  NotificationSettingsState.from(
    NotificationPrefs prefs, {
    this.ready = true,
    this.loading = false,
    this.busy = false,
    this.error,
  }) : super(
         off: Set.unmodifiable(prefs.off),
         smartScheduling: prefs.smartScheduling,
         reminderTime: prefs.reminderTime,
       );
  final bool ready, loading, busy;
  final String? error;
}

class NotificationSettingsController
    extends Notifier<NotificationSettingsState> {
  NotificationRepository get _repo => ref.read(notificationRepositoryProvider);
  int _generation = 0;
  NotificationPrefs? _pending;
  static const requestError =
      'We couldn’t save your settings. Please try again.';
  int get generation => _generation;

  @override
  NotificationSettingsState build() {
    final generation = ++_generation;
    _pending = null;
    final repository = ref.watch(notificationRepositoryProvider);
    if (ref.watch(appConfigProvider).isApi) {
      final userId = ref.watch(
        authControllerProvider.select((s) => s.user?.id),
      );
      final unavailable = NotificationPrefs(
        off: {
          for (final category in notificationCatalog)
            for (final item in category.items)
              for (final channel in item.channels)
                NotificationPrefs.key(item.id, channel),
        },
      );
      if (userId == null) {
        return NotificationSettingsState.from(
          unavailable,
          ready: false,
          error: 'Please sign in again.',
        );
      }
      Future<void>(() => _load(repository, generation));
      return NotificationSettingsState.from(
        unavailable,
        ready: false,
        loading: true,
      );
    }
    watchSnapshot(ref, 'notifications');
    return NotificationSettingsState.from(repository.load());
  }

  bool _current(int generation) => ref.mounted && generation == _generation;

  Future<void> _load(NotificationRepository repository, int generation) async {
    if (!_current(generation)) return;
    try {
      final prefs = await repository.fetch();
      if (_current(generation)) state = NotificationSettingsState.from(prefs);
    } on Object {
      if (_current(generation)) {
        state = NotificationSettingsState.from(
          state,
          ready: state.ready,
          error: requestError,
        );
      }
    }
  }

  List<NotificationCategory> get categories => _repo.categories;

  NotificationCategory category(String id) =>
      _repo.categories.firstWhere((c) => c.id == id);

  bool hasCategory(String id) => _repo.categories.any((c) => c.id == id);

  Future<void> _set(NotificationPrefs next) async {
    if (!state.ready || state.busy || _pending != null) return;
    if (!ref.read(appConfigProvider).isApi) {
      state = NotificationSettingsState.from(next);
      await _repo.save(next);
      return;
    }
    _pending = next;
    await _savePending();
  }

  Future<void> _savePending() async {
    final next = _pending;
    if (next == null || state.busy) return;
    final generation = _generation;
    final repository = _repo;
    state = NotificationSettingsState.from(state, busy: true);
    try {
      await repository.save(next);
      if (!_current(generation)) return;
      _pending = null;
      state = NotificationSettingsState.from(repository.load());
    } on Object catch (error) {
      if (!_current(generation)) return;
      if (error is ApiException && error.isConflict) {
        _pending = null;
        try {
          final latest = await repository.fetch();
          if (!_current(generation)) return;
          state = NotificationSettingsState.from(latest, error: requestError);
          return;
        } on Object {
          /* Keep the last accepted value on refresh failure. */
        }
      }
      if (_current(generation)) {
        state = NotificationSettingsState.from(state, error: requestError);
      }
    }
  }

  Future<void> retry() async {
    if (state.busy || state.loading) return;
    if (_pending != null) {
      await _savePending();
    } else {
      state = NotificationSettingsState.from(
        state,
        ready: state.ready,
        loading: true,
      );
      await _load(_repo, _generation);
    }
  }

  Future<void> toggle(String itemId, NotificationChannel channel) async {
    final k = NotificationPrefs.key(itemId, channel);
    final off = {...state.off};
    off.contains(k) ? off.remove(k) : off.add(k);
    await _set(state.copyWith(off: off));
  }

  Future<void> setSmartScheduling(bool on) =>
      _set(state.copyWith(smartScheduling: on));

  Future<void> setReminderTime(ReminderTime time) =>
      _set(state.copyWith(reminderTime: time));

  /// Restores every channel in [categoryId] (and reminder schedule for
  /// Reminders) to the repository defaults.
  Future<void> restoreDefault(String categoryId) async {
    final cat = category(categoryId), d = _repo.defaults;
    final keys = {
      for (final i in cat.items)
        for (final c in i.channels) NotificationPrefs.key(i.id, c),
    };
    final off = {
      ...state.off.where((k) => !keys.contains(k)),
      ...d.off.where(keys.contains),
    };
    await _set(
      categoryId == 'reminders'
          ? state.copyWith(
              off: off,
              smartScheduling: d.smartScheduling,
              reminderTime: d.reminderTime,
            )
          : state.copyWith(off: off),
    );
  }

  /// Number of channels the user turned off inside [categoryId].
  int offCount(String categoryId) {
    var n = 0;
    for (final i in category(categoryId).items) {
      for (final c in i.channels) {
        if (!state.isOn(i.id, c)) n++;
      }
    }
    return n;
  }

  bool isDefault(String categoryId) {
    final d = _repo.defaults;
    for (final i in category(categoryId).items) {
      for (final c in i.channels) {
        if (state.isOn(i.id, c) != d.isOn(i.id, c)) return false;
      }
    }
    return categoryId != 'reminders' ||
        (state.smartScheduling == d.smartScheduling &&
            state.reminderTime == d.reminderTime);
  }
}

final notificationSettingsControllerProvider =
    NotifierProvider<NotificationSettingsController, NotificationSettingsState>(
      NotificationSettingsController.new,
    );
