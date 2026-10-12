import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/progress/application/extended_controller.dart';
import 'package:cocenglish/features/progress/application/energy_controller.dart';
import 'package:cocenglish/features/progress/data/energy_repository.dart';
import 'package:cocenglish/features/progress/domain/energy_offer.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/presentation/energy_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class LowEnergy extends ExtendedController {
  @override
  ExtendedState build() => const ExtendedState(energy: 10);
}

class OfflineEnergy extends MockEnergyRepository {
  bool offline = true;
  @override
  Future<int> refill(EnergyOffer offer, int balance) async {
    if (offline) throw StateError('offline');
    return super.refill(offer, balance);
  }
}

class AdPushObserver extends NavigatorObserver {
  int interstitials = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name == 'energy-ad') interstitials++;
  }
}

void main() {
  testWidgets('FREE refills two energy; recharge spends preview gems once', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [extendedControllerProvider.overrideWith(LowEnergy.new)],
    );
    addTearDown(container.dispose);
    container.read(previewControllerProvider.notifier).useDemoBalance();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: referenceTheme(), home: const EnergyScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('FREE'));
    await tester.pumpAndSettle();
    expect(container.read(extendedControllerProvider).energy, 12);
    final wallet = container.read(previewWalletProvider);
    await tester.tap(find.text('Recharge'));
    await tester.pumpAndSettle();
    expect(container.read(extendedControllerProvider).energy, 25);
    expect(container.read(previewWalletProvider), wallet - 500);
    await tester.tap(find.text('Recharge'));
    await tester.pumpAndSettle();
    expect(container.read(previewWalletProvider), wallet - 500);
  });
  testWidgets('WATCH AD only refills after a reward result at scale two', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [extendedControllerProvider.overrideWith(LowEnergy.new)],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const EnergyScreen()),
        GoRoute(
          path: '/ad',
          builder: (context, _) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () => context.pop(false),
                  child: const Text('Cancel ad'),
                ),
                TextButton(
                  onPressed: () => context.pop(true),
                  child: const Text('Reward ad'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: referenceTheme(),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('WATCH AD'));
    await tester.tap(find.text('WATCH AD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel ad'));
    await tester.pumpAndSettle();
    expect(container.read(extendedControllerProvider).energy, 10);
    await tester.ensureVisible(find.text('WATCH AD'));
    await tester.tap(find.text('WATCH AD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reward ad'));
    await tester.pumpAndSettle();
    expect(container.read(extendedControllerProvider).energy, 15);
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed refill preserves balance and can retry', (tester) async {
    final repository = OfflineEnergy();
    final c = ProviderContainer(
      overrides: [
        extendedControllerProvider.overrideWith(LowEnergy.new),
        energyRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(theme: referenceTheme(), home: const EnergyScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('FREE'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Energy unavailable. Try again.'), findsOneWidget);
    expect(c.read(extendedControllerProvider).energy, 10);
    repository.offline = false;
    await tester.tap(find.text('TRY AGAIN'));
    await tester.pumpAndSettle();
    expect(c.read(extendedControllerProvider).energy, 12);
    expect(tester.takeException(), isNull);
  });
  testWidgets('rapid WATCH AD taps open one interstitial', (tester) async {
    final c = ProviderContainer(
      overrides: [extendedControllerProvider.overrideWith(LowEnergy.new)],
    );
    addTearDown(c.dispose);
    final observer = AdPushObserver();
    final router = GoRouter(
      observers: [observer],
      routes: [
        GoRoute(path: '/', builder: (_, _) => const EnergyScreen()),
        GoRoute(
          path: '/ad',
          name: 'energy-ad',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.pop(true),
              child: const Text('Finish ad'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(
          theme: referenceTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('WATCH AD'));
    await tester.tap(find.text('WATCH AD'));
    await tester.pumpAndSettle();
    expect(observer.interstitials, 1);
    expect(c.read(extendedControllerProvider).energy, 10);
    await tester.tap(find.text('Finish ad'));
    await tester.pumpAndSettle();
    expect(find.text('WATCH AD').hitTestable(), findsOneWidget);
    expect(c.read(extendedControllerProvider).energy, 15);
    expect(tester.takeException(), isNull);
  });
}
