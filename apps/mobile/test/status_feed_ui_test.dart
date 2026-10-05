import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/progress/application/social_controller.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/presentation/social_screens.dart';
import 'package:cocenglish/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<ProviderContainer> app(WidgetTester tester, String path) async {
  await tester.pumpWidget(
    MainApp(
      initial: OnboardingState(
        step: OnboardingStep.lessonEntry,
        language: 'English',
      ),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byTooltip('Practice'));
  final container = ProviderScope.containerOf(context);
  GoRouter.of(context).push(path);
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('actual league status sheet cancels draft, commits and clears', (
    tester,
  ) async {
    final c = await app(tester, '/league');
    c.read(previewControllerProvider.notifier).optIntoLeague();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Set your status'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Popcorn status'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Set your status'))).pop();
    await tester.pumpAndSettle();
    expect(c.read(statusControllerProvider).selected, isNull);
    expect(c.read(statusControllerProvider).draft, isNull);
    await tester.tap(find.byTooltip('Set your status'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Popcorn status'));
    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
    expect(c.read(statusControllerProvider).selected, 'popcorn');
    expect(find.byType(StatusPickerSheet), findsNothing);
    await tester.tap(find.byTooltip('Set your status'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('CLEAR STATUS'));
    await tester.tap(find.text('CLEAR STATUS'));
    await tester.pumpAndSettle();
    expect(c.read(statusControllerProvider).selected, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'actual status insufficient purchase preserves draft and funded buy spends once',
    (tester) async {
      final c = await app(tester, '/league');
      c.read(previewControllerProvider.notifier).optIntoLeague();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Set your status'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Cool Duo status, 500 gems'));
      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('USE GEMS'));
      await tester.pumpAndSettle();
      expect(find.text('Not enough gems'), findsOneWidget);
      expect(c.read(statusControllerProvider).draft, 'cool');
      expect(c.read(previewWalletProvider), 5);
      await tester.tap(find.text('OK'));
      c.read(previewControllerProvider.notifier).useDemoBalance();
      await tester.pumpAndSettle();
      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('USE GEMS'));
      await tester.pumpAndSettle();
      expect(find.byType(StatusPickerSheet), findsNothing);
      expect(c.read(statusControllerProvider).selected, 'cool');
      expect(c.read(previewWalletProvider), 535);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'actual feed adds friends, profile identity and comment validation work',
    (tester) async {
      final c = await app(tester, '/feed');
      await tester.tap(find.text('ADD 2 FRIENDS'));
      await tester.pumpAndSettle();
      expect(c.read(previewControllerProvider).following, {'Alex', 'Sam Lee'});
      await tester.tap(find.text('VIEW PROFILE').last);
      await tester.pumpAndSettle();
      expect(find.text('Sam Lee'), findsWidgets);
      await tester.tap(find.byTooltip('Back').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.bySemanticsLabel('Comment first-friend'),
        500,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.bySemanticsLabel('Comment first-friend'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('POST'));
      await tester.pumpAndSettle();
      expect(
        find.text('Write a comment between 1 and 280 characters.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'Nice work!');
      await tester.tap(find.text('POST'));
      await tester.pumpAndSettle();
      expect(find.text('Nice work!'), findsOneWidget);
      expect(c.read(feedControllerProvider).comments['first-friend'], [
        'Nice work!',
      ]);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.tap(find.text('CLOSE'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('feed and actual status modal width$width text$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final c = ProviderContainer();
        addTearDown(c.dispose);
        final key = GlobalKey();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: c,
            child: MaterialApp(
              theme: referenceTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  key: key,
                  builder: (context) => const FeedScreen(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        c.read(feedControllerProvider.notifier).addSuggested();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.bySemanticsLabel('Comment first-friend'),
          500,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final widgetRef = tester.element(find.byType(FeedScreen)) as WidgetRef;
        final future = showStatusPicker(key.currentContext!, widgetRef);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('CLEAR STATUS'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('CLEAR STATUS'));
        await tester.pumpAndSettle();
        await future;
        expect(tester.takeException(), isNull);
      });
    }
  }
}
