import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import "package:cocenglish/features/learning/domain/learning_models.dart";
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/domain/course_catalog.dart';
import 'package:cocenglish/features/learning/presentation/sections_screen.dart';
import 'package:cocenglish/features/learning/presentation/unit_guide_screen.dart';

void main() {
  for (final width in [360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('sections screen $width text$scale golden', (tester) async {
        tester.view.physicalSize = Size(width, width == 430 ? 932 : 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer(
          overrides: [
            learningStateProvider.overrideWith(
              () => _MockLearningStateController(20),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: referenceTheme(),
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true,
                  ),
                  child: RepaintBoundary(
                    key: const ValueKey('sections-master-screen'),
                    child: const SectionsScreen(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byKey(const ValueKey('sections-master-screen')),
          matchesGoldenFile(
            'goldens/ui_master/sprint_sections_${width.toInt()}_text${scale.toInt()}.png',
          ),
        );
      });

      testWidgets('unit guide screen $width text$scale golden', (tester) async {
        tester.view.physicalSize = Size(width, width == 430 ? 932 : 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: referenceTheme(),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: RepaintBoundary(
                  key: const ValueKey('guide-master-screen'),
                  child: const UnitGuideScreen(target: CourseTarget(1, 1)),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byKey(const ValueKey('guide-master-screen')),
          matchesGoldenFile(
            'goldens/ui_master/sprint_guide_${width.toInt()}_text${scale.toInt()}.png',
          ),
        );
      });
    }
  }
}

class _MockLearningStateController extends LearningStateController {
  _MockLearningStateController(this._score);
  final int _score;

  @override
  LearningState build() => LearningState(score: _score, streak: 0, gems: 0);
}
