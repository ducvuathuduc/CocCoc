import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/features/account/application/avatar_controller.dart';
import 'package:cocenglish/features/account/domain/avatar_configuration.dart';
import 'package:cocenglish/features/account/presentation/avatar_motion.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/application/extended_controller.dart';
import 'package:cocenglish/features/progress/presentation/own_profile_screen.dart';
import 'package:cocenglish/features/progress/presentation/profile_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _SavedAvatarController extends AvatarController {
  static const values = <String, double>{'SkinColor': 2, 'HairColor': 3};

  @override
  AvatarState build() => AvatarState(
    saved: values,
    draft: values,
    catalog: AvatarCatalog.empty(),
    hasAvatar: true,
  );
}

Widget _marker(String label) => Scaffold(body: Center(child: Text(label)));

GoRouter _router() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const OwnProfileScreen()),
    GoRoute(path: '/settings', builder: (_, _) => _marker('settings-route')),
    GoRoute(
      path: '/settings/avatar',
      builder: (_, _) => _marker('avatar-route'),
    ),
    GoRoute(path: '/friends', builder: (_, _) => _marker('friends-route')),
    GoRoute(
      path: '/profile/courses',
      builder: (_, _) => _marker('courses-route'),
    ),
    GoRoute(
      path: '/profile/friends',
      builder: (_, state) =>
          _marker('friends-${state.uri.queryParameters['tab']}-route'),
    ),
    GoRoute(path: '/score', builder: (_, _) => _marker('score-route')),
    GoRoute(
      path: '/achievements',
      builder: (_, _) => _marker('achievements-route'),
    ),
    GoRoute(path: '/activity', builder: (_, _) => _marker('activity-route')),
    GoRoute(path: '/badges', builder: (_, _) => _marker('badges-route')),
    GoRoute(
      path: '/auth/register',
      builder: (_, _) => _marker('register-route'),
    ),
  ],
);

Future<ProviderContainer> _pumpProfile(
  WidgetTester tester, {
  bool savedAvatar = false,
  String? plan,
  double width = 390,
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(
    overrides: [
      if (savedAvatar)
        avatarControllerProvider.overrideWith(_SavedAvatarController.new),
    ],
  );
  addTearDown(container.dispose);
  container.read(previewControllerProvider.notifier)
    ..saveProfile('Sam Lee', 'demo@cocenglish.test')
    ..follow('Alex')
    ..optIntoLeague();
  if (plan != null) {
    container.read(extendedControllerProvider.notifier)
      ..choosePlan(plan)
      ..confirmPlan();
  }
  container
      .read(learningStateProvider.notifier)
      .claim(
        const SessionReceipt(
          id: 'profile-progress',
          nodeId: 'node-profile',
          xp: 24,
          accuracy: 1,
          elapsed: Duration(minutes: 1),
          firstCompletion: true,
          guest: false,
          placement: false,
        ),
      );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: referenceTheme(),
        routerConfig: _router(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('lower profile keeps its header and opens monthly badges', (
    tester,
  ) async {
    await _pumpProfile(tester);
    await tester.scrollUntilVisible(
      find.text('MONTHLY BADGES'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Settings').hitTestable(), findsOneWidget);
    expect(find.text('Sam Lee').hitTestable(), findsOneWidget);
    await tester.tap(find.text('MONTHLY BADGES'));
    await tester.pumpAndSettle();
    expect(find.text('badges-route'), findsOneWidget);
  });

  testWidgets('profile shows live progress and each social counter route', (
    tester,
  ) async {
    await _pumpProfile(tester);

    expect(find.text('Sam Lee'), findsOneWidget);
    expect(find.text('1 day'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Bronze'), findsOneWidget);
    expect(find.text('24 XP'), findsOneWidget);
    expect(find.text('Courses'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Followers'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-courses')));
    await tester.pumpAndSettle();
    expect(find.text('courses-route'), findsOneWidget);
    GoRouter.of(tester.element(find.text('courses-route'))).go('/');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-following')));
    await tester.pumpAndSettle();
    expect(find.text('friends-following-route'), findsOneWidget);
    GoRouter.of(tester.element(find.text('friends-following-route'))).go('/');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-followers')));
    await tester.pumpAndSettle();
    expect(find.text('friends-followers-route'), findsOneWidget);
  });

  testWidgets('unfinished profile opens avatar builder and add friends', (
    tester,
  ) async {
    await _pumpProfile(tester);

    expect(find.text('Finish your profile!'), findsOneWidget);
    await tester.tap(find.text('COMPLETE PROFILE'));
    await tester.pumpAndSettle();
    expect(find.text('avatar-route'), findsOneWidget);
    GoRouter.of(tester.element(find.text('avatar-route'))).go('/');
    await tester.pumpAndSettle();
    await tester.tap(find.text('ADD FRIENDS'));
    await tester.pumpAndSettle();
    expect(find.text('friends-route'), findsOneWidget);
  });

  testWidgets(
    'saved avatar and score card use saved state and independent actions',
    (tester) async {
      await _pumpProfile(tester, savedAvatar: true);

      final avatar = tester.widget<AvatarMotion>(find.byType(AvatarMotion));
      expect(avatar.values, _SavedAvatarController.values);
      expect(avatar.animate, isFalse);
      expect(
        find.text('Add your Duolingo\nScore to LinkedIn!'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Dismiss score card'));
      await tester.pumpAndSettle();
      expect(find.text('Add your Duolingo\nScore to LinkedIn!'), findsNothing);
      expect(
        GoRouter.of(tester.element(find.text('OVERVIEW'))).state.uri.path,
        '/',
      );

      final fresh = await _pumpProfile(tester, savedAvatar: true);
      expect(
        fresh.read(avatarControllerProvider).saved,
        _SavedAvatarController.values,
      );
      await tester.tap(find.text('GET STARTED'));
      await tester.pumpAndSettle();
      expect(find.text('score-route'), findsOneWidget);
    },
  );

  testWidgets('profile QR shares own identity', (tester) async {
    await _pumpProfile(tester);

    await tester.tap(find.byTooltip('Profile link'));
    await tester.pumpAndSettle();
    final dialog = tester.widget<ProfileShareDialog>(
      find.byType(ProfileShareDialog),
    );
    expect(dialog.userId, 'me');
    expect(dialog.name, 'Sam Lee');
  });

  testWidgets('paid plan shows its original profile badge', (tester) async {
    await _pumpProfile(tester, savedAvatar: true, plan: 'max-individual');

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ReferenceArt && widget.region.file == 'profile-06',
      ),
      findsOneWidget,
    );
  });

  testWidgets('320 wide text scale 2 scrolls every profile section', (
    tester,
  ) async {
    await _pumpProfile(tester, width: 320, textScale: 2);

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('CREATE A PROFILE'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('CREATE A PROFILE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
