import 'dart:io';
import 'dart:ui' as ui;

import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/application/social_controller.dart';
import 'package:cocenglish/features/progress/presentation/social_screens.dart';
import 'package:cocenglish/features/progress/presentation/hub_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('capture native English feed and actual status overlay', (
    tester,
  ) async {
    if (!const bool.fromEnvironment('CAPTURE_UI')) return;
    const ratio = 1180 / 390;
    tester.view.physicalSize = const Size(1180, 2556);
    tester.view.devicePixelRatio = ratio;
    tester.view.padding = const FakeViewPadding(
      top: 59 * ratio,
      bottom: 34 * ratio,
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await tester.runAsync(() async {
      await (FontLoader('DuolingoSans')
            ..addFont(rootBundle.load('assets/fonts/DuolingoSans.ttf'))
            ..addFont(rootBundle.load('assets/fonts/DuolingoSans-Bold.ttf')))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await ReferenceArt.preloadFiles([
        'status-icons',
        'feed-suggestions',
        'feed-learning',
        'feed-sentences',
        'feed-friend',
        '05',
        'lesson-01',
        'league-05',
        'status-league',
      ]);
    });
    for (final name in [
      'feed-empty',
      'feed-posts',
      'feed-sentences',
      'feed-first-friend',
      'feed-learning-detail',
      'status-picker',
      'status-selected',
      'status-premium',
    ]) {
      final c = ProviderContainer();
      if (name != 'feed-empty') {
        c.read(feedControllerProvider.notifier).addSuggested();
      }
      c.read(previewControllerProvider.notifier).optIntoLeague();
      if (name == 'status-selected') {
        c.read(statusControllerProvider.notifier)
          ..choose('popcorn')
          ..save();
      }
      final key = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: referenceTheme(),
              home: name.startsWith('status')
                  ? const LeagueScreen()
                  : name == 'feed-learning-detail'
                  ? const FeedLearningScreen()
                  : const FeedScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (name.startsWith('status')) {
        await tester.tap(find.byTooltip('Set your status'));
        await tester.pumpAndSettle();
        if (name == 'status-premium') {
          await tester.tap(find.bySemanticsLabel('Cool Duo status, 500 gems'));
          await tester.tap(find.text('DONE'));
          await tester.pumpAndSettle();
        }
      }
      if (name == 'feed-sentences' || name == 'feed-first-friend') {
        await tester.scrollUntilVisible(
          name == 'feed-sentences'
              ? find.text('The stores are big.')
              : find.text('Added their first friend!'),
          250,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
      }
      await tester.runAsync(
        () => ReferenceArt.preloadFiles(
          tester
              .widgetList<ReferenceArt>(find.byType(ReferenceArt))
              .map((art) => art.region.file),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: name);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await boundary.toImage(pixelRatio: ratio);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        await File('../../docs/design/qa/english-extended/$name.png')
            .writeAsBytes(data!.buffer.asUint8List());
        img.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      c.dispose();
    }
  });
}
