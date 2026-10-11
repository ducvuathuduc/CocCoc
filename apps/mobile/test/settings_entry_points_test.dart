import 'package:cocenglish/features/account/presentation/account_screens.dart';
import 'package:cocenglish/features/account/presentation/password_change_screen.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/presentation/streak_widgets_screen.dart';
import 'package:cocenglish/features/shop/presentation/shop_screen.dart';
import 'package:cocenglish/main.dart';
import 'package:cocenglish/features/notifications/presentation/notification_screens.dart';
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

  Future<void> open(WidgetTester t, String text) async {
    final target = find.text(text);
    if (target.evaluate().isEmpty) {
      // Lazily built list scrolled past the row: scroll back to the top.
      await t.scrollUntilVisible(
        target,
        -200,
        scrollable: find.byType(Scrollable).last,
      );
    }
    await t.ensureVisible(target);
    await t.pumpAndSettle();
    await t.tap(target);
    await t.pumpAndSettle();
  }

  testWidgets('settings rows open their Duolingo sub-pages', (t) async {
    final router = await boot(t);
    final c = ProviderScope.containerOf(t.element(find.byTooltip('Practice')));
    router.push('/settings');
    await t.pumpAndSettle();

    await open(t, 'Preferences');
    expect(find.byType(PreferencesScreen), findsOneWidget);
    final sound = c.read(previewControllerProvider).sound;
    await t.tap(find.text('Sound effects'));
    await t.pumpAndSettle();
    expect(c.read(previewControllerProvider).sound, !sound);
    router.pop();
    await t.pumpAndSettle();

    await open(t, 'Notifications');
    await open(t, 'Reminders');
    expect(find.byType(NotificationCategoryScreen), findsOneWidget);
    router.pop();
    await t.pumpAndSettle();
    router.pop();
    await t.pumpAndSettle();

    await open(t, 'Privacy settings');
    final private = c.read(previewControllerProvider).private;
    await t.tap(find.text('Private profile'));
    await t.pumpAndSettle();
    expect(c.read(previewControllerProvider).private, !private);
    router.pop();
    await t.pumpAndSettle();

    await open(t, 'Help Center');
    await open(t, 'Connection and recovery');
    expect(find.byType(RecoveryScreen), findsOneWidget);
    router.pop();
    await t.pumpAndSettle();
    await open(t, 'Sync status');
    expect(find.byType(SyncScreen), findsOneWidget);
    router.pop();
    await t.pumpAndSettle();
    router.pop();
    await t.pumpAndSettle();

    await open(t, 'Profile');
    expect(find.byType(EditProfileScreen), findsOneWidget);
    await t.ensureVisible(find.byKey(const ValueKey('profile-password')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('profile-password')));
    await t.pumpAndSettle();
    expect(find.byType(PasswordChangeScreen), findsOneWidget);
    router.pop();
    await t.pumpAndSettle();
    await open(t, 'DELETE ACCOUNT');
    expect(find.byType(DeleteAccountScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('shop widget reward opens streak widgets', (t) async {
    await boot(t);
    await t.tap(find.byTooltip('Shop'));
    await t.pumpAndSettle();
    final shopList = find
        .descendant(
          of: find.byType(ShopScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await t.scrollUntilVisible(
      find.text('Widget Reward'),
      200,
      scrollable: shopList,
    );
    final claim = find.descendant(
      of: find
          .ancestor(of: find.text('Widget Reward'), matching: find.byType(Row))
          .first,
      matching: find.text('CLAIM'),
    );
    await t.pumpAndSettle();
    await t.tap(claim);
    await t.pumpAndSettle();
    expect(find.byType(StreakWidgetsScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
