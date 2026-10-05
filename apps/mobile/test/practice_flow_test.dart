import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/practice/presentation/practice_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('practice hub keeps source hierarchy at text scale two', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const PracticeHubScreen(),
      ),
    );

    expect(find.text('Video Call'), findsOneWidget);
    expect(find.text('MAX'), findsOneWidget);
    expect(find.text('CALL LILY'), findsOneWidget);
    expect(find.text('Skill practice'), findsOneWidget);
    expect(find.text('Roleplay'), findsOneWidget);
    expect(find.text('Practice collection'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('word practice reveals an answer and records local recall', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: PracticeDetailScreen(kind: 'recall')),
      ),
    );

    expect(find.text('a woman'), findsNothing);
    await tester.tap(find.text('REVEAL ANSWER'));
    await tester.pump();
    expect(find.text('người phụ nữ'), findsOneWidget);

    await tester.tap(find.text('I REMEMBER THIS'));
    await tester.pump();
    expect(find.text('1 recalled'), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('denied speech uses an assisted guest text substitution', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/speaking/record',
      routes: [
        GoRoute(
          path: '/speaking/record',
          builder: (_, _) => const SpeakingRecordScreen(),
        ),
        GoRoute(
          path: '/lesson/practice',
          builder: (_, _) => const Scaffold(body: Text('Typed practice')),
        ),
        GoRoute(
          path: '/practice',
          builder: (_, _) => const Scaffold(body: Text('Practice hub')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.ensureVisible(find.text('SIMULATE DENIED'));
    await tester.tap(find.text('SIMULATE DENIED'));
    await tester.pump();
    expect(find.text('Microphone permission denied'), findsOneWidget);
    await tester.tap(find.text('USE TYPED PRACTICE'));
    await tester.pumpAndSettle();

    expect(find.text('Typed practice'), findsOneWidget);
    final lesson = container.read(lessonControllerProvider);
    expect(lesson.guest, isTrue);
    expect(lesson.assisted, isTrue);
    expect(lesson.current?.kind, ExerciseKind.textTranslation);
  });

  testWidgets('background resets recording and disposal cancels its callback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SpeakingRecordScreen())),
    );
    await tester.tap(find.text('START MOCK RECORDING'));
    await tester.pump();
    expect(find.text('Capturing mock speech…'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Capturing mock speech…'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('START MOCK RECORDING'), findsOneWidget);

    await tester.tap(find.text('START MOCK RECORDING'));
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('call reconnects safely after app resumes', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SpeakingCallScreen())),
    );
    await tester.ensureVisible(find.text('START MOCK CALL'));
    await tester.tap(find.text('START MOCK CALL'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Lily is waiting for your typed reply'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Reconnecting…'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Lily is waiting for your typed reply'), findsOneWidget);
  });
}
