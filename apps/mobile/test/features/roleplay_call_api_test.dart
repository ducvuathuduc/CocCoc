import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cocenglish/core/api/client/active_course.dart';
import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/core/api/client/api_transport.dart';
import 'package:cocenglish/features/call/application/call_controller.dart';
import 'package:cocenglish/features/call/data/api_call_repository.dart';
import 'package:cocenglish/features/call/data/call_repository.dart';
import 'package:cocenglish/features/call/domain/call_models.dart';
import 'package:cocenglish/features/practice/application/journey_controller.dart';
import 'package:cocenglish/features/roleplay/application/roleplay_controller.dart';
import 'package:cocenglish/features/roleplay/data/api_roleplay_repository.dart';
import 'package:cocenglish/features/roleplay/data/roleplay_repository.dart';
import 'package:cocenglish/features/roleplay/domain/roleplay_models.dart';
import 'package:cocenglish/features/roleplay/domain/server_scenarios.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_api_transport.dart';

const _iso = '2026-10-12T08:00:00.000Z';

Map<String, Object?> conversation(
  String id,
  String scenario, {
  String status = 'ACTIVE',
  String kind = 'ROLEPLAY',
  int stars = 0,
  int words = 0,
  int xp = 0,
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
  'turnCount': 4,
  'wordsUsed': words,
  'stars': stars,
  'xpAwarded': xp,
  'feedback': null,
  'expiresAt': _iso,
};

Map<String, Object?> tutor(
  String requestId,
  String text, {
  String? correction,
  String explanation = 'Tốt lắm!',
}) => {
  'requestId': requestId,
  'tutorText': text,
  'correction': correction,
  'explanation': explanation,
  'source': 'authored',
  'assessedPronunciation': false,
};

Map<String, Object?> lease(String sessionId) => {
  'sessionId': sessionId,
  'mode': 'TURN',
  'providerAlias': 'scripted',
  'model': 'scripted-v1',
  'ephemeralToken': null,
  'connectExpiresAt': null,
  'sessionExpiresAt': '2026-10-12T08:30:00.000Z',
  'epoch': 3,
  'inputSampleRate': 16000,
  'outputSampleRate': 24000,
  'configVersion': 'cfg-1',
};

ApiHttpResponse error(String code, {Map<String, Object?> details = const {}}) {
  final body = errorEnvelope(code);
  (body['error']! as Map<String, Object?>)['details'] = details;
  return ApiHttpResponse(
    code == 'ENTITLEMENT_REQUIRED' ? 403 : 409,
    jsonEncode(body),
  );
}

/// Answers POST /v1/tutor like the scripted provider: on-topic turns advance
/// [server]'s script, a turn containing "banana" is off topic.
void scriptTutor(FakeApiTransport transport, ServerScenario server) {
  var step = 0;
  transport.on('POST /v1/tutor', (request) {
    final body = bodyOf(request);
    final id = body['requestId']! as String;
    final text = body['learnerText']! as String;
    final current = server.steps[step];
    if (text.contains('banana')) {
      return jsonResponse(
        tutor(
          id,
          "Let's try again. ${current.partner}",
          correction: current.expect,
          explanation: current.hintVi,
        ),
      );
    }
    step++;
    return jsonResponse(
      tutor(
        id,
        step >= server.steps.length
            ? server.closing
            : server.steps[step].partner,
      ),
    );
  });
}

void main() {
  late FakeApiTransport transport;
  late ApiEndpoints api;
  late ActiveCourse course;

  setUp(() {
    transport = FakeApiTransport();
    api = ApiEndpoints(fakeClient(transport));
    course = ActiveCourse(api, fixed: 'vi_en');
  });

  group('server scenario mapping', () {
    test('mirror matches services/ai SCENARIOS (ids, lines, closings)', () {
      final file = File('../../services/ai/src/domain/scenarios.ts');
      if (!file.existsSync()) {
        markTestSkipped('services/ai not checked out next to apps/mobile');
        return;
      }
      final src = file.readAsStringSync();
      String unquote(String s) =>
          s.replaceAll(r"\'", "'").replaceAll(r'\"', '"');
      final ids = [
        for (final m in RegExp(
          r"^\s{4}id: '([^']+)'",
          multiLine: true,
        ).allMatches(src))
          m[1]!,
      ];
      expect(ids, [for (final s in serverScenarios) s.id]);
      final partners = [
        for (final m in RegExp(
          r"^\s+partner: '((?:[^'\\]|\\.)*)'",
          multiLine: true,
        ).allMatches(src))
          unquote(m[1]!),
      ];
      expect(partners, [
        for (final s in serverScenarios)
          for (final st in s.steps) st.partner,
      ]);
      final closings = [
        for (final m in RegExp(
          r"^\s+closing: '((?:[^'\\]|\\.)*)'",
          multiLine: true,
        ).allMatches(src))
          unquote(m[1]!),
      ];
      expect(closings, [for (final s in serverScenarios) s.closing]);
    });

    test('every library card plays a known server scenario', () {
      const mock = MockRoleplayRepository();
      for (final topic in mock.topics()) {
        for (final card in mock.scenariosFor(topic.id)) {
          expect(roleplayServerLinks, contains(card.id));
          expect(serverScenarioById(serverScenarioIdFor(card.id)), isNotNull);
        }
      }
      expect(serverScenarioIdFor('rp_doctor_visit'), 'rp_doctor_visit');
      expect(serverScenarioIdFor('unknown-card'), fallbackServerScenarioId);
      expect(cardIdForServerScenario('rp_meet_new_friend'), 'intro');
      expect(cardIdForServerScenario('rp_bus_ticket'), 'airport');
      expect(cardIdForServerScenario('rp_doctor_visit'), isNull);
      expect(callServerScenarioIdFor('lily'), 'rp_daily_routine');
    });

    test('API cards take the server script as their dialogue', () {
      final repo = ApiRoleplayRepository(api, course);
      final airport = repo.scenario('airport')!;
      final server = serverScenarioById('rp_bus_ticket')!;
      expect(airport.title, 'Make it to the airport on time');
      expect(airport.lines.map((l) => l.prompt), [
        for (final s in server.steps) s.partner,
      ]);
      expect(airport.lines.first.hints.single.phrase, isNotEmpty);
      final market = repo.scenario('market')!;
      expect(market.title, 'Buying a T-shirt', reason: 'retitled card');
      expect(
        market.scene,
        const MockRoleplayRepository().scenario('market')!.scene,
      );
      final line = ApiRoleplayRepository.lineFor(
        const ServerScenarioStep(
          partner: 'Hi',
          expect: 'Hello',
          hintVi: 'Chào: "Hello there."',
        ),
      );
      expect(line.hints.single.gloss, 'Chào');
      expect(line.hints.single.phrase, 'Hello there.');
    });
  });

  group('ApiRoleplayRepository commands', () {
    test('start, tutor turn and complete use server ids and bodies', () async {
      transport
        ..json('POST /v1/conversations', conversation('c1', 'rp_bus_ticket'))
        ..on(
          'POST /v1/tutor',
          (r) => jsonResponse(
            tutor(bodyOf(r)['requestId']! as String, 'One-way or return?'),
          ),
        )
        ..json(
          'POST /v1/conversations/c1/complete',
          conversation(
            'c1',
            'rp_bus_ticket',
            status: 'COMPLETED',
            stars: 3,
            words: 7,
            xp: 40,
          ),
        )
        ..json('GET /v1/conversations', {
          'items': <Object?>[],
          'nextCursor': null,
          'asOf': _iso,
        });
      final repo = ApiRoleplayRepository(api, course);
      final session = await repo.startSession('airport');
      expect(session.serverScenarioId, 'rp_bus_ticket');
      expect(bodyOf(transport.to('POST /v1/conversations').single), {
        'kind': 'ROLEPLAY',
        'courseId': 'vi_en',
        'scenarioId': 'rp_bus_ticket',
        'voiceSessionId': null,
      });
      final turn = await repo.sendTurn(session, 'To the airport, please.');
      expect(turn.advanced, isTrue);
      expect(turn.reply, 'One-way or return?');
      final sent = bodyOf(transport.to('POST /v1/tutor').single);
      expect(sent['scenarioId'], 'rp_bus_ticket');
      expect(sent['learnerText'], 'To the airport, please.');
      expect(sent['level'], 'A1');
      expect(sent['locale'], 'en-US');
      expect(sent['feedbackLocale'], 'vi-VN');
      final result = await repo.complete(session);
      expect((result.stars, result.wordsUsed, result.xp), (3, 7, 40));
      expect(
        bodyOf(transport.to('POST /v1/conversations/c1/complete').single),
        {'endReason': 'COMPLETED'},
      );
    });

    test(
      'ENTITLEMENT_REQUIRED and SESSION_INCOMPLETE map to domain errors',
      () async {
        transport.on(
          'POST /v1/conversations',
          (_) => error(
            'ENTITLEMENT_REQUIRED',
            details: {'feature': 'ROLEPLAY', 'required': 'MAX'},
          ),
        );
        final repo = ApiRoleplayRepository(api, course);
        await expectLater(
          repo.startSession('hotel'),
          throwsA(
            isA<MaxRequiredException>().having(
              (e) => e.feature,
              'feature',
              'ROLEPLAY',
            ),
          ),
        );
        transport.on(
          'POST /v1/conversations/c2/complete',
          (_) => error(
            'SESSION_INCOMPLETE',
            details: {'completedSteps': 1, 'requiredSteps': 4},
          ),
        );
        await expectLater(
          repo.complete(
            const RoleplayLiveSession(
              conversationId: 'c2',
              cardId: 'hotel',
              serverScenarioId: 'rp_hotel_check_in',
            ),
          ),
          throwsA(
            isA<RoleplayIncompleteException>()
                .having((e) => e.completedSteps, 'completed', 1)
                .having((e) => e.requiredSteps, 'required', 4),
          ),
        );
      },
    );
  });

  group('roleplay session in API mode', () {
    ProviderContainer containerFor() {
      final container = ProviderContainer(
        overrides: [
          roleplayRepositoryProvider.overrideWithValue(
            ApiRoleplayRepository(api, course),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<void> settle() async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('turns go to the server, replies render, the end completes', () async {
      final server = serverScenarioById('rp_hotel_check_in')!;
      transport
        ..json(
          'POST /v1/conversations',
          conversation('c7', 'rp_hotel_check_in'),
        )
        ..json(
          'POST /v1/conversations/c7/complete',
          conversation(
            'c7',
            'rp_hotel_check_in',
            status: 'COMPLETED',
            stars: 2,
            words: 5,
            xp: 30,
          ),
        )
        ..json('GET /v1/conversations', {
          'items': <Object?>[],
          'nextCursor': null,
          'asOf': _iso,
        });
      scriptTutor(transport, server);
      final container = containerFor();
      final provider = journeyControllerProvider('roleplay');
      final vm = container.read(provider.notifier);
      expect(vm.pickScenario('hotel'), isTrue);
      vm.start();
      await settle();
      expect(vm.roleplayLines.first.prompt, server.steps.first.partner);
      expect(vm.roleplayLines, hasLength(server.steps.length));

      // Off topic: same step, server retry line shown, draft kept.
      vm.edit('I like banana');
      vm.send();
      expect(container.read(provider).waiting, isTrue);
      vm.send(); // ignored while the turn is in flight
      await settle();
      var state = container.read(provider);
      expect(state.step, 0);
      expect(state.draft, 'I like banana');
      expect(vm.roleplayLines[0].prompt, startsWith("Let's try again."));
      expect(vm.roleplayLines[0].translation, server.steps[0].hintVi);

      for (var i = 0; i < server.steps.length; i++) {
        vm.edit('Yes, I have a reservation for two nights $i');
        vm.send();
        await settle();
      }
      state = container.read(provider);
      expect(state.complete, isTrue);
      expect(state.replies, hasLength(server.steps.length));
      expect(
        transport.to('POST /v1/tutor'),
        hasLength(server.steps.length + 1),
      );
      expect(
        transport.to('POST /v1/conversations'),
        hasLength(1),
        reason: 'one conversation per run',
      );
      expect(
        bodyOf(transport.to('POST /v1/conversations/c7/complete').single),
        {'endReason': 'COMPLETED'},
      );
      final result = container
          .read(roleplayLibraryControllerProvider)
          .lastResult!;
      expect(
        (result.scenarioId, result.stars, result.wordsUsed, result.xp),
        ('hotel', 2, 5, 30),
      );
    });

    test('ENTITLEMENT_REQUIRED flags the Max upsell', () async {
      transport.on(
        'POST /v1/conversations',
        (_) => error('ENTITLEMENT_REQUIRED', details: {'feature': 'ROLEPLAY'}),
      );
      final container = containerFor();
      final provider = journeyControllerProvider('roleplay');
      final vm = container.read(provider.notifier);
      vm.pickScenario('movie');
      vm.start();
      await settle();
      expect(container.read(provider).maxRequired, isTrue);
      vm.edit('Sure!');
      vm.send();
      await settle();
      expect(transport.to('POST /v1/tutor'), isEmpty);
    });

    test('SESSION_INCOMPLETE resumes at the server step', () async {
      final server = serverScenarioById('rp_weekend_plans')!;
      transport
        ..json('POST /v1/conversations', conversation('c8', 'rp_weekend_plans'))
        ..on(
          'POST /v1/conversations/c8/complete',
          (_) => error(
            'SESSION_INCOMPLETE',
            details: {'completedSteps': 3, 'requiredSteps': 4},
          ),
        );
      scriptTutor(transport, server);
      final container = containerFor();
      final provider = journeyControllerProvider('roleplay');
      final vm = container.read(provider.notifier);
      vm.pickScenario('movie');
      vm.start();
      for (var i = 0; i < server.steps.length; i++) {
        vm.edit('Yes, I am free $i');
        vm.send();
        await settle();
      }
      final state = container.read(provider);
      expect(state.complete, isFalse);
      expect(state.step, 3);
      expect(state.replies, hasLength(3));
      expect(state.error, isNotNull);
    });

    test('mock mode keeps the local, synchronous flow', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final provider = journeyControllerProvider('roleplay');
      final vm = container.read(provider.notifier);
      vm.pickScenario('hotel');
      vm.start();
      vm.edit('I have a reservation');
      vm.send();
      expect(container.read(provider).step, 1);
      expect(transport.requests, isEmpty);
    });
  });

  group('ApiCallRepository', () {
    void voice(FakeApiTransport t) => t
      ..on(
        'POST /v1/voice-sessions',
        (r) => jsonResponse(lease(bodyOf(r)['sessionId']! as String)),
      )
      ..json(
        'POST /v1/voice-sessions/00000000-0000-4000-8000-000000000001/close',
        {
          'sessionId': '00000000-0000-4000-8000-000000000001',
          'status': 'CLOSED',
          'epoch': 3,
          'accountedSeconds': 0,
        },
      );

    test('placeholder WAV is 16 kHz mono 16-bit PCM', () {
      final b = turnPlaceholderWav;
      expect(String.fromCharCodes(b.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(b.sublist(8, 12)), 'WAVE');
      final d = b.buffer.asByteData();
      expect(d.getUint16(20, Endian.little), 1);
      expect(d.getUint16(22, Endian.little), 1);
      expect(d.getUint32(24, Endian.little), 16000);
      expect(d.getUint16(34, Endian.little), 16);
      expect(d.getUint32(40, Endian.little), b.length - 44);
      expect(turnPlaceholderWavSha256, matches(RegExp(r'^[a-f0-9]{64}$')));
    });

    test('call runs on the server script with voice turns, then COMPLETED', () async {
      final server = serverScenarioById('rp_daily_routine')!;
      voice(transport);
      var step = 0;
      transport
        ..json(
          'POST /v1/conversations',
          conversation('v9', server.id, kind: 'VIDEO_CALL'),
        )
        ..on(
          'POST /v1/voice-sessions/00000000-0000-4000-8000-000000000001/turns',
          (r) {
            final body = bodyOf(r);
            final expect = server.steps[step].expect;
            step++;
            return jsonResponse({
              'turnId': body['turnId'],
              'epoch': body['epoch'],
              'transcript': expect,
              'tutor': tutor(
                body['turnId']! as String,
                step >= server.steps.length
                    ? server.closing
                    : server.steps[step].partner,
              ),
              'audioAssetId': null,
              'score': null,
              'mode': 'TURN',
            });
          },
        )
        ..json(
          'POST /v1/conversations/v9/complete',
          conversation(
            'v9',
            server.id,
            kind: 'VIDEO_CALL',
            status: 'COMPLETED',
          ),
        );
      final repo = ApiCallRepository(api, course);
      final session = await repo.loadSession('lily');
      expect(session.partnerName, 'Lily');
      expect(session.script.first.text, server.steps.first.partner);
      expect(session.script, hasLength(server.steps.length * 2 + 1));
      expect(bodyOf(transport.to('POST /v1/voice-sessions').single), {
        'sessionId': '00000000-0000-4000-8000-000000000001',
        'scenarioId': 'rp_daily_routine',
        'mode': 'TURN',
        'level': 'A1',
      });
      expect(bodyOf(transport.to('POST /v1/conversations').single), {
        'kind': 'VIDEO_CALL',
        'courseId': 'vi_en',
        'scenarioId': 'rp_daily_routine',
        'voiceSessionId': '00000000-0000-4000-8000-000000000001',
      });
      for (var i = 0; i < server.steps.length; i++) {
        final turn = await repo.speakTurn(session.id, i * 2 + 1);
        expect(turn.transcript, server.steps[i].expect);
      }
      final turns = transport.to(
        'POST /v1/voice-sessions/00000000-0000-4000-8000-000000000001/turns',
      );
      final first = bodyOf(turns.first);
      expect(first['epoch'], 3);
      expect(first['audioSha256'], turnPlaceholderWavSha256);
      expect(base64Decode(first['wavBase64']! as String), turnPlaceholderWav);
      await repo.completeCall(session.id, session.script.length);
      expect(
        bodyOf(transport.to('POST /v1/conversations/v9/complete').single),
        {'endReason': 'COMPLETED'},
      );
    });

    test('SESSION_INCOMPLETE on hang-up falls back to USER_EXIT', () async {
      voice(transport);
      transport
        ..json(
          'POST /v1/conversations',
          conversation('v2', 'rp_daily_routine', kind: 'VIDEO_CALL'),
        )
        ..once(
          'POST /v1/conversations/v2/complete',
          (_) => error('SESSION_INCOMPLETE'),
        )
        ..json(
          'POST /v1/conversations/v2/complete',
          conversation(
            'v2',
            'rp_daily_routine',
            kind: 'VIDEO_CALL',
            status: 'ABANDONED',
          ),
        );
      transport.on(
        'POST /v1/voice-sessions/00000000-0000-4000-8000-000000000001/turns',
        (r) {
          final body = bodyOf(r);
          return jsonResponse({
            'turnId': body['turnId'],
            'epoch': body['epoch'],
            'transcript': 'ok',
            'tutor': tutor(body['turnId']! as String, 'next'),
            'audioAssetId': null,
            'score': null,
            'mode': 'TURN',
          });
        },
      );
      final repo = ApiCallRepository(api, course);
      final session = await repo.loadSession('lily');
      for (var i = 0; i < 4; i++) {
        await repo.speakTurn(session.id, i * 2 + 1);
      }
      await repo.completeCall(session.id, session.script.length);
      final ends = transport.to('POST /v1/conversations/v2/complete');
      expect(ends.map((r) => bodyOf(r)['endReason']), [
        'COMPLETED',
        'USER_EXIT',
      ]);
    });

    test('ENTITLEMENT_REQUIRED closes the voice session and asks for Max', () async {
      voice(transport);
      transport.on(
        'POST /v1/conversations',
        (_) =>
            error('ENTITLEMENT_REQUIRED', details: {'feature': 'VIDEO_CALL'}),
      );
      final repo = ApiCallRepository(api, course);
      await expectLater(
        repo.loadSession('lily'),
        throwsA(
          isA<CallMaxRequired>().having(
            (e) => e.preview.partnerName,
            'preview',
            'Lily',
          ),
        ),
      );
      expect(
        transport.to(
          'POST /v1/voice-sessions/00000000-0000-4000-8000-000000000001/close',
        ),
        hasLength(1),
      );
    });

    test(
      'CallController lands on the existing upsell phase without Max',
      () async {
        voice(transport);
        transport.on(
          'POST /v1/conversations',
          (_) =>
              error('ENTITLEMENT_REQUIRED', details: {'feature': 'VIDEO_CALL'}),
        );
        final container = ProviderContainer(
          overrides: [
            callRepositoryProvider.overrideWithValue(
              ApiCallRepository(api, course),
            ),
          ],
        );
        addTearDown(container.dispose);
        final sub = container.listen(callControllerProvider, (_, _) {});
        addTearDown(sub.close);
        await container.read(callControllerProvider.notifier).start();
        final state = container.read(callControllerProvider);
        expect(state.phase, CallPhase.upsell);
        expect(state.error, isNull);
        expect(state.session!.copy.upgradeLabel, 'UPGRADE TO MAX');
      },
    );

    test('CallController mic sends a voice turn and shows server lines', () async {
      final server = serverScenarioById('rp_daily_routine')!;
      voice(transport);
      transport
        ..json(
          'POST /v1/conversations',
          conversation('v5', server.id, kind: 'VIDEO_CALL'),
        )
        ..on(
          'POST /v1/voice-sessions/00000000-0000-4000-8000-000000000001/turns',
          (r) {
            final body = bodyOf(r);
            return jsonResponse({
              'turnId': body['turnId'],
              'epoch': body['epoch'],
              'transcript': 'I get up at six.',
              'tutor': tutor(body['turnId']! as String, 'Server reply line.'),
              'audioAssetId': null,
              'score': null,
              'mode': 'TURN',
            });
          },
        );
      final container = ProviderContainer(
        overrides: [
          callRepositoryProvider.overrideWithValue(
            _FastCalls(ApiCallRepository(api, course)),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(callControllerProvider, (_, _) {});
      addTearDown(sub.close);
      final vm = container.read(callControllerProvider.notifier);
      await vm.start();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      var state = container.read(callControllerProvider);
      expect(state.phase, CallPhase.connected);
      expect(state.awaitingLearner, isTrue);
      vm.pressMic();
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      state = container.read(callControllerProvider);
      expect(state.session!.script[1].text, 'I get up at six.');
      expect(state.session!.script[2].text, 'Server reply line.');
      expect(state.cursor, greaterThanOrEqualTo(2));
    });
  });
}

/// Wraps the API repository with near-zero call timings for unit tests.
class _FastCalls implements CallRepository, CallTurns {
  _FastCalls(this.inner);
  final ApiCallRepository inner;

  @override
  Future<CallSession> loadSession(String partnerId) async {
    final s = await inner.loadSession(partnerId);
    return CallSession(
      id: s.id,
      partnerName: s.partnerName,
      learnerInitial: s.learnerInitial,
      xpReward: s.xpReward,
      script: s.script,
      copy: s.copy,
      ringDuration: const Duration(milliseconds: 1),
      partnerLineDuration: const Duration(milliseconds: 1),
      listenDuration: const Duration(milliseconds: 1),
    );
  }

  @override
  Future<CallTurnResult> speakTurn(
    String sessionId,
    int cursor, {
    Uint8List? wav,
  }) => inner.speakTurn(sessionId, cursor, wav: wav);

  @override
  Future<void> completeCall(String sessionId, int linesSpoken) =>
      inner.completeCall(sessionId, linesSpoken);
}
