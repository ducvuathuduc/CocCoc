import '../../account/domain/avatar_configuration.dart';

/// Authored mock identity choices from the verified original avatar catalog.
/// These are independent of the learner's saved/draft avatar.
class ProfileAppearance {
  const ProfileAppearance({
    required this.hair,
    required this.background,
    required this.skinTone,
    required this.clothing,
    this.glasses = 0,
    this.expression = 1,
  });

  final double hair, background, skinTone, clothing, glasses, expression;

  Map<String, double> get overrides => Map.unmodifiable({
    'MainHair': hair,
    'BackgroundColor': background,
    'SkinTone': skinTone,
    'ClothingColor': clothing,
    'Glasses': glasses,
    'Expression': expression,
  });

  Map<String, double> valuesFor(AvatarCatalog catalog) => Map.unmodifiable({
    ...catalog.defaults,
    for (final entry in overrides.entries)
      if (catalog.allows(entry.key, entry.value)) entry.key: entry.value,
  });
}
