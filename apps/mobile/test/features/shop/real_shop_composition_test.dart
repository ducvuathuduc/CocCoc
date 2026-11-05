import 'dart:async';

import 'package:cocenglish/core/config/app_config.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/domain/preview_state.dart';
import 'package:cocenglish/features/shop/application/shop_controller.dart';
import 'package:cocenglish/features/shop/data/shop_repository.dart';
import 'package:cocenglish/features/shop/presentation/shop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

ShopState serverState({int wallet = 42}) => ShopState(
  wallet: wallet,
  freezes: 1,
  timerBoosts: 3,
  specialOffers: const [
    ShopOffer(
      id: 'friends-chest',
      title: 'Friends Chest',
      actionLabel: 'LOCKED',
      available: false,
    ),
  ],
  timerBoostOffers: const [
    ShopOffer(id: 'timer-single', title: 'Single', price: 7),
  ],
  freezeOffer: const ShopOffer(id: 'freeze', title: '1-day', price: 11),
);

void main() {
  testWidgets('API shop renders server wallet without reading preview state', (
    tester,
  ) async {
    final repository = _ShopFake(serverState());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(dataSource: DataSource.api),
          ),
          shopRepositoryProvider.overrideWithValue(repository),
          previewWalletProvider.overrideWith(
            (ref) => throw StateError('preview wallet read'),
          ),
          previewControllerProvider.overrideWith(_ForbiddenPreview.new),
        ],
        child: const MaterialApp(home: ShopScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('42'), findsOneWidget);
    expect(find.text('1035'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Friends Chest'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Friends Chest'), findsOneWidget);
    expect(find.text('LOCKED'), findsWidgets);
    await tester.tap(find.text('LOCKED').first);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed load shows retry and close controls at narrow large text layout',
    (tester) async {
      final repository = _ShopFake(serverState())..failLoads = 1;
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(path: '/shop', builder: (_, _) => const ShopScreen()),
        ],
      );
      addTearDown(router.dispose);
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(dataSource: DataSource.api),
            ),
            shopRepositoryProvider.overrideWithValue(repository),
          ],
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      router.push('/shop');
      await tester.pumpAndSettle();

      expect(find.text('Shop unavailable'), findsOneWidget);
      expect(find.text('RETRY'), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('RETRY'));
      await tester.tap(find.text('RETRY'));
      await tester.pumpAndSettle();
      expect(find.text('42'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    },
  );

  testWidgets('reopening API shop refreshes the authoritative wallet', (
    tester,
  ) async {
    final repository = _ShopFake(serverState());
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(path: '/shop', builder: (_, _) => const ShopScreen()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(dataSource: DataSource.api),
          ),
          shopRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    router.push('/shop');
    await tester.pumpAndSettle();
    expect(find.text('42'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);

    repository.replace(serverState(wallet: 99));
    router.push('/shop');
    await tester.pumpAndSettle();
    expect(find.text('99'), findsOneWidget);
    expect(repository.refreshLoads, greaterThan(0));

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  test(
    'failed purchase retains wallet and retry reuses the command id',
    () async {
      final repository = _ShopFake(serverState())..failPurchases = 1;
      final container = ProviderContainer(
        overrides: [shopRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      container.listen(
        shopControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      await repository.loaded.future;
      await Future<void>.delayed(Duration.zero);

      expect(
        await container
            .read(shopControllerProvider.notifier)
            .buyItem('timer-single', 9999),
        isFalse,
      );
      expect(container.read(shopControllerProvider).requireValue.wallet, 42);
      expect(
        await container
            .read(shopControllerProvider.notifier)
            .buyItem('timer-single', 9999),
        isTrue,
      );
      expect(repository.commandIds, hasLength(2));
      expect(repository.commandIds.toSet(), hasLength(1));
    },
  );

  test('late repository A load cannot replace repository B', () async {
    final a = _ShopFake.pending();
    final b = _ShopFake.pending();
    final container = ProviderContainer(
      overrides: [shopRepositoryProvider.overrideWithValue(a)],
    );
    addTearDown(container.dispose);
    container.listen(shopControllerProvider, (_, _) {}, fireImmediately: true);
    await Future<void>.delayed(Duration.zero);

    container.updateOverrides([shopRepositoryProvider.overrideWithValue(b)]);
    container.read(shopControllerProvider);
    b.complete(serverState(wallet: 22));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(shopControllerProvider).requireValue.wallet, 22);

    a.complete(serverState(wallet: 11));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(shopControllerProvider).requireValue.wallet, 22);
  });

  test('concurrent duplicate buy starts one repository command', () async {
    final repository = _ShopFake(serverState())
      ..holdPurchase = Completer<void>();
    final container = ProviderContainer(
      overrides: [shopRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    container.listen(shopControllerProvider, (_, _) {}, fireImmediately: true);
    await repository.loaded.future;
    await Future<void>.delayed(Duration.zero);
    final controller = container.read(shopControllerProvider.notifier);
    final first = controller.buyItem('timer-single', 7);
    final second = controller.buyItem('timer-single', 7);
    expect(await second, isFalse);
    expect(repository.commandIds, hasLength(1));
    repository.holdPurchase!.complete();
    expect(await first, isTrue);
  });
}

class _ShopFake implements ShopRepository {
  _ShopFake(ShopState state) : _state = state {
    loaded.complete();
  }

  _ShopFake.pending() : _state = null;

  ShopState? _state;
  final loaded = Completer<void>();
  final pendingLoad = Completer<ShopState>();
  final commandIds = <String>[];
  int failPurchases = 0;
  int failLoads = 0;
  int refreshLoads = 0;
  Completer<void>? holdPurchase;

  void replace(ShopState state) => _state = state;

  void complete(ShopState state) {
    _state = state;
    if (!pendingLoad.isCompleted) pendingLoad.complete(state);
  }

  @override
  Future<ShopState> loadShop({bool refresh = false}) async {
    if (refresh) refreshLoads++;
    if (failLoads > 0) {
      failLoads--;
      throw StateError('load failed');
    }
    return _state ?? pendingLoad.future;
  }

  @override
  Future<void> buyItem(
    String id,
    int displayCost, {
    required String commandId,
  }) async {
    commandIds.add(commandId);
    if (failPurchases > 0) {
      failPurchases--;
      throw StateError('failed');
    }
    await holdPurchase?.future;
  }
}

class _ForbiddenPreview extends PreviewController {
  @override
  PreviewState build() => throw StateError('preview controller read');
}
