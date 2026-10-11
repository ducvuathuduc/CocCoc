import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/app_icon/application/app_icon_controller.dart';
import 'package:cocenglish/features/app_icon/data/app_icon_repository.dart';
import 'package:cocenglish/features/app_icon/domain/app_icon_choice.dart';
import 'package:cocenglish/features/app_icon/presentation/app_icon_sheet.dart';
import 'package:cocenglish/features/gift/application/gift_controller.dart';
import 'package:cocenglish/features/gift/data/gift_repository.dart';
import 'package:cocenglish/features/gift/presentation/gift_screens.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/progress/application/streak_controller.dart';
import 'package:cocenglish/features/progress/presentation/streak_screen.dart';
import 'package:cocenglish/features/progress/presentation/super_screen.dart';
import 'package:cocenglish/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('App icon', () {
    Future<MockAppIconRepository> pumpStreak(WidgetTester t) async {
      t.view.physicalSize = const Size(430, 932);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final repo = MockAppIconRepository();
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            appIconRepositoryProvider.overrideWithValue(repo),
            streakFixtureProvider.overrideWithValue(
              StreakFixture(
                days: 12,
                month: DateTime(2026, 10),
                practiced: {for (var d = 1; d <= 11; d++) d},
              ),
            ),
          ],
          child: MaterialApp(
            theme: referenceTheme(),
            home: const StreakScreen(),
          ),
        ),
      );
      await t.pumpAndSettle();
      return repo;
    }

    Future<void> openSheet(WidgetTester t) async {
      final change = find.text('CHANGE APP ICON');
      if (change.evaluate().isEmpty) {
        await t.scrollUntilVisible(
          change,
          300,
          scrollable: find.byType(Scrollable).first,
        );
      }
      await t.ensureVisible(change);
      await t.pumpAndSettle();
      await t.tap(change);
      await t.pumpAndSettle();
      expect(find.text('Select an app icon!'), findsOneWidget);
    }

    ProviderContainer container(WidgetTester t) =>
        ProviderScope.containerOf(t.element(find.byType(StreakScreen)));

    testWidgets('CHANGE APP ICON opens the selector sheet', (t) async {
      await pumpStreak(t);
      await openSheet(t);
      expect(find.text('STREAK SOCIETY'), findsOneWidget);
      expect(find.text('MAX'), findsOneWidget);
      expect(find.text('RESTORE ORIGINAL ICON'), findsOneWidget);
    });

    testWidgets('choosing Max persists, confirms and shows selected state', (
      t,
    ) async {
      final repo = await pumpStreak(t);
      await openSheet(t);
      await t.tap(find.byKey(const ValueKey('app-icon-max')));
      await t.pumpAndSettle();

      expect(repo.current, AppIconChoice.max);
      expect(container(t).read(appIconControllerProvider), AppIconChoice.max);
      expect(find.text('Select an app icon!'), findsNothing);
      expect(find.byType(AppIconChangedDialog), findsOneWidget);
      expect(
        find.text('You have changed the icon for “Duolingo”.'),
        findsOneWidget,
      );
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      expect(find.byType(AppIconChangedDialog), findsNothing);

      await openSheet(t);
      final maxCard = t.getSemantics(
        find.byKey(const ValueKey('app-icon-max')),
      );
      expect(maxCard, isSemantics(isSelected: true));
      final streakCard = t.getSemantics(
        find.byKey(const ValueKey('app-icon-streakSociety')),
      );
      expect(streakCard, isSemantics(isSelected: false));
    });

    testWidgets('Streak Society then restore original icon', (t) async {
      final repo = await pumpStreak(t);
      await openSheet(t);
      await t.tap(find.byKey(const ValueKey('app-icon-streakSociety')));
      await t.pumpAndSettle();
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      expect(repo.current, AppIconChoice.streakSociety);

      await openSheet(t);
      await t.tap(find.byKey(const ValueKey('restore-original-icon')));
      await t.pumpAndSettle();
      expect(find.byType(AppIconChangedDialog), findsOneWidget);
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      expect(repo.current, AppIconChoice.original);
      expect(repo.writes, [
        AppIconChoice.streakSociety,
        AppIconChoice.original,
      ]);
    });

    test('controller reads the stored icon on start', () {
      final c = ProviderContainer(
        overrides: [
          appIconRepositoryProvider.overrideWithValue(
            MockAppIconRepository(initial: AppIconChoice.max),
          ),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(appIconControllerProvider), AppIconChoice.max);
    });
  });

  group('Gift Super', () {
    Future<GoRouter> boot(WidgetTester t) async {
      t.view.physicalSize = const Size(430, 932);
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

    Future<void> tapVisible(WidgetTester t, Finder f) async {
      if (f.evaluate().isEmpty) {
        await t.scrollUntilVisible(
          f,
          200,
          scrollable: find.byType(Scrollable).last,
        );
      }
      await t.ensureVisible(f);
      await t.pumpAndSettle();
      await t.tap(f);
      await t.pumpAndSettle();
    }

    testWidgets('Shop > Gift Super runs the whole mock purchase', (t) async {
      final router = await boot(t);
      router.push('/shop');
      await t.pumpAndSettle();
      await tapVisible(t, find.text('GIFT'));
      expect(find.byType(GiftSubscriptionScreen), findsOneWidget);
      expect(find.text('GIFT SUBSCRIPTION'), findsOneWidget);

      await tapVisible(t, find.byKey(const ValueKey('gift-super')));
      expect(find.byType(GiftSuperIntroScreen), findsOneWidget);
      expect(
        find.text('Gift an entire year of unlimited energy and no ads!'),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('gift-intro-continue')));
      await t.pumpAndSettle();
      expect(find.byType(GiftRecipientScreen), findsOneWidget);

      // CONTINUE is disabled until a friend is picked.
      await t.tap(find.byKey(const ValueKey('gift-recipient-continue')));
      await t.pumpAndSettle();
      expect(find.byType(GiftRecipientScreen), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('gift-recipient-maya')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('gift-recipient-continue')));
      await t.pumpAndSettle();
      expect(find.byType(GiftNoteScreen), findsOneWidget);
      expect(
        find.text(r'$95.99 for 1 year of Super. No auto-renewal'),
        findsOneWidget,
      );

      await t.enterText(
        find.byKey(const ValueKey('gift-note-field')),
        'Surprise! Can’t wait to see you flex those new phrases',
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('gift-continue-payment')));
      await t.pumpAndSettle();
      expect(find.byType(GiftCheckoutSheet), findsOneWidget);
      expect(find.text('Maya (@maya.speaks)'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('gift-buy')));
      await t.pump();
      expect(find.text('PROCESSING…'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
      expect(find.byType(GiftSentScreen), findsOneWidget);
      expect(find.text('Gift sent!'), findsOneWidget);
      expect(
        find.textContaining('Maya will get 1 year of Super'),
        findsOneWidget,
      );

      await t.tap(find.byKey(const ValueKey('gift-done')));
      await t.pumpAndSettle();
      expect(find.byType(GiftSubscriptionScreen), findsOneWidget);
      expect(find.text('SENT GIFTS'), findsOneWidget);
      expect(find.text('Super • 1 year for Maya'), findsOneWidget);
    });

    testWidgets('Manage subscription has a GIFT SUPER entry', (t) async {
      final router = await boot(t);
      router.push('/subscription');
      await t.pumpAndSettle();
      expect(find.byType(SubscriptionScreen), findsOneWidget);
      await tapVisible(
        t,
        find.byKey(const ValueKey('subscription-gift-super')),
      );
      expect(find.byType(GiftSubscriptionScreen), findsOneWidget);
    });

    testWidgets('FAQ rows expand', (t) async {
      final router = await boot(t);
      router.push(GiftRoutes.hub);
      await t.pumpAndSettle();
      expect(
        find.textContaining('Video Call and Roleplay let you'),
        findsNothing,
      );
      await tapVisible(t, find.text('Which plan is best for speaking?'));
      expect(
        find.textContaining('Video Call and Roleplay let you'),
        findsOneWidget,
      );
    });

    test('controller picks plan + recipient and records the order', () async {
      final c = ProviderContainer(
        overrides: [
          giftRepositoryProvider.overrideWithValue(
            MockGiftRepository(latency: Duration.zero),
          ),
        ],
      );
      addTearDown(c.dispose);
      final vm = c.read(giftControllerProvider.notifier);
      expect(await vm.purchase(), isNull); // no recipient yet
      vm.selectPlan('max-1y');
      vm.selectRecipient('alex');
      vm.setNote('  hi  ');
      final order = await vm.purchase();
      expect(order!.plan.name, 'Max');
      expect(order.note, 'hi');
      expect(c.read(giftControllerProvider).sent, hasLength(1));
      vm.start();
      expect(c.read(giftControllerProvider).recipient, isNull);
      expect(c.read(giftControllerProvider).sent, hasLength(1));
    });
  });
}
