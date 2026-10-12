import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cocenglish/features/progress/data/league_repository.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/progress/presentation/league_ranking.dart';

import 'support/app_fonts.dart';
import 'support/settle_images.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('LeagueRankingSurface matches golden 430', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [mockLeagueRosterProvider.overrideWithValue(const [])],
        child: MaterialApp(
          theme: referenceTheme(),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: RepaintBoundary(
              key: const ValueKey('league-surface'),
              child: LeagueRankingSurface(
                ownAvatar: const SizedBox(
                  width: 45,
                  height: 45,
                  child: ColoredBox(color: Colors.green),
                ),
                onOpenProfile: (_) {},
                onSetStatus: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await settleImages(tester);

    await expectLater(
      find.byKey(const ValueKey('league-surface')),
      matchesGoldenFile('goldens/ui_master/sprint_league_screen_430.png'),
    );
  });
}
