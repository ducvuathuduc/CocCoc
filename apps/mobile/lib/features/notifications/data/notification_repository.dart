import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/notification_models.dart';

/// Settings > Notifications boundary: the catalog of notification types and
/// the user's saved preferences. Override [notificationRepositoryProvider]
/// with an API-backed implementation.
abstract class NotificationRepository {
  List<NotificationCategory> get categories;
  NotificationPrefs get defaults;
  NotificationPrefs load();
  Future<void> save(NotificationPrefs prefs);
}

const _p = NotificationChannel.push, _e = NotificationChannel.email;

class MockNotificationRepository implements NotificationRepository {
  MockNotificationRepository({NotificationPrefs? initial})
    : _saved =
          initial ??
          // Matches the reference account: Early Bird / Night Owl push off.
          const NotificationPrefs(off: {'early_bird.push', 'night_owl.push'});

  NotificationPrefs _saved;
  int saves = 0;

  @override
  final List<NotificationCategory> categories = const [
    NotificationCategory(
      id: 'reminders',
      title: 'Reminders',
      subtitle: 'Daily practice and streak reminders',
      groups: [
        NotificationGroup([
          NotificationItem(
            id: 'practice',
            label: 'Practice reminder',
            channels: [_p, _e],
          ),
        ]),
        NotificationGroup([
          NotificationItem(
            id: 'streak_freeze',
            label: 'Streak Freeze Used',
            channels: [_p],
          ),
          NotificationItem(
            id: 'streak_saver',
            label: 'Streak Saver',
            channels: [_p],
          ),
          NotificationItem(
            id: 'early_bird',
            label: 'Early Bird Reward',
            channels: [_p],
          ),
          NotificationItem(
            id: 'night_owl',
            label: 'Night Owl Reward',
            channels: [_p],
          ),
          NotificationItem(
            id: 'weekly_progress',
            label: 'Weekly progress',
            channels: [_e],
          ),
        ]),
      ],
    ),
    NotificationCategory(
      id: 'friends',
      title: 'Friends',
      subtitle: 'Updates on new followers and your friends’ achievements',
      groups: [
        NotificationGroup([
          NotificationItem(
            id: 'new_follower',
            label: 'New follower',
            channels: [_p, _e],
          ),
          NotificationItem(
            id: 'friend_achievements',
            label: 'Friend achievements',
            channels: [_p, _e],
          ),
          NotificationItem(
            id: 'friends_quest',
            label: 'Friends Quest',
            channels: [_p],
          ),
        ]),
      ],
    ),
    NotificationCategory(
      id: 'leaderboards',
      title: 'Leaderboards',
      subtitle: 'Progress updates in your league',
      groups: [
        NotificationGroup([
          NotificationItem(
            id: 'league_overtaken',
            label: 'Passed in your league',
            channels: [_p, _e],
          ),
          NotificationItem(
            id: 'league_results',
            label: 'League results',
            channels: [_p, _e],
          ),
        ]),
      ],
    ),
    NotificationCategory(
      id: 'announcements',
      title: 'Announcements',
      subtitle: 'Updates about new features, promotions, and events',
      groups: [
        NotificationGroup([
          NotificationItem(
            id: 'new_features',
            label: 'New features',
            channels: [_p, _e],
          ),
          NotificationItem(
            id: 'promotions',
            label: 'Promotions',
            channels: [_p, _e],
          ),
          NotificationItem(id: 'events', label: 'Events', channels: [_p, _e]),
        ]),
      ],
    ),
    NotificationCategory(
      id: 'nudges',
      title: 'Friend Nudges',
      subtitle: 'Reminders from friends',
      groups: [
        NotificationGroup([
          NotificationItem(
            id: 'friend_nudge',
            label: 'Friend nudges',
            channels: [_p],
          ),
        ]),
      ],
    ),
  ];

  @override
  final NotificationPrefs defaults = const NotificationPrefs();

  @override
  NotificationPrefs load() => _saved;

  @override
  Future<void> save(NotificationPrefs prefs) async {
    _saved = prefs;
    saves++;
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => MockNotificationRepository(),
);
