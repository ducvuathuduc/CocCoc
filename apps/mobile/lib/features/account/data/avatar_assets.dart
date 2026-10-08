import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/avatar_configuration.dart';

const _catalogAsset = 'assets/avatar/avatar_builder_config.json';

final avatarCatalogProvider = FutureProvider<AvatarCatalog>((ref) async {
  final source = await rootBundle.loadString(_catalogAsset);
  return AvatarCatalogLoader.parse(source);
});

class AvatarCatalogLoader {
  const AvatarCatalogLoader._();

  static AvatarCatalog parse(String source) {
    final document = jsonDecode(source) as Map<String, dynamic>;
    final config = document['avatarBuilderConfig'] as Map<String, dynamic>;
    final rawDefaults =
        config['defaultBuiltAvatarState'] as Map<String, dynamic>;
    final defaults = <String, double>{
      for (final entry in rawDefaults.entries)
        entry.key: (entry.value as num).toDouble(),
      // EyeColor is used by the current face palette but omitted upstream.
      'EyeColor': 1,
    };
    final rawTabs = config['stateChooserTabs'] as List<dynamic>;
    final rawDisplays =
        config['avatarOnProfileDisplayOptions'] as Map<String, dynamic>? ??
        const {};
    return AvatarCatalog(
      defaults: defaults,
      profileDisplays: {
        for (final entry in rawDisplays.entries)
          double.parse(entry.key): AvatarProfileDisplay(
            backgroundColor:
                (entry.value as Map<String, dynamic>)['backgroundColor']
                    as String,
            iconColor:
                (entry.value as Map<String, dynamic>)['learningAppIconColor']
                    as String,
          ),
      },
      tabs: rawTabs
          .cast<Map<String, dynamic>>()
          .map(_parseTab)
          .toList(growable: false),
    );
  }

  static AvatarTab _parseTab(Map<String, dynamic> value) {
    final selected = value['selectedIcon'] as Map<String, dynamic>;
    final unselected = value['unselectedIcon'] as Map<String, dynamic>;
    return AvatarTab(
      name: value['tabName'] as String,
      selectedIconAsset: _localIcon(selected['lightUrl'] as String),
      unselectedIconAsset: _localIcon(unselected['lightUrl'] as String),
      sections: (value['sections'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_parseSection)
          .toList(growable: false),
    );
  }

  static AvatarSection _parseSection(Map<String, dynamic> value) {
    final palette = value['buttonType'] == 'IMAGE';
    final rawOptions =
        value[palette ? 'imageButtons' : 'featureButtons'] as List<dynamic>;
    return AvatarSection(
      title: value['header'] as String,
      layout: value['layoutType'] == 'LINEAR'
          ? AvatarChoiceLayout.linear
          : AvatarChoiceLayout.grid,
      options: rawOptions
          .cast<Map<String, dynamic>>()
          .map(_parseOption)
          .toList(growable: false),
    );
  }

  static AvatarOption _parseOption(Map<String, dynamic> value) {
    final rawOverrides = value['statesToOverride'] as Map<String, dynamic>?;
    return AvatarOption(
      stateName: value['state'] as String,
      value: (value['value'] as num).toDouble(),
      color: value['color'] as String?,
      overrides: rawOverrides == null
          ? const {}
          : {
              for (final entry in rawOverrides.entries)
                entry.key: (entry.value as num).toDouble(),
            },
    );
  }

  static String _localIcon(String url) {
    final filename = Uri.parse(url).pathSegments.last;
    return 'assets/avatar/$filename';
  }
}
