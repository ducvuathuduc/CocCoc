import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/core/design/character_motion.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/application/unit_skip_controller.dart';
import 'package:cocenglish/features/learning/domain/unit_skip.dart';
import 'package:cocenglish/features/learning/presentation/unit_skip_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixture = UnitSkipFixture(
  questions: <UnitSkipQuestion>[
    UnitSkipQuestion(
      id: 'visit-paris',
      lesson: 'Travel',
      prompt: 'Bạn có đang ghé thăm Paris không?',
      tokens: <UnitSkipToken>[
        UnitSkipToken(id: 'are', text: 'Are'),
        UnitSkipToken(id: 'you', text: 'you'),
        UnitSkipToken(id: 'visiting', text: 'visiting'),
        UnitSkipToken(id: 'paris', text: 'Paris?'),
        UnitSkipToken(id: 'like', text: 'like'),
      ],
      answerTokenIds: <String>['are', 'you', 'visiting', 'paris'],
    ),
    UnitSkipQuestion(
      id: 'study-english',
      lesson: 'School',
      prompt: 'Tôi thích học tiếng Anh.',
      tokens: <UnitSkipToken>[
        UnitSkipToken(id: 'i', text: 'I'),
        UnitSkipToken(id: 'like', text: 'like'),
        UnitSkipToken(id: 'learning', text: 'learning'),
        UnitSkipToken(id: 'english', text: 'English.'),
      ],
      answerTokenIds: <String>['i', 'like', 'learning', 'english'],
    ),
    UnitSkipQuestion(
      id: 'breakfast',
      lesson: 'Daily routine',
      prompt: 'Chúng tôi ăn sáng lúc bảy giờ.',
      tokens: <UnitSkipToken>[
        UnitSkipToken(id: 'we', text: 'We'),
        UnitSkipToken(id: 'eat', text: 'eat'),
        UnitSkipToken(id: 'breakfast', text: 'breakfast'),
        UnitSkipToken(id: 'seven', text: 'at seven.'),
      ],
      answerTokenIds: <String>['we', 'eat', 'breakfast', 'seven'],
    ),
  ],
);

ProviderContainer _container() => ProviderContainer(
  overrides: [unitSkipFixtureProvider.overrideWithValue(_fixture)],
);

void _answerCorrectly(UnitSkipController controller) {
  for (final id in controller.question!.answerTokenIds) {
    controller.toggleToken(id);
  }
  controller.check();
}

