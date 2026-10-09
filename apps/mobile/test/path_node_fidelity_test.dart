import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/learning/presentation/learning_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'path press lowers its face and cancellation keeps the command untouched',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: referenceTheme(),
          home: Center(
            child: PathNode(
              current: true,
              completed: false,
              icon: Icons.star_rounded,
              onTap: () => calls++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final star = find.byIcon(Icons.star_rounded);
      final rest = tester.getCenter(star);
      final ring = tester.getRect(find.byType(CustomPaint).last);
      final gesture = await tester.startGesture(rest);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getCenter(star).dy, closeTo(rest.dy + 7, .01));
      expect(tester.getRect(find.byType(CustomPaint).last), ring);
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        .94,
      );
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
        const Duration(milliseconds: 100),
      );
      await gesture.cancel();
      await tester.pump();
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
        const Duration(milliseconds: 250),
      );
      await tester.pump(const Duration(milliseconds: 125));
      expect(
        tester
            .widget<ScaleTransition>(find.byType(ScaleTransition))
            .scale
            .value,
        greaterThan(1),
      );
      await tester.pumpAndSettle();
      expect(tester.getCenter(star), rest);
      expect(calls, 0);
      await tester.tap(star);
      await tester.pumpAndSettle();
      expect(calls, 1);
    },
  );
  testWidgets(
    'reduced motion path press settles immediately without a command',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Center(
              child: PathNode(
                current: false,
                completed: false,
                icon: Icons.star_rounded,
                onTap: () => calls++,
              ),
            ),
          ),
        ),
      );
      final star = find.byIcon(Icons.star_rounded);
      final gesture = await tester.startGesture(tester.getCenter(star));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
        Duration.zero,
      );
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
