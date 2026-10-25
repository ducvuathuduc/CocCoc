import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/learning/presentation/learning_path.dart';
import 'package:cocenglish/features/shell/application/app_shell_providers.dart';
import 'package:cocenglish/features/shell/domain/app_shell_models.dart';
import 'package:cocenglish/features/shell/presentation/app_bottom_nav.dart';
import 'package:cocenglish/features/shell/presentation/app_stats_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'dark reduced-motion home keeps the source mascot background transparent',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: referenceTheme(brightness: Brightness.dark),
            home: const Scaffold(
              body: MediaQuery(
                data: MediaQueryData(disableAnimations: true),
                child: LearningPath(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w is ReferenceArt && w.region.file == 'path-duo-transparent',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('dark shell and locked path use native dark source surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStatsProvider.overrideWithValue(const [
            AppStat(
              kind: AppStatKind.course,
              label: 'Courses',
              value: '',
              semanticLabel: 'Courses',
            ),
            AppStat(
              kind: AppStatKind.streak,
              label: 'Streak',
              value: '2',
              semanticLabel: 'Streak, 2 days',
            ),
            AppStat(
              kind: AppStatKind.gems,
              label: 'Shop',
              value: '540',
              semanticLabel: 'Shop, 540 gems',
            ),
            AppStat(
              kind: AppStatKind.hearts,
              label: 'Hearts',
              value: '5',
              semanticLabel: 'Hearts, 5',
            ),
            AppStat(
              kind: AppStatKind.energy,
              label: 'Energy',
              value: '25',
              semanticLabel: 'Energy, 25',
            ),
          ]),
        ],
        child: MaterialApp(
          theme: referenceTheme(brightness: Brightness.dark),
          home: Scaffold(
            body: Column(
              children: [
                AppStatsBar(onSelected: (_) {}),
                PathNode(
                  current: false,
                  completed: false,
                  icon: Icons.lock_rounded,
                  onTap: () {},
                ),
              ],
            ),
            bottomNavigationBar: AppBottomNav(
              selectedBranch: 2,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final nav = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(AppBottomNav),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = nav.decoration! as BoxDecoration;
    expect(decoration.color, ReferencePalette.dark.surface);
    expect(decoration.border!.top.color, ReferencePalette.dark.border);

    final navFiles = tester
        .widgetList<ReferenceArt>(
          find.descendant(
            of: find.byType(AppBottomNav),
            matching: find.byType(ReferenceArt),
          ),
        )
        .map((art) => art.region.file)
        .toList();
    expect(navFiles, const [
      'android-dark-shell-icons',
      'android-dark-shell-icons',
      'android-dark-shell-icons',
      'android-dark-shell-icons',
      'android-dark-shell-icons',
    ]);

    final statFiles = tester
        .widgetList<ReferenceArt>(
          find.descendant(
            of: find.byType(AppStatsBar),
            matching: find.byType(ReferenceArt),
          ),
        )
        .map((art) => art.region.file)
        .toList();
    expect(statFiles, const [
      '05',
      'android-dark-shell-icons',
      'android-dark-shell-icons',
      'android-dark-shell-icons',
      'energy-icon-transparent',
    ]);

    final lockedFace = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(PathNode),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final lockedDecoration = lockedFace.decoration! as BoxDecoration;
    expect(lockedDecoration.color, ReferencePalette.dark.border);
    expect(
      lockedDecoration.boxShadow!.single.color,
      ReferencePalette.dark.raisedSurface,
    );
  });
}
