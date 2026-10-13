import '../domain/super_features.dart';

/// No preferences contract exists for these switches yet; the mock keeps
/// them in memory.
abstract class SuperFeaturesRepository {
  SuperFeaturesContent get content;
  List<SuperFeature> load();
  Future<bool> setEnabled(String id, bool enabled);
}

class MockSuperFeaturesRepository implements SuperFeaturesRepository {
  MockSuperFeaturesRepository({
    this.content = const SuperFeaturesContent(),
    List<SuperFeature> features = defaults,
    this.succeed = true,
  }) : _features = [...features];

  static const defaults = [
    SuperFeature(
      id: 'unlimited_energy',
      title: 'Unlimited energy',
      subtitle: 'Keep learning without running out of energy',
    ),
    SuperFeature(
      id: 'personalized_practice',
      title: 'Personalized Practice',
      subtitle: 'Add review of your mistakes to your path',
    ),
    SuperFeature(
      id: 'legendary',
      title: 'Free Legendary attempts',
      subtitle: 'Try Legendary levels without spending gems',
    ),
    SuperFeature(
      id: 'sound_effects_super',
      title: 'Super celebrations',
      subtitle: 'Show Super animations after lessons',
    ),
  ];

  @override
  final SuperFeaturesContent content;
  final bool succeed;
  final List<SuperFeature> _features;
  @override
  List<SuperFeature> load() => List.unmodifiable(_features);
  @override
  Future<bool> setEnabled(String id, bool enabled) async {
    if (!succeed) return false;
    final i = _features.indexWhere((f) => f.id == id);
    if (i < 0) return false;
    _features[i] = _features[i].copyWith(enabled: enabled);
    return true;
  }
}
