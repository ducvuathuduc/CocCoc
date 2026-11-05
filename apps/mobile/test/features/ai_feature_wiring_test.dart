import 'dart:typed_data';

import 'package:cocenglish/core/api/api_contracts.dart' as wire;
import 'package:cocenglish/core/api/client/active_course.dart';
import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/core/api/client/api_providers.dart';
import 'package:cocenglish/core/audio/speech_recorder.dart';
import 'package:cocenglish/core/config/app_config.dart';
import 'package:cocenglish/features/call/data/ai_capabilities.dart';
import 'package:cocenglish/features/call/data/api_call_repository.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/data/english_explanations.dart';
import 'package:cocenglish/features/learning/data/speech_assessment.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/learning/presentation/explanation_screen.dart';
import 'package:cocenglish/features/roleplay/data/api_roleplay_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_api_transport.dart';

const _iso = '2026-10-12T08:00:00.000Z';
final _testWav = pcm16ToWav(Uint8List.fromList(List<int>.filled(3200, 7)));

Map<String, Object?> capabilities({
  bool pronunciation = true,
  bool turnSpeech = false,
}) => {
  'configVersion': 'cfg-1',
  'textTutor': true,
  'nativeLive': false,
  'turnSpeech': turnSpeech,
  'pronunciation': pronunciation,
  'offlineShadowing': true,
  'nativeLiveReason': null,
  'pronunciationReason': pronunciation ? null : 'AZURE_DISABLED',
  'liveUiMaxSeconds': 180,
  'dailyLiveSessionLimit': 0,
};

Map<String, Object?> assessment({
  String jobId = '00000000-0000-4000-8000-000000000001',
  String status = 'SUCCEEDED',
  String state = 'VALID',
  String expiresAt = '2027-10-12T08:30:00.000Z',
}) => {
  'jobId': jobId,
  'status': status,
  'transcript': 'Hello, Sam.',
  'accuracy': state == 'VALID' ? 70 : null,
  'fluency': state == 'VALID' ? 81.5 : null,
  'completeness': state == 'VALID' ? 80 : null,
  'prosody': null,
  'words': state == 'VALID'
      ? [
          {
            'word': 'Hello',
            'accuracy': 91,
            'errorType': 'None',
            'phonemes': <Object?>[],
          },
        ]
      : <Object?>[],
  'scorer': state == 'VALID' ? 'azure-pronunciation-assessment' : null,
  'scoreVersion': state == 'VALID' ? 'azure-rest-v1-hundredmark' : null,
  'unavailableReason': state == 'VALID' ? null : 'NO_SCORE',
  'expiresAt': expiresAt,
  'scoreState': state,
  'locale': 'en-US',
  'referenceHash': 'a' * 64,
  'provider': 'azure',
  'modelVersion': state == 'VALID' ? 'azure-rest-v1-hundredmark' : null,
  'miscues': <Object?>[],
};

Map<String, Object?> tutor(Map<String, Object?> body) => {
  'requestId': body['requestId'],
  'tutorText': 'Good try! Keep your sentence short and clear.',
  'correction': null,
  'explanation': 'Câu này dùng “the” trước danh từ số ít.',
  'source': 'fallback',
  'assessedPronunciation': false,
};

Map<String, Object?> conversation(
  String id,
  String scenario, {
  String kind = 'VIDEO_CALL',
  String status = 'ACTIVE',
  String? voice,
}) => {
  'conversationId': id,
  'kind': kind,
  'courseId': 'vi_en',
  'scenarioId': scenario,
  'voiceSessionId': voice,
  'status': status,
  'startedAt': _iso,
  'completedAt': status == 'COMPLETED' ? _iso : null,
  'turnCount': 0,
  'wordsUsed': 0,
  'stars': 0,
  'xpAwarded': 0,
  'feedback': null,
  'expiresAt': _iso,
};

Map<String, Object?> lease(String sessionId) => {
  'sessionId': sessionId,
  'mode': 'TURN',
  'providerAlias': 'scripted',
  'model': 'scripted-v1',
  'ephemeralToken': null,
  'connectExpiresAt': null,
  'sessionExpiresAt': '2027-10-12T08:30:00.000Z',
  'epoch': 3,
  'inputSampleRate': 16000,
  'outputSampleRate': 24000,
  'configVersion': 'cfg-1',
};

Map<String, Object?> voiceState(String sessionId, {String status = 'ACTIVE'}) =>
    {
      'sessionId': sessionId,
      'status': status,
      'epoch': 3,
      'accountedSeconds': 0,
    };

AppConfig apiConfig() => const AppConfig(dataSource: DataSource.api);

ApiEndpoints endpointsFor(FakeApiTransport transport) =>
    ApiEndpoints(fakeClient(transport));

