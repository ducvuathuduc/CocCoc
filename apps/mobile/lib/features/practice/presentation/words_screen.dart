import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/practice_controller.dart';
import '../domain/practice_models.dart';

class WordsScreen extends ConsumerWidget {
  const WordsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(practiceControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            LearningHeader(
              title: 'Words',
              onClose: () =>
                  context.canPop() ? context.pop() : context.go('/practice'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 18),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Practice your\nEnglish words',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            ReferenceArt(
                              ArtRegion(
                                'words-02',
                                Rect.fromLTWH(895, 360, 205, 215),
                              ),
                              width: 75,
                              height: 78,
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF78E9F3), Color(0xFF71ECB2)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ReferenceButton(
                            label: 'START PRACTICE',
                            backgroundColor: Colors.transparent,
                            edgeColor: const Color(0xFF5FD1E4),
                            foregroundColor: Colors.black,
                            onPressed: () => context.push('/practice/recall'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(thickness: 2),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${state.words.length} words',
                            style: headingStyle,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _sort(context, ref),
                          child: const Text(
                            'SORT',
                            style: TextStyle(
                              color: LearningColors.blue,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              letterSpacing: .8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: ReferenceColors.border,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          for (final word in state.sortedWords) ...[
                            if (word != state.sortedWords.first)
                              const Divider(height: 2, thickness: 2),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 13,
                                horizontal: 5,
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Listen to ${word.term}',
                                    onPressed: () => showLearningNotice(
                                      context,
                                      'Audio unavailable',
                                      'Recorded word audio is not bundled yet. You can read the word and practice its meaning.',
                                    ),
                                    icon: const Icon(
                                      Icons.volume_up_rounded,
                                      color: LearningColors.blue,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          word.term,
                                          key: const ValueKey('word-term'),
                                          style: headingStyle.copyWith(
                                            fontSize: 21,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          word.meaning,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            color: ReferenceColors.disabled,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Icon(
                                      Icons.circle,
                                      size: 7,
                                      color: state.recalledIds.contains(word.id)
                                          ? LearningColors.green
                                          : LearningColors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sort(BuildContext context, WidgetRef ref) =>
      learningSheet<void>(
        context,
        title: 'Sort',
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: ReferenceColors.border, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (final order in WordSort.values) ...[
                if (order == WordSort.alphabetical)
                  const Divider(height: 1, thickness: 2),
                ListTile(
                  leading: Icon(
                    order == WordSort.recent ? Icons.schedule : Icons.sort,
                    color: ReferenceColors.muted,
                  ),
                  title: Text(
                    order == WordSort.recent
                        ? 'Recently learned'
                        : 'Alphabetically',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing:
                      ref.read(practiceControllerProvider).wordSort == order
                      ? const Icon(
                          Icons.check,
                          color: LearningColors.blue,
                          size: 30,
                        )
                      : null,
                  onTap: () {
                    ref.read(practiceControllerProvider.notifier).sort(order);
                    Navigator.pop(context);
                  },
                ),
              ],
            ],
          ),
        ),
      );
}
