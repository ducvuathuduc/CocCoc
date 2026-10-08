import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/account/presentation/account_screens.dart';
import 'package:cocenglish/features/progress/presentation/achievements_screen.dart';
import 'package:cocenglish/features/progress/presentation/super_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'badges and family invite keep engineering notes out of product copy',
    (t) async {
      for (final page in [
        const MonthlyBadgesScreen(),
        const FamilyPlanScreen(),
      ]) {
        await t.pumpWidget(
          ProviderScope(
            child: MaterialApp(theme: referenceTheme(), home: page),
          ),
        );
        await t.pumpAndSettle();
        expect(find.textContaining('archived source'), findsNothing);
        expect(find.text('INVITE TO PREVIEW'), findsNothing);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      }
    },
  );
  testWidgets('connection recovery exposes only learner actions', (t) async {
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: referenceTheme(),
          home: const RecoveryScreen(),
        ),
      ),
    );
    expect(find.text('timeout'), findsNothing);
    expect(find.text('401'), findsNothing);
    expect(find.text('429'), findsNothing);
    expect(find.text('Connection and recovery'), findsNothing);
    await t.tap(find.text('RETRY'));
    await t.pumpAndSettle();
    expect(find.text('You’re ready to continue'), findsOneWidget);
    expect(find.text('CONTINUE'), findsOneWidget);
  });
}