void main() {
  test('capabilities gate the speech assessor and fail closed', () async {
    final transport = FakeApiTransport();
    transport.json(
      'GET /v1/ai/capabilities',
      capabilities(pronunciation: false),
    );
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(apiConfig()),
        apiEndpointsProvider.overrideWithValue(endpointsFor(transport)),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(speechAssessorProvider), isNull);
    final caps = await container.read(aiCapabilitiesProvider.future);
    expect(caps?.pronunciation, isFalse);
    expect(container.read(speechAssessorProvider), isNull);

    final enabledTransport = FakeApiTransport();
    enabledTransport.json('GET /v1/ai/capabilities', capabilities());
    final enabled = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(apiConfig()),
        apiEndpointsProvider.overrideWithValue(endpointsFor(enabledTransport)),
      ],
    );
    addTearDown(enabled.dispose);
    await enabled.read(aiCapabilitiesProvider.future);
    expect(enabled.read(speechAssessorProvider), isA<ApiSpeechAssessor>());

    final offline = FakeApiTransport()..offline = true;
    final offlineContainer = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(apiConfig()),
        apiEndpointsProvider.overrideWithValue(endpointsFor(offline)),
      ],
    );
    addTearDown(offlineContainer.dispose);
    expect(await offlineContainer.read(aiCapabilitiesProvider.future), isNull);
    expect(offlineContainer.read(speechAssessorProvider), isNull);
  });

  test('mock mode never reads capabilities and keeps speech offline', () {
    final transport = FakeApiTransport();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(const AppConfig()),
        apiEndpointsProvider.overrideWithValue(endpointsFor(transport)),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(speechAssessorProvider), isNull);
    expect(transport.requests, isEmpty);
  });

  test('assessment jobs are polled until terminal', () async {
    final transport = FakeApiTransport();
    final api = endpointsFor(transport);
    transport
      ..json(
        'POST /v1/assessment-jobs',
        assessment(
          status: 'QUEUED',
          state: 'NULL_UNAVAILABLE',
          expiresAt: '2026-10-12T08:30:00.000Z',
        ),
        status: 202,
      )
      ..json(
        'GET /v1/assessment-jobs/00000000-0000-4000-8000-000000000001',
        assessment(),
      );
    final assessor = ApiSpeechAssessor(
      api,
      pollInterval: Duration.zero,
      maxWait: const Duration(seconds: 5),
      now: () => DateTime.utc(2026, 10, 12, 8),
      sleep: (_) async {},
    );
    final verdict = await assessor.assess(
      _testWav,
      exerciseId: 'practice-pronunciation-1',
      referenceText: 'Hello, Sam.',
    );
    expect(verdict.scored, isTrue);
    expect(verdict.accuracy, 70);
    expect(
      transport.to(
        'GET /v1/assessment-jobs/00000000-0000-4000-8000-000000000001',
      ),
      hasLength(1),
    );
  });

  test(
    'an expired pending assessment falls back to a nullable verdict',
    () async {
      final transport = FakeApiTransport();
      final api = endpointsFor(transport);
      transport.json(
        'POST /v1/assessment-jobs',
        assessment(
          status: 'QUEUED',
          state: 'NULL_UNAVAILABLE',
          expiresAt: '2026-10-12T07:59:00.000Z',
        ),
        status: 202,
      );
      final assessor = ApiSpeechAssessor(
        api,
        pollInterval: Duration.zero,
        now: () => DateTime.utc(2026, 10, 12, 8),
        sleep: (_) async {},
      );
      final verdict = await assessor.assess(
        _testWav,
        exerciseId: 'practice-pronunciation-1',
        referenceText: 'Hello, Sam.',
      );
      expect(verdict.scored, isFalse);
      expect(verdict.accuracy, isNull);
      expect(
        transport.to(
          'GET /v1/assessment-jobs/00000000-0000-4000-8000-000000000001',
        ),
        isEmpty,
      );
    },
  );

  test(
    'call heartbeats its open voice session and stops after hang-up',
    () async {
      final transport = FakeApiTransport();
      final api = endpointsFor(transport);
      const sessionId = '00000000-0000-4000-8000-000000000001';
      transport
        ..on(
          'POST /v1/voice-sessions',
          (r) => jsonResponse(lease(bodyOf(r)['sessionId']! as String)),
        )
        ..json(
          'POST /v1/conversations',
          conversation('c-call', 'rp_daily_routine'),
        )
        ..json(
          'POST /v1/voice-sessions/$sessionId/heartbeat',
          voiceState(sessionId),
        )
        ..json(
          'POST /v1/conversations/c-call/complete',
          conversation('c-call', 'rp_daily_routine', status: 'COMPLETED'),
        )
        ..json(
          'POST /v1/voice-sessions/$sessionId/close',
          voiceState(sessionId, status: 'CLOSED'),
        );
      final repo = ApiCallRepository(
        api,
        ActiveCourse(api, fixed: 'vi_en'),
        heartbeatInterval: const Duration(milliseconds: 5),
      );
      final session = await repo.loadSession('lily');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final beats = transport.to(
        'POST /v1/voice-sessions/$sessionId/heartbeat',
      );
      expect(beats, isNotEmpty);
      final body = bodyOf(beats.last);
      expect(body['epoch'], 3);
      expect(body['turnCount'], 0);
      expect(body['elapsedSeconds'], isA<int>());

      await repo.completeCall(session.id, 0);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final stopped = transport
          .to('POST /v1/voice-sessions/$sessionId/heartbeat')
          .length;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        transport.to('POST /v1/voice-sessions/$sessionId/heartbeat'),
        hasLength(stopped),
      );
      expect(
        transport.to('POST /v1/voice-sessions/$sessionId/close'),
        hasLength(1),
      );
    },
  );

  test('roleplay heartbeats a capability-gated voice session', () async {
    final transport = FakeApiTransport();
    final api = endpointsFor(transport);
    const sessionId = '00000000-0000-4000-8000-000000000001';
    transport
      ..on(
        'POST /v1/voice-sessions',
        (r) => jsonResponse(lease(bodyOf(r)['sessionId']! as String)),
      )
      ..on(
        'POST /v1/conversations',
        (r) => jsonResponse(
          conversation(
            'c-rp',
            'rp_hotel_check_in',
            kind: 'ROLEPLAY',
            voice: bodyOf(r)['voiceSessionId'] as String?,
          ),
        ),
      )
      ..json(
        'POST /v1/voice-sessions/$sessionId/heartbeat',
        voiceState(sessionId),
      )
      ..json(
        'POST /v1/conversations/c-rp/complete',
        conversation(
          'c-rp',
          'rp_hotel_check_in',
          kind: 'ROLEPLAY',
          status: 'COMPLETED',
        ),
      )
      ..json(
        'POST /v1/voice-sessions/$sessionId/close',
        voiceState(sessionId, status: 'CLOSED'),
      )
      ..json('GET /v1/conversations', {
        'items': <Object?>[],
        'nextCursor': null,
        'asOf': _iso,
      });
    final repo = ApiRoleplayRepository(
      api,
      ActiveCourse(api, fixed: 'vi_en'),
      heartbeatInterval: const Duration(milliseconds: 5),
      capabilities: () async =>
          wire.Capabilities.fromJson(capabilities(turnSpeech: true)),
    );
    final session = await repo.startSession('hotel');
    expect(session.voiceSessionId, sessionId);
    expect(
      bodyOf(transport.to('POST /v1/conversations').single)['voiceSessionId'],
      sessionId,
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(
      transport.to('POST /v1/voice-sessions/$sessionId/heartbeat'),
      isNotEmpty,
    );
    await repo.complete(session);
    final stopped = transport
        .to('POST /v1/voice-sessions/$sessionId/heartbeat')
        .length;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      transport.to('POST /v1/voice-sessions/$sessionId/heartbeat'),
      hasLength(stopped),
    );
    expect(
      transport.to('POST /v1/voice-sessions/$sessionId/close'),
      hasLength(1),
    );
  });

  test(
    'explain my answer uses the server tutor and the real lesson id',
    () async {
      final transport = FakeApiTransport();
      transport.on('POST /v1/tutor', (r) => jsonResponse(tutor(bodyOf(r))));
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(apiConfig()),
          apiEndpointsProvider.overrideWithValue(endpointsFor(transport)),
        ],
      );
      addTearDown(container.dispose);
      const exercise = Exercise(
        id: 'srv-explain-1',
        kind: ExerciseKind.textTranslation,
        title: 'Translate to English',
        prompt: 'Con mèo',
        correctText: 'The cat',
      );
      final request = ExplanationRequest(
        exercise: exercise,
        nodeId: 'node-7',
        answer: 'a cat',
      );
      final explanation = await container.read(
        exerciseExplanationProvider(request).future,
      );
      expect(explanation?.$1, contains('“the”'));
      expect(explanation?.$2.single, contains('Good try!'));
      final body = bodyOf(transport.to('POST /v1/tutor').single);
      expect(body['exerciseId'], 'srv-explain-1');
      expect(body['learnerText'], 'a cat');
      expect(body['feedbackLocale'], 'vi-VN');
    },
  );

  testWidgets('explanation screen renders the server bundle explanation', (
    tester,
  ) async {
    final transport = FakeApiTransport();
    transport.on('POST /v1/tutor', (r) => jsonResponse(tutor(bodyOf(r))));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(apiConfig()),
          apiEndpointsProvider.overrideWithValue(endpointsFor(transport)),
          lessonControllerProvider.overrideWith(_ServerExplanationLesson.new),
        ],
        child: const MaterialApp(home: ExplanationScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Câu này dùng “the” trước danh từ số ít.'),
      findsOneWidget,
    );
    expect(
      find.text('An explanation is unavailable for this exercise.'),
      findsNothing,
    );
    final body = bodyOf(transport.to('POST /v1/tutor').single);
    expect(body['exerciseId'], 'srv-explain-1');
  });
}

class _ServerExplanationLesson extends LessonController {
  @override
  LessonState build() => const LessonState(
    stage: LessonStage.feedback,
    exercises: [
      Exercise(
        id: 'srv-explain-1',
        kind: ExerciseKind.textTranslation,
        title: 'Translate to English',
        prompt: 'Con mèo',
        correctText: 'The cat',
      ),
    ],
    nodeId: 'node-7',
    text: 'a cat',
    correct: false,
  );
}
