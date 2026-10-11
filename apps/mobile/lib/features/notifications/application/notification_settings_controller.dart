import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_repository.dart';
import '../domain/notification_models.dart';

/// State for Settings > Notifications and its category screens.
class NotificationSettingsController extends Notifier<NotificationPrefs> {
  NotificationRepository get _repo => ref.read(notificationRepositoryProvider);

  @override
  NotificationPrefs build() => _repo.load();

  List<NotificationCategory> get categories => _repo.categories;

  NotificationCategory category(String id) =>
      _repo.categories.firstWhere((c) => c.id == id);

  bool hasCategory(String id) => _repo.categories.any((c) => c.id == id);

  void _set(NotificationPrefs next) {
    state = next;
    _repo.save(next);
  }

  void toggle(String itemId, NotificationChannel channel) {
    final k = NotificationPrefs.key(itemId, channel);
    final off = {...state.off};
    off.contains(k) ? off.remove(k) : off.add(k);
    _set(state.copyWith(off: off));
  }

  void setSmartScheduling(bool on) => _set(state.copyWith(smartScheduling: on));

  void setReminderTime(ReminderTime time) =>
      _set(state.copyWith(reminderTime: time));

  /// Restores every channel in [categoryId] (and reminder schedule for
  /// Reminders) to the repository defaults.
  void restoreDefault(String categoryId) {
    final cat = category(categoryId), d = _repo.defaults;
    final keys = {
      for (final i in cat.items)
        for (final c in i.channels) NotificationPrefs.key(i.id, c),
    };
    final off = {
      ...state.off.where((k) => !keys.contains(k)),
      ...d.off.where(keys.contains),
    };
    _set(
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
    NotifierProvider<NotificationSettingsController, NotificationPrefs>(
      NotificationSettingsController.new,
    );
