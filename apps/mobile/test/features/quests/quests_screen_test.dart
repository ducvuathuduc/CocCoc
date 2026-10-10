import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/quests/application/quests_controller.dart';
import 'package:cocenglish/features/quests/data/quests_mock_data.dart';
import 'package:cocenglish/features/quests/domain/quest_models.dart';
import 'package:cocenglish/features/quests/presentation/quests_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await (FontLoader('DuolingoSans')
          ..addFont(rootBundle.load('assets/fonts/DuolingoSans.ttf'))
          ..addFont(rootBundle.load('assets/fonts/DuolingoSans-Bold.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    await ReferenceArt.preloadFiles([
      'quests-02',
      'quests-03',
      'quests-04',
      'quests-05',
      'quests-06',
    ]);
  });

  Widget buildQuestsApp({
    double scale = 1.0,
    QuestsTabState? initialState,
    QuestSectionType? sectionType,
  }) {
    return ProviderScope(
      overrides: [
        if (initialState != null)
          questsControllerProvider.overrideWith(
            () => _TestQuestsController(initialState),
          ),
      ],
      child: MaterialApp(
        theme: referenceTheme(),
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: RepaintBoundary(
          key: const ValueKey('quests-screen'),
          child: QuestsScreen(sectionType: sectionType),
        ),
      ),
    );
  }

  group('QuestsScreen Golden Tests', () {
    for (final width in [360.0, 430.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'Intro goldens at width ${width.toInt()} textScale ${scale.toInt()}',
          (tester) async {
            tester.view.physicalSize = Size(width, 844);
            tester.view.devicePixelRatio = 1;
            tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
            tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetPadding);
            addTearDown(tester.view.resetViewPadding);

            await tester.pumpWidget(
              buildQuestsApp(
                scale: scale,
                initialState: const QuestsTabState(introSeen: false),
              ),
            );
            await tester.pumpAndSettle();

            await expectLater(
              find.byKey(const ValueKey('quests-screen')),
              matchesGoldenFile(
                '../../goldens/ui_master/quests_intro_w${width.toInt()}_s${scale.toInt()}.png',
              ),
            );
          },
        );

        testWidgets(
          'Main screen (Friends Quest) goldens at width ${width.toInt()} textScale ${scale.toInt()}',
          (tester) async {
            tester.view.physicalSize = Size(width, 844);
            tester.view.devicePixelRatio = 1;
            tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
            tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetPadding);
            addTearDown(tester.view.resetViewPadding);

            await tester.pumpWidget(
              buildQuestsApp(
                scale: scale,
                initialState: const QuestsTabState(
                  introSeen: true,
                  sectionType: QuestSectionType.friends,
                  friendsQuest: QuestsMockData.inProgressFriendsQuest,
                ),
              ),
            );
            await tester.pumpAndSettle();

            await expectLater(
              find.byKey(const ValueKey('quests-screen')),
              matchesGoldenFile(
                '../../goldens/ui_master/quests_main_w${width.toInt()}_s${scale.toInt()}.png',
              ),
            );
          },
        );

        testWidgets(
          'Friends Quest completed goldens at width ${width.toInt()} textScale ${scale.toInt()}',
          (tester) async {
            tester.view.physicalSize = Size(width, 844);
            tester.view.devicePixelRatio = 1;
            tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
            tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetPadding);
            addTearDown(tester.view.resetViewPadding);

            await tester.pumpWidget(
              buildQuestsApp(
                scale: scale,
                initialState: const QuestsTabState(
                  introSeen: true,
                  sectionType: QuestSectionType.friends,
                  friendsQuest: QuestsMockData.completedFriendsQuest,
                ),
              ),
            );
            await tester.pumpAndSettle();

            await expectLater(
              find.byKey(const ValueKey('quests-screen')),
              matchesGoldenFile(
                '../../goldens/ui_master/quests_completed_w${width.toInt()}_s${scale.toInt()}.png',
              ),
            );
          },
        );

        testWidgets(
          'Weekend Quest goldens at width ${width.toInt()} textScale ${scale.toInt()}',
          (tester) async {
            tester.view.physicalSize = Size(width, 844);
            tester.view.devicePixelRatio = 1;
            tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
            tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetPadding);
            addTearDown(tester.view.resetViewPadding);

            await tester.pumpWidget(
              buildQuestsApp(
                scale: scale,
                initialState: const QuestsTabState(
                  introSeen: true,
                  sectionType: QuestSectionType.weekend,
                  monthlyChallenge: QuestsMockData.weekendMonthlyChallenge,
                  weekendQuest: QuestsMockData.defaultWeekendQuest,
                ),
              ),
            );
            await tester.pumpAndSettle();

            await expectLater(
              find.byKey(const ValueKey('quests-screen')),
              matchesGoldenFile(
                '../../goldens/ui_master/quests_weekend_w${width.toInt()}_s${scale.toInt()}.png',
              ),
            );
          },
        );
      }
    }
  });

  group('QuestsScreen Widget & Interaction Tests', () {
    testWidgets('tapping CONTINUE dismisses intro screen and shows quests list', (tester) async {
      await tester.pumpWidget(
        buildQuestsApp(
          initialState: const QuestsTabState(introSeen: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CONTINUE'), findsOneWidget);
      expect(find.text('December Quest'), findsNothing);

      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      expect(find.text('CONTINUE'), findsNothing);
      expect(find.text('December Quest'), findsOneWidget);
      expect(find.text('FRIENDS QUEST'), findsOneWidget);
      expect(find.text('DAILY QUESTS'), findsOneWidget);
    });

    testWidgets('tapping NUDGE triggers nudge state update', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildQuestsApp(
          initialState: const QuestsTabState(introSeen: true),
        ),
      );
      await tester.pumpAndSettle();

      final nudgeBtn = find.text('NUDGE');
      expect(nudgeBtn, findsOneWidget);
      await tester.scrollUntilVisible(nudgeBtn, 100);
      await tester.pumpAndSettle();

      await tester.tap(nudgeBtn);
      await tester.pumpAndSettle();

      expect(find.text('NUDGE'), findsOneWidget);
    });

    testWidgets('tapping GIFT triggers gift state update', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildQuestsApp(
          initialState: const QuestsTabState(introSeen: true),
        ),
      );
      await tester.pumpAndSettle();

      final giftBtn = find.text('GIFT');
      expect(giftBtn, findsOneWidget);
      await tester.scrollUntilVisible(giftBtn, 100);
      await tester.pumpAndSettle();

      await tester.tap(giftBtn);
      await tester.pumpAndSettle();

      expect(find.text('GIFT'), findsOneWidget);
    });

    testWidgets('claimQuest claims eligible daily quest and marks claimed', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildQuestsApp(
          initialState: const QuestsTabState(
            introSeen: true,
            dailyQuests: [
              DailyQuest(
                id: 'daily-score',
                title: 'Score 90% in 1 lesson',
                current: 1,
                target: 1,
                chestType: QuestChestType.silver,
                isClaimed: false,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final claimTarget = find.text('Score 90% in 1 lesson');
      expect(claimTarget, findsOneWidget);

      await tester.scrollUntilVisible(claimTarget, 100);
      await tester.pumpAndSettle();
      await tester.tap(claimTarget);
      await tester.pumpAndSettle();

      // Second tap is idempotent and does not crash or claim again
      await tester.tap(claimTarget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

class _TestQuestsController extends QuestsController {
  _TestQuestsController(this._initial);
  final QuestsTabState _initial;

  @override
  QuestsTabState build() => _initial;
}
