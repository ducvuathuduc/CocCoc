import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../learning/application/learning_controller.dart';
import '../../learning/application/course_navigation_controller.dart';
import '../../session/application/real_learning_session.dart';

class PlacementEntryScreen extends ConsumerWidget {
  const PlacementEntryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prepared = ref.watch(realLearningSessionProvider);
    final lesson = ref.watch(lessonControllerProvider);
    final eligible =
        !prepared.isLoading &&
        !prepared.hasError &&
        (prepared.value?.needsEnrollment == true ||
            prepared.value?.hasSavedPlacement == true);
    return Scaffold(
      appBar: AppBar(title: const Text('Check your starting point')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.school_outlined, size: 64),
              const SizedBox(height: 24),
              const Text(
                'Find where to start',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Answer 10 questions from your course. Your first answers determine your starting point. This test does not award XP or certify a CEFR level.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Stay online to submit answers. If interrupted, return here to resume your saved test.',
              ),
              if (prepared.isLoading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (prepared.hasError) ...[
                const Text('Could not load your course.'),
                TextButton(
                  onPressed: () => ref.invalidate(realLearningSessionProvider),
                  child: const Text('RETRY'),
                ),
              ],
              if (!prepared.isLoading && !prepared.hasError && !eligible)
                const Text(
                  'You already have a learning path. Continue your existing course.',
                ),
              if (lesson.error != null)
                Text(lesson.error!, semanticsLabel: lesson.error),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: !eligible || lesson.busy
                    ? null
                    : () async {
                        await ref
                            .read(lessonControllerProvider.notifier)
                            .start(nodeId: 'placement', placement: true);
                        if (!context.mounted) return;
                        final result = ref.read(lessonControllerProvider);
                        if (result.error == null && result.current != null) {
                          context.push('/lesson/placement');
                        }
                      },
                child: Text(lesson.busy ? 'LOADING…' : 'START OR RESUME TEST'),
              ),
              TextButton(
                onPressed: () => context.go(eligible ? '/connecting' : '/home'),
                child: const Text('BACK'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlacementResultScreen extends ConsumerWidget {
  const PlacementResultScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipt = ref.watch(lessonControllerProvider).receipt;
    final prepared = ref.watch(realLearningSessionProvider);
    final ready =
        !prepared.isLoading &&
        !prepared.hasError &&
        prepared.value?.needsEnrollment == false;
    return Scaffold(
      appBar: AppBar(title: const Text('Placement result')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.check_circle_outline, size: 64),
              const SizedBox(height: 24),
              const Text(
                'Your starting point',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              if (receipt?.placement == true)
                Text(
                  'First answers correct: ${(receipt!.accuracy * 10).round()}/10',
                ),
              const SizedBox(height: 16),
              const Text(
                'Your course position is saved by the server. Continue to the highlighted unit. No XP or streak is awarded for this test.',
              ),
              if (prepared.isLoading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (prepared.hasError) ...[
                const Text(
                  'Your result is saved. Reconnect to load your path.',
                ),
                TextButton(
                  onPressed: () => ref.invalidate(realLearningSessionProvider),
                  child: const Text('RETRY'),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: ready
                    ? () {
                        ref
                            .read(courseNavigationProvider.notifier)
                            .selectFrontier();
                        context.go('/home');
                      }
                    : null,
                child: const Text('CONTINUE TO MY COURSE'),
              ),
              if (!prepared.isLoading && !prepared.hasError && !ready)
                TextButton(
                  onPressed: () => context.go('/connecting'),
                  child: const Text('CHOOSE STARTING POINT'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