void main() {
  test('invalid unit is safe and authored units stay within 2 through 8', () {
    final invalid = _container();
    addTearDown(invalid.dispose);

    expect(
      invalid.read(unitSkipControllerProvider(1)).stage,
      UnitSkipStage.unavailable,
    );
    expect(
      invalid.read(unitSkipControllerProvider(9)).stage,
      UnitSkipStage.unavailable,
    );
    for (var unit = 2; unit <= 8; unit++) {
      final state = invalid.read(unitSkipControllerProvider(unit));
      expect(state.unit, unit);
      expect(state.section, 1);
      expect(state.sectionCheck, isFalse);
      expect(state.questions.length, greaterThanOrEqualTo(3));
    }
  });

  test('provider identity separates section checks from unit checks', () {
    final container = _container();
    addTearDown(container.dispose);
    final unit = unitSkipControllerProvider(2);
    final section = unitSkipControllerProvider(
      2,
      section: 2,
      sectionCheck: true,
    );
    final sectionUnit = unitSkipControllerProvider(2, section: 2);

    expect(section, isNot(same(unit)));
    expect(sectionUnit, isNot(same(section)));
    expect(container.read(unit).section, 1);
    expect(container.read(unit).sectionCheck, isFalse);
    expect(container.read(section).section, 2);
    expect(container.read(section).sectionCheck, isTrue);
    expect(container.read(sectionUnit).section, 2);
    expect(container.read(sectionUnit).sectionCheck, isFalse);

    container.read(unit.notifier).start();
    expect(container.read(unit).stage, UnitSkipStage.answering);
    expect(container.read(section).stage, UnitSkipStage.intro);
    expect(container.read(sectionUnit).stage, UnitSkipStage.intro);
    expect(
      container
          .read(unitSkipControllerProvider(2, section: 3, sectionCheck: true))
          .stage,
      UnitSkipStage.unavailable,
    );
  });

  test('fixture override is snapshotted before source lists can mutate', () {
    final sourceTokens = <UnitSkipToken>[
      const UnitSkipToken(id: 'we', text: 'We'),
      const UnitSkipToken(id: 'learn', text: 'learn.'),
    ];
    final sourceAnswer = <String>['we', 'learn'];
    final sourceQuestions = <UnitSkipQuestion>[
      UnitSkipQuestion(
        id: 'one',
        lesson: 'One',
        prompt: 'Chúng tôi học.',
        tokens: sourceTokens,
        answerTokenIds: sourceAnswer,
      ),
      ..._fixture.questions.skip(1),
    ];
    final container = ProviderContainer(
      overrides: [
        unitSkipFixtureProvider.overrideWithValue(
          UnitSkipFixture(questions: sourceQuestions),
        ),
      ],
    );
    addTearDown(container.dispose);
    final provider = unitSkipControllerProvider(2);

    final built = container.read(provider);
    sourceTokens.add(const UnitSkipToken(id: 'later', text: 'later'));
    sourceAnswer.add('later');
    sourceQuestions.clear();

    expect(built.questions, hasLength(3));
    expect(built.questions.first.tokens, hasLength(2));
    expect(built.questions.first.answerTokenIds, <String>['we', 'learn']);
    expect(() => built.questions.clear(), throwsUnsupportedError);
    expect(() => built.questions.first.tokens.clear(), throwsUnsupportedError);
    expect(
      () => built.questions.first.answerTokenIds.clear(),
      throwsUnsupportedError,
    );
  });

  test('malformed fixture override is unavailable instead of throwing', () {
    final container = ProviderContainer(
      overrides: [
        unitSkipFixtureProvider.overrideWithValue(
          const UnitSkipFixture(
            questions: <UnitSkipQuestion>[
              UnitSkipQuestion(
                id: 'short',
                lesson: 'Short',
                prompt: 'Quá ngắn.',
                tokens: <UnitSkipToken>[
                  UnitSkipToken(id: 'short', text: 'Short'),
                ],
                answerTokenIds: <String>['missing'],
              ),
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(unitSkipControllerProvider(2)).stage,
      UnitSkipStage.unavailable,
    );
  });

  test('wrong checks preserve input and consume one bounded heart', () {
    final container = _container();
    addTearDown(container.dispose);
    final controller = container.read(unitSkipControllerProvider(2).notifier);
    controller.start();
    controller.toggleToken('like');
    controller.check();

    var state = container.read(unitSkipControllerProvider(2));
    expect(state.stage, UnitSkipStage.feedback);
    expect(state.correct, isFalse);
    expect(state.hearts, 4);
    expect(state.selectedTokenIds, <String>['like']);

    controller.check();
    expect(container.read(unitSkipControllerProvider(2)).hearts, 4);
    controller.continueAfterFeedback();
    state = container.read(unitSkipControllerProvider(2));
    expect(state.stage, UnitSkipStage.answering);
    expect(state.questionIndex, 0);
    expect(state.selectedTokenIds, <String>['like']);
  });

  test('last-heart warning appears once before failure', () {
    final container = _container();
    addTearDown(container.dispose);
    final controller = container.read(unitSkipControllerProvider(2).notifier);
    controller.start();

    for (var mistake = 0; mistake < 4; mistake++) {
      if (mistake == 0) controller.toggleToken('like');
      controller.check();
      expect(container.read(unitSkipControllerProvider(2)).hearts, 4 - mistake);
      controller.continueAfterFeedback();
    }
    expect(
      container.read(unitSkipControllerProvider(2)).stage,
      UnitSkipStage.lastHeartWarning,
    );
    controller.continueAfterWarning();
    controller.check();
    expect(container.read(unitSkipControllerProvider(2)).hearts, 0);
    controller.continueAfterFeedback();
    expect(
      container.read(unitSkipControllerProvider(2)).stage,
      UnitSkipStage.failed,
    );
    controller.continueAfterWarning();
    expect(
      container.read(unitSkipControllerProvider(2)).stage,
      UnitSkipStage.failed,
    );
  });

  test('each question advances only after correct feedback', () {
    final container = _container();
    addTearDown(container.dispose);
    final controller = container.read(unitSkipControllerProvider(3).notifier);
    controller.start();

    for (var question = 0; question < _fixture.questions.length; question++) {
      expect(controller.question!.id, _fixture.questions[question].id);
      _answerCorrectly(controller);
      expect(
        container.read(unitSkipControllerProvider(3)).stage,
        UnitSkipStage.feedback,
      );
      controller.continueAfterFeedback();
    }
    expect(
      container.read(unitSkipControllerProvider(3)).stage,
      UnitSkipStage.passed,
    );
    expect(controller.acknowledgePass(), isTrue);
    expect(controller.acknowledgePass(), isFalse);
  });

  test('autoDispose starts a fresh entry after the listener leaves', () async {
    final container = _container();
    addTearDown(container.dispose);
    final provider = unitSkipControllerProvider(2);
    final subscription = container.listen(provider, (_, _) {});
    container.read(provider.notifier).start();
    expect(container.read(provider).stage, UnitSkipStage.answering);

    subscription.close();
    await container.pump();

    expect(container.read(provider).stage, UnitSkipStage.intro);
    expect(container.read(provider).hearts, 5);
  });

  testWidgets('cancel and system back preserve learning balances', (
    tester,
  ) async {
    var closes = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [unitSkipFixtureProvider.overrideWithValue(_fixture)],
        child: MaterialApp(
          theme: referenceTheme(),
          home: UnitSkipScreen(
            unit: 2,
            onClose: () => closes++,
            onPassed: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    final context = tester.element(find.byType(UnitSkipScreen));
    final container = ProviderScope.containerOf(context);
    final before = container.read(learningStateProvider);

    await tester.tap(find.text('NOT NOW'));
    await tester.pump();
    expect(closes, 1);
    expect(container.read(learningStateProvider).xp, before.xp);
    expect(container.read(learningStateProvider).gems, before.gems);

    await tester.tap(find.text('NOT NOW'));
    await tester.pump();
    expect(closes, 1);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(closes, 1);
    expect(container.read(learningStateProvider).xp, before.xp);
  });

  testWidgets('optional target label changes destination copy only', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [unitSkipFixtureProvider.overrideWithValue(_fixture)],
        child: MaterialApp(
          theme: referenceTheme(),
          home: UnitSkipScreen(
            unit: 2,
            section: 2,
            sectionCheck: true,
            targetLabel: 'Section 2',
            onClose: () {},
            onPassed: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Pass this test to jump ahead to Section 2!'),
      findsOneWidget,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(UnitSkipScreen)),
    );
    final state = container.read(
      unitSkipControllerProvider(2, section: 2, sectionCheck: true),
    );
    expect(state.unit, 2);
    expect(state.section, 2);
    expect(state.sectionCheck, isTrue);
  });

  testWidgets(
    'system back pops a routed challenge without callback recursion',
    (tester) async {
      var closes = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [unitSkipFixtureProvider.overrideWithValue(_fixture)],
          child: MaterialApp(
            theme: referenceTheme(),
            initialRoute: '/skip',
            routes: {
              '/': (_) => const Scaffold(body: Text('Learning path')),
              '/skip': (context) => UnitSkipScreen(
                unit: 2,
                onClose: () {
                  closes++;
                  Navigator.of(context).pop();
                },
                onPassed: () {},
              ),
            },
          ),
        ),
      );
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Learning path'), findsOneWidget);
      expect(closes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed continue closes once', (tester) async {
    var closes = 0;
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [unitSkipFixtureProvider.overrideWithValue(_fixture)],
        child: MaterialApp(
          theme: referenceTheme(),
          home: UnitSkipScreen(
            unit: 2,
            onClose: () => closes++,
            onPassed: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    container = ProviderScope.containerOf(
      tester.element(find.byType(UnitSkipScreen)),
    );
    final controller = container.read(unitSkipControllerProvider(2).notifier);
    controller.start();
    for (var i = 0; i < 5; i++) {
      if (i == 0) controller.toggleToken('like');
      controller.check();
      controller.continueAfterFeedback();
      if (container.read(unitSkipControllerProvider(2)).stage ==
          UnitSkipStage.lastHeartWarning) {
        controller.continueAfterWarning();
      }
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUE'));
    expect(closes, 1);
    await tester.tap(find.text('CONTINUE'));
    expect(closes, 1);
  });

  testWidgets('fresh passed entry calls back once without fake XP', (
    tester,
  ) async {
    var passes = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [unitSkipFixtureProvider.overrideWithValue(_fixture)],
        child: MaterialApp(
          theme: referenceTheme(),
          home: UnitSkipScreen(
            unit: 2,
            onClose: () {},
            onPassed: () => passes++,
          ),
        ),
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(UnitSkipScreen)),
    );
    final controller = container.read(unitSkipControllerProvider(2).notifier);

    controller.start();
    while (container.read(unitSkipControllerProvider(2)).stage !=
        UnitSkipStage.passed) {
      _answerCorrectly(controller);
      controller.continueAfterFeedback();
    }
    await tester.pumpAndSettle();
    expect(find.text('CLAIM XP'), findsNothing);
    expect(find.text('CONTINUE'), findsOneWidget);
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();
    expect(passes, 1);
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();
    expect(passes, 1);
  });

  testWidgets(
    'unit skip Lin resets across retry and question feedback epochs',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [unitSkipFixtureProvider.overrideWithValue(_fixture)],
          child: MaterialApp(
            theme: referenceTheme(),
            home: UnitSkipScreen(
              unit: 2,
              section: 3,
              onClose: () {},
              onPassed: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(UnitSkipScreen)),
      );
      final provider = unitSkipControllerProvider(2, section: 3);
      final controller = container.read(provider.notifier);
      final learningBefore = container.read(learningStateProvider);

      CharacterMotion motion() =>
          tester.widget<CharacterMotion>(find.byType(CharacterMotion));

      controller.start();
      await tester.pump();
      expect(motion().character, LessonCharacter.lin);
      expect(motion().reaction, CharacterReaction.reset);
      expect(
        motion().epoch,
        'unit-skip:section=3:unit=2:sectionCheck=false:question=0',
      );
      expect(motion().width, 92);
      expect(motion().height, 174);

      controller.toggleToken('like');
      controller.check();
      await tester.pump();
      expect(motion().reaction, CharacterReaction.incorrect);

      controller.continueAfterFeedback();
      await tester.pump();
      expect(motion().reaction, CharacterReaction.reset);
      expect(motion().epoch, contains('question=0'));

      controller.toggleToken('like');
      for (final id in controller.question!.answerTokenIds) {
        controller.toggleToken(id);
      }
      controller.check();
      await tester.pump();
      expect(motion().reaction, CharacterReaction.correct);

      controller.continueAfterFeedback();
      await tester.pump();
      expect(motion().reaction, CharacterReaction.reset);
      expect(
        motion().epoch,
        'unit-skip:section=3:unit=2:sectionCheck=false:question=1',
      );
      expect(container.read(learningStateProvider), same(learningBefore));
    },
  );

  testWidgets('warning and failure fit normal and compact text two layouts', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final layout in <(double, double)>[(390, 1), (320, 2)]) {
      tester.view.physicalSize = Size(layout.$1, 568);
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey<(double, double)>(layout),
          overrides: [unitSkipFixtureProvider.overrideWithValue(_fixture)],
          child: MaterialApp(
            theme: referenceTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(layout.$2),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: UnitSkipScreen(unit: 2, onClose: () {}, onPassed: () {}),
          ),
        ),
      );
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(UnitSkipScreen)),
      );
      final provider = unitSkipControllerProvider(2);
      final controller = container.read(provider.notifier);
      controller.start();
      controller.toggleToken('like');
      for (var mistake = 0; mistake < 4; mistake++) {
        controller.check();
        controller.continueAfterFeedback();
      }
      await tester.pumpAndSettle();

      expect(
        find.text('Careful! You can only make 1 more mistake!'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull, reason: '$layout warning');

      controller.continueAfterWarning();
      controller.check();
      controller.continueAfterFeedback();
      await tester.pumpAndSettle();

      expect(
        find.text("You didn't unlock Unit 2, but you can try again later!"),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull, reason: '$layout failure');
    }
  });

  testWidgets(
    '320 wide text scale two scrolls and exposes selected semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [unitSkipFixtureProvider.overrideWithValue(_fixture)],
          child: MaterialApp(
            theme: referenceTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: UnitSkipScreen(unit: 8, onClose: () {}, onPassed: () {}),
          ),
        ),
      );
      await tester.pump();
      await tester.ensureVisible(find.text("LET'S GO"));
      await tester.tap(find.text("LET'S GO"));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Are'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Are'));
      await tester.pump();

      expect(find.bySemanticsLabel('Are, selected'), findsOneWidget);
      await tester.ensureVisible(find.text('CHECK'));
      expect(find.text('CHECK'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}
