import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/cache/snapshot_cache.dart';
import '../../billing/application/billing_controller.dart';
import '../../reminders/application/reminder_coordinator.dart';
import '../../reminders/domain/reminder_models.dart';
import '../../reminders/services/notification_gateway.dart';

enum SuperReminderStatus { off, scheduled, denied, unsupported, unavailable }

class SuperReminderState {
  const SuperReminderState({
    this.enabled = false,
    this.status = SuperReminderStatus.off,
    this.at,
  });
  final bool enabled;
  final SuperReminderStatus status;
  final DateTime? at;
}

final superAccessReminderProvider =
    NotifierProvider<SuperAccessReminder, SuperReminderState>(
      SuperAccessReminder.new,
    );

class _ReminderWork {
  Future<void> tail = Future.value();
  Future<void> run(Future<void> Function() task) {
    final next = tail.then((_) => task());
    tail = next.catchError((Object _) {});
    return next;
  }
}

// Kept outside account-scoped state so old/new account native operations cannot
// interleave, including a delayed platform schedule followed by cancellation.
final _reminderWorkProvider = Provider<_ReminderWork>((ref) => _ReminderWork());

class SuperAccessReminder extends Notifier<SuperReminderState> {
  static const notificationId = 800;
  static const key = 'super.access.reminder.v1';
  Future<void> _queue = Future.value();
  int _revision = 0;

  @override
  SuperReminderState build() {
    final store = ref.watch(snapshotStoreProvider);
    final revision = ++_revision;
    ref.listen(billingControllerProvider, (_, _) => unawaited(sync()));
    unawaited(() async {
      try {
        final enabled = await store.read(key) == 'true';
        if (!ref.mounted || revision != _revision) return;
        state = SuperReminderState(enabled: enabled);
        await sync();
      } catch (_) {
        /* Unsupported storage keeps reminders off. */
      }
    }());
    return const SuperReminderState();
  }

  Future<void> select(bool enabled) async {
    ++_revision;
    state = SuperReminderState(enabled: enabled);
    final store = ref.read(snapshotStoreProvider);
    final save = _queue.then((_) => store.write(key, '$enabled'));
    _queue = save.catchError((Object _) {});
    try {
      await save;
    } catch (_) {
      if (ref.mounted) {
        state = SuperReminderState(
          enabled: enabled,
          status: SuperReminderStatus.unavailable,
        );
      }
      return;
    }
    if (ref.mounted) await sync(requestPermission: enabled);
  }

  /// Serial work prevents an old account's scheduling from winning over cancel.
  Future<void> sync({bool requestPermission = false}) {
    final revision = _revision;
    final notes = ref.read(notificationGatewayProvider);
    final work = ref.read(_reminderWorkProvider);
    final next = work.run(() async {
      if (!ref.mounted || revision != _revision) return;
      await notes.cancel([notificationId]);
      if (!ref.mounted || revision != _revision || !state.enabled) return;
      state = const SuperReminderState(enabled: true);
      if (!ref.read(reminderPlatformSupportedProvider)) {
        state = const SuperReminderState(
          enabled: true,
          status: SuperReminderStatus.unsupported,
        );
        return;
      }
      var granted = await notes.permission() == ReminderPermission.granted;
      if (!granted && requestPermission) {
        granted = await notes.requestPermission();
      }
      if (!ref.mounted || revision != _revision) return;
      if (!granted) {
        state = const SuperReminderState(
          enabled: true,
          status: SuperReminderStatus.denied,
        );
        return;
      }
      final billing = ref.read(billingControllerProvider);
      final snapshot = billing.snapshot;
      final now = ref.read(reminderClockProvider)();
      final expires = snapshot.activeUntil ?? snapshot.receipt?.expiresAt;
      if (!billing.loaded ||
          billing.hasError ||
          snapshot.selection == null ||
          expires == null ||
          !expires.isAfter(now)) {
        return;
      }
      final at = expires.subtract(const Duration(days: 2));
      if (!at.isAfter(now)) return;
      final zone = await ref.read(deviceZoneProvider).current();
      if (!ref.mounted || revision != _revision) return;
      await notes.schedule(
        PlannedReminder(
          id: notificationId,
          kind: ReminderKind.superAccess,
          at: tz.TZDateTime.from(at, zone),
          title: 'Your Super access ends soon',
          body:
              'Your access ends in 2 days. You can check your plan in the app.',
          link: ReminderLinks.superAccess,
        ),
      );
      if (!ref.mounted || revision != _revision) {
        await notes.cancel([notificationId]);
        return;
      }
      state = SuperReminderState(
        enabled: true,
        status: SuperReminderStatus.scheduled,
        at: at,
      );
    });
    return next.catchError((Object _) {
      if (ref.mounted && revision == _revision) {
        state = SuperReminderState(
          enabled: state.enabled,
          status: SuperReminderStatus.unavailable,
        );
      }
    });
  }
}
