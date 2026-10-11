import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_widgets.dart';
import '../../../core/ui/duo_form.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../application/delete_account_controller.dart';
import '../data/account_repository.dart';

const _duoDone = ArtRegion('delete-06', Rect.fromLTWH(383, 805, 414, 445));

/// Duolingo Delete Account flow (delete/02–06): legal notice with a
/// countdown-locked action, confirm bottom sheet, then "Check your email".
class DeleteAccountScreen extends ConsumerWidget {
  const DeleteAccountScreen({super.key});

  void _close(BuildContext context) =>
      context.canPop() ? context.pop() : Navigator.maybePop(context);

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final copy = ref.read(accountRepositoryProvider).deleteContent;
    await showDuoSheet<void>(
      context,
      (sheet) => Column(
        key: const ValueKey('delete-confirm-sheet'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            copy.confirmTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: DuoFormColors.ink,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            copy.confirmQuestion,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, color: DuoFormColors.body),
          ),
          const SizedBox(height: 22),
          ReferenceButton(
            key: const ValueKey('delete-confirm'),
            label: copy.actionLabel,
            backgroundColor: DuoFormColors.red,
            edgeColor: DuoFormColors.redEdge,
            onPressed: () async {
              final ok = await ref
                  .read(deleteAccountControllerProvider.notifier)
                  .confirm();
              if (ok && sheet.mounted) Navigator.pop(sheet);
            },
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(sheet),
            child: Text(
              copy.cancelLabel,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: .8,
                color: DuoFormColors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(accountRepositoryProvider).deleteContent;
    final requested = ref.watch(deletionRequestedProvider);
    final s = ref.watch(deleteAccountControllerProvider);
    final bodyStyle = const TextStyle(
      fontSize: 20,
      height: 1.3,
      color: DuoFormColors.ink,
    );
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 52,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    copy.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: DuoFormColors.ink,
                    ),
                  ),
                  Positioned(
                    left: 4,
                    child: IconButton(
                      tooltip: 'Close',
                      onPressed: () => _close(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 28,
                        color: DuoFormColors.hint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(
              height: 2,
              thickness: 2,
              color: DuoFormColors.fieldBorder,
            ),
            Expanded(
              child: DuoStepSwitcher(
                child: requested
                    ? Center(
                        key: const ValueKey('delete-done'),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const ReferenceArt(
                                _duoDone,
                                width: 137,
                                height: 147,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                copy.doneTitle,
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w700,
                                  color: DuoFormColors.ink,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                copy.doneBody,
                                textAlign: TextAlign.center,
                                style: bodyStyle.copyWith(
                                  color: DuoFormColors.body,
                                ),
                              ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        key: const ValueKey('delete-notice'),
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        child: DefaultTextStyle.merge(
                          style: bodyStyle,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(copy.body),
                              const SizedBox(height: 22),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(text: copy.subscriptionNotice),
                                    TextSpan(
                                      text: copy.instructionsLabel,
                                      style: const TextStyle(
                                        color: DuoFormColors.link,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: requested
                  ? DuoBlueButton(
                      key: const ValueKey('delete-done-button'),
                      label: copy.doneLabel,
                      onPressed: () => _close(context),
                    )
                  : TextButton(
                      key: const ValueKey('delete-action'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      onPressed: s.canDelete
                          ? () => _confirm(context, ref)
                          : null,
                      child: Text(
                        s.secondsLeft > 0
                            ? '${copy.actionLabel} (${s.secondsLeft})'
                            : copy.actionLabel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .8,
                          color: s.canDelete
                              ? DuoFormColors.redText
                              : DuoFormColors.countdown,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
