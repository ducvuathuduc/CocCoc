import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'profile password route closes back without losing profile draft',
    (t) async {
      await t.pumpWidget(
        MainApp(
          initial: OnboardingState(
            step: OnboardingStep.lessonEntry,
            language: 'English',
          ),
        ),
      );
      await t.pumpAndSettle();
      GoRouter.of(t.element(find.byTooltip('Practice')))
          .push('/settings/profile');
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, 'Draft learner');
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('profile-password')),
        240,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('profile-editor-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.tap(find.byKey(const ValueKey('profile-password')));
      await t.pumpAndSettle();
      expect(find.text('Old password'), findsOneWidget);
      await t.enterText(find.byKey(const ValueKey('password-old')), 'draft');
      await t.tap(find.byTooltip('Close password'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('profile-first')),
        -240,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('profile-editor-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Draft learner'), findsOneWidget);
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('profile-password')),
        240,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('profile-editor-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.tap(find.byKey(const ValueKey('profile-password')));
      await t.pumpAndSettle();
      expect(
        t
            .widget<TextFormField>(find.byKey(const ValueKey('password-old')))
            .initialValue,
        '',
      );
    },
  );
}
