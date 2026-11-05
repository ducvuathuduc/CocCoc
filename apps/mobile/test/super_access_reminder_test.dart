import 'package:cocenglish/core/cache/snapshot_cache.dart';
import 'package:cocenglish/features/billing/application/billing_controller.dart';
import 'package:cocenglish/features/billing/domain/billing_models.dart';
import 'package:cocenglish/features/reminders/application/reminder_coordinator.dart';
import 'package:cocenglish/features/reminders/domain/reminder_models.dart';
import 'package:cocenglish/features/reminders/services/device_zone.dart';
import 'package:cocenglish/features/reminders/services/notification_gateway.dart';
import 'package:cocenglish/features/super_trial/application/super_access_reminder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

class _Billing extends BillingController {
  @override
  BillingState build() => BillingState(
    loaded: true,
    snapshot: BillingSnapshot(
      selection: 'individual',
      activeUntil: DateTime.utc(2026, 11, 1),
    ),
  );
  void free() => state = const BillingState(loaded: true);
}

class _Notes extends NoopNotificationGateway {
  bool granted = true;
  int requests = 0;
  final pending = <int, PlannedReminder>{};
  @override
  Future<ReminderPermission> permission() async =>
      granted ? ReminderPermission.granted : ReminderPermission.denied;
  @override
  Future<bool> requestPermission() async {
    requests++;
    return granted;
  }

  @override
  Future<void> cancel(Iterable<int> ids) async {
    for (final id in ids) {
      pending.remove(id);
    }
  }

  @override
  Future<void> schedule(PlannedReminder reminder) async {
    pending[reminder.id] = reminder;
  }
}

void main() {
  setUpAll(tzdata.initializeTimeZones);
  test('only opt-in confirmed access schedules; revoke cancels; restart restores date', () async {
    final store = MemorySnapshotStore();
    final notes = _Notes();
    ProviderContainer make() => ProviderContainer(
      overrides: [
        snapshotStoreProvider.overrideWithValue(store),
        notificationGatewayProvider.overrideWithValue(notes),
        reminderPlatformSupportedProvider.overrideWithValue(true),
        reminderClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 10, 24),
        ),
        deviceZoneProvider.overrideWithValue(FixedDeviceZone('Etc/UTC')),
        billingControllerProvider.overrideWith(_Billing.new),
      ],
    );
    var c = make();
    var vm = c.read(superAccessReminderProvider.notifier);
    await vm.sync();
    expect(notes.pending, isEmpty);
    await vm.select(true);
    expect(
      c.read(superAccessReminderProvider).status,
      SuperReminderStatus.scheduled,
      reason: 'enabled=${c.read(superAccessReminderProvider).enabled}',
    );
    expect(notes.pending[800]!.at.toUtc(), DateTime.utc(2026, 10, 30));
    expect(
      c.read(superAccessReminderProvider).status,
      SuperReminderStatus.scheduled,
    );
    c.dispose();
    c = make();
    vm = c.read(superAccessReminderProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await vm.sync();
    expect(notes.pending[800]!.at.toUtc(), DateTime.utc(2026, 10, 30));
    (c.read(billingControllerProvider.notifier) as _Billing).free();
    await vm.sync();
    expect(notes.pending, isEmpty);
    c.dispose();
  });
  test(
    'denied permission cannot claim scheduled; opting out cancels',
    () async {
      final notes = _Notes()..granted = false;
      final c = ProviderContainer(
        overrides: [
          snapshotStoreProvider.overrideWithValue(MemorySnapshotStore()),
          notificationGatewayProvider.overrideWithValue(notes),
          reminderPlatformSupportedProvider.overrideWithValue(true),
          reminderClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 10, 24),
          ),
          billingControllerProvider.overrideWith(_Billing.new),
        ],
      );
      final vm = c.read(superAccessReminderProvider.notifier);
      await vm.select(true);
      expect(
        c.read(superAccessReminderProvider).status,
        SuperReminderStatus.denied,
      );
      expect(notes.pending, isEmpty);
      expect(notes.requests, 1);
      await vm.select(false);
      expect(notes.pending, isEmpty);
      c.dispose();
    },
  );
}
