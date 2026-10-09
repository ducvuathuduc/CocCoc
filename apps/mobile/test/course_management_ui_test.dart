import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/account/application/course_management_controller.dart';
import 'package:cocenglish/features/account/presentation/course_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ProviderContainer> pumpCourses(
  WidgetTester tester, {
  double width = 390,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: referenceTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: const CourseManagementScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('shows scoped languages and explains protected English', (
    tester,
  ) async {
    await pumpCourses(tester);

    expect(find.text('English'), findsOneWidget);
    expect(find.text('Chinese'), findsOneWidget);
    expect(find.text('Indonesian'), findsOneWidget);
    expect(find.text('Italian'), findsOneWidget);
    expect(find.text('Math'), findsNothing);
    expect(find.text('Music'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Remove English course'));
    await tester.pumpAndSettle();
    expect(
      find.text('English is your active course and cannot be removed.'),
      findsOneWidget,
    );
    expect(find.text('Are you sure?'), findsNothing);
  });

  testWidgets('cancel retains course and confirm removes it once', (
    tester,
  ) async {
    final container = await pumpCourses(tester);

    await tester.tap(find.bySemanticsLabel('Remove Italian course'));
    await tester.pumpAndSettle();
    expect(find.text('Are you sure?'), findsOneWidget);
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(find.text('Italian'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Remove Italian course'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('REMOVE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Are you sure?'), findsNothing);
    expect(find.text('Italian'), findsOneWidget);
    expect(
      container.read(courseManagementProvider).phase,
      CourseRemovalPhase.removing,
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Italian'), findsNothing);
    expect(
      container
          .read(courseManagementProvider)
          .courses
          .map((course) => course.id),
      isNot(contains('italian')),
    );
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('sheet stays usable at width $width and text scale $scale', (
        tester,
      ) async {
        await pumpCourses(tester, width: width, textScale: scale);
        await tester.tap(find.bySemanticsLabel('Remove Chinese course'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('REMOVE'),
          180,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('CANCEL'));
        await tester.pumpAndSettle();
        expect(find.text('Chinese'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
