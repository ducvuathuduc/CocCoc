import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/design/reference_theme.dart';
import '../application/learning_stats_provider.dart';

class LearningStatsScreen extends ConsumerStatefulWidget {
  const LearningStatsScreen({super.key});

  @override
  ConsumerState<LearningStatsScreen> createState() => _LearningStatsState();
}

class _LearningStatsState extends ConsumerState<LearningStatsScreen> {
  int period = 7;

  Future<void> refresh() async {
    ref.invalidate(learningStatsProvider);
    try {
      await ref.read(learningStatsProvider.future);
    } catch (_) {
      // The provider renders the retry state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(learningStatsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Learning statistics')),
      body: stats.when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Statistics could not be loaded. Check your connection and try again.',
                ),
                TextButton(
                  onPressed: () => ref.invalidate(learningStatsProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text('7 days')),
                  ButtonSegment(value: 28, label: Text('28 days')),
                ],
                selected: {period},
                onSelectionChanged: (value) =>
                    setState(() => period = value.first),
              ),
              const SizedBox(height: 16),
              Text('Learning zone: ${data.learningZone}'),
              Text('Updated: ${data.asOf}'),
              const SizedBox(height: 16),
              _StatsContent(
                days: data.days.skip(data.days.length - period).toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Rewards may arrive shortly after a lesson. Pull down to refresh. Placement tests do not award XP.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Accuracy covers recorded first attempts in lessons since statistics tracking was enabled. Older answers are excluded.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsContent extends StatelessWidget {
  const _StatsContent({required this.days});
  final List<wire.LearningStatsDay> days;

  @override
  Widget build(BuildContext context) {
    final xp = days.fold(0, (n, d) => n + d.studyXp);
    final lessons = days.fold(0, (n, d) => n + d.completedLessons);
    final reviews = days.fold(0, (n, d) => n + d.reviewSessions);
    final active = days.where((d) => d.active).length;
    final total = days.fold(0, (n, d) => n + d.trackedOriginalCount);
    final correct = days.fold(0, (n, d) => n + d.trackedOriginalCorrect);
    final maximum = days.fold(1, (n, d) => d.studyXp > n ? d.studyXp : n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            Text('$xp XP'),
            Text('$lessons lessons'),
            Text('$reviews reviews'),
            Text('$active active days'),
            Text(
              total == 0
                  ? 'Accuracy: no recorded answers'
                  : 'Accuracy: ${(100 * correct / total).toStringAsFixed(1)}% ($correct/$total)',
            ),
          ],
        ),
        if (active == 0)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No learning activity in this period. Complete a lesson to get started.',
            ),
          ),
        const SizedBox(height: 20),
        Text(
          'Daily XP and learning history',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        for (final day in days.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Semantics(
              label:
                  '${day.day}: ${day.studyXp} XP, ${day.completedLessons} lessons, ${day.reviewSessions} reviews',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${day.day} · ${day.studyXp} XP'),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: day.studyXp / maximum,
                    color: ReferenceColors.green,
                    backgroundColor: ReferenceColors.border,
                    minHeight: 10,
                  ),
                  Text(
                    '${day.completedLessons} lessons · ${day.reviewSessions} reviews',
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
