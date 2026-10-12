import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../../core/ui/duo_form.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../../notifications/application/notification_settings_controller.dart';
import '../application/reminder_coordinator.dart';

/// Shows the reminder explainer once, after the first finished lesson, then
/// the OS permission dialog if the learner opts in (FR-NOTIFY-001). Returns
/// immediately when there is nothing to ask.
Future<void> maybeOfferReminders(BuildContext context, WidgetRef ref) async {
  final coordinator = ref.read(reminderCoordinatorProvider);
  if (!await coordinator.shouldOfferPermission()) return;
  if (!context.mounted) return;
  final accepted = await showDuoSheet<bool>(
    context,
    (context) => const ReminderPermissionSheet(),
  );
  if (accepted == true) {
    await coordinator.acceptPermissionOffer();
  } else {
    await coordinator.declinePermissionOffer();
  }
}

/// Explainer built only from existing components (ReferenceArt, ReferenceButton,
/// the shared Duo bottom sheet and palette colours).
class ReminderPermissionSheet extends ConsumerWidget {
  const ReminderPermissionSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = ref.watch(notificationSettingsControllerProvider).reminderTime;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: ReferenceArt(
            ReferenceArtRegions.writing,
            width: 145,
            height: 139,
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: const Text(
            'Make learning a habit',
            textAlign: TextAlign.center,
            style: headingStyle,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'We’ll send a friendly reminder at ${time.label} and warn you '
          'before your streak goes out. You can change this anytime in '
          'Settings.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, color: ReferenceColors.muted),
        ),
        const SizedBox(height: 28),
        ReferenceButton(
          label: 'TURN ON REMINDERS',
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: 12),
        ReferenceButton(
          label: 'NOT NOW',
          outlined: true,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
