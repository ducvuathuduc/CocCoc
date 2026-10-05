import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../application/learning_controller.dart';
import '../data/english_explanations.dart';
import '../domain/learning_models.dart';
import 'learning_visuals.dart';

const maxBadge = ArtRegion('explain-answer', Rect.fromLTWH(930, 225, 206, 75));

class ExplanationScreen extends ConsumerStatefulWidget {
  const ExplanationScreen({super.key});
  @override
  ConsumerState<ExplanationScreen> createState() => _ExplanationScreenState();
}

class _ExplanationScreenState extends ConsumerState<ExplanationScreen> {
  bool? helpful;
  void _back() => context.canPop() ? context.pop() : context.go('/home');
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lessonControllerProvider);
    final exercise = state.current;
    final explanation = englishExplanations[exercise?.id];
    if (exercise == null ||
        explanation == null ||
        state.stage != LessonStage.feedback) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              LearningHeader(title: 'Explanation', onClose: _back),
              const Expanded(
                child: Center(
                  child: Text(
                    'An explanation is unavailable for this exercise.',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ReferenceButton(
                  label: 'BACK TO LESSON',
                  onPressed: _back,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final answer = exerciseAnswer(exercise);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _ScrollableRegion(
              maxHeight: MediaQuery.sizeOf(context).height * .36,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black, Colors.black, Color(0xFF234D52)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Back to lesson',
                          onPressed: _back,
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Color(0xFFB6C7CC),
                            size: 30,
                          ),
                        ),
                        const Spacer(),
                        const ReferenceArt(maxBadge, width: 68, height: 25),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      exercise.prompt,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF11373A),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: const Color(0xFF20BFAA),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        answer,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: LearningCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _ScrollableRegion(
                        maxHeight: MediaQuery.sizeOf(context).height * .22,
                        child: Container(
                          width: double.infinity,
                          color: const Color(0xFFF7F7F7),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.correct == true
                                    ? 'Correct answer'
                                    : 'Replaced',
                                style: const TextStyle(
                                  color: ReferenceColors.disabled,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text.rich(
                                TextSpan(
                                  style: const TextStyle(fontSize: 21),
                                  children: [
                                    if (state.correct == false) ...[
                                      TextSpan(
                                        text: submittedAnswer(exercise, state),
                                        style: const TextStyle(
                                          decoration:
                                              TextDecoration.lineThrough,
                                        ),
                                      ),
                                      const TextSpan(text: ' → '),
                                    ],
                                    TextSpan(
                                      text: answer,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                explanation.$1,
                                style: const TextStyle(
                                  fontSize: 21,
                                  height: 1.5,
                                ),
                              ),
                              for (final example in explanation.$2)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    '• $example',
                                    style: const TextStyle(
                                      fontSize: 21,
                                      height: 1.4,
                                      color: Color(0xFF008998),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            for (final value in [false, true])
                              IconButton(
                                tooltip: value ? 'Helpful' : 'Not helpful',
                                isSelected: helpful == value,
                                onPressed: () => setState(
                                  () =>
                                      helpful = helpful == value ? null : value,
                                ),
                                icon: Icon(
                                  value
                                      ? Icons.thumb_up_outlined
                                      : Icons.thumb_down_outlined,
                                  color: const Color(0xFF008998),
                                ),
                                selectedIcon: Icon(
                                  value
                                      ? Icons.thumb_up_rounded
                                      : Icons.thumb_down_rounded,
                                  color: const Color(0xFF008998),
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
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF22DDE3), Color(0xFF20E6B5)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ReferenceButton(
                  label: 'CONTINUE LESSON',
                  foregroundColor: Colors.black,
                  backgroundColor: Colors.transparent,
                  edgeColor: const Color(0xFF13BECD),
                  onPressed: _back,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScrollableRegion extends StatelessWidget {
  const _ScrollableRegion({required this.maxHeight, required this.child});
  final double maxHeight;
  final Widget child;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxHeight: maxHeight),
    child: SingleChildScrollView(child: child),
  );
}
