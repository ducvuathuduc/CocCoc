import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cocenglish/features/quests/presentation/quests_screen.dart';

void main() {
  testWidgets('QuestsScreen matches golden 430', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: QuestsScreen(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await expectLater(
      find.byType(QuestsScreen),
      matchesGoldenFile('goldens/ui_master/sprint_quests_screen_430.png'),
    );
  });
}
