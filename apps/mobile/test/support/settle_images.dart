import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Decodes every Image currently in the tree, including owned mascot poses,
/// with real async IO, then settles. Repeats so images
/// revealed by the first decode are loaded too.
Future<void> settleImages(WidgetTester tester, {int passes = 3}) async {
  for (var i = 0; i < passes; i++) {
    final providers = <ImageProvider>{};
    BuildContext? context;
    for (final element in find.byType(Image).evaluate()) {
      providers.add((element.widget as Image).image);
      context ??= element;
    }
    if (context == null || providers.isEmpty) break;
    final ctx = context;
    await tester.runAsync(() async {
      await Future.wait(
        providers.map((p) => precacheImage(p, ctx, onError: (_, _) {})),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
  }
}
