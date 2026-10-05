import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/profile_actions_controller.dart';

Widget _iosPanel(Widget child) => CupertinoTheme(
  data: const CupertinoThemeData(
    primaryColor: Color(0xFF007AFF),
    textTheme: CupertinoTextThemeData(
      textStyle: TextStyle(
        fontFamily: 'DuolingoSans',
        fontSize: 17,
        color: Color(0xFF807E80),
      ),
      actionTextStyle: TextStyle(
        fontFamily: 'DuolingoSans',
        fontSize: 22,
        color: Color(0xFF007AFF),
      ),
    ),
  ),
  child: child,
);

Future<void> showProfileOptions(
  BuildContext context,
  WidgetRef ref,
  String userId,
) async {
  final result = await showCupertinoModalPopup<String>(
    context: context,
    builder: (sheet) => _iosPanel(
      CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheet, 'report'),
            child: const Text(
              'Report user',
              style: TextStyle(fontFamily: 'DuolingoSans'),
            ),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(sheet, 'block'),
            child: const Text(
              'Block user',
              style: TextStyle(fontFamily: 'DuolingoSans'),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheet),
          child: const Text(
            'Cancel',
            style: TextStyle(fontFamily: 'DuolingoSans'),
          ),
        ),
      ),
    ),
  );
  if (!context.mounted || result == null) return;
  if (result == 'block') {
    final accepted = await _confirm(
      context,
      'Block $userId?',
      'You can unblock this profile later.',
      'BLOCK',
    );
    if (accepted && context.mounted) {
      ref.read(profileActionsProvider.notifier).block(userId);
    }
    return;
  }
  final reason = await showCupertinoModalPopup<String>(
    context: context,
    builder: (sheet) => _iosPanel(
      CupertinoActionSheet(
        message: const Text(
          'Choose a reason for the report...',
          style: TextStyle(fontFamily: 'DuolingoSans'),
        ),
        actions: [
          for (final reason in reportReasons)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(sheet, reason),
              child: Text(
                reason,
                style: const TextStyle(fontFamily: 'DuolingoSans'),
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheet),
          child: const Text(
            'Cancel',
            style: TextStyle(fontFamily: 'DuolingoSans'),
          ),
        ),
      ),
    ),
  );
  if (!context.mounted || reason == null) return;
  final accepted = await _confirm(
    context,
    'Report and block $userId?',
    'Reason: $reason\nPreview only',
    'REPORT',
  );
  if (accepted && context.mounted) {
    ref.read(profileActionsProvider.notifier).reportAndBlock(userId, reason);
  }
}

Future<bool> _confirm(
  BuildContext context,
  String title,
  String body,
  String action,
) async =>
    await showCupertinoDialog<bool>(
      context: context,
      builder: (dialog) => _iosPanel(
        CupertinoAlertDialog(
          title: Text(
            title,
            style: const TextStyle(fontFamily: 'DuolingoSans'),
          ),
          content: Text(
            body,
            style: const TextStyle(fontFamily: 'DuolingoSans'),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialog, false),
              textStyle: const TextStyle(fontFamily: 'DuolingoSans'),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              textStyle: const TextStyle(fontFamily: 'DuolingoSans'),
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(action),
            ),
          ],
        ),
      ),
    ) ??
    false;

Future<void> showProfileShare(
  BuildContext context, {
  required String userId,
  required String name,
}) {
  ProviderScope.containerOf(
    context,
    listen: false,
  ).read(profileActionsProvider.notifier).beginShare();
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0xAA131F35),
    builder: (dialog) => Consumer(
      builder: (context, ref, _) => Stack(
        children: [
          ProfileShareDialog(userId: userId, name: name),
          if (ref.watch(profileActionsProvider).copiedUser == userId)
            Align(
              alignment: Alignment.bottomCenter,
              child: IgnorePointer(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Material(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(
                            color: ReferenceColors.border,
                            width: 2,
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                          child: Text(
                            'Profile link copied',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: ReferenceColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class ProfileShareDialog extends ConsumerWidget {
  const ProfileShareDialog({
    required this.userId,
    required this.name,
    super.key,
  });
  final String userId, name;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileActionsProvider);
    final url = profilePreviewUrl(userId);
    return Dialog(
      constraints: const BoxConstraints(maxWidth: 350),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    tooltip: 'Close profile link',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: ReferenceColors.ink),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Column(
                        children: [
                          Text(
                            name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '@${name.toLowerCase().replaceAll(' ', '')}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: ReferenceColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 12),
              Stack(
                alignment: Alignment.center,
                children: [
                  QrImageView(
                    size: 264,
                    data: url,
                    version: QrVersions.auto,
                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                    padding: const EdgeInsets.all(12),
                    backgroundColor: Colors.white,
                    semanticsLabel: 'Profile QR code: $url',
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: ReferenceColors.ink,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.circle,
                      color: ReferenceColors.ink,
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const ClipOval(
                      child: ReferenceArt(
                        LearningArt.avatar,
                        width: 38,
                        height: 38,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const ReferenceArt(
                ReferenceArtRegions.wordmark,
                width: 101,
                height: 25,
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 24,
                runSpacing: 18,
                children: [
                  _linkAction(
                    context,
                    'Share link',
                    Icons.ios_share,
                    () => showDialog<void>(
                      context: context,
                      builder: (dialog) => AlertDialog(
                        title: const Text('Share profile'),
                        content: SelectableText(url),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialog),
                            child: const Text('CLOSE'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _linkAction(
                    context,
                    'Copy link',
                    Icons.link,
                    state.copying
                        ? null
                        : () async {
                            await ref
                                .read(profileActionsProvider.notifier)
                                .copyLink(userId);
                          },
                  ),
                ],
              ),
              if (state.copying)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Copying link…'),
                ),
              if (state.copyError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    state.copyError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linkAction(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback? onTap,
  ) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 66,
        child: Tooltip(
          message: label,
          child: ReferenceButton(
            label: '',
            outlined: true,
            leading: Icon(icon, size: 26, color: ReferenceColors.ink),
            onPressed: onTap,
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: ReferenceColors.muted,
        ),
      ),
    ],
  );
}
