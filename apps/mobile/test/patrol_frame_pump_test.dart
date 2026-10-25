import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../patrol_test/support/advance_frame.dart';

void main() {
  testWidgets(
    'native interaction advances while continuous frames remain active',
    (tester) async {
      final animation = AnimationController(
        vsync: tester,
        duration: const Duration(seconds: 1),
      )..repeat();
      try {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: AnimatedBuilder(
              animation: animation,
              builder: (_, _) =>
                  Text('Frame ${animation.value.toStringAsFixed(2)}'),
            ),
          ),
        );
        final before = tester.binding.clock.now();

        await advanceFrame(tester);

        expect(
          tester.binding.clock.now().difference(before).inMilliseconds,
          lessThan(1000),
        );
        expect(animation.isAnimating, isTrue);
        expect(tester.binding.hasScheduledFrame, isTrue);
        expect(find.text('Frame 0.00'), findsNothing);
        expect(find.textContaining('Frame '), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        animation.dispose();
      }
    },
  );
}
