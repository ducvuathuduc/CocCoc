import 'package:cocenglish/core/design/character_motion.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/practice/application/clash_controller.dart';
import 'package:cocenglish/features/practice/presentation/clash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'clash uses original coach and answer-driven Zari/Oscar state inputs',
    (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final vm = c.read(clashControllerProvider.notifier);
      vm
        ..advance()
        ..advance();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: referenceTheme(),
            home: const ClashScreen(clockEnabled: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<CharacterMotion>(find.byType(CharacterMotion)).character,
        LessonCharacter.eddy,
      );
      vm.advance();
      await tester.pumpAndSettle();
      expect(
        tester.widget<CharacterMotion>(find.byType(CharacterMotion)).character,
        LessonCharacter.zari,
      );
      vm
        ..choose('sister')
        ..check();
      await tester.pumpAndSettle();
      final correct = tester.widget<CharacterMotion>(
        find.byType(CharacterMotion),
      );
      expect(correct.reaction, CharacterReaction.correct);
      final epoch = correct.epoch;
      vm.tick(5);
      await tester.pumpAndSettle();
      expect(
        tester.widget<CharacterMotion>(find.byType(CharacterMotion)).epoch,
        epoch,
      );
      vm
        ..advance()
        ..choose('Your')
        ..check();
      await tester.pumpAndSettle();
      final wrong = tester.widget<CharacterMotion>(
        find.byType(CharacterMotion),
      );
      expect(wrong.character, LessonCharacter.oscar);
      expect(wrong.reaction, CharacterReaction.incorrect);
      vm.tick(60);
      await tester.pumpAndSettle();
      expect(
        tester.widget<CharacterMotion>(find.byType(CharacterMotion)).character,
        LessonCharacter.eddy,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
