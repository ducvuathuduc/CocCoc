import 'dart:io';
import 'dart:ui' as ui;

import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/practice/presentation/practice_screens.dart';
import 'package:cocenglish/features/profile/profile_mock.dart';
import 'package:cocenglish/features/profile/profile_tab_screen.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/domain/preview_state.dart';
import 'package:cocenglish/features/progress/presentation/social_screens.dart';
import 'package:cocenglish/features/quests/presentation/quests_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'support/app_fonts.dart';
import 'support/settle_images.dart';

class _QuestsPreview extends PreviewController {
  @override
  PreviewState build() => const PreviewState(questIntroSeen: true);
}

Future<GlobalKey> _pump(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  tester.view.physicalSize = const Size(360, 717);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final boundary = GlobalKey();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: referenceTheme(brightness: Brightness.dark),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 717),
            disableAnimations: true,
          ),
          child: RepaintBoundary(key: boundary, child: screen),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await settleImages(tester);
  return boundary;
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundary,
  String name,
) async {
  const output = String.fromEnvironment('DARK_MODE_CAPTURE_DIR');
  if (output.isEmpty) return;
  await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(output).create(recursive: true);
    await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(loadAppFonts);
  testWidgets('practice and profile source surfaces use dark neutral palette', (
    tester,
  ) async {
    final practiceBoundary = await _pump(tester, const PracticeHubScreen());
    final practice = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(practice.backgroundColor, ReferencePalette.dark.surface);
    expect(
      tester.widget<Text>(find.text('Skill practice')).style?.color,
      ReferencePalette.dark.ink,
    );
    await _capture(tester, practiceBoundary, 'dark-practice');

    final profileBoundary = await _pump(
      tester,
      const ProfileTabScreen(profile: profileMockNew),
    );
    final profile = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(profile.backgroundColor, ReferencePalette.dark.surface);
    expect(
      tester
          .widget<Text>(find.text('@SAMLEE782112 · JOINED 2025'))
          .style
          ?.color,
      ReferencePalette.dark.disabled,
    );
    await _capture(tester, profileBoundary, 'dark-profile');
    expect(tester.takeException(), isNull);
  });

  testWidgets('quests and feed source surfaces keep readable dark neutrals', (
    tester,
  ) async {
    final questsBoundary = await _pump(
      tester,
      const QuestsScreen(),
      overrides: [previewControllerProvider.overrideWith(_QuestsPreview.new)],
    );
    final quests = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(quests.backgroundColor, ReferencePalette.dark.surface);
    await _capture(tester, questsBoundary, 'dark-quests');

    final feedBoundary = await _pump(tester, const FeedScreen());
    final rich = tester.widget<RichText>(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('Add friends'),
      ),
    );
    expect((rich.text as TextSpan).style?.color, ReferencePalette.dark.ink);
    await _capture(tester, feedBoundary, 'dark-feed');
    expect(tester.takeException(), isNull);
  });
}
