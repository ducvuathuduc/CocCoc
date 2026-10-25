import 'dart:async';
import 'dart:typed_data';

import 'package:cocenglish/core/audio/speech_recorder.dart';
import 'package:cocenglish/features/call/application/call_controller.dart';
import 'package:cocenglish/features/call/data/call_repository.dart';
import 'package:cocenglish/features/call/domain/call_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pronunciation_fakes.dart';

const _copy = CallCopy(
  introTitle: 'Video call',
  introCallLabel: 'CALL',
  introLaterLabel: 'LATER',
  callingLabel: 'Calling',
  earnedLabel: 'Earned',
  reviewTitle: 'Review',
  continueLabel: 'CONTINUE',
  upsellLead: 'Get ',
  upsellHighlight: 'unlimited',
  upsellTail: ' calls',
  upgradeLabel: 'UPGRADE',
  noThanksLabel: 'NO THANKS',
  phoneKicker: 'Video Call',
  maxBadge: 'MAX',
  listeningLabel: 'Listening…',
);

const _session = CallSession(
  id: 'session',
  partnerName: 'Lily',
  learnerInitial: 'A',
  xpReward: 20,
  copy: _copy,
  ringDuration: Duration.zero,
  partnerLineDuration: Duration.zero,
  listenDuration: Duration.zero,
  script: [
    CallLine(speaker: CallSpeaker.partner, text: 'Hello.'),
    CallLine(speaker: CallSpeaker.learner, text: 'Hello.'),
    CallLine(speaker: CallSpeaker.partner, text: 'Bye.'),
  ],
);

