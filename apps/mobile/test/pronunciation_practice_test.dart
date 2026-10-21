import 'dart:async';
import 'dart:typed_data';

import 'support/pronunciation_fakes.dart';

import 'package:cocenglish/core/audio/speech_recorder.dart';
import 'package:cocenglish/features/learning/data/speech_assessment.dart';
import 'package:cocenglish/features/practice/presentation/practice_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openPractice(
  WidgetTester tester,
  FakeRecorder recorder,
  SpeechAssessor? assessor, {
  double scale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        speechRecorderProvider.overrideWithValue(recorder),
        speechAssessorProvider.overrideWithValue(assessor),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const SpeakingRecordScreen(),
      ),
    ),
  );
}

Future<void> tapVisible(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pump();
}

void main() {
  testWidgets('scored feedback fits a narrow display at text scale two', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openPractice(tester, FakeRecorder(), FakeAssessor(), scale: 2);
    await tapVisible(tester, 'TAP TO SPEAK');
    await tapVisible(tester, 'STOP AND CHECK');
    expect(find.text('Accuracy: 86/100'), findsOneWidget);
    await tapVisible(tester, 'Hello: Good (90/100)');
    await tester.pumpAndSettle();
    expect(find.text('/h/: 95/100'), findsOneWidget);
    await tester.ensureVisible(find.text('NEXT SENTENCE'));
    expect(tester.takeException(), isNull);
  });
  testWidgets('records real audio and submits the displayed reference once', (
    tester,
  ) async {
    final recorder = FakeRecorder();
    final assessor = FakeAssessor()..pending = Completer<SpeechVerdict>();
    await openPractice(tester, recorder, assessor);
    expect(recorder.starts, 0);
    expect(find.text('Hello, I am Sam.'), findsOneWidget);
    await tapVisible(tester, 'TAP TO SPEAK');
    expect(recorder.starts, 1);
    await tapVisible(tester, 'STOP AND CHECK');
    expect(assessor.calls.single.wav.length, 32044);
    expect(assessor.calls.single.wav.take(4), [82, 73, 70, 70]);
    expect(assessor.calls.single.reference, 'Hello, I am Sam.');
    expect(assessor.calls.single.exerciseId, 'practice-pronunciation-1');
    expect(find.text('STOP AND CHECK'), findsNothing);
    assessor.pending!.complete(assessor.verdict);
    await tester.pump();
    expect(find.text('Accuracy: 86/100'), findsOneWidget);
    expect(find.text('Fluency: 79/100'), findsOneWidget);
    expect(find.text('Completeness: 100/100'), findsOneWidget);
    expect(find.textContaining('Prosody:'), findsNothing);
    expect(find.textContaining('Sam: Try again'), findsOneWidget);
    await tapVisible(tester, 'Hello: Good (90/100)');
    await tester.pumpAndSettle();
    expect(find.text('/h/: 95/100'), findsOneWidget);
    expect(find.text('/ə/: 55/100'), findsOneWidget);
    await tapVisible(tester, 'NEXT SENTENCE');
    expect(find.text('Could you help me, please?'), findsOneWidget);
    expect(find.text('Accuracy: 86/100'), findsNothing);
  });

  testWidgets('permission denied never sends audio and offers typed practice', (
    tester,
  ) async {
    final recorder = FakeRecorder()..allowed = false;
    final assessor = FakeAssessor();
    await openPractice(tester, recorder, assessor);
    await tapVisible(tester, 'TAP TO SPEAK');
    expect(find.text('Microphone unavailable'), findsOneWidget);
    expect(find.text('USE TYPED PRACTICE'), findsOneWidget);
    expect(assessor.calls, isEmpty);
  });

  testWidgets('double tap cannot open two microphone sessions', (tester) async {
    final recorder = FakeRecorder()..permission = Completer<bool>();
    final assessor = FakeAssessor();
    await openPractice(tester, recorder, assessor);
    await tester.ensureVisible(find.text('TAP TO SPEAK'));
    await tester.tap(find.text('TAP TO SPEAK'));
    await tester.tap(find.text('TAP TO SPEAK'));
    expect(recorder.starts, 1);
    recorder.permission!.complete(true);
    await tester.pump();
    await tapVisible(tester, 'STOP AND CHECK');
    expect(recorder.stops, 1);
    expect(assessor.calls, hasLength(1));
  });

  testWidgets('recording stops automatically at 15 seconds', (tester) async {
    final recorder = FakeRecorder();
    final assessor = FakeAssessor();
    await openPractice(tester, recorder, assessor);
    await tapVisible(tester, 'TAP TO SPEAK');
    await tester.pump(const Duration(seconds: 14));
    expect(recorder.stops, 0);
    expect(assessor.calls, isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(recorder.stops, 1);
    expect(assessor.calls, hasLength(1));
    await tester.pump(const Duration(seconds: 20));
    expect(assessor.calls, hasLength(1));
  });

  testWidgets('empty recording is retryable and never sent', (tester) async {
    final recorder = FakeRecorder()..audio = null;
    final assessor = FakeAssessor();
    await openPractice(tester, recorder, assessor);
    await tapVisible(tester, 'TAP TO SPEAK');
    await tapVisible(tester, 'STOP AND CHECK');
    expect(find.text('No audio captured. Try speaking again.'), findsOneWidget);
    expect(assessor.calls, isEmpty);
    recorder.audio = pcm16ToWav(Uint8List(32000));
    await tapVisible(tester, 'TAP TO SPEAK');
    await tapVisible(tester, 'STOP AND CHECK');
    expect(find.text('Accuracy: 86/100'), findsOneWidget);
  });

  testWidgets('network failure preserves sentence and permits explicit retry', (
    tester,
  ) async {
    final recorder = FakeRecorder();
    final assessor = FakeAssessor()..fails = true;
    await openPractice(tester, recorder, assessor);
    await tapVisible(tester, 'TAP TO SPEAK');
    await tapVisible(tester, 'STOP AND CHECK');
    expect(
      find.textContaining('Could not assess this recording.'),
      findsOneWidget,
    );
    expect(find.text('Hello, I am Sam.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(assessor.calls, hasLength(1));
    assessor.fails = false;
    await tapVisible(tester, 'TAP TO SPEAK');
    await tapVisible(tester, 'STOP AND CHECK');
    expect(find.text('Accuracy: 86/100'), findsOneWidget);
    expect(assessor.calls, hasLength(2));
  });

  testWidgets('transcript-only result never displays numeric pronunciation', (
    tester,
  ) async {
    final recorder = FakeRecorder();
    final assessor = FakeAssessor()
      ..verdict = const SpeechVerdict(
        scored: false,
        passed: true,
        transcript: 'Hello, I am Sam.',
      );
    await openPractice(tester, recorder, assessor, scale: 2);
    await tapVisible(tester, 'TAP TO SPEAK');
    await tapVisible(tester, 'STOP AND CHECK');
    expect(find.text('Pronunciation not assessed'), findsOneWidget);
    expect(
      find.textContaining('No pronunciation score is available.'),
      findsOneWidget,
    );
    expect(find.textContaining('/100'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mock mode offers typed practice without a fabricated recording',
    (tester) async {
      final recorder = FakeRecorder();
      await openPractice(tester, recorder, null);
      expect(find.text('Pronunciation assessment unavailable'), findsOneWidget);
      expect(find.text('TAP TO SPEAK'), findsNothing);
      expect(find.text('USE TYPED PRACTICE'), findsOneWidget);
      expect(recorder.starts, 0);
    },
  );

  testWidgets('background cancels capture and never submits it', (
    tester,
  ) async {
    final recorder = FakeRecorder();
    final assessor = FakeAssessor();
    await openPractice(tester, recorder, assessor);
    await tapVisible(tester, 'TAP TO SPEAK');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(recorder.cancels, greaterThan(0));
    expect(find.text('TAP TO SPEAK'), findsOneWidget);
    await tester.pump(const Duration(seconds: 16));
    expect(assessor.calls, isEmpty);
  });

  testWidgets(
    'late assessment after interruption cannot replace a newer result',
    (tester) async {
      final recorder = FakeRecorder();
      final first = Completer<SpeechVerdict>();
      final assessor = FakeAssessor()..pending = first;
      await openPractice(tester, recorder, assessor);
      await tapVisible(tester, 'TAP TO SPEAK');
      await tapVisible(tester, 'STOP AND CHECK');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      assessor.pending = null;
      assessor.verdict = const SpeechVerdict(
        scored: false,
        passed: false,
        transcript: 'new attempt',
      );
      await tapVisible(tester, 'TAP TO SPEAK');
      await tapVisible(tester, 'STOP AND CHECK');
      first.complete(
        const SpeechVerdict(
          scored: true,
          passed: true,
          transcript: 'stale result',
          accuracy: 99,
        ),
      );
      await tester.pump();
      expect(find.text('Heard: new attempt'), findsOneWidget);
      expect(find.textContaining('stale result'), findsNothing);
      expect(find.text('Accuracy: 99/100'), findsNothing);
    },
  );

  testWidgets('leaving during microphone permission cancels late capture', (
    tester,
  ) async {
    final recorder = FakeRecorder()..permission = Completer<bool>();
    final assessor = FakeAssessor();
    await openPractice(tester, recorder, assessor);
    await tapVisible(tester, 'TAP TO SPEAK');
    await tester.pumpWidget(const SizedBox.shrink());
    recorder.permission!.complete(true);
    await tester.pump();
    expect(recorder.cancels, greaterThan(0));
    expect(assessor.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'iOS permission inactive state still allows recording after approval',
    (tester) async {
      final recorder = FakeRecorder()..permission = Completer<bool>();
      await openPractice(tester, recorder, FakeAssessor());
      await tapVisible(tester, 'TAP TO SPEAK');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      recorder.permission!.complete(true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('STOP AND CHECK'), findsOneWidget);
      expect(recorder.cancels, 0);
      await tapVisible(tester, 'STOP AND CHECK');
    },
  );

  testWidgets(
    'assessment timeout becomes retryable without a second submission',
    (tester) async {
      final assessor = FakeAssessor()..pending = Completer<SpeechVerdict>();
      await openPractice(tester, FakeRecorder(), assessor);
      await tapVisible(tester, 'TAP TO SPEAK');
      await tapVisible(tester, 'STOP AND CHECK');
      await tester.pump(const Duration(seconds: 60));
      expect(
        find.textContaining('Could not assess this recording.'),
        findsOneWidget,
      );
      expect(assessor.calls, hasLength(1));
      assessor.pending!.complete(assessor.verdict);
      await tester.pump();
      expect(find.textContaining('/100'), findsNothing);
    },
  );
}
