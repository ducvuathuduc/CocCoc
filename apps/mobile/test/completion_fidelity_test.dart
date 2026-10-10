import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/core/design/reward_motion.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/learning/presentation/lesson_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const receipt = SessionReceipt(
  id: 'completion-fidelity',
  nodeId: 'node-0',
  xp: 20,
  accuracy: 1,
  elapsed: Duration(seconds: 58),
  firstCompletion: true,
  guest: false,
  placement: false,
);

Widget summary({bool reduced = false}) => ProviderScope(
  child: MaterialApp(
    theme: referenceTheme(),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: const Scaffold(
        body: SingleChildScrollView(
          child: LessonSummary(receipt: receipt, mistakeCount: 0),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'XP counts upward while semantics expose the immutable final receipt',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final xp = find.byKey(const Key('lesson-summary-stat-xp'));
      try {
        await tester.pumpWidget(summary());
        expect(find.bySemanticsLabel('Total XP, 20'), findsOneWidget);
        expect(
          find.descendant(of: xp, matching: find.text('20')),
          findsNothing,
        );
        await tester.pump(const Duration(milliseconds: 250));
        final texts = tester.widgetList<Text>(
          find.descendant(of: xp, matching: find.byType(Text)),
        );
        final count = texts
            .map((text) => int.tryParse(text.data ?? ''))
            .whereType<int>()
            .single;
        expect(count, greaterThan(0));
        expect(count, lessThan(20));
        await tester.pump(const Duration(milliseconds: 250));
        expect(
          find.descendant(of: xp, matching: find.text('20')),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
      await tester.pumpWidget(summary());
      expect(
        find.descendant(of: xp, matching: find.text('20')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'completion celebration is finite and reduced motion has final stats',
    (tester) async {
      await tester.pumpWidget(summary());
      expect(
        find.byKey(const ValueKey('lesson-completion-confetti')),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        find.byKey(const ValueKey('lesson-completion-confetti')),
        findsNothing,
      );
      await tester.pumpWidget(summary(reduced: true));
      await tester.pumpAndSettle();
      expect(find.text('20'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('lesson-completion-confetti')),
        findsNothing,
      );
    },
  );
  testWidgets(
    'celebration never blocks Continue and does not replay after background',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonCelebration(
              child: TextButton(
                onPressed: () => calls++,
                child: const Text('CONTINUE'),
              ),
            ),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('lesson-completion-confetti')),
        findsOneWidget,
      );
      await tester.tap(find.text('CONTINUE'));
      await tester.pump();
      expect(calls, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('lesson-completion-confetti')),
        findsNothing,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('lesson-completion-confetti')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
