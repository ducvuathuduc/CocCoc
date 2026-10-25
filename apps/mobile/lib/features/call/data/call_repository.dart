import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/client/active_course.dart';
import '../../../core/api/client/api_providers.dart';
import '../../../core/config/app_config.dart';
import '../domain/call_models.dart';
import 'api_call_repository.dart';

/// Source of video-call sessions. Swap the provider for a real adapter.
abstract class CallRepository {
  Future<CallSession> loadSession(String partnerId);

  /// Records a finished call. Server owns XP; the mock just acknowledges.
  Future<void> completeCall(String sessionId, int linesSpoken);
}

/// Spoken turns an API-backed [CallRepository] sends to the server. The mock
/// does not implement it, so its timed, offline flow is unchanged.
abstract interface class CallTurns {
  /// Sends the learner turn at script index [cursor] of call [sessionId];
  /// [wav] must contain the captured 16 kHz mono PCM16 WAV clip.
  Future<CallTurnResult> speakTurn(
    String sessionId,
    int cursor, {
    Uint8List? wav,
  });
}

class MockCallRepository implements CallRepository {
  const MockCallRepository();

  static const _copy = CallCopy(
    introTitle: 'Video call: Lily',
    introCallLabel: 'CALL FOR FREE +15 XP',
    introLaterLabel: 'DO THIS LATER',
    callingLabel: 'Calling Lily...',
    earnedLabel: 'You earned 20 XP!',
    reviewTitle: 'Review your conversation',
    continueLabel: 'CONTINUE',
    upsellLead: 'Get ',
    upsellHighlight: 'unlimited',
    upsellTail: ' video calls with Duolingo Max',
    upgradeLabel: 'UPGRADE TO MAX',
    noThanksLabel: 'NO THANKS',
    phoneKicker: 'Video Call',
    maxBadge: 'MAX',
    listeningLabel: 'Listening…',
  );

  static const lily = CallSession(
    id: 'call-lily-demo',
    partnerName: 'Lily',
    learnerInitial: 'S',
    xpReward: 20,
    copy: _copy,
    script: [
      CallLine(speaker: CallSpeaker.partner, text: 'Good evening.'),
      CallLine(speaker: CallSpeaker.learner, text: 'Good evening.'),
      CallLine(speaker: CallSpeaker.partner, text: 'How are you?'),
      CallLine(speaker: CallSpeaker.learner, text: 'I am fine.'),
      CallLine(speaker: CallSpeaker.partner, text: 'Cool.'),
      CallLine(speaker: CallSpeaker.partner, text: 'Do you speak English?'),
      CallLine(speaker: CallSpeaker.learner, text: 'Yes, I speak English.'),
      CallLine(speaker: CallSpeaker.partner, text: 'Ah, you speak English.'),
      CallLine(speaker: CallSpeaker.partner, text: 'Well, goodbye.'),
      CallLine(speaker: CallSpeaker.learner, text: 'Goodbye.'),
      CallLine(speaker: CallSpeaker.partner, text: 'See you soon.'),
    ],
  );

  @override
  Future<CallSession> loadSession(String partnerId) async => lily;

  @override
  Future<void> completeCall(String sessionId, int linesSpoken) async {}
}

final callRepositoryProvider = Provider<CallRepository>((ref) {
  if (!ref.watch(appConfigProvider).isApi) return const MockCallRepository();
  return ApiCallRepository(
    ref.watch(apiEndpointsProvider),
    ref.watch(activeCourseProvider),
  );
});
