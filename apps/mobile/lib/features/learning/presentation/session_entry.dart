import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../progress/presentation/hub_screens.dart';
import '../application/learning_controller.dart';
import '../data/learning_repository.dart';
import 'learning_visuals.dart';

class SessionEntryScreen extends ConsumerStatefulWidget {
  const SessionEntryScreen({
    this.nodeId = 'node-0',
    this.guest = false,
    this.placement = false,
    super.key,
  });
  final String nodeId;
  final bool guest, placement;
  @override
  ConsumerState<SessionEntryScreen> createState() => _SessionEntryState();
}

class _SessionEntryState extends ConsumerState<SessionEntryScreen> {
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final p = ref.watch(learningStateProvider),
        lesson = ref.watch(lessonControllerProvider);
    final index = int.tryParse(widget.nodeId.replaceFirst('node-', ''));
    final locked =
        !widget.guest &&
        !widget.placement &&
        (index == null || index < 0 || index > p.currentNode || index > 7);
    return PreviewPage(
      title: widget.placement
          ? 'Check your level'
          : widget.guest
          ? 'Try a lesson'
          : 'Use basic phrases',
      children: [
        const SizedBox(height: 45),
        const ReferenceArt(LearningArt.pathDuo, width: 140, height: 145),
        const SizedBox(height: 25),
        Text(
          locked
              ? 'Not quite yet!'
              : widget.placement
              ? 'Let’s find your starting point'
              : widget.guest
              ? 'Try your first English lesson'
              : 'Ready for a lesson?',
          textAlign: TextAlign.center,
          style: headingStyle,
        ),
        const SizedBox(height: 20),
        Text(
          locked
              ? 'Complete the previous lessons to unlock this node.'
              : widget.placement
              ? 'Answer 10 original questions. This local check will not award XP or change your course progress.'
              : 'Practise words, sentences and conversations at your own pace.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: ReferenceColors.muted, fontSize: 18),
        ),
        if (lesson.error != null)
          Text(
            lesson.error!,
            style: const TextStyle(color: LearningColors.red),
          ),
        const SizedBox(height: 30),
        ReferenceButton(
          label: busy
              ? 'LOADING…'
              : locked
              ? 'BACK TO PATH'
              : 'START',
          onPressed: busy
              ? null
              : locked
              ? () => context.go('/home')
              : () async {
                  setState(() => busy = true);
                  await ref
                      .read(lessonControllerProvider.notifier)
                      .start(
                        nodeId: widget.nodeId,
                        guest: widget.guest,
                        placement: widget.placement,
                        exercises: widget.placement || widget.guest
                            ? mockEnglishExercises
                            : null,
                      );
                  if (!context.mounted) return;
                  setState(() => busy = false);
                  if (ref.read(lessonControllerProvider).current != null) {
                    context.replace('/lesson/${widget.nodeId}');
                  }
                },
        ),
      ],
    );
  }
}
