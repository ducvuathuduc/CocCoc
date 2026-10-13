import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/domain/preview_state.dart';
import 'package:cocenglish/features/quests/data/quests_repository.dart';
import 'package:cocenglish/features/quests/domain/quest_models.dart';
import 'package:cocenglish/features/quests/presentation/chest_opening.dart';
import 'package:cocenglish/features/quests/presentation/quests_screen.dart';
import 'package:cocenglish/features/quests/application/quests_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_fonts.dart';

/// Audit row 17: daily-quest chest opening after a credited claim.
class _Quests implements QuestsRepository {
  const _Quests();
  @override
  QuestsTabState loadQuests({
    QuestSectionType sectionType = QuestSectionType.friends,
  }) => const MockQuestsRepository().loadQuests().copyWith(
    introSeen: true,
    dailyQuests: const [
      DailyQuest(
        id: 'daily-score',
        title: 'Score 90% in 1 lesson',
        current: 1,
        target: 1,
        chestType: QuestChestType.silver,
      ),
    ],
  );
}

class _Preview extends PreviewController {
  @override
  PreviewState build() => const PreviewState(questIntroSeen: true);
}

Future<ProviderContainer> _pump(WidgetTester t, {bool reduced = true}) async {
  t.view.physicalSize = const Size(360, 780);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final c = ProviderContainer(
    overrides: [
      questsRepositoryProvider.overrideWithValue(const _Quests()),
      previewControllerProvider.overrideWith(_Preview.new),
    ],
  );
  addTearDown(c.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: referenceTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduced,
            padding: const EdgeInsets.only(top: 56, bottom: 34),
          ),
          child: child!,
        ),
        home: const QuestsScreen(),
      ),
    ),
  );
  await t.pumpAndSettle();
  final quest = find.text('Score 90% in 1 lesson');
  await t.scrollUntilVisible(quest, 100);
  await t.pumpAndSettle();
  await t.tap(quest);
  return c;
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await ReferenceArt.preloadFiles(['quests-06', 'lesson-01']);
  });

  testWidgets('reduced motion shows the opened chest at once', (t) async {
    final c = await _pump(t);
    await t.pump();
    expect(find.byKey(const ValueKey('chest-opening')), findsOneWidget);
    expect(find.text('+10'), findsOneWidget);
    expect(find.text('You earned 10 gems!'), findsOneWidget);
    expect(c.read(previewWalletProvider), greaterThanOrEqualTo(10));
    await t.tap(find.text('CONTINUE'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('chest-opening')), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('motion: pop, wiggle, burst, gems, then copy', (t) async {
    await _pump(t, reduced: false);
    await t.pump();
    await t.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const ValueKey('chest-opening')), findsOneWidget);
    Opacity copy() => t.widget<Opacity>(
      find
          .ancestor(of: find.text('+10'), matching: find.byType(Opacity))
          .first,
    );
    expect(copy().opacity, 0);
    // CONTINUE is not tappable mid-animation.
    await t.tap(find.text('CONTINUE'), warnIfMissed: false);
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('chest-opening')), findsOneWidget);
    await t.pump(ChestOpeningMotion.total);
    expect(copy().opacity, 1);
    await t.tap(find.text('CONTINUE'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
    expect(find.byKey(const ValueKey('chest-opening')), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a second claim does not reopen the chest', (t) async {
    await _pump(t);
    await t.pump();
    await t.tap(find.text('CONTINUE'));
    await t.pumpAndSettle();
    await t.tap(find.text('Score 90% in 1 lesson'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('chest-opening')), findsNothing);
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('chest opening goldens at 360 (burst and final)', (t) async {
    await _pump(t, reduced: false);
    await t.pump();
    // Lid off, flash and rays mid-burst (≈1.05 s of 1.8 s).
    await t.pump(const Duration(milliseconds: 1050));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/gap/chest_opening_burst_360.png'),
    );
    await t.pump(ChestOpeningMotion.total);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/gap/chest_opening_360.png'),
    );
    await t.pumpWidget(const SizedBox.shrink());
  });
}
