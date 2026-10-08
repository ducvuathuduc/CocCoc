enum StreakWidgetMood {
  ready,
  early,
  practice,
  lastChance,
  save,
  protected,
  away,
}

// Archived visual fixtures, independent of the learner's current streak journal.
const widgetWeekdays = <StreakWidgetMood, List<(String, bool)>>{
  StreakWidgetMood.ready: [],
  StreakWidgetMood.early: [
    ('T', true),
    ('F', true),
    ('S', true),
    ('S', true),
    ('M', false),
  ],
  StreakWidgetMood.practice: [
    ('F', true),
    ('S', true),
    ('S', true),
    ('M', true),
    ('T', false),
  ],
  StreakWidgetMood.lastChance: [
    ('F', true),
    ('S', true),
    ('S', true),
    ('M', true),
    ('T', false),
  ],
  StreakWidgetMood.save: [
    ('S', true),
    ('M', true),
    ('T', true),
    ('W', true),
    ('T', false),
  ],
  StreakWidgetMood.protected: [
    ('F', true),
    ('S', true),
    ('S', true),
    ('M', true),
    ('T', true),
  ],
  StreakWidgetMood.away: [],
};

class StreakWidgetStyle {
  const StreakWidgetStyle(
    this.mood,
    this.asset,
    this.title,
    this.smallTitle,
    this.startColor,
    this.endColor,
    this.mediumArt,
    this.smallArt,
  );
  final StreakWidgetMood mood;
  final String asset, title, smallTitle;
  final int startColor, endColor;
  // Source-pixel regions contain only the original illustration; labels are native.
  final (double, double, double, double) mediumArt, smallArt;
}

final streakWidgetStyles = List<StreakWidgetStyle>.unmodifiable(const [
  StreakWidgetStyle(
    StreakWidgetMood.ready,
    'widget-ready',
    'Ready to start learning?',
    'Ready to start learning?',
    0xFF00A6F5,
    0xFFABE6FC,
    (690, 487, 413, 241),
    (77, 1020, 481, 251),
  ),
  StreakWidgetStyle(
    StreakWidgetMood.early,
    'widget-early',
    'Get started early!',
    'Get started early!',
    0xFF3997E8,
    0xFF83BBF0,
    (720, 475, 383, 251),
    (80, 1050, 477, 219),
  ),
  StreakWidgetStyle(
    StreakWidgetMood.practice,
    'widget-practice',
    'Please practice!',
    'Extend your streak!',
    0xFF9D43F6,
    0xFFBF65EC,
    (695, 444, 408, 282),
    (77, 1050, 481, 220),
  ),
  StreakWidgetStyle(
    StreakWidgetMood.lastChance,
    'widget-last-chance',
    'Last chance!',
    'Last chance!',
    0xFFAF3300,
    0xFF9A0750,
    (695, 441, 408, 285),
    (77, 997, 481, 274),
  ),
  StreakWidgetStyle(
    StreakWidgetMood.save,
    'widget-save',
    'Save your streak!',
    'Don’t forget me!',
    0xFF390200,
    0xFFAA2C29,
    (640, 442, 463, 284),
    (77, 1018, 481, 252),
  ),
  StreakWidgetStyle(
    StreakWidgetMood.protected,
    'widget-six',
    'Don’t forget me!',
    'Come back soon!',
    0xFF48042A,
    0xFFAA1859,
    (675, 470, 428, 255),
    (77, 1010, 481, 260),
  ),
  StreakWidgetStyle(
    StreakWidgetMood.away,
    'widget-seven',
    'Come back to English!',
    'Come back to English!',
    0xFF122452,
    0xFF1888AB,
    (690, 457, 413, 269),
    (77, 1040, 481, 230),
  ),
]);
