import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/learning/application/unit_skip_controller.dart';
import 'package:cocenglish/features/learning/domain/unit_skip.dart';
import 'package:cocenglish/features/learning/presentation/unit_skip_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_fonts.dart';

void main() {
  setUpAll(loadAppFonts);
  testWidgets(
    'failed check illustration opens real hearts offer without changing Continue',
    (tester) async {
      var closed = 0;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: referenceTheme(),
            home: UnitSkipScreen(
              unit: 2,
              onClose: () => closed++,
              onPassed: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final c = ProviderScope.containerOf(
        tester.element(find.byType(UnitSkipScreen)),
      );
      final controller = c.read(unitSkipControllerProvider(2).notifier);
      controller.start();
      for (var i = 0; i < 5; i++) {
        final wrong = controller.question!.tokens.firstWhere(
          (t) => !controller.question!.answerTokenIds.contains(t.id),
        );
        if (i == 0) controller.toggleToken(wrong.id);
        controller.check();
        controller.continueAfterFeedback();
        if (c.read(unitSkipControllerProvider(2)).stage ==
            UnitSkipStage.lastHeartWarning) {
          controller.continueAfterWarning();
        }
      }
      await tester.pumpAndSettle();
      expect(c.read(unitSkipControllerProvider(2)).hearts, 0);
      expect(c.read(unitSkipControllerProvider(2)).stage, UnitSkipStage.failed);
      final illustration = find.byWidgetPredicate(
        (w) => w is ReferenceArt && w.region.file == 'unit-skip-failed',
      );
      await tester.tap(
        find
            .ancestor(of: illustration, matching: find.byType(GestureDetector))
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('You ran out of hearts!'), findsOneWidget);
      expect(find.text('TRY 1 WEEK FOR FREE'), findsOneWidget);
      await tester.ensureVisible(find.text('NO THANKS'));
      await tester.tap(find.text('NO THANKS'));
      await tester.pumpAndSettle();
      expect(closed, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
