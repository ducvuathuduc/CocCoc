import 'package:cocenglish/features/practice/application/journey_controller.dart';
import 'package:cocenglish/features/practice/data/stories_repository.dart';
import 'package:cocenglish/features/practice/domain/journey_models.dart';
import 'package:cocenglish/features/practice/presentation/story_library.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cocenglish/main.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';

void main() {
  test(
    'wrong choices and bank order are graded, same story keeps the draft',
    () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final vm = c.read(journeyControllerProvider('story').notifier);
      vm
        ..pickStory('jacket')
        ..start()
        ..continueReading()
        ..edit('kept draft');
      vm.select(
        vm.question!.options.firstWhere(
          (v) => !vm.question!.answer.contains(v),
        ),
      );
      final before = c.read(journeyControllerProvider('story'));
      expect(vm.pickStory('missing'), isFalse);
      expect(vm.pickStory('jacket'), isTrue);
      final after = c.read(journeyControllerProvider('story'));
      expect(after.selected, before.selected);
      expect(after.draft, 'kept draft');
      expect(after.step, before.step);
      vm.check();
      expect(c.read(journeyControllerProvider('story')).feedback, isFalse);
      expect(c.read(journeyControllerProvider('story')).correct, 0);
      expect(c.read(journeyControllerProvider('story')).attempted, 1);
      vm.next();
      vm
        ..select(vm.question!.answer.single)
        ..check()
        ..next();
      for (final answer in vm.question!.answer.reversed) {
        vm.select(answer);
      }
      vm.check();
      expect(c.read(journeyControllerProvider('story')).feedback, isFalse);
      expect(c.read(journeyControllerProvider('story')).correct, 1);
      expect(c.read(journeyControllerProvider('story')).attempted, 3);
    },
  );
  testWidgets('close and reopen a story restores its selected answer', (
    tester,
  ) async {
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
    await tester.ensureVisible(find.text('Stories'));
    await tester.tap(find.text('Stories'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('I Want This Jacket!'));
    await tester.tap(find.text('I Want This Jacket!'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('START'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    final falseOption = find.byWidgetPredicate(
      (w) => w is Icon && w.semanticLabel == 'False',
    );
    await tester.tap(falseOption);
    await tester.pumpAndSettle();
    final context = tester.element(falseOption);
    final c = ProviderScope.containerOf(context);
    final before = c.read(journeyControllerProvider('story'));
    await tester.tap(find.byTooltip('Exit story'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('END LESSON'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RESUME'));
    await tester.pumpAndSettle();
    final after = c.read(journeyControllerProvider('story'));
    expect(after.selected, before.selected);
    expect(after.step, before.step);
    expect(tester.takeException(), isNull);
  });
  test('each library story uses its own English questions and invalid IDs preserve the draft', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final vm = c.read(journeyControllerProvider('story').notifier);
    for (final story in englishStoryLibrary.values) {
      expect(vm.pickStory(story.id), isTrue);
      vm.start();
      expect(vm.story.title, story.title);
      expect(vm.question!.prompt, story.title);
      expect(vm.pickStory('missing'), isFalse);
      expect(c.read(journeyControllerProvider('story')).storyId, story.id);
      while (!c.read(journeyControllerProvider('story')).complete) {
        final q = vm.question!;
        if (q.kind == JourneyKind.reading) {
          vm.continueReading();
        } else {
          for (final answer in q.answer) {
            vm.select(answer);
          }
          vm.check();
          expect(
            c.read(journeyControllerProvider('story')).feedback,
            isTrue,
            reason: story.id,
          );
          vm.next();
        }
      }
    }
  });
  for (final width in [360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('library card titles fit $width text $scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: referenceTheme(),
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 844),
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: const StoryLibraryScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('I Want This Jacket!'), findsOneWidget);
        expect(find.text('A Big Family'), findsOneWidget);
      });
    }
  }
}
