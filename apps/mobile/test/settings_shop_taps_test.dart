import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/account/application/settings_extras_controller.dart';
import 'package:cocenglish/features/account/data/settings_repository.dart';
import 'package:cocenglish/features/account/presentation/account_screens.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/domain/preview_state.dart';
import 'package:cocenglish/features/progress/presentation/family_subscription_screen.dart';
import 'package:cocenglish/features/shop/presentation/shop_screen.dart';
import 'package:cocenglish/features/shop/presentation/shop_widgets.dart';
import 'package:cocenglish/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<GoRouter> boot(WidgetTester t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MainApp(
        initial: OnboardingState(
          step: OnboardingStep.lessonEntry,
          language: 'English',
        ),
      ),
    );
    await t.pumpAndSettle();
    return GoRouter.of(t.element(find.byTooltip('Practice')));
  }

  ProviderContainer container(WidgetTester t) =>
      ProviderScope.containerOf(t.element(find.byType(Navigator).first));

  Future<void> open(WidgetTester t, String text) async {
    final target = find.text(text);
    if (target.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        target,
        200,
        scrollable: find.byType(Scrollable).last,
      );
    }
    await t.ensureVisible(target);
    await t.pumpAndSettle();
    await t.tap(target);
    await t.pumpAndSettle();
  }

  group('Settings sub-pages', () {
    testWidgets('Duolingo for Schools joins and leaves a classroom', (t) async {
      final router = await boot(t);
      router.push('/settings');
      await t.pumpAndSettle();
      await open(t, 'Duolingo for Schools');
      expect(find.byType(SchoolsSettingsScreen), findsOneWidget);
      expect(find.byType(RecoveryScreen), findsNothing);

      final join = find.text('JOIN CLASSROOM');
      await t.tap(join);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('schools-joined')), findsNothing);

      await t.enterText(find.byKey(const ValueKey('schools-code')), 'abc');
      await t.pumpAndSettle();
      await t.tap(join);
      await t.pumpAndSettle();
      expect(find.text('Classroom codes have 6 letters or numbers.'),
          findsOneWidget);

      await t.enterText(find.byKey(const ValueKey('schools-code')), 'zzz999');
      await t.pumpAndSettle();
      await t.tap(join);
      await t.pumpAndSettle();
      expect(find.textContaining('couldn’t find that classroom'),
          findsOneWidget);

      await t.enterText(find.byKey(const ValueKey('schools-code')), 'abc123');
      await t.pumpAndSettle();
      await t.tap(join);
      await t.pumpAndSettle();
      expect(find.text('You joined Ms. Rivera’s English class'),
          findsOneWidget);
      expect(container(t).read(settingsExtrasControllerProvider).classroom,
          'Ms. Rivera’s English class');

      await t.tap(find.text('LEAVE CLASSROOM'));
      await t.pumpAndSettle();
      expect(container(t).read(settingsExtrasControllerProvider).classroom,
          isNull);
      expect(find.byKey(const ValueKey('schools-code')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('Social accounts toggle linked providers', (t) async {
      final router = await boot(t);
      router.push('/settings');
      await t.pumpAndSettle();
      await open(t, 'Social accounts');
      expect(find.byType(SocialAccountsScreen), findsOneWidget);
      expect(find.text('Facebook'), findsOneWidget);
      await t.tap(find.text('Google'));
      await t.pumpAndSettle();
      expect(container(t).read(settingsExtrasControllerProvider).connected,
          {'google'});
      await t.tap(find.text('Google'));
      await t.pumpAndSettle();
      expect(container(t).read(settingsExtrasControllerProvider).connected,
          isEmpty);
      expect(t.takeException(), isNull);
    });

    testWidgets('Feedback submits through the repository and returns',
        (t) async {
      final repo = MockSettingsRepository(latency: Duration.zero);
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (_, _) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/support/feedback',
            builder: (_, _) => const FeedbackScreen(),
          ),
        ],
      );
      await t.pumpWidget(
        ProviderScope(
          overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp.router(
            theme: referenceTheme(),
            routerConfig: router,
          ),
        ),
      );
      await t.pumpAndSettle();
      await open(t, 'Feedback');
      expect(find.byType(FeedbackScreen), findsOneWidget);

      // SUBMIT is disabled until a message is written.
      await t.ensureVisible(find.text('SUBMIT'));
      await t.tap(find.text('SUBMIT'));
      await t.pumpAndSettle();
      expect(repo.sent, isEmpty);

      await t.tap(find.byKey(const ValueKey('feedback-topic-2')));
      await t.enterText(
        find.byKey(const ValueKey('feedback-message')),
        'Add more speaking practice',
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('SUBMIT'));
      await t.tap(find.text('SUBMIT'));
      await t.pumpAndSettle();
      expect(repo.sent.single.topic, 'Suggestion');
      expect(repo.sent.single.message, 'Add more speaking practice');
      expect(find.text('Thanks for your feedback!'), findsOneWidget);
      await t.tap(find.text('GOT IT'));
      await t.pumpAndSettle();
      expect(find.byType(FeedbackScreen), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('Restore subscription gives feedback instead of nothing',
        (t) async {
      final router = await boot(t);
      router.push('/settings');
      await t.pumpAndSettle();
      await open(t, 'RESTORE SUBSCRIPTION');
      expect(find.text('No subscription found'), findsOneWidget);
      await t.tap(find.text('GOT IT'));
      await t.pumpAndSettle();
      expect(find.text('No subscription found'), findsNothing);
      expect(t.takeException(), isNull);
    });
  });

  group('Shop taps', () {
    Future<void> openShop(WidgetTester t) async {
      await t.tap(find.byTooltip('Shop'));
      await t.pumpAndSettle();
    }

    Finder rowAction(String title, String label) => find.descendant(
      of: find.ancestor(of: find.text(title), matching: find.byType(Row)).first,
      matching: find.text(label),
    );

    Future<void> scrollTo(WidgetTester t, String text) async {
      final list = find
          .descendant(
            of: find.byType(ShopScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      await t.scrollUntilVisible(find.text(text), 200, scrollable: list);
      await t.pumpAndSettle();
    }

    for (final reduced in [false, true]) {
      testWidgets(
        'Friends Chest and Genshin CLAIM credit the wallet once '
        '(reduced motion: $reduced)',
        (t) async {
          t.platformDispatcher.accessibilityFeaturesTestValue = reduced
              ? const FakeAccessibilityFeatures(disableAnimations: true)
              : const FakeAccessibilityFeatures();
          addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
          await boot(t);
          final c = container(t);
          await openShop(t);
          final before = c.read(previewWalletProvider);

          await scrollTo(t, 'Friends Chest');
          await t.tap(rowAction('Friends Chest', 'CLAIM'));
          await t.pump();
          expect(find.byType(ShopRewardReveal), findsOneWidget);
          await t.pumpAndSettle();
          expect(find.text('You earned 20 gems!'), findsOneWidget);
          expect(find.text('+20'), findsOneWidget);
          expect(c.read(previewWalletProvider), before + 20);
          await t.tap(find.text('CONTINUE'));
          await t.pumpAndSettle();
          expect(rowAction('Friends Chest', 'CLAIMED'), findsOneWidget);
          await t.tap(rowAction('Friends Chest', 'CLAIMED'));
          await t.pumpAndSettle();
          expect(find.byType(ShopRewardReveal), findsNothing);
          expect(c.read(previewWalletProvider), before + 20);

          await scrollTo(t, 'Genshin Impact\nReward');
          await t.tap(rowAction('Genshin Impact\nReward', 'CLAIM'));
          await t.pumpAndSettle();
          expect(find.text('You earned 50 gems!'), findsOneWidget);
          await t.tap(find.text('CONTINUE'));
          await t.pumpAndSettle();
          expect(c.read(previewWalletProvider), before + 70);
          // Header balance follows the wallet.
          expect(find.text('${before + 70}'), findsOneWidget);
          expect(t.takeException(), isNull);
        },
      );
    }

    testWidgets('Max Family Plan UPGRADE opens the Family plan screen',
        (t) async {
      await boot(t);
      await openShop(t);
      await scrollTo(t, 'UPGRADE');
      await t.tap(find.text('UPGRADE'));
      await t.pumpAndSettle();
      expect(find.byType(FamilySubscriptionScreen), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('Streak Freeze at 2/2 shows maxed feedback, no purchase',
        (t) async {
      t.view.physicalSize = const Size(390, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      late ProviderContainer c;
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            previewControllerProvider.overrideWith(_TwoFreezes.new),
            previewWalletProvider.overrideWith(
              (ref) => 1035 - ref.watch(previewControllerProvider).spentGems,
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              c = ProviderScope.containerOf(context);
              return MaterialApp(
                theme: referenceTheme(),
                home: const ShopScreen(),
              );
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      await scrollTo(t, '1-day');
      expect(
        find.bySemanticsLabel(RegExp('2 of 2 equipped. Maximum reached')),
        findsOneWidget,
      );
      await t.tap(find.text('425'));
      await t.pumpAndSettle();
      expect(find.text('Streak Freeze maxed out'), findsOneWidget);
      expect(find.text('Streak Freeze equipped!'), findsNothing);
      expect(c.read(previewControllerProvider).freezes, 2);
      expect(c.read(previewControllerProvider).spentGems, 0);
      await t.tap(find.text('GOT IT'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });

    testWidgets('Streak Freeze below max still buys one', (t) async {
      await boot(t);
      final c = container(t);
      c.read(previewControllerProvider.notifier).useDemoBalance();
      await openShop(t);
      await scrollTo(t, '1-day');
      await t.tap(find.text('425'));
      await t.pumpAndSettle();
      expect(find.text('Streak Freeze equipped!'), findsOneWidget);
      expect(c.read(previewControllerProvider).freezes, 1);
    });
  });

  test('PreviewController.claimShopReward is once-only', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final vm = c.read(previewControllerProvider.notifier);
    expect(vm.claimShopReward('friends-chest', 20), isTrue);
    expect(vm.claimShopReward('friends-chest', 20), isFalse);
    expect(vm.claimShopReward('', 20), isFalse);
    expect(vm.claimShopReward('genshin-reward', 0), isFalse);
    expect(c.read(previewControllerProvider).bonusGems, 20);
    expect(vm.shopRewardClaimed('friends-chest'), isTrue);
  });
}

class _TwoFreezes extends PreviewController {
  @override
  PreviewState build() => const PreviewState(freezes: 2);
}
