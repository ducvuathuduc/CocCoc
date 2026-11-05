import 'package:flutter_test/flutter_test.dart';

/// Advances transient work without requiring looping audio/animation to stop.
Future<void> advanceFrame(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 500));
