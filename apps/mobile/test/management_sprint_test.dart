import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/account/presentation/course_management_screen.dart';

import 'support/app_fonts.dart';
import 'support/settle_images.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('CourseManagementScreen matches golden 430', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: referenceTheme(),
          home: const Scaffold(
            body: RepaintBoundary(
              key: ValueKey('course-management-screen'),
              child: CourseManagementScreen(),
            ),
          ),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await settleImages(tester);

    await expectLater(
      find.byKey(const ValueKey('course-management-screen')),
      matchesGoldenFile('goldens/ui_master/sprint_management_screen_430.png'),
    );
  });
}
