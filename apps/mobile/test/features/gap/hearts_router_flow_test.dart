import 'package:cocenglish/main.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/data/learning_repository.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/hearts/application/hearts_controller.dart';
import 'package:cocenglish/features/hearts/presentation/hearts_sheets.dart';
import 'package:cocenglish/features/hearts/presentation/heart_earned_screen.dart';
import 'package:cocenglish/features/ads/presentation/ad_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_fonts.dart';

class ShortPractice extends MockLearningRepository {
  @override
  Future<List<Exercise>> loadLesson(String nodeId) async => const [
    Exercise(
      id: 'heart-practice-word',
      kind: ExerciseKind.choice,
      title: 'Translate the word',
      prompt: 'hello',
      choices: [
        ExerciseChoice(id: 'hello', text: 'hello'),
        ExerciseChoice(id: 'bye', text: 'goodbye'),
      ],
      correctIds: ['hello'],
    ),
  ];
}

void main() {
  setUpAll(loadAppFonts);
  testWidgets(
    'real router: practice completion -> heart -> ad -> second heart',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            learningRepositoryProvider.overrideWithValue(ShortPractice()),
          ],
          child: MainApp(
            initial: OnboardingState(
              step: OnboardingStep.lessonEntry,
              language: 'English',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byTooltip('Practice'));
      final container = ProviderScope.containerOf(context);
      showNeedHeartsSheet(context);
      await tester.pumpAndSettle();
      await tester.tap(find.text('PRACTICE TO EARN HEARTS'));
      await tester.pumpAndSettle();
      expect(
        container.read(lessonControllerProvider).nodeId,
        'hearts-practice',
      );
      await tester.tap(find.text('hello').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('CHECK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(find.text('CLAIM XP'), findsOneWidget);
      await tester.tap(find.text('CLAIM XP'));
      await tester.pumpAndSettle();
      expect(find.byType(HeartEarnedScreen), findsOneWidget);
      expect(container.read(heartsControllerProvider).balance, 1);
      await tester.tap(find.text('EARN 1 HEART'));
      await tester.pumpAndSettle();
      expect(find.byType(AdScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(find.byType(HeartEarnedScreen), findsOneWidget);
      expect(container.read(heartsControllerProvider).balance, 2);
      expect(find.text('EARN 1 HEART'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
