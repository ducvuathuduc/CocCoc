import 'dart:ui' show SemanticsAction;

import 'package:cocenglish/main.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/account/application/course_management_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/progress/presentation/profile_lists_screen.dart';
import 'package:cocenglish/features/progress/application/profile_lists_controller.dart';
import 'package:cocenglish/features/progress/application/profile_surface_controller.dart';
import 'package:cocenglish/features/progress/application/profile_actions_controller.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';

void main() {
  test('followBack only follows snapshot members once', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final surface = container.read(profileSurfaceProvider.notifier);
    surface.receiveFollowers({'James Smith'});
    final xpBefore = container.read(learningStateProvider).xp;

    expect(surface.followBack('Not a follower'), isFalse);
    expect(container.read(previewControllerProvider).following, isEmpty);
    container.read(profileActionsProvider.notifier).block('James Smith');
    expect(surface.followBack('James Smith'), isFalse);
    expect(container.read(previewControllerProvider).following, isEmpty);
    container.read(profileActionsProvider.notifier).unblock('James Smith');
    expect(surface.followBack('James Smith'), isTrue);
    expect(surface.followBack('James Smith'), isFalse);
    expect(container.read(previewControllerProvider).following, {
      'James Smith',
    });
    expect(container.read(profileSurfaceProvider).followers, {'James Smith'});
    expect(container.read(learningStateProvider).xp, xpBefore);
  });

  testWidgets(
    'source lists scroll without clipping at 320 and text scale two',
    (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      for (final page in [
        const ProfileCoursesScreen(),
        const ProfileFriendsScreen(),
        const ProfileFriendsScreen(initialTab: ProfileFriendsTab.followers),
      ]) {
        await t.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: referenceTheme(),
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: page,
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        if (page is ProfileFriendsScreen) {
          await t.ensureVisible(find.text('FOLLOWERS'));
          await t.tap(find.text('FOLLOWERS'));
          await t.pumpAndSettle();
          expect(find.text('No followers yet'), findsOneWidget);
          expect(t.takeException(), isNull);
        }
        await t.pumpWidget(const SizedBox.shrink());
      }
    },
  );
  Future<BuildContext> home(WidgetTester t) async {
    await t.pumpWidget(
      MainApp(
        initial: OnboardingState(
          step: OnboardingStep.lessonEntry,
          language: 'English',
        ),
      ),
    );
    await t.pumpAndSettle();
    return t.element(find.byTooltip('Practice'));
  }

  testWidgets(
    'profile courses reflect enrollment; opening the list does not switch English',
    (t) async {
      final context = await home(t);
      final c = ProviderScope.containerOf(context);
      final router = GoRouter.of(context);
      router.push('/profile/courses');
      await t.pumpAndSettle();
      expect(find.text("Sam’s Courses"), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Chinese'), findsOneWidget);
      expect(find.text('Math'), findsNothing);
      expect(find.text('Music'), findsNothing);
      expect(find.text('Chess'), findsNothing);
      final vm = c.read(courseManagementProvider.notifier);
      expect(vm.requestRemoval('chinese'), isTrue);
      expect(await t.runAsync(vm.confirmRemoval), isTrue);
      await t.pump();
      expect(find.text('Chinese'), findsNothing);
      expect(c.read(previewControllerProvider).course, 'English');
      await t.tap(find.byTooltip('Back'));
      await t.pumpAndSettle();
      expect(find.byTooltip('Practice'), findsOneWidget);
    },
  );

  testWidgets(
    'profile friend tabs keep following identity and empty followers separate',
    (t) async {
      final context = await home(t);
      final c = ProviderScope.containerOf(context);
      c.read(previewControllerProvider.notifier).follow('Alex');
      GoRouter.of(context).push('/profile/friends?tab=followers');
      await t.pumpAndSettle();
      expect(find.text('No followers yet'), findsOneWidget);
      expect(find.text('Alex'), findsNothing);
      await t.tap(find.text('FOLLOWING'));
      await t.pumpAndSettle();
      expect(find.text('Alex'), findsOneWidget);
      await t.tap(find.text('Alex'));
      await t.pumpAndSettle();
      expect(find.byTooltip('Profile options'), findsOneWidget);
      await t.tap(find.byTooltip('Back'));
      await t.pumpAndSettle();
      expect(find.text('FOLLOWING'), findsOneWidget);
      expect(c.read(previewControllerProvider).following, {'Alex'});
    },
  );

  testWidgets(
    'changing friend route query selects the requested tab in the reused page',
    (t) async {
      final context = await home(t);
      final c = ProviderScope.containerOf(context);
      c.read(previewControllerProvider.notifier).follow('Alex');
      final router = GoRouter.of(context);
      router.go('/profile/friends?tab=following');
      await t.pumpAndSettle();
      expect(find.text('Alex'), findsOneWidget);
      router.go('/profile/friends?tab=followers');
      await t.pumpAndSettle();
      expect(find.text('No followers yet'), findsOneWidget);
      expect(find.text('Alex'), findsNothing);
    },
  );

  testWidgets(
    'populated followers follow back once and retain source state on return',
    (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);

      final context = await home(t);
      final c = ProviderScope.containerOf(context);
      final followers = <String>{'James Smith', 'Alex'};
      c.read(profileSurfaceProvider.notifier).receiveFollowers(followers);
      followers.add('Injected later');
      c.read(previewControllerProvider.notifier).follow('Alex');
      final xpBefore = c.read(learningStateProvider).xp;
      final router = GoRouter.of(context);

      router.push('/profile/friends?tab=followers');
      await t.pumpAndSettle();
      expect(find.text('James Smith'), findsOneWidget);
      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Injected later'), findsNothing);
      expect(find.text('J'), findsOneWidget);
      expect(
        t.getTopLeft(find.text('James Smith')).dy,
        lessThan(t.getTopLeft(find.text('Alex')).dy),
      );
      expect(
        t
            .widget<CircleAvatar>(
              find.ancestor(
                of: find.text('J'),
                matching: find.byType(CircleAvatar),
              ),
            )
            .backgroundColor,
        const Color(0xFFFF9600),
      );
      expect(find.bySemanticsLabel('Follow back James Smith'), findsOneWidget);
      expect(
        t
            .widget<Semantics>(
              find.byKey(const ValueKey('friends-tab-followers')),
            )
            .properties
            .selected,
        isTrue,
      );
      expect(t.takeException(), isNull);

      final followBack = find.byKey(const ValueKey('follow-back-James Smith'));
      final animatedPadding = find.descendant(
        of: followBack,
        matching: find.byType(AnimatedPadding),
      );
      expect(
        t.getSize(find.descendant(of: followBack, matching: find.byType(Icon))),
        const Size(24, 24),
      );
      expect(
        t.getSize(
          find.descendant(of: followBack, matching: find.byType(TextButton)),
        ),
        const Size(42, 32),
      );
      expect(
        t
            .getSemantics(find.bySemanticsLabel('Follow back James Smith'))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      final press = await t.startGesture(t.getCenter(followBack));
      await t.pump(const Duration(milliseconds: 150));
      await t.pump(const Duration(milliseconds: 80));
      expect(
        t.widget<AnimatedPadding>(animatedPadding).padding,
        const EdgeInsets.only(top: 4),
      );
      await press.cancel();
      await t.pump(const Duration(milliseconds: 80));
      expect(
        t.widget<AnimatedPadding>(animatedPadding).padding,
        const EdgeInsets.only(bottom: 4),
      );

      await t.tapAt(t.getTopLeft(followBack) + const Offset(1, 1));
      await t.tap(find.bySemanticsLabel('Follow back James Smith'));
      await t.pumpAndSettle();
      expect(c.read(previewControllerProvider).following, {
        'Alex',
        'James Smith',
      });
      expect(c.read(profileSurfaceProvider).followers, {'Alex', 'James Smith'});
      expect(c.read(learningStateProvider).xp, xpBefore);
      expect(find.bySemanticsLabel('Follow back James Smith'), findsNothing);

      await t.tap(find.text('James Smith'));
      await t.pumpAndSettle();
      expect(router.state.uri.pathSegments.last, 'James Smith');
      expect(find.text('Profile unavailable'), findsNothing);
      expect(find.byTooltip('Profile options'), findsOneWidget);
      expect(find.text('FOLLOWING'), findsOneWidget);
      router.pop();
      await t.pumpAndSettle();
      expect(find.text('James Smith'), findsOneWidget);
      expect(find.text('Alex'), findsOneWidget);
      expect(find.bySemanticsLabel('Follow back James Smith'), findsNothing);
      expect(
        t
            .widget<Semantics>(
              find.byKey(const ValueKey('friends-tab-followers')),
            )
            .properties
            .selected,
        isTrue,
      );
      expect(c.read(profileSurfaceProvider).followers, {'Alex', 'James Smith'});
      expect(t.takeException(), isNull);
    },
  );
}
