import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/client/api_providers.dart';
import '../../../core/config/app_config.dart';
import '../data/energy_repository.dart';
import '../domain/energy_offer.dart';
import 'extended_controller.dart';
import 'preview_controller.dart';

final energyRepositoryProvider = Provider<EnergyRepository>(
  (ref) => ref.watch(appConfigProvider).isApi
      ? ApiEnergyRepository(ref.watch(apiEndpointsProvider))
      : MockEnergyRepository(),
);
final energyOffersProvider = Provider<List<EnergyOffer>>(
  (ref) => ref.watch(energyRepositoryProvider).offers,
);
final energyControllerProvider = NotifierProvider<EnergyController, bool>(
  EnergyController.new,
);

class EnergyController extends Notifier<bool> {
  String? error;
  @override
  bool build() => false;
  bool available(EnergyOffer offer) {
    final energy = ref.read(extendedControllerProvider);
    final api = ref.read(appConfigProvider).isApi;
    return !state &&
        !energy.unlimited &&
        energy.energy < ref.read(energyRepositoryProvider).capacity &&
        (api
            ? offer.kind == EnergyRefillKind.ad ||
                  offer.kind == EnergyRefillKind.recharge
            : true) &&
        (api ||
            offer.cost == 0 ||
            ref.read(previewWalletProvider) >= offer.cost);
  }

  bool beginAd(EnergyOffer offer) {
    if (offer.kind != EnergyRefillKind.ad || !available(offer)) return false;
    state = true;
    return true;
  }

  void endAd() {
    if (ref.mounted) state = false;
  }

  Future<void> refill(EnergyOffer offer, {bool adRewarded = false}) async {
    error = null;
    if (!available(offer) ||
        (offer.kind == EnergyRefillKind.ad && !adRewarded)) {
      return;
    }
    state = true;
    try {
      final api = ref.read(appConfigProvider).isApi;
      final balance = await ref
          .read(energyRepositoryProvider)
          .refill(offer, ref.read(extendedControllerProvider).energy);
      if (!api &&
          offer.cost > 0 &&
          !ref
              .read(previewControllerProvider.notifier)
              .spendRefillGems(offer.cost)) {
        return;
      }
      ref.read(extendedControllerProvider.notifier).setEnergy(balance);
    } catch (_) {
      error = 'Energy unavailable. Try again.';
    } finally {
      state = false;
    }
  }
}
