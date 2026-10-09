import 'dart:io';
import 'dart:ui' as ui;

import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/progress/application/profile_actions_controller.dart';
import 'package:cocenglish/features/progress/presentation/hub_screens.dart';
import 'package:cocenglish/features/account/presentation/course_management_screen.dart';
import 'package:cocenglish/features/account/application/course_management_controller.dart';
import 'package:cocenglish/features/account/presentation/password_change_screen.dart';
import 'package:cocenglish/features/auth/application/auth_controller.dart';
import 'package:cocenglish/features/auth/data/mock_auth_repository.dart';
import 'package:cocenglish/features/auth/presentation/login_flow.dart';
import 'package:cocenglish/features/onboarding/presentation/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('source sized profile/course continuation captures', (t) async {
    if (!const bool.fromEnvironment('CAPTURE_UI')) return;
    final oldShadows = debugDisableShadows;
    debugDisableShadows = false;
    const ratio = 1180 / 390;
    t.view.physicalSize = const Size(1180, 2556);
    t.view.devicePixelRatio = ratio;
    t.view.padding = const FakeViewPadding(top: 59 * ratio, bottom: 34 * ratio);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPadding);
    await t.runAsync(() async {
      await (FontLoader('DuolingoSans')
            ..addFont(rootBundle.load('assets/fonts/DuolingoSans.ttf'))
            ..addFont(rootBundle.load('assets/fonts/DuolingoSans-Bold.ttf')))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await ReferenceArt.preloadFiles([
        '02',
        'course-remove',
        '05',
        'profile-01',
        'profile-02',
        'lesson-01',
      ]);
    });
    for (final scene in [
      'courses',
      'course-confirm',
      'course-removing',
      'course-removed',
      'profile-link',
      'profile-link-copied',
      'report-reasons',
      'profile-blocked',
      'password-empty',
      'password-filled',
      'password-error',
      'password-mismatch',
      'saved-accounts',
      'saved-account-remove',
      'saved-account-removed',
    ]) {
      final repository = MockAuthRepository(delay: Duration.zero);
      if (scene.startsWith('saved-account')) {
        await t.runAsync(
          () => repository.signIn('demo@cocenglish.test', 'duolingo-demo'),
        );
      }
      final c = ProviderContainer(
        overrides: [
          profileClipboardWriterProvider.overrideWithValue((_) async {}),
          authRepositoryProvider.overrideWithValue(repository),
        ],
      );
      if (scene.startsWith('saved-account')) {
        await t.runAsync(
          () => c.read(authControllerProvider.notifier).initialize(),
        );
      }
      final courses = scene.startsWith('course');
      if (scene == 'course-removed') {
        c.read(courseManagementProvider.notifier).requestRemoval('italian');
        await t.runAsync(
          () => c.read(courseManagementProvider.notifier).confirmRemoval(),
        );
      }
      if (scene == 'profile-blocked') {
        c.read(profileActionsProvider.notifier).reportAndBlock('Alex', 'Spam');
      }
      final boundary = GlobalKey();
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: referenceTheme(),
              home: courses
                  ? const CourseManagementScreen()
                  : scene.startsWith('password')
                  ? const PasswordChangeScreen()
                  : scene.startsWith('saved-account')
                  ? Builder(
                      builder: (context) => LoginFlow(
                        initialize: false,
                        onExit: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                WelcomeScreen(onStart: () {}, onLogin: () {}),
                          ),
                        ),
                        onStart: () {},
                      ),
                    )
                  : ProfileScreen(
                      userId: scene.startsWith('profile-link') ? 'me' : 'Alex',
                    ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      if (scene.startsWith('saved-account')) {
        await t.tap(find.text('MANAGE ACCOUNTS'));
        await t.pumpAndSettle();
        if (scene != 'saved-accounts') {
          await t.tap(find.bySemanticsLabel('Remove saved account'));
          await t.pumpAndSettle();
          if (scene == 'saved-account-removed') {
            await t.tap(find.text('Remove'));
            await t.pumpAndSettle();
          }
        }
      }
      if (scene.startsWith('password') && scene != 'password-empty') {
        await t.enterText(
          find.byKey(const ValueKey('password-old')),
          scene == 'password-error' ? 'wrong' : 'duolingo-demo',
        );
        await t.enterText(
          find.byKey(const ValueKey('password-new')),
          'replacement-demo',
        );
        await t.enterText(
          find.byKey(const ValueKey('password-confirm')),
          scene == 'password-mismatch' ? 'different-demo' : 'replacement-demo',
        );
        await t.testTextInput.receiveAction(TextInputAction.done);
        await t.pumpAndSettle();
        if (scene == 'password-error') {
          await t.tap(find.text('SAVE'));
          await t.pumpAndSettle();
        }
      }
      if (scene == 'course-confirm' || scene == 'course-removing') {
        await t.tap(find.bySemanticsLabel('Remove Italian course'));
        await t.pumpAndSettle();
        if (scene == 'course-removing') {
          await t.tap(find.text('REMOVE'));
          await t.pump();
          await t.pump(const Duration(milliseconds: 250));
          expect(
            c.read(courseManagementProvider).phase,
            CourseRemovalPhase.removing,
          );
        }
      }
      if (scene.startsWith('profile-link')) {
        await t.tap(find.byTooltip('Profile link'));
        await t.pumpAndSettle();
        if (scene.endsWith('copied')) {
          await t.tap(find.byTooltip('Copy link'));
          await t.pumpAndSettle();
        }
      }
      if (scene == 'report-reasons') {
        await t.tap(find.byTooltip('Profile options'));
        await t.pumpAndSettle();
        await t.tap(find.text('Report user'));
        await t.pumpAndSettle();
      }
      await t.runAsync(() async {
        await ReferenceArt.preloadFiles([
          '05',
          'profile-01',
          '02',
          'course-remove',
        ]);
      });
      await t.pump();
      expect(t.takeException(), isNull);
      await t.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: ratio);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          '../../docs/design/qa/english-continuation/$scene.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      if (scene == 'course-removing') await t.pump(const Duration(seconds: 1));
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      c.dispose();
    }
    debugDisableShadows = oldShadows;
  });
}