Future<void> settle([int turns = 5]) async {
  for (var i = 0; i < turns; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<CallController> startCall(ProviderContainer container) async {
  container.listen(callControllerProvider, (_, _) {}, fireImmediately: true);
  final controller = container.read(callControllerProvider.notifier);
  await controller.start();
  await settle();
  expect(container.read(callControllerProvider).awaitingLearner, isTrue);
  return controller;
}

void main() {
  test('denied microphone stays on learner turn and submits nothing', () async {
    final recorder = FakeRecorder()..allowed = false;
    final repository = _CallRepository();
    final container = ProviderContainer(
      overrides: [
        callRepositoryProvider.overrideWithValue(repository),
        speechRecorderProvider.overrideWithValue(recorder),
      ],
    );
    addTearDown(container.dispose);
    final controller = await startCall(container);

    controller.pressMic();
    await settle();

    final state = container.read(callControllerProvider);
    expect(repository.turns, isEmpty);
    expect(state.awaitingLearner, isTrue);
    expect(state.listening, isFalse);
    expect(state.error, isNotNull);
  });

  test('empty capture retries recording and only valid WAV submits', () async {
    final recorder = FakeRecorder()..audio = null;
    final repository = _CallRepository();
    final container = ProviderContainer(
      overrides: [
        callRepositoryProvider.overrideWithValue(repository),
        speechRecorderProvider.overrideWithValue(recorder),
      ],
    );
    addTearDown(container.dispose);
    final controller = await startCall(container);

    controller.pressMic();
    await settle(1);
    controller.pressMic();
    await settle();
    expect(repository.turns, isEmpty);
    expect(container.read(callControllerProvider).error, isNotNull);

    recorder.audio = pcm16ToWav(Uint8List(3200));
    controller.pressMic();
    await settle(1);
    controller.pressMic();
    await settle();
    expect(repository.turns, hasLength(1));
    expect(recorder.starts, 2);
  });

  test(
    'hangup while permission is pending cancels and never submits',
    () async {
      final recorder = FakeRecorder()..permission = Completer<bool>();
      final repository = _CallRepository();
      final container = ProviderContainer(
        overrides: [
          callRepositoryProvider.overrideWithValue(repository),
          speechRecorderProvider.overrideWithValue(recorder),
        ],
      );
      addTearDown(container.dispose);
      final controller = await startCall(container);

      controller.pressMic();
      await settle(1);
      controller.hangUp();
      recorder.permission!.complete(true);
      await settle();

      expect(recorder.cancels, greaterThan(0));
      expect(repository.turns, isEmpty);
      expect(container.read(callControllerProvider).phase, CallPhase.ended);
    },
  );

  test(
    'provider disposal cancels capture before delayed permission resolves',
    () async {
      final recorder = FakeRecorder()..permission = Completer<bool>();
      final repository = _CallRepository();
      final container = ProviderContainer(
        overrides: [
          callRepositoryProvider.overrideWithValue(repository),
          speechRecorderProvider.overrideWithValue(recorder),
        ],
      );
      final controller = await startCall(container);
      controller.pressMic();
      await settle(1);

      container.dispose();
      recorder.permission!.complete(true);
      await settle();

      expect(recorder.cancels, greaterThan(0));
      expect(repository.turns, isEmpty);
    },
  );

  test('repository switch cancels delayed microphone start', () async {
    final recorder = FakeRecorder()..permission = Completer<bool>();
    final firstRepository = _CallRepository();
    final secondRepository = _CallRepository();
    final container = ProviderContainer(
      overrides: [
        callRepositoryProvider.overrideWithValue(firstRepository),
        speechRecorderProvider.overrideWithValue(recorder),
      ],
    );
    addTearDown(container.dispose);
    final controller = await startCall(container);
    controller.pressMic();
    await settle(1);

    container.updateOverrides([
      callRepositoryProvider.overrideWithValue(secondRepository),
      speechRecorderProvider.overrideWithValue(recorder),
    ]);
    container.read(callControllerProvider);
    recorder.permission!.complete(true);
    await settle();

    expect(container.read(callControllerProvider).phase, CallPhase.idle);
    expect(recorder.cancels, greaterThan(0));
    expect(firstRepository.turns, isEmpty);
    expect(secondRepository.turns, isEmpty);
  });

  test('hangup while recorder stop is pending never submits', () async {
    final recorder = _DelayedStopRecorder();
    final repository = _CallRepository();
    final container = ProviderContainer(
      overrides: [
        callRepositoryProvider.overrideWithValue(repository),
        speechRecorderProvider.overrideWithValue(recorder),
      ],
    );
    addTearDown(container.dispose);
    final controller = await startCall(container);
    controller.pressMic();
    await settle(1);
    controller.pressMic();
    await settle(1);

    controller.hangUp();
    recorder.stopped.complete(pcm16ToWav(Uint8List(3200)));
    await settle();

    expect(repository.turns, isEmpty);
    expect(container.read(callControllerProvider).phase, CallPhase.ended);
  });

  test(
    'account switch ignores delayed turn reply and cancels session',
    () async {
      final recorder = FakeRecorder();
      final repository = _CallRepository()
        ..pendingTurn = Completer<CallTurnResult>();
      final container = ProviderContainer(
        overrides: [
          callAccountIdentityProvider.overrideWithValue('account-a'),
          callRepositoryProvider.overrideWithValue(repository),
          speechRecorderProvider.overrideWithValue(recorder),
        ],
      );
      addTearDown(container.dispose);
      final controller = await startCall(container);
      controller.pressMic();
      await settle(1);
      controller.pressMic();
      await settle(2);
      expect(repository.turns, hasLength(1));

      container.updateOverrides([
        callAccountIdentityProvider.overrideWithValue('account-b'),
        callRepositoryProvider.overrideWithValue(repository),
        speechRecorderProvider.overrideWithValue(recorder),
      ]);
      container.read(callControllerProvider);
      repository.pendingTurn!.complete(
        const CallTurnResult(transcript: 'late', reply: 'late'),
      );
      await settle();

      expect(container.read(callControllerProvider).phase, CallPhase.idle);
    },
  );

  test(
    'failed turn retries same captured WAV without recording again',
    () async {
      final recorder = FakeRecorder()
        ..audio = pcm16ToWav(Uint8List.fromList(List<int>.filled(3200, 7)));
      final repository = _CallRepository()..failTurns = 1;
      final container = ProviderContainer(
        overrides: [
          callRepositoryProvider.overrideWithValue(repository),
          speechRecorderProvider.overrideWithValue(recorder),
        ],
      );
      addTearDown(container.dispose);
      final controller = await startCall(container);
      controller.pressMic();
      await settle(1);
      controller.pressMic();
      await settle();
      expect(repository.turns, hasLength(1));

      controller.pressMic();
      await settle();
      expect(repository.turns, hasLength(2));
      expect(repository.turns[1], repository.turns[0]);
      expect(recorder.starts, 1);
    },
  );
}

final class _CallRepository implements CallRepository, CallTurns {
  final turns = <List<int>>[];
  int failTurns = 0;
  Completer<CallTurnResult>? pendingTurn;

  @override
  Future<CallSession> loadSession(String partnerId) async => _session;

  @override
  Future<void> completeCall(String sessionId, int linesSpoken) async {}

  @override
  Future<CallTurnResult> speakTurn(
    String sessionId,
    int cursor, {
    Uint8List? wav,
  }) async {
    turns.add(wav!.toList());
    if (failTurns > 0) {
      failTurns--;
      throw StateError('network response lost');
    }
    if (pendingTurn case final pending?) return pending.future;
    return const CallTurnResult(transcript: 'Hello.', reply: 'Bye.');
  }
}

final class _DelayedStopRecorder implements SpeechRecorder {
  final stopped = Completer<Uint8List?>();
  int cancels = 0;

  @override
  Future<void> cancel() async => cancels++;

  @override
  Future<bool> start() async => true;

  @override
  Future<Uint8List?> stop() => stopped.future;
}
