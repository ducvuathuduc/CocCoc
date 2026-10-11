import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/account/presentation/course_management_screen.dart';

void main() {
  testWidgets('CourseManagementScreen matches golden 430', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    await expectLater(
      find.byKey(const ValueKey('course-management-screen')),
      matchesGoldenFile('goldens/ui_master/sprint_management_screen_430.png'),
    );
  });
}
