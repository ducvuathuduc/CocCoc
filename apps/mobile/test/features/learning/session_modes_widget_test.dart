import 'dart:convert';
import 'dart:io';

import 'package:cocenglish/core/api/client/service_apis.dart';
import 'package:cocenglish/core/cache/lesson_journal.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/data/api_learning_repository.dart';
import 'package:cocenglish/features/learning/domain/session_mode.dart';
import 'package:cocenglish/features/learning/presentation/lesson_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_api_transport.dart';

final Map<String, Object?> _bundle = jsonDecode(
  File('test/fixtures/api/lesson_bundle_u1n1l1.json').readAsStringSync(),
) as Map<String, Object?>;

const _courseId = 'vi_en';
const _lessonId = 'activity-u1n1l1';

Map<String, Object?> _courses() => {
  'items': [
    {
      'courseId': _courseId,
      'title': 'English',
      'sourceLocale': 'vi',
      'targetLocale': 'en',
      'publishedVersion': 'v1',
      'available': true,
    },
  ],
  'nextCursor': null,
  'asOf': isoNow,
};

Map<String, Object?> _path() => {
  'enrollment': {
    'courseId': _courseId,
    'courseVersion': 'v1',
    'frontierNodeOrder': 0,
    'completedLessonIds': <String>[],
    'masteredNodeIds': <String>[],
    'revision': 4,
  },
  'nodes': [
    {
      'nodeId': 'u1n1',
      'unitId': 'u1',
      'sectionId': 'sec1',
      'order': 0,
      'title': 'Xin chào',
      'kind': 'lesson',
      'state': 'current',
      'lessonIds': [_lessonId],
    },
  ],
  'asOf': isoNow,
  'nextCursor': null,
};

Map<String, Object?> _session(SessionMode mode) => {
  'sessionId': 'sess-1',
  'courseId': _courseId,
  'lessonId': _lessonId,
  'lessonVersion': 'v1.$_lessonId',
  'status': 'ACTIVE',
  'mode': mode.wireName,
  'revision': 0,
  'nextOriginalOrdinal': 0,
  'retryPass': 0,
  'expiresAt': isoNow,
  'bundle': _bundle,
  'answerHistory': <Object?>[],
  'lastFeedback': null,
  if (mode.isGate) 'passThreshold': 0.8,
};

Map<String, Object?> _completion({
  required SessionMode mode,
  required bool passed,
  String? unlockedNodeId,
}) => {
  'completionId': 'comp-1',
  'sessionId': 'sess-1',
  'originalCount': 10,
  'originalCorrect': passed ? 9 : 4,
  'assisted': false,
  'source': 'ONLINE',
  'mode': mode.wireName,
  'completedAt': isoNow,
  'enrollmentRevision': 5,
  'rewardStatus': 'notEligible',
  'needsReviewIds': <String>[],
  'passed': passed,
  'unlockedNodeId': ?unlockedNodeId,
};

ApiLearningRepository _repository(FakeApiTransport transport) =>
    ApiLearningRepository(
      learning: LearningApi(fakeClient(transport)),
      journal: InMemoryLessonJournal(),
      ids: SequenceIds(),
    );

Future<ProviderContainer> _pumpAuthoredSession(
  WidgetTester tester,
  SessionMode mode,
) async {
  final transport = FakeApiTransport()
    ..json('GET /v1/courses', _courses())
    ..json('GET /v1/courses/$_courseId/path', _path())
    ..json('POST /v1/sessions', _session(mode));
  final container = ProviderContainer(
    overrides: [
      learningRepositoryProvider.overrideWithValue(_repository(transport)),
    ],
  );
  addTearDown(container.dispose);
  await container
      .read(lessonControllerProvider.notifier)
      .start(nodeId: _lessonId, mode: mode, lessonId: _lessonId);

  expect(
    container.read(lessonControllerProvider).error,
    isNull,
    reason: '${mode.wireName} session should start',
  );
  expect(container.read(lessonControllerProvider).mode, mode);
  expect(
    bodyOf(transport.to('POST /v1/sessions').single),
    containsPair('mode', mode.wireName),
  );

  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: referenceTheme(), home: const LessonScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final mode in SessionMode.values.where((mode) => mode.isAuthored)) {
    testWidgets('renders ${mode.wireName} through the lesson exercise flow', (
      tester,
    ) async {
      await _pumpAuthoredSession(tester, mode);

      // The server bundle is rendered by the existing exercise widgets.
      expect(find.text('xin chào'), findsOneWidget);
      expect(find.text('bạn bè'), findsOneWidget);
      expect(find.text('CHECK'), findsOneWidget);
    });
  }

  test(
    'passed gate completion carries threshold, pass and unlocked node',
    () async {
      final mode = SessionMode.testOut;
      final transport = FakeApiTransport()
        ..json('GET /v1/courses', _courses())
        ..json('GET /v1/courses/$_courseId/path', _path())
        ..json('POST /v1/sessions', _session(mode))
        ..json(
          'POST /v1/sessions/sess-1/complete',
          _completion(mode: mode, passed: true, unlockedNodeId: 'u2n1'),
        );
      final repository = _repository(transport);
      await repository.loadAuthored(mode: mode, lessonId: _lessonId);

      final receipt = await repository.complete(
        nodeId: _lessonId,
        originalCorrect: 9,
        originalTotal: 10,
        elapsed: Duration.zero,
        guest: false,
        placement: false,
      );

      expect(receipt.xp, 0);
      expect(receipt.rewardPending, isFalse);
      expect(receipt.outcome?.mode, mode);
      expect(receipt.outcome?.passThreshold, 0.8);
      expect(receipt.outcome?.passed, isTrue);
      expect(receipt.outcome?.unlockedNodeId, 'u2n1');
    },
  );

  test('failed checkpoint is a completion, not an error', () async {
    final mode = SessionMode.checkpoint;
    final transport = FakeApiTransport()
      ..json('GET /v1/courses', _courses())
      ..json('GET /v1/courses/$_courseId/path', _path())
      ..json('POST /v1/sessions', _session(mode))
      ..json(
        'POST /v1/sessions/sess-1/complete',
        _completion(mode: mode, passed: false),
      );
    final repository = _repository(transport);
    await repository.loadAuthored(mode: mode, lessonId: _lessonId);

    final receipt = await repository.complete(
      nodeId: _lessonId,
      originalCorrect: 4,
      originalTotal: 10,
      elapsed: Duration.zero,
      guest: false,
      placement: false,
    );

    expect(receipt.xp, 0);
    expect(receipt.outcome?.mode, mode);
    expect(receipt.outcome?.passed, isFalse);
    expect(receipt.outcome?.unlockedNodeId, isNull);
  });
}
