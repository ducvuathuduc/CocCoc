import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/quests/presentation/quests_screen.dart';
import 'package:cocenglish/features/quests/data/quests_repository.dart';
import 'package:cocenglish/features/quests/application/quests_controller.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/domain/preview_state.dart';

import 'support/app_fonts.dart';
import 'support/settle_images.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('QuestsScreen matches golden 430', (tester) async {
    tester.view.physicalSize = const Size(430, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questsRepositoryProvider.overrideWithValue(const MockQuestsRepository()),
          previewControllerProvider.overrideWith(() => _SprintPreviewController()),
        ],
        child: MaterialApp(
          theme: referenceTheme(),
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: RepaintBoundary(
            key: const ValueKey('quests-screen'),
            child: const QuestsScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await settleImages(tester);

    await expectLater(
      find.byKey(const ValueKey('quests-screen')),
      matchesGoldenFile('goldens/ui_master/sprint_quests_screen_430.png'),
    );
  });
}

class _SprintPreviewController extends PreviewController {
  @override
  PreviewState build() => const PreviewState(questIntroSeen: true);
}
