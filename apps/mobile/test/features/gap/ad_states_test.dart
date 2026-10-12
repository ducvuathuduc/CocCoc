import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/ads/application/ads_controller.dart';
import 'package:cocenglish/features/ads/data/ads_repository.dart';
import 'package:cocenglish/features/ads/presentation/ad_screen.dart';
import 'package:cocenglish/features/progress/application/extended_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_fonts.dart';

class OfflineAd extends MockAdsRepository {
  bool offline = true;
  int impressions = 0;
  @override
  Future<void> impression(String id, String placement) async {
    impressions++;
    if (offline) throw StateError('offline');
    await super.impression(id, placement);
  }
}

Future<ProviderContainer> show(
  WidgetTester tester,
  AdsRepository repository,
) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final c = ProviderContainer(
    overrides: [adsRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: referenceTheme(),
        home: const AdScreen(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

void main() {
  setUpAll(loadAppFonts);
  testWidgets('offline ad exposes retry, does not unlock a reward', (
    tester,
  ) async {
    final repository = OfflineAd();
    final c = await show(tester, repository);
    expect(find.text('Ad unavailable. Try again.'), findsOneWidget);
    expect(c.read(adControllerProvider).ready, isFalse);
    expect(await c.read(adControllerProvider.notifier).finish(), isFalse);
    repository.offline = false;
    await tester.ensureVisible(find.text('TRY AGAIN'));
    await tester.tap(find.text('TRY AGAIN'));
    await tester.pumpAndSettle();
    expect(c.read(adControllerProvider).ready, isTrue);
    expect(repository.impressions, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets('ad timer pauses in background and disposes at text scale two', (
    tester,
  ) async {
    final c = await show(tester, MockAdsRepository());
    final remaining = c.read(adControllerProvider).seconds;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 6));
    expect(c.read(adControllerProvider).seconds, remaining);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(c.read(adControllerProvider).seconds, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });
  test('Super suppresses impressions', () async {
    final repository = OfflineAd();
    final c = ProviderContainer(
      overrides: [adsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(c.dispose);
    c.read(extendedControllerProvider.notifier).choosePlan('individual');
    c.read(extendedControllerProvider.notifier).confirmPlan();
    // No router is required to verify the application guard.
    await c
        .read(adControllerProvider.notifier)
        .start('LESSON_END_INTERSTITIAL');
    expect(repository.impressions, 0);
    expect(c.read(adsEligibleProvider), isFalse);
  });
}
