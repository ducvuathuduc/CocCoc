import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/client/idempotency.dart';
import '../../../core/api/client/api_providers.dart';
import '../../../core/config/app_config.dart';
import '../../progress/application/extended_controller.dart';
import '../data/ads_repository.dart';
import '../data/api_ads_repository.dart';
import '../domain/house_ad.dart';

final adsRepositoryProvider = Provider<AdsRepository>(
  (ref) => ref.watch(appConfigProvider).isApi
      ? ApiAdsRepository(ref.watch(apiEndpointsProvider))
      : MockAdsRepository(),
);
final houseAdProvider = Provider<HouseAd>(
  (ref) => ref.watch(adsRepositoryProvider).houseAd,
);
final adsEligibleProvider = Provider<bool>(
  (ref) => !ref.watch(extendedControllerProvider).unlimited,
);
final adControllerProvider =
    NotifierProvider.autoDispose<AdController, AdState>(AdController.new);

class AdState {
  const AdState({
    this.seconds = 5,
    this.ready = false,
    this.busy = false,
    this.error,
    this.rewarded = false,
  });
  final int seconds;
  final bool ready, busy, rewarded;
  final String? error;
}

class AdController extends Notifier<AdState> {
  Timer? _timer;
  bool _disposed = false;
  bool _paused = false;
  final id = UuidV4Generator().next();
  String _placement = 'LESSON_END_INTERSTITIAL';
  @override
  AdState build() {
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
    });
    return AdState(seconds: ref.watch(houseAdProvider).skipAfter.inSeconds);
  }

  Future<void> start(String placement) async {
    if (!ref.read(adsEligibleProvider) || state.ready || state.busy) return;
    _placement = placement;
    state = AdState(seconds: state.seconds, busy: true);
    try {
      await ref.read(adsRepositoryProvider).impression(id, placement);
      if (_disposed) return;
      state = AdState(seconds: state.seconds, ready: true);
      _scheduleTimer();
    } catch (_) {
      if (!_disposed) {
        state = AdState(
          seconds: state.seconds,
          error: 'Ad unavailable. Try again.',
        );
      }
    }
  }

  void pause() {
    _paused = true;
    _timer?.cancel();
  }

  void resume() {
    _paused = false;
    _scheduleTimer();
  }

  void _scheduleTimer() {
    _timer?.cancel();
    if (!state.ready || state.seconds == 0 || _disposed || _paused) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      state = AdState(seconds: state.seconds - 1, ready: true);
      if (state.seconds == 0) timer.cancel();
    });
  }

  Future<bool> finish() async {
    if (!ref.read(adsEligibleProvider) ||
        !state.ready ||
        state.seconds > 0 ||
        state.busy ||
        state.rewarded) {
      return false;
    }
    state = const AdState(seconds: 0, ready: true, busy: true);
    try {
      final rewarded = await ref
          .read(adsRepositoryProvider)
          .complete(id, _placement);
      if (!_disposed) {
        state = AdState(seconds: 0, ready: true, rewarded: rewarded);
      }
      return rewarded;
    } catch (_) {
      if (!_disposed) {
        state = const AdState(
          seconds: 0,
          ready: true,
          error: 'Reward unavailable. Try again.',
        );
      }
      return false;
    }
  }
}
