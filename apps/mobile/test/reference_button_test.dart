import 'package:cocenglish/core/design/reference_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tactile edge depresses on press and cancellation does not act', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ReferenceButton(label: 'CONTINUE', onPressed: () => calls++),
          ),
        ),
      ),
    );
    final button = find.byType(TextButton);
    final rest = tester.getTopLeft(button);
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getTopLeft(button).dy, closeTo(rest.dy + 4, .01));
    await gesture.cancel();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(tester.getTopLeft(button).dy, greaterThan(rest.dy));
    expect(tester.getTopLeft(button).dy, lessThan(rest.dy + 4));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(button).dy, rest.dy);
    expect(calls, 0);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(calls, 1);
  });
}
