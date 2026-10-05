import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/progress/application/streak_controller.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/domain/preview_state.dart';
import 'package:cocenglish/features/progress/application/extended_controller.dart';
import 'package:cocenglish/features/progress/application/family_reaction_controller.dart';
import 'package:cocenglish/features/progress/presentation/streak_screen.dart';
import 'package:cocenglish/features/progress/presentation/family_subscription_screen.dart';
import 'package:cocenglish/features/practice/application/clash_controller.dart';
import 'package:cocenglish/features/practice/presentation/clash_screen.dart';
import 'package:cocenglish/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class FundedPreview extends PreviewController {
  @override
  PreviewState build() => const PreviewState(bonusGems: 4000);
}

Future<ProviderContainer> openApp(WidgetTester tester, String path) async {
  await tester.pumpWidget(
    MainApp(
      initial: OnboardingState(
        step: OnboardingStep.lessonEntry,
        language: 'English',
      ),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byTooltip('Practice'));
  final c = ProviderScope.containerOf(context);
  GoRouter.of(context).push(path);
  await tester.pumpAndSettle();
  return c;
}

void main() {
  test(
    'shield insufficient or repeated purchase never double spends wallet',
    () {
      final empty = ProviderContainer();
      addTearDown(empty.dispose);
      expect(
        empty.read(previewControllerProvider.notifier).buyStreakShield(),
        isFalse,
      );
      expect(empty.read(previewControllerProvider).spentGems, 0);
      final c = ProviderContainer(
        overrides: [previewControllerProvider.overrideWith(FundedPreview.new)],
      );
      addTearDown(c.dispose);
      expect(
        c.read(previewControllerProvider.notifier).buyStreakShield(),
        isTrue,
      );
      expect(c.read(previewWalletProvider), 1005);
      expect(
        c.read(previewControllerProvider.notifier).buyStreakShield(),
        isFalse,
      );
      expect(c.read(previewWalletProvider), 1005);
    },
  );
  testWidgets(
    'real streak accept, cancel remove, confirm remove and invite retain Back state',
    (tester) async {
      final c = await openApp(tester, '/streak');
      await tester.tap(find.text('FRIENDS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ACCEPT'));
      await tester.pumpAndSettle();
      expect(c.read(streakControllerProvider).remaining, 4);
      await tester.tap(find.text('EDIT'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('End streak with Alex Smith'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('NO THANKS'));
      await tester.pumpAndSettle();
      expect(c.read(streakControllerProvider).friends.length, 1);
      await tester.tap(find.byTooltip('End streak with Alex Smith'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('END FRIEND STREAK'));
      await tester.pumpAndSettle();
      expect(c.read(streakControllerProvider).remaining, 5);
      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invite a friend').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('INVITE').first);
      await tester.pumpAndSettle();
      expect(find.text('4 invites remaining'), findsOneWidget);
      await tester.tap(find.byTooltip('Close invites'));
      await tester.pumpAndSettle();
      expect(find.text('Request pending'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'real Family nudge dismiss preserves choice, send is local and once-only',
    (tester) async {
      final c = await openApp(tester, '/subscription/family');
      c.read(extendedControllerProvider.notifier)
        ..choosePlan('max-family')
        ..confirmPlan()
        ..invite('Alex Smith');
      await tester.pumpAndSettle();
      await tester.tap(find.text('NUDGE'));
      await tester.pumpAndSettle();
      c.read(familyReactionControllerProvider.notifier).select(2);
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('Great job!'))).pop();
      await tester.pumpAndSettle();
      expect(c.read(familyReactionControllerProvider).nudged, isEmpty);
      await tester.tap(find.text('NUDGE'));
      await tester.pumpAndSettle();
      expect(find.text('Great job!'), findsOneWidget);
      await tester.tap(find.text('SEND CONGRATS TO ALEX SMITH!'));
      await tester.pumpAndSettle();
      expect(find.text('NUDGED'), findsOneWidget);
      expect(c.read(familyReactionControllerProvider).nudged, {'Alex Smith'});
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'actual clash pauses for sheet/background and resumes saved answer on Back',
    (tester) async {
      final c = await openApp(tester, '/clash');
      await tester.tap(find.text('START FRIENDS CLASH'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUE'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('sister'));
      await tester.pump(const Duration(seconds: 3));
      final before = c.read(clashControllerProvider).remaining;
      expect(before, lessThan(60));
      await tester.tap(find.byTooltip('Close clash'));
      await tester.pumpAndSettle();
      final paused = c.read(clashControllerProvider).remaining;
      await tester.pump(const Duration(seconds: 5));
      expect(c.read(clashControllerProvider).remaining, paused);
      await tester.tap(find.text('KEEP PLAYING'));
      await tester.pump(const Duration(milliseconds: 100));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 5));
      expect(c.read(clashControllerProvider).remaining, paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 2));
      expect(c.read(clashControllerProvider).remaining, lessThan(paused));
      expect(c.read(clashControllerProvider).answer, ['sister']);
      final router = GoRouter.of(tester.element(find.text('sister').first));
      router.pop();
      await tester.pumpAndSettle();
      final back = c.read(clashControllerProvider).remaining;
      await tester.pump(const Duration(seconds: 5));
      expect(c.read(clashControllerProvider).remaining, back);
      router.push('/clash');
      await tester.pump(const Duration(milliseconds: 500));
      expect(c.read(clashControllerProvider).answer, ['sister']);
      c.read(clashControllerProvider.notifier).tick(60);
      await tester.pumpAndSettle();
      expect(find.textContaining('Time’s up!'), findsOneWidget);
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(find.text('It’s Joshua’s turn now!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Family reaction choices expose labeled selected buttons', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final c = await openApp(tester, '/subscription/family');
    c.read(extendedControllerProvider.notifier)
      ..choosePlan('max-family')
      ..confirmPlan()
      ..invite('Alex Smith');
    await tester.pumpAndSettle();
    await tester.tap(find.text('NUDGE'));
    await tester.pumpAndSettle();
    for (final label in [
      'You’re on fire!',
      'You’ve got this!',
      'Great job!',
      'Keep it going!',
    ]) {
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == label &&
              widget.properties.button == true,
        ),
        findsOneWidget,
      );
    }
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Great job!' &&
            widget.properties.button == true,
      ),
    );
    await tester.pumpAndSettle();
    expect(c.read(familyReactionControllerProvider).selected, 2);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Great job!' &&
            widget.properties.selected == true,
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets(
    'actual achievement navigation tracks detail routes and deep-link Back returns home',
    (tester) async {
      await openApp(tester, '/achievements');
      final router = GoRouter.of(tester.element(find.text('Achievements')));
      await tester.tap(find.text('Perfect Week').last);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/achievements/perfect-week');
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Monthly badges'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/badges');
      router.go('/achievements/xp-olympian');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Practice'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('social layout width$width text$scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final c = ProviderContainer(
          overrides: [
            streakClockProvider.overrideWithValue(DateTime(2026, 10, 5)),
          ],
        );
        addTearDown(c.dispose);
        Future<void> show(Widget child) async {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: c,
              child: MaterialApp(
                theme: referenceTheme(),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 844),
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true,
                  ),
                  child: child,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        await show(const StreakScreen());
        c.read(streakControllerProvider.notifier).selectFriends(true);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await show(const FriendStreakInviteScreen());
        c.read(extendedControllerProvider.notifier)
          ..choosePlan('max-family')
          ..confirmPlan()
          ..invite('Alex Smith');
        await show(const FamilySubscriptionScreen());
        final vm = c.read(clashControllerProvider.notifier);
        await show(const ClashScreen(clockEnabled: false));
        for (var i = 0; i < 3; i++) {
          vm.advance();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        vm.choose('sister');
        vm.check();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        vm.tick(60);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        vm.advance();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
