import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/reference_theme.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/appearance_controller.dart';
import '../domain/appearance_preference.dart';

class DarkModeSetting extends ConsumerWidget {
  const DarkModeSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceControllerProvider);
    return ListTile(
      key: const ValueKey('dark-mode-setting'),
      contentPadding: EdgeInsets.zero,
      title: const Text(
        'Dark mode',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      trailing: Text(
        appearance.preference.label,
        style: TextStyle(fontSize: 16, color: context.referencePalette.muted),
      ),
      onTap: () => showDarkModeDialog(context),
    );
  }
}

Future<void> showDarkModeDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _DarkModeDialog());

class _DarkModeDialog extends ConsumerWidget {
  const _DarkModeDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(
      appearanceControllerProvider.select((state) => state.preference),
    );
    return AlertDialog(
      title: Text(
        'Dark mode',
        style: headingStyle.copyWith(color: context.referencePalette.ink),
      ),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      content: RadioGroup<AppearancePreference>(
        groupValue: selected,
        onChanged: (value) async {
          if (value == null) return;
          final saved = await ref
              .read(appearanceControllerProvider.notifier)
              .select(value);
          if (context.mounted && saved) Navigator.pop(context);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final preference in AppearancePreference.values)
              RadioListTile<AppearancePreference>(
                key: ValueKey('dark-mode-${preference.storageValue}'),
                title: Text(preference.label),
                value: preference,
                activeColor: LearningColors.green,
              ),
          ],
        ),
      ),
      actions: [
        if (ref.watch(appearanceControllerProvider).saveFailed)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Couldn’t save this setting. Try again.',
              style: TextStyle(color: LearningColors.red),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'CANCEL',
            style: TextStyle(
              color: LearningColors.blue,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
