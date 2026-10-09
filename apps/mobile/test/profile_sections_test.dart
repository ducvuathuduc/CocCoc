import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/features/progress/application/extended_controller.dart';
import 'package:cocenglish/features/progress/application/streak_controller.dart';
import 'package:cocenglish/features/progress/presentation/profile_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _marker(String label) => Scaffold(body: Center(child: Text(label)));

GoRouter _router() => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const Scaffold(
        body: SingleChildScrollView(child: OwnProfileSections()),
      ),
    ),
    GoRoute(path: '/streak', builder: (_, _) => _marker('streak-route')),
    GoRoute(path: '/streak/invite', builder: (_, _) => _marker('invite-route')),
    GoRoute(path: '/badges', builder: (_, _) => _marker('badges-route')),
    GoRoute(
      path: '/achievements',
      builder: (_, _) => _marker('achievements-route'),
    ),
    GoRoute(
      path: '/achievements/:id',
      builder: (_, state) =>
          _marker('achievement-${state.pathParameters['id']}'),
    ),
    GoRoute(
      path: '/subscription/family',
      builder: (_, _) => _marker('family-route'),
    ),
  ],
);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  double width = 390,
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
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
  testWidgets(
    'empty Friend Streak slots invite and heading opens friends view',
    (tester) async {
      final container = await _pump(tester, width: 342);

      final inviteSlots = find.bySemanticsLabel(
        'Invite a friend to a Friend Streak',
      );
      expect(inviteSlots, findsNWidgets(5));
      expect(
        tester.getCenter(inviteSlots.at(1)).dx -
            tester.getCenter(inviteSlots.first).dx,
        closeTo(72.5, .1),
      );
      await tester.tap(
        find.bySemanticsLabel('Invite a friend to a Friend Streak').first,
      );
      await tester.pumpAndSettle();
      expect(find.text('invite-route'), findsOneWidget);

      GoRouter.of(tester.element(find.text('invite-route'))).go('/');
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Open Friend Streaks'));
      await tester.pumpAndSettle();
      expect(find.text('streak-route'), findsOneWidget);
      expect(container.read(streakControllerProvider).showFriends, isTrue);
    },
  );

  testWidgets(
    'accepted and pending friends update avatars without archived counts',
    (tester) async {
      final container = await _pump(tester);

      expect(
        container.read(streakControllerProvider.notifier).accept('alex'),
        isTrue,
      );
      expect(
        container.read(streakControllerProvider.notifier).invite('maria'),
        isTrue,
      );
      await tester.pump();

      expect(
        find.bySemanticsLabel('Alex Smith, 0 day Friend Streak'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Maria Garcia, Friend Streak pending'),
        findsOneWidget,
      );
      expect(find.text('342'), findsNothing);
      expect(
        find.bySemanticsLabel('Invite a friend to a Friend Streak'),
        findsNWidgets(3),
      );
    },
  );

  testWidgets('badge and achievement shortcuts preserve destination ids', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.bySemanticsLabel('September 2025, locked'), findsOneWidget);
    expect(find.bySemanticsLabel('October 2025, earned'), findsOneWidget);
    expect(find.bySemanticsLabel('November 2025, locked'), findsOneWidget);
    expect(find.bySemanticsLabel('December 2025, locked'), findsOneWidget);
    expect(find.bySemanticsLabel('August 2025, locked'), findsNothing);
    expect(find.bySemanticsLabel('January 2025, earned'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('monthly-november')),
        matching: find.byType(ReferenceArt),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('monthly-october')),
        matching: find.byType(ReferenceArt),
      ),
      findsOneWidget,
    );
    await tester.tap(find.bySemanticsLabel('Open Monthly Badges'));
    await tester.pumpAndSettle();
    expect(find.text('badges-route'), findsOneWidget);

    GoRouter.of(tester.element(find.text('badges-route'))).go('/');
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Perfect Week, earned'), findsOneWidget);
    expect(find.bySemanticsLabel('Mistake Mechanic, locked'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Perfect Week, earned'));
    await tester.pumpAndSettle();
    expect(find.text('achievement-perfect-week'), findsOneWidget);
  });

  testWidgets('family section is conditional and reflects local member state', (
    tester,
  ) async {
    final container = await _pump(tester, width: 320, textScale: 2);
    final semantics = tester.ensureSemantics();

    expect(find.text('MAX FAMILY'), findsNothing);
    container.read(extendedControllerProvider.notifier)
      ..choosePlan('max-family')
      ..confirmPlan();
    await tester.pump();
    expect(find.text('MAX FAMILY'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Max Family, no invited members'),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.bySemanticsLabel('Max Family, no invited members')),
      const Size(320, 88),
    );

    expect(
      container.read(extendedControllerProvider.notifier).invite('Alex Smith'),
      isNull,
    );
    await tester.pump();
    expect(
      find.bySemanticsLabel('Max Family, 1 invited member: Alex Smith'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.bySemanticsLabel('Manage Max Family'));
    await tester.pumpAndSettle();
    expect(find.text('family-route'), findsOneWidget);
    semantics.dispose();
  });
}
