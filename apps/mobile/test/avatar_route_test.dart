import 'package:cocenglish/main.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cocenglish/features/account/data/avatar_assets.dart';

void main() {
  testWidgets('profile opens avatar and cancel preserves profile draft', (
    t,
  ) async {
    await t.pumpWidget(
      MainApp(
        initial: OnboardingState(
          step: OnboardingStep.lessonEntry,
          language: 'English',
        ),
      ),
    );
    await t.pumpAndSettle();
    final c = ProviderScope.containerOf(t.element(find.byTooltip('Practice')));
    await t.runAsync(() => c.read(avatarCatalogProvider.future));
    GoRouter.of(t.element(find.byTooltip('Practice')))
        .push('/settings/profile');
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const ValueKey('profile-first')),
      'Draft learner',
    );
    await t.ensureVisible(find.text('CHANGE AVATAR'));
    await t.tap(find.text('CHANGE AVATAR'));
    await t.pumpAndSettle();
    expect(find.text('Create Avatar'), findsOneWidget);
    await t.tap(find.byTooltip('Close avatar builder'));
    await t.pumpAndSettle();
    expect(find.text('Draft learner'), findsOneWidget);
  });
}
