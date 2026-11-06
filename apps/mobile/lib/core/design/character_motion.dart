import 'package:flutter/material.dart';

import 'cocenglish_brand.dart';

enum LessonCharacter {
  bea,
  eddy,
  falstaff,
  junior,
  lily,
  lin,
  lucy,
  oscar,
  vikram,
  zari,
}

enum CharacterReaction { reset, correct, incorrect }

extension LessonCharacterLegacyAsset on LessonCharacter {
  /// The source rig was removed from the app package. Kept empty for legacy
  /// capture helpers that still compile against the old enum shape.
  @Deprecated('Character rigs are no longer bundled or loaded.')
  String get asset => '';
}

extension CharacterReactionLegacyInput on CharacterReaction {
  @Deprecated('Feedback is now rendered with CocEnglish artwork.')
  String get input => switch (this) {
    CharacterReaction.reset => 'reset_trig',
    CharacterReaction.correct => 'correct_trig',
    CharacterReaction.incorrect => 'incorrect_trig',
  };
}

/// Project-owned replacement for the archived lesson-character animations.
/// The lesson character ID remains part of existing exercise data, while every
/// screen now renders the CocEnglish mascot artwork.
class CharacterMotion extends StatelessWidget {
  const CharacterMotion({
    required this.character,
    required this.width,
    required this.height,
    required this.fallback,
    this.reaction = CharacterReaction.reset,
    this.epoch = '',
    this.contentScale = 1,
    this.contentAlignment = Alignment.center,
    this.enabled = const bool.fromEnvironment(
      'ENABLE_MASCOT_MOTION',
      defaultValue: true,
    ),
    super.key,
  });

  final LessonCharacter character;
  final CharacterReaction reaction;
  final String epoch;
  final double contentScale;
  final Alignment contentAlignment;
  final double width;
  final double height;
  final Widget fallback;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CocEnglishMascot(
      width: width,
      height: height,
      pose: switch (reaction) {
        CharacterReaction.reset => CocEnglishMascotPose.wave,
        CharacterReaction.correct => CocEnglishMascotPose.celebrate,
        CharacterReaction.incorrect => CocEnglishMascotPose.study,
      },
    ),
  );
}
