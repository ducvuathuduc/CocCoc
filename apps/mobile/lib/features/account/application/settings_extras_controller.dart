import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';

class SettingsExtrasState {
  const SettingsExtrasState({
    this.classroom,
    this.joinError,
    this.joining = false,
    this.connected = const {},
    this.sending = false,
    this.feedbackSent = 0,
  });
  final String? classroom, joinError;
  final bool joining, sending;
  final Set<String> connected;
  final int feedbackSent;

  SettingsExtrasState copyWith({
    String? classroom,
    bool clearClassroom = false,
    String? joinError,
    bool clearJoinError = false,
    bool? joining,
    Set<String>? connected,
    bool? sending,
    int? feedbackSent,
  }) => SettingsExtrasState(
    classroom: clearClassroom ? null : classroom ?? this.classroom,
    joinError: clearJoinError ? null : joinError ?? this.joinError,
    joining: joining ?? this.joining,
    connected: connected ?? this.connected,
    sending: sending ?? this.sending,
    feedbackSent: feedbackSent ?? this.feedbackSent,
  );
}

/// State for Settings > Duolingo for Schools / Social accounts / Feedback.
class SettingsExtrasController extends Notifier<SettingsExtrasState> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  SettingsExtrasState build() =>
      SettingsExtrasState(connected: _repo.connectedSocial);

  Future<bool> joinClassroom(String code) async {
    if (state.joining) return false;
    state = state.copyWith(joining: true, clearJoinError: true);
    final result = await _repo.joinClassroom(code);
    state = state.copyWith(
      joining: false,
      classroom: result.classroom,
      joinError: result.error,
    );
    return result.classroom != null;
  }

  void leaveClassroom() =>
      state = state.copyWith(clearClassroom: true, clearJoinError: true);

  Future<void> setSocial(String id, bool connected) async {
    final next = {...state.connected};
    connected ? next.add(id) : next.remove(id);
    state = state.copyWith(connected: next);
    await _repo.setSocialConnected(id, connected: connected);
  }

  Future<bool> sendFeedback(String topic, String message) async {
    if (state.sending || message.trim().isEmpty) return false;
    state = state.copyWith(sending: true);
    await _repo.sendFeedback(topic, message.trim());
    state = state.copyWith(
      sending: false,
      feedbackSent: state.feedbackSent + 1,
    );
    return true;
  }
}

final settingsExtrasControllerProvider =
    NotifierProvider<SettingsExtrasController, SettingsExtrasState>(
      SettingsExtrasController.new,
    );
