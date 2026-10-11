import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/onboarding/application/onboarding_controller.dart';
import 'package:cocenglish/features/onboarding/data/onboarding_content_repository.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_content.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/onboarding/presentation/onboarding_flow.dart';
import 'package:cocenglish/features/onboarding/presentation/widgets/onboarding_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RenamedContent implements OnboardingContentRepository {
  @override
  OnboardingContent loadContent() => const OnboardingContent(
    welcomeTagline: 't',
    getStartedLabel: 'g',
    haveAccountLabel: 'h',
    sourceLanguageHeader: 'For Vietnamese speakers',
    fallbackLanguage: 'English',
    languages: [LanguageOption(name: 'English', flagIndex: 4)],
    knowledgeLevels: ['Level zero'],
    reasons: [],
    goals: [],
    benefits: [],
    plans: [],
    startOptions: [],
    prompts: {
      OnboardingStep.language: [PromptSegment('Which course?')],
    },
    alternatePrompts: {},
    buttonLabels: {},
    defaultButtonLabel: 'NEXT',
    savingLabel: '…',
    notNowLabel: 'NO',
    saveErrorText: 'err',
    retryLabel: 'retry',
    buildingTitle: 'B',
    buildingBody: [],
    notificationPreview: NotificationPreviewCopy(
      title: 'a',
      body: 'b',
      deny: 'c',
      allow: 'd',
    ),
    reminderDialog: DialogCopy(
      title: 'a',
      body: 'b',
      cancel: 'c',
      confirm: 'd',
    ),
    superDialog: DialogCopy(title: 'a', body: 'b', cancel: 'c', confirm: 'd'),
    progress: {OnboardingStep.language: .1},
  );
}

Widget _app(
  OnboardingState initial, {
  bool reduced = false,
  OnboardingContentRepository? content,
  Key? boundary,
}) => ProviderScope(
  overrides: [
    initialOnboardingProvider.overrideWithValue(initial),
    if (content != null)
      onboardingContentRepositoryProvider.overrideWithValue(content),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: referenceTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: child!,
    ),
    home: RepaintBoundary(key: boundary, child: const OnboardingFlow()),
  ),
);

void _phone(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

double _scaleOf(WidgetTester tester, String text) {
  final scale = tester.widget<ScaleTransition>(
    find
        .ancestor(of: find.text(text), matching: find.byType(ScaleTransition))
        .first,
  );
  return scale.scale.value;
}

void main() {
  setUpAll(() async {
    await (FontLoader('DuolingoSans')
          ..addFont(rootBundle.load('assets/fonts/DuolingoSans.ttf'))
          ..addFont(rootBundle.load('assets/fonts/DuolingoSans-Bold.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets('screen copy comes from the content repository', (tester) async {
    _phone(tester, 430);
    await tester.pumpWidget(
      _app(
        OnboardingState(step: OnboardingStep.language),
        content: _RenamedContent(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('For Vietnamese speakers'), findsOneWidget);
    expect(find.text('Which course?'), findsOneWidget);
    expect(find.text('NEXT'), findsOneWidget);
    expect(find.text('Spanish'), findsNothing);
  });

  testWidgets('selecting an option plays the select bounce', (tester) async {
    _phone(tester, 430);
    await tester.pumpWidget(
      _app(OnboardingState(step: OnboardingStep.goal, goal: 10)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('15 min / day'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(_scaleOf(tester, '15 min / day'), lessThan(1));
    await tester.pumpAndSettle();
    expect(_scaleOf(tester, '15 min / day'), 1);
  });

  testWidgets('continue slides the next step in while the old one leaves', (
    tester,
  ) async {
    _phone(tester, 430);
    await tester.pumpWidget(
      _app(OnboardingState(step: OnboardingStep.routine, language: 'French')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('Let’s set up a learning routine!'), findsOneWidget);
    expect(find.text('What’s your daily learning goal?'), findsOneWidget);
    expect(find.byType(SlideTransition), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('Let’s set up a learning routine!'), findsNothing);
  });

  testWidgets('progress bar animates its fill between steps', (tester) async {
    _phone(tester, 430);
    await tester.pumpWidget(
      _app(OnboardingState(step: OnboardingStep.routine, language: 'French')),
    );
    await tester.pumpAndSettle();
    double fill() => tester
        .widget<FractionallySizedBox>(find.byType(FractionallySizedBox).first)
        .widthFactor!;
    final start = fill();
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final mid = fill();
    await tester.pumpAndSettle();
    expect(mid, greaterThan(start));
    expect(fill(), greaterThan(mid));
  });

  testWidgets('reduced motion swaps steps and selections instantly', (
    tester,
  ) async {
    _phone(tester, 430);
    await tester.pumpWidget(
      _app(
        OnboardingState(step: OnboardingStep.knowledge, language: 'French'),
        reduced: true,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('I know some common words'));
    await tester.pump();
    expect(_scaleOf(tester, 'I know some common words'), 1);
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();
    await tester.pump();
    expect(find.text('How much French do you know?'), findsNothing);
    expect(find.text('Why are you learning French?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mascot bubble pops in on a new step', (tester) async {
    _phone(tester, 430);
    await tester.pumpWidget(
      _app(OnboardingState(step: OnboardingStep.greeting)),
    );
    await tester.pump();
    final popIn = find.ancestor(
      of: find.text('Hi there! I’m Duo!'),
      matching: find.byType(PopIn),
    );
    expect(popIn, findsOneWidget);
    double opacity() => tester
        .widget<Opacity>(
          find.descendant(of: popIn, matching: find.byType(Opacity)).first,
        )
        .opacity;
    expect(opacity(), lessThan(1));
    await tester.pumpAndSettle();
    expect(opacity(), 1);
  });

  for (final shot in [
    (
      'knowledge',
      OnboardingState(
        step: OnboardingStep.knowledge,
        language: 'French',
        knowledge: 1,
      ),
    ),
    (
      'reasons',
      OnboardingState(
        step: OnboardingStep.reasons,
        language: 'French',
        reasonIds: {0, 2, 3},
      ),
    ),
  ]) {
    testWidgets('golden ${shot.$1} 430', (tester) async {
      _phone(tester, 430);
      const key = ValueKey('onboarding-golden');
      await tester.pumpWidget(_app(shot.$2, boundary: key));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => ReferenceArt.preloadFiles(
          tester
              .widgetList<ReferenceArt>(find.byType(ReferenceArt))
              .map((art) => art.region.file)
              .toSet(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(key),
        matchesGoldenFile(
          'goldens/ui_master/sprint_onboarding_${shot.$1}_430.png',
        ),
      );
    });
  }
}
