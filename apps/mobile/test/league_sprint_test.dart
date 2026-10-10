import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cocenglish/features/progress/presentation/league_result_screen.dart';

void main() {
  testWidgets('LeagueResultScreen matches golden 430', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LeagueResultScreen(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await expectLater(
      find.byType(LeagueResultScreen),
      matchesGoldenFile('goldens/ui_master/sprint_league_screen_430.png'),
    );
  });
}
