import 'dart:io';

import 'package:cocenglish/features/account/application/avatar_controller.dart';
import 'package:cocenglish/features/account/data/avatar_assets.dart';
import 'package:cocenglish/features/account/presentation/avatar_motion.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/application/profile_actions_controller.dart';
import 'package:cocenglish/features/progress/application/profile_appearance_provider.dart';
import 'package:cocenglish/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  test(
    'all foreign portrait choices belong to the original immutable catalog',
    () {
      final catalog = AvatarCatalogLoader.parse(
        File('assets/avatar/avatar_builder_config.json').readAsStringSync(),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      for (final userId in sampleProfileIds) {
        final appearance = container.read(profileAppearanceProvider(userId))!;
        for (final choice in appearance.overrides.entries) {
          expect(
            catalog.allows(choice.key, choice.value),
            isTrue,
            reason: '$userId:${choice.key}:${choice.value}',
          );
        }
        expect(
          () => appearance.valuesFor(catalog)['MainHair'] = 99,
          throwsUnsupportedError,
        );
      }
      expect(container.read(profileAppearanceProvider('unknown')), isNull);
    },
  );

  Future<(GoRouter, ProviderContainer)> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MainApp(
        initial: OnboardingState(
          step: OnboardingStep.lessonEntry,
          language: 'English',
        ),
      ),
    );
    await settle(tester);
    final context = tester.element(find.byTooltip('Profile'));
    final router = GoRouter.of(context);
    final container = ProviderScope.containerOf(context);
    await tester.runAsync(() => container.read(avatarCatalogProvider.future));
    router.push('/profile/James%20Smith');
    await settle(tester);
    return (router, container);
  }

  testWidgets(
    'foreign header places original avatar before identity and actions',
    (tester) async {
      await open(tester);
      expect(find.byType(AvatarMotion), findsOneWidget);
      expect(
        tester.getBottomLeft(find.byType(AvatarMotion)).dy,
        lessThan(tester.getTopLeft(find.text('James Smith').first).dy),
      );
      expect(find.byTooltip('Share profile'), findsOneWidget);
      expect(find.text('Courses'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
      expect(find.text('Followers'), findsOneWidget);
      expect(find.text('FOLLOW'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('follow share cancel and close retain foreign identity', (
    tester,
  ) async {
    final (router, container) = await open(tester);
    final xp = container.read(learningStateProvider).xp;
    final catalog = container.read(avatarCatalogProvider).requireValue;
    container.read(avatarControllerProvider.notifier)
      ..attachCatalog(catalog)
      ..begin()
      ..select('MainHair', 40)
      ..save();
    final savedAvatar = container.read(avatarControllerProvider).saved;
    final foreign = container
        .read(profileAppearanceProvider('James Smith'))!
        .valuesFor(catalog);
    expect(
      tester.widget<AvatarMotion>(find.byType(AvatarMotion)).values,
      foreign,
    );
    expect(savedAvatar, isNot(equals(foreign)));
    await tester.tap(find.text('FOLLOW'));
    await settle(tester);
    expect(find.text('FOLLOWING'), findsOneWidget);
    expect(find.bySemanticsLabel('Unfollow James Smith'), findsOneWidget);
    expect(
      container.read(previewControllerProvider).following,
      contains('James Smith'),
    );
    await tester.tap(find.byTooltip('Share profile'));
    await settle(tester);
    expect(
      find.bySemanticsLabel(
        'Profile QR code: ${profilePreviewUrl('James Smith')}',
      ),
      findsOneWidget,
    );
    final avatars = tester
        .widgetList<AvatarMotion>(find.byType(AvatarMotion))
        .toList();
    expect(avatars, hasLength(2));
    expect(avatars[0].values, avatars[1].values);
    expect(avatars[1].values, foreign);
    await tester.tap(find.byTooltip('Close profile link'));
    await settle(tester);
    expect(Uri.decodeComponent(router.state.uri.path), '/profile/James Smith');
    expect(container.read(learningStateProvider).xp, xp);
    expect(container.read(avatarControllerProvider).saved, savedAvatar);
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);
    expect(router.state.uri.path, '/home');
    expect(tester.takeException(), isNull);
  });

  testWidgets('foreign header text2 controls fit and direct Back is safe', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final (router, _) = await open(tester);
    router.go('/profile/James%20Smith');
    await settle(tester);
    await tester.ensureVisible(find.byTooltip('Share profile'));
    await settle(tester);
    expect(find.byTooltip('Share profile').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    router.go('/profile/James%20Smith');
    await settle(tester);
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await settle(tester);
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);
    expect(router.state.uri.path, '/home');
  });

  testWidgets(
    'hero controls follow source light and dark background metadata',
    (tester) async {
      final (router, _) = await open(tester);
      Icon backIcon() => tester.widget<Icon>(
        find.descendant(
          of: find.byTooltip('Back'),
          matching: find.byType(Icon),
        ),
      );
      router.go('/profile/Alex');
      await settle(tester);
      expect(backIcon().color, const Color(0xFF4B4B4B));
      router.go('/profile/James%20Smith');
      await settle(tester);
      expect(backIcon().color, const Color(0xFFFFFFFD));
      expect(tester.takeException(), isNull);
    },
  );
}
