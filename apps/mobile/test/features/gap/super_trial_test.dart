import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/super_trial/application/super_trial_provider.dart';
import 'package:cocenglish/features/super_trial/data/super_trial_repository.dart';
import 'package:cocenglish/features/super_trial/domain/super_trial_offer.dart';
import 'package:cocenglish/features/super_trial/presentation/super_trial_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/app_fonts.dart';
import '../../support/settle_images.dart';

/// Opens the trial from a launcher so the pop result is observable.
Future<({MockSuperTrialRepository repo, List<bool?> results})> pump(
  WidgetTester tester, {
  Size size = const Size(360, 800),
  double scale = 1,
  SuperTrialOffer offer = const SuperTrialOffer(),
  bool open = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repo = MockSuperTrialRepository(offer: offer);
  final results = <bool?>[];
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () async =>
                results.add(await context.push<bool>(SuperTrialScreen.route)),
            child: const Text('Open'),
          ),
        ),
      ),
      GoRoute(
        path: SuperTrialScreen.route,
        builder: (_, _) => const SuperTrialScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [superTrialRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: referenceTheme(),
        routerConfig: router,
        builder: (_, child) => MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
      ),
    ),
  );
  if (open) {
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await settleImages(tester);
  }
  return (repo: repo, results: results);
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('renders repository copy inside the bubble', (tester) async {
    await pump(tester);
    const offer = SuperTrialOffer();
    expect(find.text(offer.title), findsOneWidget);
    expect(find.text(offer.footnote), findsOneWidget);
    expect(find.text(offer.acceptLabel), findsOneWidget);
    expect(find.text(offer.declineLabel), findsOneWidget);
    expect(find.bySemanticsLabel(offer.bubbleText), findsOneWidget);
    // Bubble text sits inside the painted bubble (x 249–930, y 828–1199 of
    // the 1179×2556 capture → cover-mapped at 360×800).
    final bubble = tester.getRect(
      find.byKey(const ValueKey('super-trial-bubble')),
    );
    const s = 800 / 2556;
    final crop = (1179 - 360 / s) / 2;
    expect(bubble.left, greaterThanOrEqualTo((249 - crop) * s));
    expect(bubble.right, lessThanOrEqualTo((930 - crop) * s));
    expect(bubble.top, greaterThanOrEqualTo(828 * s));
    expect(bubble.bottom, lessThanOrEqualTo(1080 * s));
  });

  testWidgets('copy is driven by the repository', (tester) async {
    await pump(
      tester,
      offer: const SuperTrialOffer(
        title: 'Try Super free for 14 days',
        bubbleHighlight: '3 days',
        acceptLabel: 'START FREE TRIAL',
      ),
    );
    expect(find.text('Try Super free for 14 days'), findsOneWidget);
    expect(find.text('START FREE TRIAL'), findsOneWidget);
    expect(
      find.bySemanticsLabel('We’ll notify you 3 days before your trial ends'),
      findsOneWidget,
    );
  });

  testWidgets('TRY pops true and records acceptance', (tester) async {
    final r = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('super-trial-accept')));
    await tester.pumpAndSettle();
    expect(find.byType(SuperTrialScreen), findsNothing);
    expect(r.results, [true]);
    expect(r.repo.choices, [SuperTrialChoice.accepted]);
  });

  testWidgets('NO THANKS pops false and records decline', (tester) async {
    final r = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('super-trial-decline')));
    await tester.pumpAndSettle();
    expect(r.results, [false]);
    expect(r.repo.choices, [SuperTrialChoice.declined]);
  });

  testWidgets('system back counts as a decline', (tester) async {
    final r = await pump(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(r.results, [null]);
    expect(r.repo.choices, [SuperTrialChoice.declined]);
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('no overflow at $size with 2x text', (tester) async {
      await pump(tester, size: size, scale: 2);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('super-trial-accept')), findsOneWidget);
      final button = tester.getRect(
        find.byKey(const ValueKey('super-trial-accept')),
      );
      final decline = tester.getRect(
        find.byKey(const ValueKey('super-trial-decline')),
      );
      expect(button.bottom, lessThanOrEqualTo(decline.top + 1));
      expect(decline.bottom, lessThanOrEqualTo(size.height));
    });
  }

  testWidgets('super trial golden at 360', (tester) async {
    await pump(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/gap/super_trial_360.png'),
    );
  });
}
