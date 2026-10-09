import 'package:cocenglish/features/practice/application/journey_controller.dart';
import 'package:cocenglish/features/practice/presentation/journey_screens.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:flutter/material.dart';
import 'package:cocenglish/main.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'practice opens Roleplay, submits native input, and reviews the actual replies',
    (tester) async {
      await tester.pumpWidget(
        MainApp(
          initial: OnboardingState(
            step: OnboardingStep.lessonEntry,
            language: 'English',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Practice'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Roleplay'));
      await tester.tap(find.text('Roleplay'));
      await tester.pumpAndSettle();
      expect(find.text('Dine at a Restaurant'), findsOneWidget);
      await tester.tap(find.text('START'));
      await tester.pumpAndSettle();
      for (final reply in ['Yes, please.', 'Water, please.', 'Thank you.']) {
        await tester.enterText(find.byType(TextFormField), reply);
        await tester.tap(find.byTooltip('Send reply'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Roleplay complete!'), findsOneWidget);
      await tester.tap(find.text('REVIEW FEEDBACK'));
      await tester.pumpAndSettle();
      for (final reply in ['Yes, please.', 'Water, please.', 'Thank you.']) {
        await tester.scrollUntilVisible(
          find.text(reply),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text(reply), findsOneWidget);
      }
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(find.text('Skill practice'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('English journey states fit width$width text$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final kind in ['story', 'radio', 'roleplay']) {
          final c = ProviderContainer();
          final vm = c.read(journeyControllerProvider(kind).notifier);
          vm.start();
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: c,
              child: MaterialApp(
                theme: referenceTheme(),
                home: JourneyScreen(kind: kind),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: kind);
          if (kind == 'roleplay') {
            vm
              ..edit('Yes, please.')
              ..send()
              ..edit('Water, please.')
              ..send()
              ..edit('Thank you.')
              ..send();
          } else {
            vm.continueReading();
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            while (!c.read(journeyControllerProvider(kind)).complete) {
              final q = vm.question!;
              if (q.kind.name == 'pairs') {
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
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason: '$kind/${q.kind.name}',
              );
            }
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$kind/complete');
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          c.dispose();
        }
      });
    }
  }
  test(
    'story preserves a wrong selection through feedback and finishes once',
    () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final vm = c.read(journeyControllerProvider('story').notifier);
      vm.start();
      vm.continueReading();
      expect(c.read(journeyControllerProvider('story')).step, 1);
      vm.select('True');
      vm.check();
      expect(c.read(journeyControllerProvider('story')).feedback, false);
      expect(c.read(journeyControllerProvider('story')).selected, ['True']);
      vm.next();
      vm.select('mother');
      vm.check();
      vm.next();
      vm.select('my mother');
      vm.check();
      vm.next();
      for (final word in ['You', 'have', 'a', 'big', 'family']) {
        vm.select(word);
      }
      vm.check();
      vm.next();
      expect(c.read(journeyControllerProvider('story')).complete, true);
      final done = c.read(journeyControllerProvider('story'));
      vm.next();
      expect(c.read(journeyControllerProvider('story')), same(done));
      expect(done.correct, 3);
      expect(done.attempted, 4);
    },
  );
  test('radio cannot check half a pair, and transcript picks are editable', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final vm = c.read(journeyControllerProvider('radio').notifier);
    vm.start();
    vm.continueReading();
    vm.select('woman');
    vm.check();
    expect(c.read(journeyControllerProvider('radio')).feedback, isNull);
    vm.select('người phụ nữ');
    vm.check();
    expect(c.read(journeyControllerProvider('radio')).feedback, true);
    vm.next();
    vm.select('large');
    vm.select('cao lớn');
    vm.check();
    vm.next();
    vm.select('smart');
    vm.select('thông minh');
    vm.check();
    vm.next();
    vm.select('funny');
    vm.select('large');
    vm.select('funny');
    expect(c.read(journeyControllerProvider('radio')).selected, ['large']);
    vm.select('smart');
    vm.check();
    expect(c.read(journeyControllerProvider('radio')).feedback, true);
  });
  test(
    'roleplay preserves draft on validation, resumes, and resets deliberately',
    () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final vm = c.read(journeyControllerProvider('roleplay').notifier);
      vm.start();
      vm.edit(' ');
      vm.send();
      expect(c.read(journeyControllerProvider('roleplay')).draft, ' ');
      expect(c.read(journeyControllerProvider('roleplay')).error, isNotNull);
      vm.edit('Yes, please.');
      vm.send();
      expect(c.read(journeyControllerProvider('roleplay')).replies, [
        'Yes, please.',
      ]);
      vm.edit('Water, please.');
      expect(
        c.read(journeyControllerProvider('roleplay')).draft,
        'Water, please.',
      );
      vm.send();
      vm.edit('Thank you.');
      vm.send();
      expect(c.read(journeyControllerProvider('roleplay')).complete, true);
      vm.start();
      expect(c.read(journeyControllerProvider('roleplay')).replies, isEmpty);
      expect(c.read(journeyControllerProvider('roleplay')).draft, isEmpty);
    },
  );
}
