/// Delivery channel a notification can be sent on.
enum NotificationChannel { push, email }

/// One notification type (e.g. "Streak Saver") and the channels it supports.
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.label,
    required this.channels,
  });
  final String id, label;
  final List<NotificationChannel> channels;
}

/// A group of notification items rendered as one rounded card.
class NotificationGroup {
  const NotificationGroup(this.items);
  final List<NotificationItem> items;
}

/// A row on Settings > Notifications, opening its own detail screen.
class NotificationCategory {
  const NotificationCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.groups,
  });
  final String id, title, subtitle;
  final List<NotificationGroup> groups;

  Iterable<NotificationItem> get items => groups.expand((g) => g.items);
}

/// Wall-clock time for the practice reminder (no date, 24h internally).
class ReminderTime {
  const ReminderTime(this.hour, this.minute);
  final int hour, minute;

  /// "5:00 PM" as Duolingo shows it.
  String get label {
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour < 12 ? 'AM' : 'PM';
    return '$h12:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderTime && other.hour == hour && other.minute == minute;
  @override
  int get hashCode => Object.hash(hour, minute);
}

/// Persisted notification preferences. Keys of [enabled] are
/// `"<itemId>.<channel>"`; a missing key means the channel is on.
class NotificationPrefs {
  const NotificationPrefs({
    this.off = const {},
    this.smartScheduling = false,
    this.reminderTime = const ReminderTime(17, 0),
  });
  final Set<String> off;
  final bool smartScheduling;
  final ReminderTime reminderTime;

  static String key(String itemId, NotificationChannel c) =>
      '$itemId.${c.name}';

  bool isOn(String itemId, NotificationChannel c) =>
      !off.contains(key(itemId, c));

  NotificationPrefs copyWith({
    Set<String>? off,
    bool? smartScheduling,
    ReminderTime? reminderTime,
  }) => NotificationPrefs(
    off: off ?? this.off,
    smartScheduling: smartScheduling ?? this.smartScheduling,
    reminderTime: reminderTime ?? this.reminderTime,
  );
}
