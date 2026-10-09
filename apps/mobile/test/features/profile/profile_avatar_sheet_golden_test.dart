import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/profile/profile_mock.dart';
import 'package:cocenglish/features/profile/profile_tab_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Avatar creation sheet goldens (ref 03.png): drag handle, 3 avatars,
/// START (blue tactile) + MAYBE LATER.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('DuolingoSans')
          ..addFont(rootBundle.load('assets/fonts/DuolingoSans.ttf'))
          ..addFont(rootBundle.load('assets/fonts/DuolingoSans-Bold.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final width in [360.0, 430.0]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets(
        'avatar sheet ${width.toInt()} text${textScale.toInt()} golden',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: referenceTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: true,
                  textScaler: TextScaler.linear(textScale),
                  padding: const EdgeInsets.only(top: 59, bottom: 34),
                ),
                child: RepaintBoundary(
                  key: const ValueKey('ui-master-screen'),
                  child: child!,
                ),
              ),
              home: const ProfileTabScreen(profile: profileMockNew),
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('COMPLETE PROFILE'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('COMPLETE PROFILE'));
          await tester.pumpAndSettle();
          expect(find.text('Create your avatar!'), findsOneWidget);
          expect(find.text('START'), findsOneWidget);
          expect(find.text('MAYBE LATER'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(const ValueKey('ui-master-screen')),
            matchesGoldenFile(
              '../../goldens/ui_master/profile_avatar_sheet_${width.toInt()}_text${textScale.toInt()}.png',
            ),
          );
        },
      );
    }
  }
}
