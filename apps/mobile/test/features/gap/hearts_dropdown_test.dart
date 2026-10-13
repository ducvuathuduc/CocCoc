import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/hearts/application/hearts_controller.dart';
import 'package:cocenglish/features/hearts/data/hearts_repository.dart';
import 'package:cocenglish/features/hearts/domain/hearts.dart';
import 'package:cocenglish/features/hearts/presentation/hearts_dropdown.dart';
import 'package:cocenglish/features/learning/presentation/learning_path.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/app_fonts.dart';
import '../../support/settle_images.dart';

/// Audit row 7: hearts dropdown from the stats bar (sc_901080ed).
Future<ProviderContainer> pumpPath(
  WidgetTester t, {
  int balance = 3,
  LivesModel model = LivesModel.hearts,
  bool reduced = true,
  double scale = 1,
}) async {
  t.view.physicalSize = const Size(360, 780);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      heartsRepositoryProvider.overrideWithValue(
        MockHeartsRepository(
          initial: HeartsState(
            balance: balance,
            nextHeartIn: const Duration(hours: 4, minutes: 7),
          ),
          livesModel: model,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const Scaffold(body: SafeArea(child: LearningPath())),
      ),
      GoRoute(
        path: '/super',
        builder: (_, _) => const Scaffold(body: Text('Super destination')),
      ),
      GoRoute(
        path: '/lesson/practice',
        builder: (_, _) => const Scaffold(body: Text('Practice destination')),
      ),
      GoRoute(
        path: '/energy',
        builder: (_, _) => const Scaffold(body: Text('Energy destination')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: referenceTheme(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 56, bottom: 34),
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduced,
          ),
          child: child!,
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  await settleImages(t);
  return container;
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('energy-model learners keep the energy stat', (t) async {
    await pumpPath(t, model: LivesModel.energy);
    expect(find.byTooltip('Hearts'), findsNothing);
    expect(find.byTooltip('Energy'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
  });

  for (final reduced in [true, false]) {
    testWidgets('hearts stat opens the dropdown, reduced=$reduced', (t) async {
      await pumpPath(t, reduced: reduced);
      expect(find.text('3'), findsWidgets);
      await t.tap(find.byTooltip('Hearts'));
      if (!reduced) {
        await t.pump(const Duration(milliseconds: 100));
        expect(find.byKey(const ValueKey('hearts-dropdown')), findsOneWidget);
      }
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('hearts-dropdown')), findsOneWidget);
      expect(find.text('UNLIMITED HEARTS'), findsOneWidget);
      expect(find.text('FREE TRIAL'), findsOneWidget);
      expect(find.text('REFILL HEARTS'), findsOneWidget);
      expect(find.text('PRACTICE TO EARN HEARTS'), findsOneWidget);
      expect(find.textContaining('4h 7m', findRichText: true), findsOneWidget);
      // Tapping the dimmed path closes it.
      await t.tapAt(const Offset(180, 700));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('hearts-dropdown')), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('UNLIMITED HEARTS opens Super', (t) async {
    await pumpPath(t);
    await t.tap(find.byTooltip('Hearts'));
    await t.pumpAndSettle();
    await t.tap(find.text('UNLIMITED HEARTS'));
    await t.pumpAndSettle();
    expect(find.text('Super destination'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('refill spends gems once and fills hearts', (t) async {
    final c = await pumpPath(t);
    // Without enough gems refill is disabled.
    await t.tap(find.byTooltip('Hearts'));
    await t.pumpAndSettle();
    await t.tap(find.text('REFILL HEARTS'));
    await t.pumpAndSettle();
    expect(c.read(heartsControllerProvider).balance, 3);
    expect(find.byKey(const ValueKey('hearts-dropdown')), findsOneWidget);
    await t.tapAt(const Offset(180, 700));
    await t.pumpAndSettle();
    c.read(previewControllerProvider.notifier).useDemoBalance();
    final before = c.read(previewWalletProvider);
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Hearts'));
    await t.pumpAndSettle();
    await t.tap(find.text('REFILL HEARTS'));
    await t.pumpAndSettle();
    expect(c.read(heartsControllerProvider).balance, 5);
    expect(c.read(previewWalletProvider), before - 500);
    expect(find.byKey(const ValueKey('hearts-dropdown')), findsNothing);
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('practice is only offered at zero hearts', (t) async {
    await pumpPath(t, balance: 0);
    await t.tap(find.byTooltip('Hearts'));
    await t.pumpAndSettle();
    final practice = t.widget<Semantics>(
      find
          .ancestor(
            of: find.text('PRACTICE TO EARN HEARTS'),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(practice.properties.enabled, isNot(false));
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('dropdown fits text scale 2 at 360', (t) async {
    await pumpPath(t, scale: 2);
    await t.tap(find.byTooltip('Hearts'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('hearts-dropdown')), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('hearts dropdown golden at 360', (t) async {
    final c = await pumpPath(t);
    // The capture has enough gems (505) for the 500-gem refill.
    c.read(previewControllerProvider.notifier).useDemoBalance();
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Hearts'));
    await t.pumpAndSettle();
    await settleImages(t);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/gap/hearts_dropdown_360.png'),
    );
    await t.pumpWidget(const SizedBox.shrink());
  });

  test('dropdown motion tokens', () {
    expect(HeartsDropdownMotion.duration, const Duration(milliseconds: 250));
  });
}
