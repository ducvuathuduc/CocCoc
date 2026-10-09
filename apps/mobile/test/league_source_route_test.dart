import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/account/application/avatar_controller.dart';
import 'package:cocenglish/features/account/data/avatar_assets.dart';
import 'package:cocenglish/features/account/presentation/avatar_motion.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/presentation/social_screens.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'one local lesson unlocks Welcome; Continue joins without reward',
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
      final c = ProviderScope.containerOf(
        t.element(find.byTooltip('Practice')),
      );
      c
          .read(learningStateProvider.notifier)
          .claim(
            const SessionReceipt(
              id: 'league-eligibility',
              nodeId: 'english-lesson',
              xp: 20,
              accuracy: 1,
              elapsed: Duration(minutes: 1),
              firstCompletion: true,
              guest: false,
              placement: false,
            ),
          );
      final progress = c.read(learningStateProvider);
      await t.tap(find.byTooltip('League'));
      await t.pumpAndSettle();
      expect(find.text('Welcome to Leaderboards!'), findsOneWidget);
      expect(c.read(previewControllerProvider).leagueOptIn, isFalse);
      await t.runAsync(() => c.read(avatarCatalogProvider.future));
      await t.ensureVisible(find.text('CONTINUE'));
      await t.pump();
      await t.tap(find.text('CONTINUE'));
      await t.pumpAndSettle();
      expect(find.text('Bronze League'), findsOneWidget);
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 350)),
      );
      await t.pump();
      expect(c.read(previewControllerProvider).leagueOptIn, isTrue);
      expect(c.read(learningStateProvider).xp, progress.xp);
      expect(
        c.read(learningStateProvider).completedLessons,
        progress.completedLessons,
      );
      await t.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('League keeps saved avatar and separate status interaction', (
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
    final catalog = await t.runAsync(
      () => c.read(avatarCatalogProvider.future),
    );
    final avatar = c.read(avatarControllerProvider.notifier)
      ..attachCatalog(catalog!);
    avatar.begin();
    avatar.select('MainHair', 40);
    avatar.save();
    final saved = c.read(avatarControllerProvider).saved;
    c.read(previewControllerProvider.notifier).optIntoLeague();
    await t.tap(find.byTooltip('League'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.byKey(const ValueKey('league-own-status')),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('league')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      t
          .widget<AvatarMotion>(
            find.byKey(const ValueKey('league-saved-avatar')),
          )
          .values,
      saved,
    );
    await t.tap(find.bySemanticsLabel('Set your status'));
    await t.pumpAndSettle();
    expect(find.text('Set your status'), findsOneWidget);
    expect(
      t
          .widget<AvatarMotion>(
            find.descendant(
              of: find.byType(StatusPickerSheet),
              matching: find.byType(AvatarMotion),
            ),
          )
          .values,
      saved,
    );
    expect(c.read(avatarControllerProvider).saved, saved);
  });

  testWidgets('joined League keeps source layout and profile Back state', (
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
    c.read(previewControllerProvider.notifier).optIntoLeague();
    await t.tap(find.byTooltip('League'));
    await t.pumpAndSettle();
    expect(find.textContaining('Sample weekly ranking'), findsNothing);
    expect(find.text('6 DAYS'), findsOneWidget);
    expect(find.text('Compete with other learners.'), findsOneWidget);
    expect(t.getTopLeft(find.text('Bronze League')).dx, lessThan(40));
    final headerY = t.getTopLeft(find.text('Bronze League')).dy;
    final list = find
        .descendant(
          of: find.byKey(const PageStorageKey('league')),
          matching: find.byType(Scrollable),
        )
        .first;
    await t.scrollUntilVisible(
      find.byKey(const ValueKey('league-row-Noah')),
      180,
      scrollable: list,
    );
    await t.pump();
    final offset = t.state<ScrollableState>(list).position.pixels;
    expect(offset, greaterThan(0));
    expect(t.getTopLeft(find.text('Bronze League')).dy, headerY);
    await t.tap(find.byKey(const ValueKey('league-row-Noah')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    final context = t.element(find.byTooltip('Profile options'));
    expect(GoRouter.of(context).state.uri.path, '/profile/Noah');
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(find.text('Bronze League'), findsOneWidget);
    expect(t.getTopLeft(find.text('Bronze League')).dy, headerY);
    expect(t.state<ScrollableState>(list).position.pixels, offset);
    expect(c.read(previewControllerProvider).leagueOptIn, isTrue);
  });
}
