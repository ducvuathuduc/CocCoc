import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/client/api_exception.dart';
import '../data/settings_repository.dart';

class SettingsExtrasState {
  const SettingsExtrasState({
    this.classroom,
    this.joinError,
    this.joining = false,
    this.connected = const {},
    this.sending = false,
    this.feedbackSent = 0,
    this.error,
  });
  final String? classroom, joinError;
  final bool joining, sending;
  final Set<String> connected;
  final int feedbackSent;
  final String? error;

  SettingsExtrasState copyWith({
    String? classroom,
    bool clearClassroom = false,
    String? joinError,
    bool clearJoinError = false,
    bool? joining,
    Set<String>? connected,
    bool? sending,
    int? feedbackSent,
    String? error,
    bool clearError = false,
  }) => SettingsExtrasState(
    classroom: clearClassroom ? null : classroom ?? this.classroom,
    joinError: clearJoinError ? null : joinError ?? this.joinError,
    joining: joining ?? this.joining,
    connected: connected ?? this.connected,
    sending: sending ?? this.sending,
    feedbackSent: feedbackSent ?? this.feedbackSent,
    error: clearError ? null : error ?? this.error,
  );
}

/// State for Settings > Duolingo for Schools / Social accounts / Feedback.
class SettingsExtrasController extends Notifier<SettingsExtrasState> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);
  int _revision = 0;
  bool _socialInFlight = false;

  @override
  SettingsExtrasState build() {
    _revision++;
    _socialInFlight = false;
    return SettingsExtrasState(
      connected: ref.watch(settingsRepositoryProvider).connectedSocial,
    );
  }

  Future<bool> joinClassroom(String code) async {
    if (state.joining) return false;
    state = state.copyWith(joining: true, clearJoinError: true);
    final revision = _revision;
    final result = await _repo.joinClassroom(code);
    if (!ref.mounted || revision != _revision) return false;
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
    if (_socialInFlight) return;
    _socialInFlight = true;
    final revision = _revision;
    state = state.copyWith(clearError: true);
    try {
      await _repo.setSocialConnected(id, connected: connected);
      if (!ref.mounted || revision != _revision) return;
      state = state.copyWith(connected: _repo.connectedSocial);
    } on Object catch (error) {
      if (ref.mounted && revision == _revision) {
        state = state.copyWith(error: _message(error));
      }
    } finally {
      if (revision == _revision) _socialInFlight = false;
    }
  }

  Future<bool> sendFeedback(String topic, String message) async {
    if (state.sending || message.trim().isEmpty) return false;
    state = state.copyWith(sending: true, clearError: true);
    final revision = _revision;
    try {
      await _repo.sendFeedback(topic, message.trim());
      if (!ref.mounted || revision != _revision) return false;
      state = state.copyWith(
        sending: false,
        feedbackSent: state.feedbackSent + 1,
      );
      return true;
    } on Object catch (error) {
      if (ref.mounted && revision == _revision) {
        state = state.copyWith(sending: false, error: _message(error));
      }
      return false;
    }
  }

  String _message(Object error) => error is ApiException
      ? error.userMessage
      : 'We couldn’t complete that request. Please try again.';
}

final settingsExtrasControllerProvider =
    NotifierProvider<SettingsExtrasController, SettingsExtrasState>(
      SettingsExtrasController.new,
    );
