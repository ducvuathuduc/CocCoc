import 'package:cocenglish/features/progress/application/extended_controller.dart';
import 'package:cocenglish/features/super_features/application/super_features_controller.dart';
import 'package:cocenglish/features/super_features/data/super_features_repository.dart';
import 'package:cocenglish/features/super_features/presentation/super_features_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_fonts.dart';
import 'screen_pump.dart';

Future<(ProviderContainer, MockSuperFeaturesRepository)> _pump(
  WidgetTester tester, {
  bool superPlan = true,
  bool succeed = true,
  Size size = const Size(360, 800),
  double scale = 1,
}) async {
  final repo = MockSuperFeaturesRepository(succeed: succeed);
  final c = await pumpScreen(
    tester,
    SuperFeaturesScreen.route,
    const SuperFeaturesScreen(),
    overrides: [superFeaturesRepositoryProvider.overrideWithValue(repo)],
    size: size,
    scale: scale,
  );
  final unlimited = c.read(extendedControllerProvider).unlimited;
  if (superPlan != unlimited) {
    final controller = c.read(extendedControllerProvider.notifier);
    if (superPlan) {
      controller
        ..choosePlan('individual')
        ..confirmPlan();
    } else {
      controller.cancelPlan();
    }
    await tester.pumpAndSettle();
  }
  return (c, repo);
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('Super learner toggles a feature through the repository', (
    t,
  ) async {
    final (c, repo) = await _pump(t);
    expect(find.byKey(const ValueKey('super-features-locked')), findsNothing);
    await t.tap(find.byKey(const ValueKey('super-feature-legendary')));
    await t.pumpAndSettle();
    expect(repo.load().firstWhere((f) => f.id == 'legendary').enabled, isFalse);
    expect(
      c
          .read(superFeaturesControllerProvider)
          .features
          .firstWhere((f) => f.id == 'legendary')
          .enabled,
      isFalse,
    );
  });

  testWidgets('failed save reverts the switch and shows an error', (t) async {
    final (c, _) = await _pump(t, succeed: false);
    await t.tap(find.byKey(const ValueKey('super-feature-legendary')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('super-features-error')), findsOneWidget);
    expect(
      c
          .read(superFeaturesControllerProvider)
          .features
          .firstWhere((f) => f.id == 'legendary')
          .enabled,
      isTrue,
    );
  });

  testWidgets('Free learner sees features locked with GET SUPER', (t) async {
    final (_, repo) = await _pump(t, superPlan: false);
    expect(find.byKey(const ValueKey('super-features-locked')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('super-feature-legendary')));
    await t.pumpAndSettle();
    expect(repo.load().every((f) => f.enabled), isTrue);
    await t.tap(find.byKey(const ValueKey('super-features-get-super')));
    await t.pumpAndSettle();
    expect(find.text('Stub /super'), findsOneWidget);
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('no overflow at $size with 2x text', (t) async {
      await _pump(t, size: size, scale: 2, superPlan: false);
      expect(t.takeException(), isNull);
    });
  }

  for (final superPlan in [true, false]) {
    testWidgets('manage features ${superPlan ? 'super' : 'locked'} golden', (
      t,
    ) async {
      await _pump(t, superPlan: superPlan);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/gap/super_features_${superPlan ? 'super' : 'locked'}_360.png',
        ),
      );
    });
  }
}
