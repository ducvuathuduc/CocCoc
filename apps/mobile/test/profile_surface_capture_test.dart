import 'dart:io';
import 'dart:ui' as ui;

import 'package:cocenglish/main.dart';
import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/features/account/application/avatar_controller.dart';
import 'package:cocenglish/features/account/data/avatar_assets.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/application/extended_controller.dart';
import 'package:cocenglish/features/progress/application/score_information_controller.dart';
import 'package:cocenglish/features/progress/application/profile_surface_controller.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rive/rive.dart' as rive;

void main() {
  testWidgets('capture native source profile and language lists', (t) async {
    if (!const bool.fromEnvironment('CAPTURE_PROFILE_UI')) return;
    const ratio = 1180 / 390;
    t.view.physicalSize = const Size(1180, 2556);
    t.view.devicePixelRatio = ratio;
    t.view.padding = const FakeViewPadding(top: 59 * ratio, bottom: 34 * ratio);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPadding);
    await t.runAsync(() async {
      await (FontLoader('DuolingoSans')
            ..addFont(rootBundle.load('assets/fonts/DuolingoSans.ttf'))
            ..addFont(rootBundle.load('assets/fonts/DuolingoSans-Bold.ttf')))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
            rootBundle.load(
              'packages/cupertino_icons/assets/CupertinoIcons.ttf',
            ),
          ))
          .load();
    });
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MainApp(
          initial: OnboardingState(
            step: OnboardingStep.lessonEntry,
            language: 'English',
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final context = t.element(find.byTooltip('Practice'));
    final c = ProviderScope.containerOf(context);
    final router = GoRouter.of(context);
    c
        .read(previewControllerProvider.notifier)
        .saveProfile('Sam Lee', 'sam@example.test', register: true);
    c.read(previewControllerProvider.notifier).follow('Alex');
    final catalog = await t.runAsync(
      () => c.read(avatarCatalogProvider.future),
    );
    final avatar = c.read(avatarControllerProvider.notifier)
      ..attachCatalog(catalog!);
    for (final scene in [
      'own-empty',
      'league-locked',
      'league-welcome',
      'own-saved',
      'courses',
      'following',
      'followers',
      'followers-populated',
      'followers-followed',
      'foreign-james',
      'foreign-share',
      'foreign-weekly',
      'foreign-lower',
      'foreign-awards',
      'foreign-award-detail',
      'own-lower',
      'family-empty',
      'family-member',
      'monthly-2025',
      'monthly-2024',
      'score-early',
      'score-locked',
      'course-score',
      'league-ranking',
      'league-own-row',
      'league-status',
    ]) {
      if (scene == 'league-welcome') {
        c
            .read(learningStateProvider.notifier)
            .claim(
              const SessionReceipt(
                id: 'league-welcome-capture',
                nodeId: 'english-entry',
                xp: 20,
                accuracy: 1,
                elapsed: Duration(minutes: 1),
                firstCompletion: true,
                guest: false,
                placement: false,
              ),
            );
      }
      if (scene == 'own-saved') {
        avatar.begin();
        avatar.select('MainHair', 40);
        avatar.select('BackgroundColor', 19);
        avatar.save();
      }
      if (scene == 'family-empty') {
        c.read(extendedControllerProvider.notifier)
          ..choosePlan('max-family')
          ..confirmPlan();
      }
      if (scene == 'followers-populated') {
        c.read(profileSurfaceProvider.notifier).receiveFollowers({
          'James Smith',
          'Alex',
        });
      }
      if (scene == 'family-member') {
        c.read(extendedControllerProvider.notifier).invite('Alex Smith');
      }
      if (scene == 'score-early') {
        for (var i = 0; i < 2; i++) {
          c
              .read(learningStateProvider.notifier)
              .claim(
                SessionReceipt(
                  id: 'score-capture-$i',
                  nodeId: 'score-node-$i',
                  xp: 10,
                  accuracy: 1,
                  elapsed: const Duration(minutes: 1),
                  firstCompletion: true,
                  guest: false,
                  placement: false,
                ),
              );
        }
      }
      if (const {
        'league-ranking',
        'league-own-row',
        'league-status',
      }.contains(scene)) {
        c.read(previewControllerProvider.notifier).optIntoLeague();
      }
      router.go(switch (scene) {
        'courses' => '/profile/courses',
        'following' => '/profile/friends?tab=following',
        'followers' => '/profile/friends?tab=followers',
        'followers-populated' ||
        'followers-followed' => '/profile/friends?tab=followers',
        'foreign-james' || 'foreign-share' => '/profile/James%20Smith',
        'foreign-weekly' || 'foreign-lower' => '/profile/James%20Smith',
        'foreign-awards' => '/achievements?profile=James%20Smith',
        'foreign-award-detail' =>
          '/achievements/perfect-week?profile=James%20Smith',
        'monthly-2025' || 'monthly-2024' => '/badges',
        'score-early' || 'score-locked' => '/score',
        'course-score' => '/home',
        'league-ranking' ||
        'league-own-row' ||
        'league-status' ||
        'league-locked' ||
        'league-welcome' => '/league',
        _ => '/profile/me',
      });
      await t.pumpAndSettle();
      if (scene == 'league-locked') {
        expect(find.text('START A LESSON').hitTestable(), findsOneWidget);
      }
      if (scene == 'league-welcome') {
        expect(find.text('Welcome to Leaderboards!'), findsOneWidget);
        expect(find.text('CONTINUE').hitTestable(), findsOneWidget);
      }
      if (scene == 'league-own-row' || scene == 'league-status') {
        await t.scrollUntilVisible(
          find.byKey(const ValueKey('league-own-status')),
          180,
          scrollable: find
              .descendant(
                of: find.byKey(const PageStorageKey('league')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await t.pump();
        expect(find.text('Bronze League').hitTestable(), findsOneWidget);
        if (scene == 'league-status') {
          await t.tap(find.byTooltip('Set your status'));
          await t.pumpAndSettle();
          expect(find.text('Set your status'), findsOneWidget);
        }
      }
      if (scene == 'followers-populated') {
        expect(
          find.bySemanticsLabel('Follow back James Smith'),
          findsOneWidget,
        );
      }
      if (scene == 'followers-followed') {
        await t.tap(find.bySemanticsLabel('Follow back James Smith'));
        await t.pumpAndSettle();
        expect(find.bySemanticsLabel('Follow back James Smith'), findsNothing);
      }
      if (scene == 'foreign-james') {
        expect(find.byTooltip('Profile options'), findsOneWidget);
        expect(find.text('FOLLOWING'), findsOneWidget);
      }
      if (scene == 'foreign-share') {
        await t.tap(find.byTooltip('Share profile'));
        await t.pumpAndSettle();
        expect(
          find.bySemanticsLabel(
            'Profile QR code: https://cocenglish.test/profile/James%20Smith',
          ),
          findsOneWidget,
        );
      }
      if (scene == 'foreign-weekly') {
        await t.ensureVisible(find.text('Weekly progress'));
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('profile-weekly-chart')).hitTestable(),
          findsOneWidget,
        );
      }
      if (scene == 'foreign-lower') {
        final position = t
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        position.jumpTo(position.maxScrollExtent);
        await t.pumpAndSettle();
        expect(find.text('REPORT USER').hitTestable(), findsOneWidget);
        expect(find.text('BLOCK USER').hitTestable(), findsOneWidget);
        expect(
          find.bySemanticsLabel('Legend, 4 of 10').hitTestable(),
          findsOneWidget,
        );
      }
      if (scene == 'foreign-awards') {
        expect(find.text('132'), findsOneWidget);
        expect(find.byTooltip('Monthly badges'), findsNothing);
      }
      if (scene == 'foreign-award-detail') {
        expect(find.text('Perfect Week'), findsOneWidget);
        expect(find.text('CLAIM REWARD'), findsNothing);
      }
      if (scene == 'monthly-2025') {
        expect(find.text('2025 Badges'), findsOneWidget);
      }
      if (scene == 'monthly-2024') {
        await t.scrollUntilVisible(
          find.text('2024 Badges'),
          300,
          scrollable: find
              .descendant(
                of: find.byKey(const PageStorageKey('monthly-badges-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await t.pumpAndSettle();
        expect(find.text('2024 Badges').hitTestable(), findsOneWidget);
      }
      if (scene == 'own-lower' || scene.startsWith('family-')) {
        final scrollable = t.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
        await t.pumpAndSettle();
        expect(find.text('MONTHLY BADGES'), findsOneWidget);
        expect(find.byTooltip('Settings').hitTestable(), findsOneWidget);
      }
      if (scene == 'score-locked') {
        c.read(scoreInformationProvider.notifier).selectRange(8);
        await t.drag(find.byType(ListView).first, const Offset(-900, 0));
        await t.pumpAndSettle();
        expect(
          find.text('Course content at this Score range is not yet available.'),
          findsOneWidget,
        );
      }
      if (scene == 'course-score') {
        await t.tap(find.byTooltip('Courses'));
        await t.pumpAndSettle();
        expect(find.text('MORE ABOUT SCORE'), findsOneWidget);
      }
      if (scene.startsWith('own-')) {
        expect(find.byTooltip('Settings'), findsOneWidget);
        expect(find.byTooltip('Profile'), findsOneWidget);
      }
      if (scene == 'followers') {
        expect(find.text('No followers yet'), findsOneWidget);
      }
      await t.runAsync(
        () => ReferenceArt.preloadFiles(
          t
              .widgetList<ReferenceArt>(find.byType(ReferenceArt))
              .map((art) => art.region.file),
        ),
      );
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 350)),
      );
      await t.pump();
      if (const {
        'own-saved',
        'foreign-james',
        'foreign-share',
      }.contains(scene)) {
        expect(
          find.byType(rive.RiveWidget),
          findsWidgets,
          reason: '$scene must capture the original avatar rig, not a fallback',
        );
      }
      await t.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final frame = await boundary.toImage(pixelRatio: ratio);
        final bytes = (await frame.toByteData(format: ui.ImageByteFormat.png))!;
        final file = File('../../docs/design/qa/profile-source/$scene.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes.buffer.asUint8List());
        frame.dispose();
      });
      expect(t.takeException(), isNull, reason: scene);
      if (scene == 'foreign-share') {
        await t.tap(find.byTooltip('Close profile link'));
        await t.pumpAndSettle();
      }
    }
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
}
