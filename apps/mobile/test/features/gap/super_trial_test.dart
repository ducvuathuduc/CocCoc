import 'dart:async';

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

class SlowSuperTrialRepository extends MockSuperTrialRepository {
  final release = Completer<void>();

  @override
  Future<void> record(SuperTrialChoice choice) async {
    choices.add(choice);
    await release.future;
  }
}

/// Opens the trial from a launcher so the pop result is observable.
Future<({MockSuperTrialRepository repo, List<bool?> results})> pump(
  WidgetTester tester, {
  Size size = const Size(360, 800),
  double scale = 1,
  SuperTrialOffer offer = const SuperTrialOffer(),
  TargetPlatform platform = TargetPlatform.iOS,
  MockSuperTrialRepository? repository,
  bool open = true,
}) async {
  SuperTrialScreen.debugPlatformOverride = platform;
  addTearDown(() => SuperTrialScreen.debugPlatformOverride = null);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repo = repository ?? MockSuperTrialRepository(offer: offer);
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

  testWidgets('Android shows the source-backed English seven-day comparison', (
    tester,
  ) async {
    await pump(
      tester,
      size: const Size(360, 717),
      platform: TargetPlatform.android,
    );
    expect(
      find.text('Progress faster in your English course with Super!'),
      findsOneWidget,
    );
    expect(find.text('Get a 7-day free trial of Super Duolingo'), findsNothing);
    final heading = tester.getRect(
      find.text('Progress faster in your English course with Super!'),
    );
    expect(heading.top, closeTo(125, 3));
    final comparison = tester.getRect(
      find.byKey(const ValueKey('android-super-comparison')),
    );
    expect(comparison.top, closeTo(heading.bottom + 28, 1));
    for (final feature in [
      'Learning content',
      'Unlimited Hearts',
      'Personalized Practice',
      'Unlimited Legendary',
      'No ads',
    ]) {
      expect(find.text(feature), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('android-super-badge')), findsOneWidget);
    expect(find.textContaining('14'), findsNothing);
    expect(find.textContaining('2 WEEKS'), findsNothing);
    expect(find.byKey(const ValueKey('super-trial-accept')), findsOneWidget);
    expect(find.byKey(const ValueKey('super-trial-decline')), findsOneWidget);
  });

  testWidgets('Android acceptance pops true and records exactly once', (
    tester,
  ) async {
    final repository = SlowSuperTrialRepository();
    final r = await pump(
      tester,
      platform: TargetPlatform.android,
      repository: repository,
    );
    final accept = find.byKey(const ValueKey('super-trial-accept'));
    await tester.tap(accept);
    await tester.tap(accept);
    expect(repository.choices, [SuperTrialChoice.accepted]);
    repository.release.complete();
    await tester.pumpAndSettle();
    expect(r.results, [true]);
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('Android comparison fits $size at 2x text', (tester) async {
      await pump(
        tester,
        size: size,
        scale: 2,
        platform: TargetPlatform.android,
      );
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('android-super-comparison')),
        findsOneWidget,
      );
      final accept = tester.getRect(
        find.byKey(const ValueKey('super-trial-accept')),
      );
      final decline = tester.getRect(
        find.byKey(const ValueKey('super-trial-decline')),
      );
      expect(accept.bottom, lessThanOrEqualTo(decline.top + 1));
      expect(decline.bottom, lessThanOrEqualTo(size.height));
    });
  }

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
