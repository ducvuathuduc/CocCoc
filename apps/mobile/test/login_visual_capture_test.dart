import 'dart:io';
import 'dart:ui' as ui;

import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/auth/application/auth_controller.dart';
import 'package:cocenglish/features/auth/domain/auth_state.dart';
import 'package:cocenglish/features/auth/presentation/login_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'login_flow_test.dart';
import 'support/ui_comparison.dart';

void main() {
  testWidgets('login reference fixtures render native inputs and artwork', (
    tester,
  ) async {
    final comparison = UiComparison(flow: 'login');
    await tester.runAsync(() async {
      final fonts = FontLoader('DuolingoSans')
        ..addFont(rootBundle.load('assets/fonts/DuolingoSans.ttf'))
        ..addFont(rootBundle.load('assets/fonts/DuolingoSans-Bold.ttf'));
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await Future.wait([fonts.load(), icons.load(), ReferenceArt.preload()]);
    });
    const fixtures = <int, AuthState>{
      2: AuthState(),
      3: AuthState(stage: AuthStage.details),
      4: AuthState(
        stage: AuthStage.details,
        email: 'samlee.mobbin+2@gmail.com',
        password: 'reference-only',
      ),
      5: AuthState(stage: AuthStage.busy, busy: true),
      7: AuthState(
        remembered: AuthUser(
          id: 'reference-only',
          email: 'samlee.mobbin+3@gmail.com',
          name: 'Sam Lee',
        ),
      ),
      13: AuthState(
        stage: AuthStage.forgot,
        email: 'samlee.mobbin+5@gmail.com',
      ),
      15: AuthState(
        stage: AuthStage.reset,
        recoveryUserId: 'fixture',
        recoverySecret: 'fixture',
      ),
      16: AuthState(
        stage: AuthStage.reset,
        recoveryUserId: 'fixture',
        recoverySecret: 'fixture',
        newPassword: 'reference-only',
        confirmPassword: 'reference-only',
      ),
    };
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    for (final fixture in fixtures.entries) {
      final physicalWidth = fixture.key <= 5 && fixture.key != 1
          ? 1179.0
          : fixture.key == 7
          ? 1179.0
          : 1180.0;
      tester.view.physicalSize = Size(physicalWidth, 2556);
      tester.view.devicePixelRatio = physicalWidth / 390;
      tester.view.padding = FakeViewPadding(
        top: 59 * physicalWidth / 390,
        bottom: 34 * physicalWidth / 390,
      );
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: ProviderScope(
            key: ValueKey(fixture.key),
            overrides: [
              authAvailableProvidersProvider.overrideWithValue(
                AuthProvider.values.toSet(),
              ),
              authControllerProvider.overrideWith(
                () => FixtureAuthController(fixture.value),
              ),
            ],
            child: MaterialApp(
              theme: referenceTheme(),
              debugShowCheckedModeBanner: false,
              home: LoginFlow(initialize: false, onExit: () {}, onStart: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => ReferenceArt.preloadFiles(
          tester
              .widgetList<ReferenceArt>(find.byType(ReferenceArt))
              .map((art) => art.region.file),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (fixture.key == 3) {
        expect(find.byType(TextField), findsNWidgets(2));
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'SIGN IN'))
              .onPressed,
          isNull,
        );
      }
      if (const bool.fromEnvironment('CAPTURE_UI')) {
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final frame = await render.toImage(pixelRatio: physicalWidth / 390);
          final data = await frame.toByteData(format: ui.ImageByteFormat.png);
          final output = File(
            '../../docs/design/qa/login/${fixture.key.toString().padLeft(2, '0')}.png',
          );
          await output.parent.create(recursive: true);
          await output.writeAsBytes(data!.buffer.asUint8List());
          await comparison.compare(fixture.key, frame);
          frame.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
    if (const bool.fromEnvironment('CAPTURE_UI')) {
      await tester.runAsync(comparison.write);
    }
  });
}
