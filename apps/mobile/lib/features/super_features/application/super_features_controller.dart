import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/super_features_repository.dart';
import '../domain/super_features.dart';

final superFeaturesRepositoryProvider = Provider<SuperFeaturesRepository>(
  (ref) => MockSuperFeaturesRepository(),
);
final superFeaturesContentProvider = Provider<SuperFeaturesContent>(
  (ref) => ref.watch(superFeaturesRepositoryProvider).content,
);
final superFeaturesControllerProvider =
    NotifierProvider<SuperFeaturesController, SuperFeaturesState>(
      SuperFeaturesController.new,
    );

class SuperFeaturesController extends Notifier<SuperFeaturesState> {
  @override
  SuperFeaturesState build() => SuperFeaturesState(
    features: ref.watch(superFeaturesRepositoryProvider).load(),
  );

  /// Optimistic toggle; reverts and shows an error if the save fails.
  Future<void> toggle(String id, bool enabled) async {
    final before = state.features;
    state = SuperFeaturesState(
      features: [
        for (final f in before) f.id == id ? f.copyWith(enabled: enabled) : f,
      ],
    );
    final ok = await ref
        .read(superFeaturesRepositoryProvider)
        .setEnabled(id, enabled);
    if (!ok) {
      state = SuperFeaturesState(
        features: before,
        error: ref.read(superFeaturesContentProvider).saveFailed,
      );
    }
  }
}
