import 'package:cocenglish/core/design/character_motion.dart';
import 'package:cocenglish/core/design/cocenglish_brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('lesson feedback changes pose without a looping runtime', (
    tester,
  ) async {
    for (final character in LessonCharacter.values) {
      for (final reaction in CharacterReaction.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: CharacterMotion(
                character: character,
                reaction: reaction,
                width: 99,
                height: 149,
                fallback: const SizedBox(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final mascot = tester.widget<CocEnglishMascot>(
          find.byType(CocEnglishMascot),
        );
        expect(mascot.pose, switch (reaction) {
          CharacterReaction.reset => CocEnglishMascotPose.wave,
          CharacterReaction.correct => CocEnglishMascotPose.celebrate,
          CharacterReaction.incorrect => CocEnglishMascotPose.study,
        });
        expect(
          tester.getSize(find.byType(CocEnglishMascot)),
          const Size(99, 149),
        );
        expect(tester.takeException(), isNull);
      }
    }
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion and hidden routes keep feedback visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: TickerMode(
            enabled: false,
            child: CharacterMotion(
              character: LessonCharacter.lily,
              reaction: CharacterReaction.correct,
              width: 100,
              height: 150,
              fallback: SizedBox(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CocEnglishMascot), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
