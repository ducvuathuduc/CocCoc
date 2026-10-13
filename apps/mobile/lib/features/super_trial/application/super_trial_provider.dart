import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/super_trial_repository.dart';
import '../domain/super_trial_offer.dart';

final superTrialRepositoryProvider = Provider<SuperTrialRepository>(
  (ref) => MockSuperTrialRepository(),
);
final superTrialOfferProvider = Provider<SuperTrialOffer>(
  (ref) => ref.watch(superTrialRepositoryProvider).offer,
);
