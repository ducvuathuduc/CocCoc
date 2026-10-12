import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/reminder_models.dart';

enum ReminderPermission { granted, denied, notDetermined }

/// Native notification I/O. Views and ViewModels never touch the plugin.
abstract class NotificationGateway {
  Future<void> init({required void Function(String? payload) onTap});

  /// Payload of the notification that cold-started the app, if any.
  Future<String?> launchPayload();
  Future<ReminderPermission> permission();

  /// Shows the OS permission dialog (Android 13+ / iOS). True when granted.
  Future<bool> requestPermission();
  Future<void> schedule(PlannedReminder reminder);
  Future<void> show(PlannedReminder reminder);
  Future<void> cancel(Iterable<int> ids);
}

/// Used in tests and on platforms without local notifications.
class NoopNotificationGateway implements NotificationGateway {
  @override
  Future<void> init({required void Function(String? payload) onTap}) async {}
  @override
  Future<String?> launchPayload() async => null;
  @override
  Future<ReminderPermission> permission() async => ReminderPermission.denied;
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> schedule(PlannedReminder reminder) async {}
  @override
  Future<void> show(PlannedReminder reminder) async {}
  @override
  Future<void> cancel(Iterable<int> ids) async {}
}

/// Palette green (docs/design/qa/palette_from_refs.json, ReferenceColors.green).
const _accent = Color(0xFF5BCD05);

/// `flutter_local_notifications` implementation.
///
/// - Small icon `ic_stat_coc` is a white-on-transparent vector (status bar
///   icons must be monochrome); the accent tints it in the shade.
/// - Four channels (reminders, streak, league, friends) so learners can mute
///   one kind in system settings.
/// - Exact alarms only when the OS allows them (`SCHEDULE_EXACT_ALARM` is
///   revocable on Android 12+ and denied by default on 14+); otherwise the
///   reminder is scheduled inexact-while-idle, which may drift a few minutes.
class LocalNotificationGateway implements NotificationGateway {
  LocalNotificationGateway([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();
  final FlutterLocalNotificationsPlugin _plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> init({required void Function(String? payload) onTap}) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_coc'),
        // Never prompt at launch; the prompt comes after the first lesson.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) => onTap(r.payload),
    );
    final android = _android;
    if (android != null) {
      for (final c in ReminderChannel.values) {
        await android.createNotificationChannel(
          AndroidNotificationChannel(
            c.id,
            c.title,
            description: c.description,
            importance: c == ReminderChannel.streak
                ? Importance.high
                : Importance.defaultImportance,
          ),
        );
      }
    }
  }

  @override
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return details?.notificationResponse?.payload;
  }

  @override
  Future<ReminderPermission> permission() async {
    if (Platform.isAndroid) {
      final on = await _android?.areNotificationsEnabled();
      // Android cannot tell "never asked" from "denied"; the coordinator
      // remembers whether it already asked.
      return on == true
          ? ReminderPermission.granted
          : ReminderPermission.notDetermined;
    }
    if (Platform.isIOS) {
      final opts = await _ios?.checkPermissions();
      if (opts == null) return ReminderPermission.notDetermined;
      return opts.isEnabled
          ? ReminderPermission.granted
          : ReminderPermission.notDetermined;
    }
    return ReminderPermission.denied;
  }

  @override
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      return await _android?.requestNotificationsPermission() ?? false;
    }
    if (Platform.isIOS) {
      return await _ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  NotificationDetails _details(PlannedReminder r) => NotificationDetails(
    android: AndroidNotificationDetails(
      r.kind.channel.id,
      r.kind.channel.title,
      channelDescription: r.kind.channel.description,
      icon: 'ic_stat_coc',
      color: _accent,
      largeIcon: const DrawableResourceAndroidBitmap('ic_notification_mascot'),
      importance: r.kind.channel == ReminderChannel.streak
          ? Importance.high
          : Importance.defaultImportance,
      priority: r.kind.channel == ReminderChannel.streak
          ? Priority.high
          : Priority.defaultPriority,
      category: AndroidNotificationCategory.reminder,
      styleInformation: BigTextStyleInformation(r.body),
    ),
    iOS: DarwinNotificationDetails(
      threadIdentifier: r.kind.channel.id,
      interruptionLevel: r.kind.channel == ReminderChannel.streak
          ? InterruptionLevel.timeSensitive
          : InterruptionLevel.active,
    ),
  );

  Future<AndroidScheduleMode> _mode() async {
    if (!Platform.isAndroid) return AndroidScheduleMode.exactAllowWhileIdle;
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    return exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  @override
  Future<void> schedule(PlannedReminder r) async {
    final mode = await _mode();
    try {
      await _plugin.zonedSchedule(
        id: r.id,
        scheduledDate: r.at,
        notificationDetails: _details(r),
        androidScheduleMode: mode,
        title: r.title,
        body: r.body,
        payload: r.link,
      );
    } catch (error) {
      // The exact-alarm grant can be revoked between check and schedule.
      if (mode == AndroidScheduleMode.inexactAllowWhileIdle) rethrow;
      debugPrint('Exact reminder failed, falling back to inexact: $error');
      await _plugin.zonedSchedule(
        id: r.id,
        scheduledDate: r.at,
        notificationDetails: _details(r),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: r.title,
        body: r.body,
        payload: r.link,
      );
    }
  }

  @override
  Future<void> show(PlannedReminder r) => _plugin.show(
    id: r.id,
    title: r.title,
    body: r.body,
    notificationDetails: _details(r),
    payload: r.link,
  );

  @override
  Future<void> cancel(Iterable<int> ids) async {
    for (final id in ids) {
      await _plugin.cancel(id: id);
    }
  }
}
