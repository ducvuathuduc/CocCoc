import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/notification_settings_controller.dart';
import '../domain/notification_models.dart';
import 'notification_widgets.dart';

/// Settings > Notifications hub (Customizing_reminders/06,
/// Turning_off_notifications/01): one row per category, each opening its
/// Push / Email detail screen.
class NotificationsHubScreen extends ConsumerWidget {
  const NotificationsHubScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notificationSettingsControllerProvider);
    final vm = ref.read(notificationSettingsControllerProvider.notifier);
    return NotifPage(
      title: 'Notifications',
      children: [
        const SizedBox(height: 8),
        NotifCard(
          rows: [
            for (final c in vm.categories)
              _HubRow(category: c, offCount: vm.offCount(c.id)),
          ],
        ),
      ],
    );
  }
}

class _HubRow extends StatelessWidget {
  const _HubRow({required this.category, required this.offCount});
  final NotificationCategory category;
  final int offCount;
  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('notif-category-${category.id}'),
    onTap: () => context.push('/settings/notifications/${category.id}'),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 14, 15),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: NotifColors.ink,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  category.subtitle,
                  style: const TextStyle(
                    fontSize: 16,
                    color: NotifColors.muted,
                    height: 1.15,
                    letterSpacing: 0.3,
                  ),
                ),
                if (offCount > 0) ...[
                  const SizedBox(height: 1),
                  Text(
                    '$offCount notification${offCount == 1 ? '' : 's'} turned off',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: NotifColors.blue,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.chevron_right_rounded,
            size: 30,
            color: NotifColors.chevron,
          ),
        ],
      ),
    ),
  );
}

/// One notification category's Push / Email toggles. For Reminders it also
/// carries Smart scheduling and the reminder time (Customizing_reminders/02-05).
class NotificationCategoryScreen extends ConsumerStatefulWidget {
  const NotificationCategoryScreen({required this.categoryId, super.key});
  final String categoryId;
  @override
  ConsumerState<NotificationCategoryScreen> createState() =>
      _NotificationCategoryState();
}

class _NotificationCategoryState
    extends ConsumerState<NotificationCategoryScreen> {
  bool picking = false;

  @override
  Widget build(BuildContext context) {
    final categoryId = widget.categoryId;
    final prefs = ref.watch(notificationSettingsControllerProvider);
    final vm = ref.read(notificationSettingsControllerProvider.notifier);
    if (!vm.hasCategory(categoryId)) return const NotificationsHubScreen();
    final cat = vm.category(categoryId);
    final reminders = categoryId == 'reminders';

    Widget itemRow(NotificationItem item) => _Row(
      key: ValueKey('notif-item-${item.id}'),
      label: item.label,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < item.channels.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            ChannelChip(
              key: ValueKey('chip-${item.id}-${item.channels[i].name}'),
              channel: item.channels[i],
              on: prefs.isOn(item.id, item.channels[i]),
              onTap: () => vm.toggle(item.id, item.channels[i]),
            ),
          ],
        ],
      ),
    );

    final cards = <Widget>[];
    for (var g = 0; g < cat.groups.length; g++) {
      final rows = [for (final i in cat.groups[g].items) itemRow(i)];
      if (reminders && g == 0) {
        final timeEnabled = !prefs.smartScheduling;
        rows.addAll([
          _Row(
            label: 'Smart scheduling',
            trailing: DuoSwitch(
              value: prefs.smartScheduling,
              onChanged: vm.setSmartScheduling,
            ),
          ),
          _Row(
            key: const ValueKey('reminder-time-row'),
            label: 'Reminder time',
            dimmed: !timeEnabled,
            onTap: timeEnabled
                ? () async {
                    final generation = vm.generation;
                    setState(() => picking = true);
                    final t = await showReminderTimePicker(
                      context,
                      prefs.reminderTime,
                    );
                    if (mounted) setState(() => picking = false);
                    if (t != null && mounted && generation == vm.generation) {
                      await vm.setReminderTime(t);
                    }
                  }
                : null,
            trailing: Text(
              prefs.reminderTime.label,
              style: notifRowStyle.copyWith(
                color: timeEnabled
                    ? NotifColors.blue
                    : NotifColors.disabledText,
              ),
            ),
          ),
        ]);
      }
      if (g > 0) cards.add(const SizedBox(height: 17));
      cards.add(NotifCard(rows: rows));
    }

    return NotifPage(
      title: cat.title,
      dimmed: picking,
      children: [
        for (final card in cards)
          Semantics(
            enabled: prefs.ready && !prefs.busy && prefs.error == null,
            child: AbsorbPointer(
              absorbing: !prefs.ready || prefs.busy || prefs.error != null,
              child: card,
            ),
          ),
        if (prefs.error != null) ...[
          Text(prefs.error!, textAlign: TextAlign.center),
          TextButton(onPressed: vm.retry, child: const Text('RETRY')),
        ],
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: vm.isDefault(categoryId)
              ? const SizedBox(height: 90)
              : Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Center(
                    child: TextButton(
                      key: const ValueKey('restore-default'),
                      onPressed: () => vm.restoreDefault(categoryId),
                      child: const Text(
                        'RESTORE DEFAULT',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: NotifColors.blue,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.trailing,
    this.onTap,
    this.dimmed = false,
    super.key,
  });
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool dimmed;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: SizedBox(
      height: 53,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 15, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: dimmed
                    ? notifRowStyle.copyWith(color: NotifColors.disabledText)
                    : notifRowStyle,
              ),
            ),
            trailing,
          ],
        ),
      ),
    ),
  );
}
