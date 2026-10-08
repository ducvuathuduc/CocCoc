import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/progress/application/profile_actions_controller.dart';
import 'package:cocenglish/features/progress/application/profile_summary_provider.dart';
import 'package:cocenglish/features/progress/presentation/hub_screens.dart';
import 'package:cocenglish/features/progress/presentation/own_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every profile action fixture has an immutable display summary', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    for (final userId in sampleProfileIds) {
      final summary = container.read(profileSummaryProvider(userId));
      expect(summary, isNotNull, reason: 'Missing summary for $userId');
      expect(summary!.userId, userId);
      expect(summary.name, isNotEmpty);
      expect(summary.xp, greaterThanOrEqualTo(0));
    }
  });

  testWidgets('foreign profile metrics do not borrow learner progress', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: referenceTheme(),
          home: const ProfileScreen(userId: 'Alex'),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('foreign-profile-total-xp')))
          .data,
      '120',
    );
    expect(find.text('120'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Bronze'), findsOneWidget);
    expect(find.text('Top 3 finishes'), findsOneWidget);

    container
        .read(learningStateProvider.notifier)
        .claim(
          const SessionReceipt(
            id: 'own-study',
            nodeId: 'own-node',
            xp: 999,
            accuracy: 1,
            elapsed: Duration(minutes: 5),
            firstCompletion: true,
            guest: false,
            placement: false,
          ),
        );
    await tester.pump();

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('foreign-profile-total-xp')))
          .data,
      '120',
    );
    expect(find.text('120'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Bronze'), findsOneWidget);
    expect(find.text('Top 3 finishes'), findsOneWidget);
    expect(find.text('999'), findsNothing);
  });

  testWidgets('own profile still delegates to its dedicated screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: referenceTheme(),
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(OwnProfileScreen), findsOneWidget);
  });
}
