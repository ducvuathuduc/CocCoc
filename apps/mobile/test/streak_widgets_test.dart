import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/progress/application/streak_widgets_controller.dart';
import 'package:cocenglish/features/progress/domain/streak_widget.dart';
import 'package:cocenglish/features/progress/presentation/streak_widgets_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'widget choices are immutable and invalid choices preserve selection',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(streakWidgetStyles, hasLength(7));
      expect(() => streakWidgetStyles.clear(), throwsUnsupportedError);
      final controller = container.read(streakWidgetsProvider.notifier);
      controller.select(StreakWidgetMood.practice);
      expect(container.read(streakWidgetsProvider), StreakWidgetMood.practice);
      expect(container.read(learningStateProvider).xp, 0);
    },
  );

  testWidgets(
    'gallery keeps selected portrait, count, and platform instructions',
    (t) async {
      await t.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: referenceTheme(),
            home: const StreakWidgetsScreen(),
          ),
        ),
      );
      expect(find.text('Streak widgets'), findsOneWidget);
      expect(find.text('Ready to start learning?'), findsWidgets);
      await t.scrollUntilVisible(
        find.bySemanticsLabel('Please practice!'),
        180,
      );
      await t.pumpAndSettle();
      await t.tap(find.bySemanticsLabel('Please practice!').hitTestable());
      await t.pumpAndSettle();
      await t.drag(find.byType(ListView), const Offset(0, 800));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('widget-medium-practice')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('widget-small-practice')),
        findsOneWidget,
      );
      final c = ProviderScope.containerOf(
        t.element(find.byType(StreakWidgetsScreen)),
      );
      final before = c.read(learningStateProvider);
      await t.scrollUntilVisible(find.text('HOW TO ADD A WIDGET'), 180);
      await t.pumpAndSettle();
      await t.tap(find.text('HOW TO ADD A WIDGET').hitTestable());
      await t.pumpAndSettle();
      expect(find.text('Add a widget'), findsOneWidget);
      expect(find.textContaining('Touch and hold'), findsWidgets);
      await t.tap(find.text('Android'));
      await t.pumpAndSettle();
      expect(find.textContaining('Widgets'), findsWidgets);
      await t.tap(find.text('DONE'));
      await t.pumpAndSettle();
      expect(c.read(streakWidgetsProvider), StreakWidgetMood.practice);
      expect(c.read(learningStateProvider).xp, before.xp);
      expect(c.read(learningStateProvider).streak, before.streak);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'all widget moods keep text separate from undistorted Duo at narrow sizes',
    (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final before = c.read(learningStateProvider);
      for (final scale in [1.0, 2.0]) {
        for (final style in streakWidgetStyles) {
          c.read(streakWidgetsProvider.notifier).select(style.mood);
          await t.pumpWidget(
            MaterialApp(
              theme: referenceTheme(),
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(320, 568),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: Column(
                      children: [
                        StreakWidgetCard(
                          key: const ValueKey('medium'),
                          style: style,
                          streak: 6,
                        ),
                        SizedBox(
                          width: 162,
                          child: StreakWidgetCard(
                            key: const ValueKey('small'),
                            style: style,
                            streak: 6,
                            small: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          for (final small in [false, true]) {
            final card = find.byKey(ValueKey(small ? 'small' : 'medium'));
            final art = find.descendant(
              of: card,
              matching: find.byType(ReferenceArt),
            );
            final title = find.descendant(
              of: card,
              matching: find.text(small ? style.smallTitle : style.title),
            );
            final artRect = t.getRect(art);
            final textRect = t.getRect(title);
            expect(
              artRect.overlaps(textRect),
              isFalse,
              reason: '${style.mood.name} small=$small text=$scale',
            );
            final source = small ? style.smallArt : style.mediumArt;
            expect(
              artRect.width / artRect.height,
              closeTo(source.$3 / source.$4, .001),
            );
            expect(
              find.bySemanticsLabel(
                '${small ? 'Small' : 'Medium'} widget, 6 day streak, ${small ? style.smallTitle : style.title}',
              ),
              findsOneWidget,
            );
          }
          expect(
            t.takeException(),
            isNull,
            reason: '${style.mood.name} text=$scale',
          );
        }
      }
      expect(c.read(learningStateProvider).xp, before.xp);
      expect(c.read(learningStateProvider).streak, before.streak);
    },
  );

  testWidgets(
    '320 text2 gallery and instructions scroll without shrinking text',
    (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: referenceTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: const StreakWidgetsScreen(),
          ),
        ),
      );
      await t.scrollUntilVisible(find.text('HOW TO ADD A WIDGET'), 180);
      await t.pumpAndSettle();
      await t.tap(find.text('HOW TO ADD A WIDGET').hitTestable());
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('DONE'));
      await t.tap(find.text('DONE'));
      await t.pumpAndSettle();
      expect(find.byType(FittedBox), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
}
