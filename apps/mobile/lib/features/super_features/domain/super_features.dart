/// Manage features / Super settings (audit row 33). Gummble's Android Home
/// sub-flow "Manage features" is listed but not cached, so this is derived
/// from the app's settings pages. Each toggle is a Super perk the learner can
/// switch off on their account; Free learners see them locked.
class SuperFeature {
  const SuperFeature({
    required this.id,
    required this.title,
    required this.subtitle,
    this.enabled = true,
  });
  final String id, title, subtitle;
  final bool enabled;
  SuperFeature copyWith({bool? enabled}) => SuperFeature(
    id: id,
    title: title,
    subtitle: subtitle,
    enabled: enabled ?? this.enabled,
  );
}

class SuperFeaturesContent {
  const SuperFeaturesContent({
    this.pageTitle = 'Manage features',
    this.sectionLabel = 'SUPER FEATURES',
    this.footnote = 'Turning a feature off doesn’t change your subscription.',
    this.lockedTitle = 'These features are part of Super',
    this.lockedBody = 'Get Super to turn them on.',
    this.lockedAction = 'GET SUPER',
    this.saveFailed = 'Couldn’t save that change. Try again.',
  });
  final String pageTitle,
      sectionLabel,
      footnote,
      lockedTitle,
      lockedBody,
      lockedAction,
      saveFailed;
}

class SuperFeaturesState {
  const SuperFeaturesState({this.features = const [], this.error});
  final List<SuperFeature> features;
  final String? error;
}
