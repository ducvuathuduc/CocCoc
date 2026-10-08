import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/profile_appearance.dart';

const _appearances = <String, ProfileAppearance>{
  'Alex': ProfileAppearance(hair: 58, background: 22, skinTone: 4, clothing: 2),
  'Maria': ProfileAppearance(hair: 40, background: 4, skinTone: 9, clothing: 1),
  'Lucas': ProfileAppearance(hair: 5, background: 17, skinTone: 2, clothing: 9),
  'Anna': ProfileAppearance(hair: 35, background: 7, skinTone: 1, clothing: 4),
  'Samira': ProfileAppearance(
    hair: 19,
    background: 10,
    skinTone: 15,
    clothing: 7,
  ),
  'Sam Lee': ProfileAppearance(
    hair: 40,
    background: 19,
    skinTone: 15,
    clothing: 1,
  ),
  'Noah': ProfileAppearance(hair: 49, background: 16, skinTone: 9, clothing: 2),
  'Emma': ProfileAppearance(hair: 25, background: 5, skinTone: 4, clothing: 7),
  'James Smith': ProfileAppearance(
    hair: 5,
    background: 21,
    skinTone: 4,
    clothing: 3,
    glasses: 4,
    expression: 17,
  ),
};

final profileAppearanceProvider = Provider.family<ProfileAppearance?, String>(
  (_, userId) => _appearances[userId],
);
