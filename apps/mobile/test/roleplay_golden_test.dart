import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/practice/application/journey_controller.dart';
import 'package:cocenglish/features/practice/presentation/journey_screens.dart';
import 'package:cocenglish/features/roleplay/application/roleplay_controller.dart';
import 'package:cocenglish/features/roleplay/presentation/roleplay_screens.dart';
import 'package:cocenglish/features/roleplay/presentation/roleplay_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_fonts.dart';
import 'support/settle_images.dart';

typedef _Setup = void Function(ProviderContainer c);

void _airport(ProviderContainer c, {bool intro = false, int replies = 0}) {
  final vm = c.read(journeyControllerProvider('roleplay').notifier);
  vm.pickScenario('airport');
  vm.start();
  if (intro) vm.dismissIntro();
  for (final r in [
    'I am going to the airport',
    'Yes to the airport',
    'By card',
    'Thanks',
  ].take(replies)) {
    vm.edit(r);
    vm.send();
  }
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await ReferenceArt.preloadFiles(RoleplayArt.files);
  });

  final screens = <String, (Widget, _Setup?)>{
    'library': (const RoleplayLibraryScreen(), null),
    'topic': (const RoleplayTopicScreen(topicId: 'travel'), null),
    'max_intro': (const RoleplayMaxIntroScreen(scenarioId: 'airport'), null),
    'session_intro': (
      const JourneyScreen(kind: 'roleplay', clockEnabled: false),
      (c) => _airport(c),
    ),
    'session_chat': (
      const JourneyScreen(kind: 'roleplay', clockEnabled: false),
      (c) => _airport(c, intro: true),
    ),
    'well_done': (
      const JourneyScreen(kind: 'roleplay', clockEnabled: false),
      (c) => _airport(c, intro: true, replies: 4),
    ),
    'feedback': (
      const RoleplayFeedbackScreen(),
      (c) => _airport(c, intro: true, replies: 4),
    ),
    'results': (
      const RoleplayResultsScreen(),
      (c) => _airport(c, intro: true, replies: 4),
    ),
  };

  for (final entry in screens.entries) {
    testWidgets('roleplay ${entry.key} golden 393', (t) async {
      t.view.physicalSize = const Size(393, 852);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final c = ProviderContainer();
      addTearDown(c.dispose);
      entry.value.$2?.call(c);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: referenceTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(top: 54, bottom: 34),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: RepaintBoundary(
              key: const ValueKey('page'),
              child: entry.value.$1,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await settleImages(t);
      expect(t.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('page')),
        matchesGoldenFile('goldens/roleplay/${entry.key}.png'),
      );
    });
  }

  testWidgets('roleplay library collapsed header golden 393', (t) async {
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: referenceTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 54, bottom: 34),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: const RepaintBoundary(
            key: ValueKey('page'),
            child: RoleplayLibraryScreen(),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.drag(find.byType(CustomScrollView), const Offset(0, -270));
    await t.pumpAndSettle();
    await settleImages(t);
    expect(find.text('Roleplays'), findsOneWidget);
    await expectLater(
      find.byKey(const ValueKey('page')),
      matchesGoldenFile('goldens/roleplay/library_scrolled.png'),
    );
  });

  for (final width in [360.0, 430.0]) {
    testWidgets('roleplay screens fit width $width at text x2', (t) async {
      t.view.physicalSize = Size(width, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      for (final entry in screens.entries) {
        final c = ProviderContainer();
        entry.value.$2?.call(c);
        await t.pumpWidget(
          UncontrolledProviderScope(
            container: c,
            child: MaterialApp(
              theme: referenceTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: entry.value.$1,
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: entry.key);
        await t.pumpWidget(const SizedBox());
        c.dispose();
      }
    });
  }

  test('library state starts with the restaurant featured for review', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final s = c.read(roleplayLibraryControllerProvider);
    expect(s.featuredId, 'restaurant');
    expect(s.progressOf('restaurant').stars, 2);
  });
}
