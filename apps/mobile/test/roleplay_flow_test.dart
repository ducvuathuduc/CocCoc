import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/practice/application/journey_controller.dart';
import 'package:cocenglish/features/roleplay/application/roleplay_controller.dart';
import 'package:cocenglish/features/roleplay/data/roleplay_repository.dart';
import 'package:cocenglish/features/roleplay/domain/roleplay_models.dart';
import 'package:cocenglish/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'practice → library → topic → scenario → results updates progress',
    (t) async {
      t.view.physicalSize = const Size(430, 932);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            roleplayRepositoryProvider.overrideWithValue(
              const MockRoleplayRepository.reference(),
            ),
          ],
          child: MainApp(
            initial: OnboardingState(
              step: OnboardingStep.lessonEntry,
              language: 'English',
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Practice'));
      await t.pumpAndSettle();
      await _tap(t, find.text('Roleplay'));
      expect(find.text('Dine at a Restaurant'), findsOneWidget);
      await _tap(t, find.text('SEE ALL ROLEPLAYS'));

      // Library: restaurant featured for review, eight topics.
      expect(find.text('TIME TO REVIEW'), findsOneWidget);
      expect(find.text('Dine at a restaurant'), findsOneWidget);
      expect(find.text('REVIEW +40 XP'), findsWidgets);
      for (final topic in ['Daily Life', 'Travel', 'Food & Shopping']) {
        expect(find.text(topic), findsOneWidget);
      }

      await _tap(t, find.text('Travel'));
      expect(find.text('0 of 2 roleplays complete'), findsOneWidget);
      expect(find.text('Make it to the airport on time'), findsOneWidget);
      expect(find.text('Check in at a hotel'), findsOneWidget);
      await _tap(t, find.text('START +40 XP').first);

      // Max intro → generalized session screen with scenario data.
      expect(find.textContaining('Use more words to earn'), findsOneWidget);
      await _tap(t, find.text('CONTINUE'));
      expect(find.text('Make it to the airport on time'), findsOneWidget);
      expect(find.textContaining('rushing to catch a flight'), findsOneWidget);
      await _tap(t, find.text('CONTINUE'));
      expect(find.text('Hello, where are you going?'), findsOneWidget);

      // Hint chip fills the reply.
      await _tap(t, find.text('I’m going'));
      expect(
        t.state<FormFieldState<String>>(find.byType(TextFormField)).value,
        'I’m going',
      );
      for (final reply in [
        'I’m going to the airport',
        'Yes to the airport',
        'By card please',
        'Thank you',
      ]) {
        await t.enterText(find.byType(TextFormField), reply);
        await t.tap(find.byTooltip('Send reply'));
        await t.pumpAndSettle();
      }
      expect(find.text('Well done!'), findsOneWidget);
      await _tap(t, find.text('CONTINUE'));
      expect(find.text('Review your\nRoleplay feedback'), findsOneWidget);
      expect(find.text('I’m going to the airport'), findsOneWidget);
      await _tap(t, find.text('CONTINUE'));

      // 14 words → 2 stars, 30 XP, new record.
      expect(find.text('WORDS USED'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.text('NEW RECORD'), findsOneWidget);
      await _tap(t, find.text('CONTINUE'));

      expect(find.text('Make it to the airport on time'), findsOneWidget);
      expect(find.text('TIME TO REVIEW'), findsOneWidget);
      expect(find.bySemanticsLabel('2 of 3 stars'), findsOneWidget);
      await _tap(t, find.text('Travel'));
      expect(find.text('1 of 2 roleplays complete'), findsOneWidget);
      expect(find.text('Completed · best 14 words'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('library back returns to practice; topic tile semantics', (
    t,
  ) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          roleplayRepositoryProvider.overrideWithValue(
            const MockRoleplayRepository.reference(),
          ),
        ],
        child: MainApp(
          initial: OnboardingState(
            step: OnboardingStep.lessonEntry,
            language: 'English',
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Practice'));
    await t.pumpAndSettle();
    await _tap(t, find.text('Roleplay'));
    await _tap(t, find.text('SEE ALL ROLEPLAYS'));
    expect(
      find.bySemanticsLabel('Food & Shopping, 1 of 2 complete'),
      findsOneWidget,
    );
    await t.tap(find.byTooltip('Back').first);
    await t.pumpAndSettle();
    expect(find.text('Dine at a Restaurant'), findsOneWidget);
  });

  group('RoleplayLibraryController', () {
    test('record scores stars/XP and keeps best progress', () {
      final c = ProviderContainer(
        overrides: [
          roleplayRepositoryProvider.overrideWithValue(
            const MockRoleplayRepository.reference(),
          ),
        ],
      );
      addTearDown(c.dispose);
      final vm = c.read(roleplayLibraryControllerProvider.notifier);
      final low = vm.record('hotel', 5)!;
      expect((low.stars, low.xp, low.newRecord), (1, 20, true));
      final high = vm.record('hotel', 20)!;
      expect((high.stars, high.xp, high.newRecord), (3, 40, true));
      final again = vm.record('hotel', 12)!;
      expect((again.stars, again.newRecord), (2, false));
      final p = c.read(roleplayLibraryControllerProvider).progressOf('hotel');
      expect((p.stars, p.bestWords, p.completions), (3, 20, 3));
      expect(c.read(roleplayLibraryControllerProvider).featuredId, 'hotel');
      expect(vm.topicProgress('travel'), (1, 2));
      expect(vm.record('missing', 3), isNull);
    });

    test('scoring thresholds match the references', () {
      expect(roleplayStarsFor(11), 1);
      expect(roleplayStarsFor(13), 2);
      expect(roleplayXpFor(roleplayStarsFor(13)), 30);
      expect(roleplayWordCount(['Hi there ', '  ok']), 3);
    });

    test('journey controller plays scenario lines and records results', () {
      final c = ProviderContainer(
        overrides: [
          roleplayRepositoryProvider.overrideWithValue(
            const MockRoleplayRepository.reference(),
          ),
        ],
      );
      addTearDown(c.dispose);
      final vm = c.read(journeyControllerProvider('roleplay').notifier);
      expect(vm.pickScenario('nope'), isFalse);
      expect(
        vm.roleplayLines.first.prompt,
        'Hello! Would you like the chicken?',
      );
      expect(vm.pickScenario('market'), isTrue);
      vm.start();
      expect(
        c.read(journeyControllerProvider('roleplay')).scenarioId,
        'market',
      );
      for (final r in [
        'I would like mangoes',
        'three please',
        'here you are',
      ]) {
        vm.edit(r);
        vm.send();
      }
      expect(c.read(journeyControllerProvider('roleplay')).complete, isTrue);
      final lib = c.read(roleplayLibraryControllerProvider);
      expect(lib.lastResult!.scenarioId, 'market');
      expect(lib.lastResult!.wordsUsed, 9);
      // The practice-hub restaurant still records on its own scenario.
      vm.pickScenario(null);
      vm.start();
      for (final r in ['Yes, please.', 'Water, please.', 'Thank you.']) {
        vm.edit(r);
        vm.send();
      }
      expect(
        c
            .read(roleplayLibraryControllerProvider)
            .progressOf('restaurant')
            .completions,
        2,
      );
    });
  });
}
