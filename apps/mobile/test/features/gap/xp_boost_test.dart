import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/core/api/client/api_exception.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/shop/presentation/shop_screen.dart';
import 'package:cocenglish/features/xp_boost/application/boost_controller.dart';
import 'package:cocenglish/features/xp_boost/data/api_boost_repository.dart';
import 'package:cocenglish/features/xp_boost/data/boost_repository.dart';
import 'package:cocenglish/features/xp_boost/domain/boost.dart';
import 'package:cocenglish/features/xp_boost/presentation/xp_boost_activated_screen.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/app_fonts.dart';
import '../../support/fake_api_transport.dart';

void main() {
  setUpAll(loadAppFonts);
  for (final reduced in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'activation repository copy, Continue, motion=$reduced scale=$scale',
        (t) async {
          t.view.physicalSize = const Size(360, 780);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final repository = MockBoostRepository(
            initial: const Boost(multiplier: 3, minutes: 7),
          );
          final router = GoRouter(
            initialLocation: '/xp-boost/activated',
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, _) => const Scaffold(body: Text('Home')),
              ),
              GoRoute(
                path: '/xp-boost/activated',
                builder: (_, _) => const XpBoostActivatedScreen(),
              ),
            ],
          );
          addTearDown(router.dispose);
          await t.pumpWidget(
            ProviderScope(
              overrides: [
                boostRepositoryProvider.overrideWithValue(repository),
              ],
              child: MaterialApp.router(
                theme: referenceTheme(),
                routerConfig: router,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    disableAnimations: reduced,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: child!,
                ),
              ),
            ),
          );
          await t.pump();
          await t.pump(const Duration(milliseconds: 350));
          expect(find.text('x3'), findsOneWidget);
          expect(
            find.textContaining('7 minutes', findRichText: true),
            findsOneWidget,
          );
          expect(
            find.textContaining('XP Boost activated!', findRichText: true),
            findsOneWidget,
          );
          final bubble = t.widget<BoostBubbles>(find.byType(BoostBubbles));
          expect(bubble.moving, !reduced);
          expect(t.takeException(), isNull);
          await t.tap(find.text('CONTINUE'));
          await t.pumpAndSettle();
          expect(find.text('Home'), findsOneWidget);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets(
    'real router: activated boost route shows reward, Continue returns to Shop',
    (t) async {
      // The Friends Chest CLAIM -> boost hand-off is not wired yet: the frozen
      // settings_shop_taps_test expects the gems sheet to return to Shop.
      await t.pumpWidget(
        MainApp(
          initial: OnboardingState(
            step: OnboardingStep.lessonEntry,
            language: 'English',
          ),
        ),
      );
      await t.pumpAndSettle();
      final router = GoRouter.of(t.element(find.byTooltip('Shop')));
      final container = ProviderScope.containerOf(
        t.element(find.byTooltip('Shop')),
      );
      router.push('/shop');
      await t.pumpAndSettle();
      final ok = await container
          .read(boostControllerProvider.notifier)
          .activate(
            const BoostReward(itemId: 'xp-boost', multiplier: 2, minutes: 15),
          );
      expect(ok, isTrue);
      router.push('/xp-boost/activated');
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.byType(XpBoostActivatedScreen), findsOneWidget);
      expect(find.text('x2'), findsOneWidget);
      expect(
        find.textContaining('15 minutes', findRichText: true),
        findsOneWidget,
      );
      await t.tap(find.text('CONTINUE'));
      await t.pumpAndSettle();
      expect(find.byType(ShopScreen), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'API activation uses server multiplier and duration, same key on retry',
    () async {
      final transport = FakeApiTransport();
      transport.json('POST /base/v1/me/boosts', {
        'boostId': 'boost-1',
        'kind': 'XP_BOOST',
        'multiplier': 3,
        'startsAt': '2026-10-12T08:00:00.000Z',
        'endsAt': '2026-10-12T08:12:00.000Z',
        'inventory': null,
      });
      final repository = ApiBoostRepository(
        ApiEndpoints(fakeClient(transport)),
      );
      const reward = BoostReward(
        itemId: 'xp-boost',
        multiplier: 2,
        minutes: 15,
      );
      transport.offline = true;
      await expectLater(
        repository.activate(reward),
        throwsA(isA<ApiException>()),
      );
      expect(repository.current, isNull);
      transport.offline = false;
      final first = await repository.activate(reward);
      final second = await repository.activate(reward);
      expect(first.multiplier, 3);
      expect(first.minutes, 12);
      expect(second, same(first));
      expect(transport.to('POST /base/v1/me/boosts'), hasLength(4));
      expect(bodyOf(transport.requests.last), {'itemId': 'xp-boost'});
      expect(
        transport.requests
            .map((request) => request.headers['Idempotency-Key'])
            .toSet(),
        hasLength(1),
      );
    },
  );
}
