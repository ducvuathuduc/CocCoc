import 'dart:collection';

enum AvatarChoiceLayout { linear, grid }

class AvatarOption {
  AvatarOption({
    required this.stateName,
    required this.value,
    this.color,
    Map<String, double> overrides = const {},
  }) : overrides = UnmodifiableMapView(overrides);

  final String stateName;
  final double value;
  final String? color;
  final Map<String, double> overrides;

  Map<String, double> previewValues(Map<String, double> draft) =>
      <String, double>{...draft, ...overrides, stateName: value};
}

class AvatarSection {
  AvatarSection({
    required this.title,
    required this.layout,
    required List<AvatarOption> options,
  }) : options = List.unmodifiable(options);

  final String title;
  final AvatarChoiceLayout layout;
  final List<AvatarOption> options;
  bool get isPalette => options.every((option) => option.color != null);
}

class AvatarTab {
  AvatarTab({
    required this.name,
    required this.selectedIconAsset,
    required this.unselectedIconAsset,
    required List<AvatarSection> sections,
  }) : sections = List.unmodifiable(sections);

  final String name;
  final String selectedIconAsset;
  final String unselectedIconAsset;
  final List<AvatarSection> sections;
}

class AvatarProfileDisplay {
  const AvatarProfileDisplay({
    required this.backgroundColor,
    required this.iconColor,
  });
  final String backgroundColor, iconColor;
}

class AvatarCatalog {
  AvatarCatalog({
    required Map<String, double> defaults,
    required List<AvatarTab> tabs,
    Map<double, AvatarProfileDisplay> profileDisplays = const {},
  }) : defaults = UnmodifiableMapView(defaults),
       tabs = List.unmodifiable(tabs),
       profileDisplays = Map.unmodifiable(profileDisplays),
       _allowedValues = _indexAllowedValues(tabs);

  AvatarCatalog.empty()
    : defaults = const {},
      tabs = const [],
      profileDisplays = const {},
      _allowedValues = const {};

  final Map<String, double> defaults;
  final List<AvatarTab> tabs;
  final Map<double, AvatarProfileDisplay> profileDisplays;
  final Map<String, Set<double>> _allowedValues;

  bool allows(String stateName, double value) =>
      _allowedValues[stateName]?.contains(value) ?? false;

  static Map<String, Set<double>> _indexAllowedValues(List<AvatarTab> tabs) {
    final result = <String, Set<double>>{};
    for (final tab in tabs) {
      for (final section in tab.sections) {
        for (final option in section.options) {
          result
              .putIfAbsent(option.stateName, () => <double>{})
              .add(option.value);
        }
      }
    }
    return UnmodifiableMapView(
      result.map((key, value) => MapEntry(key, Set.unmodifiable(value))),
    );
  }
}
