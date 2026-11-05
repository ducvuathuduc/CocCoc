import 'dart:io';
import 'dart:ui' as ui;

import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/account/presentation/account_screens.dart';
import 'package:cocenglish/features/profile/profile_tab_screen.dart';
import 'package:cocenglish/features/progress/presentation/league_entry_surface.dart';
import 'package:cocenglish/features/progress/presentation/social_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_fonts.dart';
import 'support/settle_images.dart';

Future<GlobalKey> _pump(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(const SizedBox.shrink());
  tester.view.physicalSize = const Size(360, 717);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final boundary = GlobalKey();
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: referenceTheme(brightness: Brightness.dark),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 717),
            textScaler: TextScaler.linear(2),
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

  testWidgets(
    'dark account forms and recovery remain readable at text scale 2',
    (tester) async {
      final schools = await _pump(tester, const SchoolsSettingsScreen());
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.style?.color, ReferencePalette.dark.ink);
      expect(field.decoration?.fillColor, ReferencePalette.dark.raisedSurface);
      await _capture(tester, schools, 'dark-settings-schools-text2');

      final feedback = await _pump(tester, const FeedbackScreen());
      expect(find.text('Feedback'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(tester, feedback, 'dark-settings-feedback-text2');

      await _pump(tester, const RecoveryScreen());
      expect(find.textContaining('answers are saved'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dark league and status modal avoid light neutral slabs', (
    tester,
  ) async {
    final league = await _pump(
      tester,
      LeagueEntrySurface(
        remainingLessons: 0,
        onStartLesson: () {},
        onContinue: () {},
      ),
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox &&
            widget.color == ReferencePalette.dark.surface,
      ),
      findsWidgets,
    );
    await _capture(tester, league, 'dark-league-entry-text2');

    final status = await _pump(
      tester,
      ColoredBox(
        color: ReferencePalette.dark.surface,
        child: const StatusPickerSheet(),
      ),
    );
    expect(find.text('Set your status'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, status, 'dark-status-picker-text2');
  });

  testWidgets('profile share and avatar sheets inherit dark modal palette', (
    tester,
  ) async {
    await _pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              TextButton(
                onPressed: () => showProfileShareSheet(
                  context,
                  userId: 'me',
                  displayName: 'Sam Lee',
                ),
                child: const Text('SHARE'),
              ),
              TextButton(
                onPressed: () => showAvatarCreateSheet(context),
                child: const Text('AVATAR'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('SHARE'));
    await tester.pumpAndSettle();
    expect(find.text('Sam Lee'), findsOneWidget);
    expect(find.textContaining('cocenglish.test'), findsOneWidget);
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.text('Sam Lee'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('AVATAR'));
    await tester.pumpAndSettle();
    expect(find.text('Create your avatar!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
