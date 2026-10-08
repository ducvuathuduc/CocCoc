import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/learning/presentation/unit_guide_screen.dart';
import 'package:cocenglish/features/progress/domain/preview_state.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/presentation/hub_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'reference course choices do not change the interactive English course',
    () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(previewControllerProvider.notifier).chooseCourse('French');
      expect(c.read(previewControllerProvider).course, 'English');
    },
  );
  test('new local learners start with English', () {
    expect(const PreviewState().course, 'English');
  });
  testWidgets(
    'English score and guide expose English with Vietnamese meanings',
    (tester) async {
      Future<void> open(Widget screen) => tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(theme: referenceTheme(), home: screen),
        ),
      );
      await open(const ScoreScreen());
      expect(find.byTooltip('Share English Score'), findsOneWidget);
      await open(const UnitGuideScreen());
      await tester.pumpAndSettle();
      expect(find.text('Hello!'), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(GuidePhraseBubble).first,
          matching: find.text('Xin chào!'),
        ),
        findsOneWidget,
      );
      expect(find.text('Bonjour !'), findsNothing);
    },
  );
}
