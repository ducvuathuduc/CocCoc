import 'dart:io';
import 'dart:ui' as ui;

import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/learning/presentation/sections_screen.dart';
import 'package:cocenglish/features/learning/presentation/explanation_screen.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/data/learning_repository.dart';
import 'package:cocenglish/features/practice/presentation/words_screen.dart';
import 'package:cocenglish/features/practice/presentation/journey_screens.dart';
import 'package:cocenglish/features/practice/presentation/challenge_intro.dart';
import 'package:cocenglish/features/practice/presentation/adventure_screen.dart';
import 'package:cocenglish/features/practice/presentation/story_library.dart';
import 'package:cocenglish/features/practice/application/adventure_controller.dart';
import 'package:cocenglish/features/practice/application/journey_controller.dart';
import 'package:cocenglish/features/practice/domain/journey_models.dart';
import 'package:cocenglish/features/progress/application/extended_controller.dart';
import 'package:cocenglish/features/progress/presentation/energy_screen.dart';
import 'package:cocenglish/features/progress/presentation/super_screen.dart';
import 'package:cocenglish/features/progress/presentation/max_screen.dart';
import 'package:cocenglish/features/progress/application/max_controller.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/application/timer_boost_controller.dart';
import 'package:cocenglish/features/progress/presentation/timer_boost_screen.dart';
import 'package:cocenglish/features/progress/presentation/hub_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('capture English extended states at source dimensions', (
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
        'Feather',
      )..addFont(rootBundle.load('assets/fonts/Feather.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await ReferenceArt.preloadFiles([
        'words-02',
        'sections-01',
        'sections-02',
        'energy-02',
        'super-07',
        'super-11',
        'super-12',
        'super-13',
        'story-portrait',
        'story-complete',
        'radio-host',
        'roleplay-scene',
      ]);
    });
    Future<void> save(String name, GlobalKey boundary) async {
      expect(tester.takeException(), isNull, reason: name);
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final img = await render.toImage(pixelRatio: ratio);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        final file = File('../../docs/design/qa/english-extended/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        img.dispose();
      });
    }

    for (final entry in [
      ('words', const WordsScreen()),
      ('stories-library', const StoryLibraryScreen()),
      ('stories-jacket-entry', const JourneyEntryScreen(kind: 'story')),
      ('stories-jacket-reading', const JourneyScreen(kind: 'story')),
      ('sections', const SectionsScreen()),
      ('section-details', const SectionDetailScreen(section: 1)),
      ('energy', const EnergyScreen()),
      ('super', const SuperScreen()),
      ('super-tour', const SuperTourScreen()),
      ('subscription', const SubscriptionScreen()),
      ('cancel', const CancelSubscriptionScreen()),
      ('family', const FamilyPlanScreen()),
      ('subscription-max', const SubscriptionScreen()),
      ('family-max', const FamilyPlanScreen()),
      for (final stage in [
        'offer',
        'comparison',
        'reminder-empty',
        'reminder-2',
        'reminder-3',
        'plans-individual',
        'plans-family',
        'checkout',
      ])
        ('max-$stage', const MaxScreen()),
      ('max-tour-welcome', const MaxTourScreen()),
      for (var i = 0; i <= 5; i++) ('max-tour-$i', const MaxTourScreen()),
      ('max-tour-invite', const MaxTourScreen()),
      ('max-tour-icon-on', const MaxTourScreen()),
      for (final state in ['default', 'single', 'error'])
        ('timer-sheet-$state', const ShopScreen()),
      ('timer-shop-empty', const ShopScreen()),
      ('timer-shop-owned', const ShopScreen()),
      ('timer-success', const TimerBoostSuccessScreen()),
      (
        'timer-challenge-expired',
        const JourneyScreen(kind: 'rapid', clockEnabled: false),
      ),
      for (final kind in ['story', 'radio', 'roleplay'])
        ('$kind-entry', JourneyEntryScreen(kind: kind)),
      for (var i = 0; i <= 5; i++)
        ('story-$i', const JourneyScreen(kind: 'story')),
      for (var i = 0; i <= 4; i++)
        ('radio-$i', const JourneyScreen(kind: 'radio')),
      for (var i = 0; i <= 3; i++)
        ('roleplay-$i', const JourneyScreen(kind: 'roleplay')),
      ('roleplay-feedback', const RoleplayFeedbackScreen()),
      ('explanation-wrong', const ExplanationScreen()),
      ('explanation-correct', const ExplanationScreen()),
      for (var i = 0; i <= 6; i++) ('adventure-$i', const AdventureScreen()),
      for (final kind in ['rapid', 'legendary'])
        ('$kind-intro', ChallengeIntroScreen(kind: kind)),
      for (final kind in ['rapid', 'legendary'])
        for (var i = 0; i <= 4; i++)
          ('$kind-$i', JourneyScreen(kind: kind, clockEnabled: false)),
      (
        'rapid-expired',
        const JourneyScreen(kind: 'rapid', clockEnabled: false),
      ),
    ]) {
      final c = ProviderContainer();
      final parts = entry.$1.split('-');
      if (parts.first == 'timer') {
        final vm = c.read(timerBoostControllerProvider.notifier);
        vm.begin();
        if (parts.last != 'error' && parts.last != 'empty') {
          c.read(previewControllerProvider.notifier).useDemoBalance();
        }
        if (parts.last == 'single' ||
            parts.last == 'success' ||
            parts.last == 'owned' ||
            parts.last == 'expired') {
          vm.select(1);
        }
        if (parts.last == 'error' ||
            parts.last == 'success' ||
            parts.last == 'owned' ||
            parts.last == 'expired') {
          vm.purchase();
        }
        if (parts.last == 'expired') {
          c.read(journeyControllerProvider('rapid').notifier)
            ..start()
            ..tick(105);
        }
      }
      if (entry.$1.startsWith('max-')) {
        final vm = c.read(maxControllerProvider.notifier);
        if (parts[1] == 'tour') {
          c.read(extendedControllerProvider.notifier)
            ..choosePlan(
              parts.last == 'invite' ? 'max-family' : 'max-individual',
            )
            ..confirmPlan();
          final target = parts.last == 'welcome'
              ? -1
              : parts.last == 'invite'
              ? 0
              : parts.last == 'on'
              ? 4
              : int.parse(parts.last);
          for (var i = -1; i < target; i++) {
            vm.advanceTour();
          }
          if (parts.last == 'on') vm.setAppIcon(true);
        } else if (parts[1] != 'offer') {
          vm.next();
          if (parts[1] != 'comparison') vm.next();
          if (parts.last == '2' ||
              parts.last == '3' ||
              parts[1] == 'plans' ||
              parts[1] == 'checkout') {
            vm.chooseReminder(parts.last == '3' ? 3 : 2);
          }
          if (parts[1] == 'plans' || parts[1] == 'checkout') vm.next();
          if (parts.last == 'family') vm.choosePlan('max-family');
        }
      }
      if (entry.$1 == 'subscription-max' || entry.$1 == 'family-max') {
        c.read(extendedControllerProvider.notifier)
          ..choosePlan('max-family')
          ..confirmPlan();
      }
      if (entry.$1.startsWith('stories-jacket')) {
        final vm = c.read(journeyControllerProvider('story').notifier);
        vm.pickStory('jacket');
        if (parts.last == 'reading') vm.start();
      }
      if (parts.first == 'explanation') {
        final vm = c.read(lessonControllerProvider.notifier);
        await vm.start(exercises: [mockEnglishExercises.first]);
        vm.select(parts.last == 'correct' ? 'woman' : 'boy');
        await tester.runAsync(vm.check);
      }
      if (parts.first == 'adventure') {
        final vm = c.read(adventureControllerProvider.notifier);
        final target = int.parse(parts.last);
        if (target > 0) vm.start();
        if (target > 1) vm.explore();
        if (target > 2) {
          vm
            ..select('An American passport!')
            ..check()
            ..next();
        }
        if (target > 3) vm.next();
        if (target > 4) vm.explore();
        if (target > 5) {
          vm
            ..select('passport')
            ..check()
            ..next();
        }
      }
      if ([
            'story',
            'radio',
            'roleplay',
            'rapid',
            'legendary',
          ].contains(parts.first) &&
          parts.last != 'entry' &&
          parts.last != 'intro') {
        final vm = c.read(journeyControllerProvider(parts.first).notifier);
        vm.start();
        final target = parts.last == 'expired'
            ? 0
            : int.tryParse(parts.last) ?? 3;
        if (parts.first == 'roleplay') {
          for (final reply in [
            'Yes, please.',
            'Water, please.',
            'Thank you.',
          ].take(target)) {
            vm
              ..edit(reply)
              ..send();
          }
        } else {
          while (c.read(journeyControllerProvider(parts.first)).step < target) {
            if (c.read(journeyControllerProvider(parts.first)).step == 2) {
              vm.dismissMilestone();
            }
            final q = vm.question!;
            if (q.kind == JourneyKind.reading) {
              vm.continueReading();
            } else if (q.kind == JourneyKind.pairs) {
              for (var i = 0; i < q.answer.length; i += 2) {
                vm
                  ..select(q.answer[i])
                  ..select(q.answer[i + 1])
                  ..check()
                  ..next();
              }
            } else {
              for (final value in q.answer) {
                vm.select(value);
              }
              vm
                ..check()
                ..next();
            }
          }
        }
        if (parts.last == 'expired') vm.tick(105);
      }
      if (['subscription', 'cancel', 'family'].contains(entry.$1)) {
        c.read(extendedControllerProvider.notifier)
          ..choosePlan('family')
          ..confirmPlan();
      }
      final boundary = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              theme: referenceTheme(),
              debugShowCheckedModeBanner: false,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
              home: entry.$2,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => ReferenceArt.preloadFiles(
          tester
              .widgetList<ReferenceArt>(find.byType(ReferenceArt))
              .map((art) => art.region.file),
        ),
      );
      await tester.pumpAndSettle();
      await save(entry.$1, boundary);
      if (entry.$1.startsWith('timer-sheet')) {
        await tester.ensureVisible(find.text('GET'));
        await tester.tap(find.text('GET'));
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => ReferenceArt.preloadFiles(['timer-boost-packs']),
        );
        if (parts.last == 'error') {
          await tester.tap(find.text('GET TIMER BOOSTS'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Not enough gems'));
        }
        await tester.pumpAndSettle();
        await save(entry.$1, boundary);
      }
      if (entry.$1 == 'max-checkout') {
        await tester.tap(find.text('START MY FREE WEEK'));
        await tester.pumpAndSettle();
        await tester.runAsync(() => ReferenceArt.preloadFiles(['max-icon']));
        await tester.pumpAndSettle();
        await save('max-checkout-sheet', boundary);
      }
      if (entry.$1 == 'stories-library') {
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -550),
        );
        await tester.pumpAndSettle();
        await save('stories-library-scrolled', boundary);
      }
      if (entry.$1 == 'words') {
        await tester.tap(find.text('SORT'));
        await tester.pumpAndSettle();
        await save('words-sort', boundary);
      }
      if (entry.$1 == 'super') {
        for (var i = 1; i <= 2; i++) {
          await tester.tap(find.text('START MY FREE WEEK'));
          await tester.pumpAndSettle();
          await save('super-$i', boundary);
        }
        await tester.tap(find.text('Individual'));
        await tester.pumpAndSettle();
        await save('super-selected', boundary);
      }
      if (entry.$1 == 'super-tour') {
        for (var i = 1; i <= 2; i++) {
          await tester.tap(find.text('MORE'));
          await tester.pumpAndSettle();
          await save('super-tour-$i', boundary);
        }
      }
      if (entry.$1 == 'energy') {
        c.read(extendedControllerProvider.notifier)
          ..choosePlan('individual')
          ..confirmPlan();
        await tester.pumpAndSettle();
        await save('energy-unlimited', boundary);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      c.dispose();
    }
  });
}
