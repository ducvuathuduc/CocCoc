import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/hearts/application/hearts_controller.dart';
import 'package:cocenglish/features/hearts/presentation/hearts_sheets.dart';
import 'package:cocenglish/features/hearts/presentation/heart_earned_screen.dart';
import 'package:cocenglish/features/ads/presentation/ad_screen.dart';
import 'package:cocenglish/features/progress/application/extended_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/app_fonts.dart';
import '../../support/settle_images.dart';

Future<ProviderContainer> pump(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
  bool reduced = false,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => child),
      GoRoute(
        path: '/super',
        builder: (_, _) => const Scaffold(body: Text('Super destination')),
      ),
      GoRoute(
        path: '/lesson/practice',
        builder: (_, _) => const Scaffold(body: Text('Practice destination')),
      ),
      GoRoute(path: '/ad', builder: (_, _) => const AdScreen()),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Home destination')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: referenceTheme(),
        routerConfig: router,
        builder: (_, child) => MediaQuery(
          data: MediaQueryData(
            size: const Size(360, 800),
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduced,
          ),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await settleImages(tester);
  return container;
}

Widget launcher(bool lesson, VoidCallback end) => Scaffold(
  body: Builder(
    builder: (context) => TextButton(
      onPressed: () => lesson
          ? showHeartsOfferSheet(context, onEnd: end)
          : showNeedHeartsSheet(context),
      child: const Text('Open'),
    ),
  ),
);

void main() {
  setUpAll(loadAppFonts);
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'need hearts selects practice and starts a session at scale $scale',
      (tester) async {
        final c = await pump(
          tester,
          launcher(false, () {}),
          scale: scale,
          reduced: scale == 2,
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(
          find.text('You need hearts to start new lessons!'),
          findsOneWidget,
        );
        expect(find.text('4h 15m'), findsOneWidget);
        expect(find.text('Practice'), findsOneWidget);
        await tester.ensureVisible(find.text('PRACTICE TO EARN HEARTS'));
        await tester.tap(find.text('PRACTICE TO EARN HEARTS'));
        await tester.pumpAndSettle();
        expect(find.text('Practice destination'), findsOneWidget);
        expect(c.read(heartsControllerProvider).practicePending, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('lesson sheet ends session and survives scale $scale', (
      tester,
    ) async {
      var ended = false;
      await pump(
        tester,
        launcher(true, () => ended = true),
        scale: scale,
        reduced: true,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('You ran out of hearts!'), findsOneWidget);
      expect(find.text('TRY 1 WEEK FOR FREE'), findsOneWidget);
      await tester.ensureVisible(find.text('NO THANKS'));
      await tester.tap(find.text('NO THANKS'));
      await tester.pumpAndSettle();
      expect(ended, isTrue);
      expect(tester.takeException(), isNull);
    });
    testWidgets('earned heart copy and reduced motion at scale $scale', (
      tester,
    ) async {
      await pump(
        tester,
        const HeartEarnedScreen(),
        scale: scale,
        reduced: true,
      );
      expect(
        find.text('You gained a heart! Watch an ad to gain another.'),
        findsOneWidget,
      );
      expect(find.text('EARN 1 HEART'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('trial action navigates to Super', (tester) async {
    await pump(tester, launcher(true, () {}));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TRY 1 WEEK FOR FREE'));
    await tester.pumpAndSettle();
    expect(find.text('Super destination'), findsOneWidget);
  });
  testWidgets('paid plans suppress rewarded ads', (tester) async {
    final c = await pump(tester, const HeartEarnedScreen());
    c.read(extendedControllerProvider.notifier).choosePlan('max-individual');
    c.read(extendedControllerProvider.notifier).confirmPlan();
    await tester.pumpAndSettle();
    expect(find.text('EARN 1 HEART'), findsNothing);
    expect(find.text('CONTINUE'), findsOneWidget);
  });
  testWidgets('house ad countdown unlocks CONTINUE and returns a reward', (
    tester,
  ) async {
    await pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final reward = await context.push<bool>('/ad');
              if (context.mounted && reward == true) context.go('/home');
            },
            child: const Text('Watch'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Watch'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byTooltip('Skip ad'), findsNothing);
    expect(find.text('CONTINUE'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Practice makes perfect.'), findsOneWidget);
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('Home destination'), findsOneWidget);
  });
  testWidgets('house-ad CTA can open the optional existing Super trial', (
    tester,
  ) async {
    await pump(tester, const AdScreen(offerTrial: true), reduced: true);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('Super destination'), findsOneWidget);
    GoRouter.of(tester.element(find.text('Super destination'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Home destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
