import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/client/api_exception.dart';
import '../../../core/config/app_config.dart';
import '../../../core/design/reference_widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../../learning/application/learning_controller.dart';
import '../../learning/data/api_learning_repository.dart';
import '../../learning/domain/learning_models.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/mistake_history_controller.dart';
import '../data/mistake_history_repository.dart';

class MistakeHistoryPanel extends ConsumerStatefulWidget {
  const MistakeHistoryPanel({super.key});
  @override
  ConsumerState<MistakeHistoryPanel> createState() =>
      _MistakeHistoryPanelState();
}

class _MistakeHistoryPanelState extends ConsumerState<MistakeHistoryPanel> {
  bool busy = false;
  String? error;
  @override
  Widget build(BuildContext context) {
    final history = ref.watch(mistakeHistoryProvider);
    ref.listen(authControllerProvider.select((s) => s.user?.id), (_, _) {
      if (mounted) {
        setState(() {
          busy = false;
          error = null;
        });
      }
    });
    return history.when(
      skipLoadingOnReload: false,
      loading: () => const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Loading saved mistakes',
        ),
      ),
      error: (failure, _) => Column(
        children: [
          Text(
            failure is ApiException
                ? failure.userMessage
                : 'Could not load saved mistakes. Please retry.',
          ),
          TextButton(
            onPressed: () => ref.invalidate(mistakeHistoryProvider),
            child: const Text('RETRY'),
          ),
        ],
      ),
      data: (value) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            value.items.isEmpty
                ? 'No mistakes to review'
                : '${value.items.length} questions to review',
            style: headingStyle,
          ),
          const SizedBox(height: 12),
          Text(
            ref.watch(appConfigProvider).isApi
                ? 'Saved by your account. Reviews include unresolved mistakes and due words. Only a correct first answer without hints resolves a mistake.'
                : 'Saved on this device for this demo account. First answers determine which mistakes remain. Demo reviews award no XP.',
          ),
          if (value.offline)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Offline copy. Reconnect to start or finish a server review.',
              ),
            ),
          if (value.warning != null) Text(value.warning!),
          const SizedBox(height: 16),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                error!,
                style: const TextStyle(color: LearningColors.red),
              ),
            ),
          if (value.items.isNotEmpty || ref.watch(appConfigProvider).isApi)
            ReferenceButton(
              label: busy
                  ? 'OPENING REVIEW…'
                  : value.items.isEmpty
                  ? 'OPEN OR RESUME REVIEW'
                  : 'REVIEW MISTAKES',
              onPressed: busy || value.offline
                  ? null
                  : () => startReview(value),
            ),
          if (value.items.isEmpty)
            ReferenceButton(
              label: 'CONTINUE LEARNING',
              outlined: true,
              onPressed: () => context.go('/home'),
            ),
          TextButton(
            onPressed: busy
                ? null
                : () => ref.invalidate(mistakeHistoryProvider),
            child: const Text('REFRESH'),
          ),
          for (final item in value.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LearningCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: headingStyle.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item.count} incorrect first answer${item.count == 1 ? '' : 's'} · ${item.at.toUtc().toIso8601String().substring(0, 10)}',
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> startReview(MistakeHistory history) async {
    if (busy) return;
    final user = ref.read(authControllerProvider).user?.id;
    final repository = ref.read(mistakeRepositoryProvider);
    final api = ref.read(appConfigProvider).isApi;
    setState(() {
      busy = true;
      error = null;
    });
    final controller = ref.read(lessonControllerProvider.notifier);
    await controller.start(
      nodeId: mistakeReviewNodeId,
      guest: !api,
      exercises: api
          ? null
          : history.items
                .map((e) => e.exercise)
                .whereType<Exercise>()
                .take(20)
                .toList(),
    );
    if (!mounted ||
        user != ref.read(authControllerProvider).user?.id ||
        !identical(repository, ref.read(mistakeRepositoryProvider))) {
      return;
    }
    final lesson = ref.read(lessonControllerProvider);
    if (lesson.error != null ||
        !{LessonStage.answering, LessonStage.feedback}.contains(lesson.stage)) {
      setState(() {
        busy = false;
        error = lesson.error ?? 'No review questions are available yet.';
      });
      return;
    }
    await context.push('/lesson/practice');
    if (mounted) {
      setState(() => busy = false);
      ref.invalidate(mistakeHistoryProvider);
    }
  }
}
