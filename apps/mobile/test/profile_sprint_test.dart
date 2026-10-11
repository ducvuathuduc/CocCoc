import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/profile/profile_mock.dart';
import 'package:cocenglish/features/profile/profile_tab_screen.dart';

import 'support/app_fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('Profile avatar sheet matches golden 430', (tester) async {
    tester.view.physicalSize = const Size(430, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: referenceTheme(),
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            padding: const EdgeInsets.only(top: 59, bottom: 34),
          ),
          child: RepaintBoundary(
            key: const ValueKey('profile-master-screen'),
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

    await expectLater(
      find.byKey(const ValueKey('profile-master-screen')),
      matchesGoldenFile('goldens/ui_master/sprint_profile_screen_430.png'),
    );
  });
}
