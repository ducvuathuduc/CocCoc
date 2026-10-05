import 'package:flutter/material.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';

abstract final class LearningColors {
  static const green = Color(0xFF58CC02);
  static const greenDark = Color(0xFF58A700);
  static const blue = Color(0xFF1CB0F6);
  static const blueDark = Color(0xFF1899D6);
  static const purple = Color(0xFFCE82FF);
  static const red = Color(0xFFFF4B4B);
  static const redDark = Color(0xFFEA2B2B);
  static const yellow = Color(0xFFFFC800);
  static const orange = Color(0xFFFF9600);
  static const correct = Color(0xFFD7FFB8);
  static const incorrect = Color(0xFFFFDFE0);
}

abstract final class LearningArt {
  static const english = ArtRegion('05', Rect.fromLTWH(102, 1788, 124, 96));
  static const french = ArtRegion('05', Rect.fromLTWH(102, 1173, 124, 96));
  static const home = ArtRegion(
    'practice-04',
    Rect.fromLTWH(48, 2338, 110, 105),
  );
  static const quests = ArtRegion(
    'lesson-01',
    Rect.fromLTWH(248, 2340, 100, 102),
  );
  static const practice = ArtRegion(
    'lesson-01',
    Rect.fromLTWH(432, 2340, 116, 104),
  );
  static const league = ArtRegion(
    'lesson-01',
    Rect.fromLTWH(644, 2340, 94, 102),
  );
  static const profile = ArtRegion(
    'practice-04',
    Rect.fromLTWH(832, 2341, 112, 99),
  );
  static const flame = ArtRegion('lesson-01', Rect.fromLTWH(366, 211, 70, 81));
  static const gem = ArtRegion('lesson-01', Rect.fromLTWH(686, 216, 61, 72));
  static const heart = ArtRegion('lesson-01', Rect.fromLTWH(1015, 220, 78, 65));
  static const guide = ArtRegion('lesson-01', Rect.fromLTWH(1006, 409, 88, 82));
  static const pathDuo = ArtRegion(
    'practice-01',
    Rect.fromLTWH(757, 1079, 255, 263),
  );
  static const boy = ArtRegion('lesson-03', Rect.fromLTWH(117, 887, 365, 427));
  static const girl = ArtRegion('lesson-03', Rect.fromLTWH(705, 882, 387, 430));
  static const cat = ArtRegion('lesson-03', Rect.fromLTWH(97, 1697, 405, 265));
  static const woman = ArtRegion(
    'lesson-03',
    Rect.fromLTWH(735, 1621, 324, 408),
  );
  static const man = ArtRegion('lesson-05', Rect.fromLTWH(731, 1624, 319, 412));
  static const bear = ArtRegion('lesson-07', Rect.fromLTWH(53, 509, 340, 510));
  static const completed = ArtRegion(
    'lesson-12',
    Rect.fromLTWH(420, 673, 404, 545),
  );
  static const medalDuo = ArtRegion(
    'results-02',
    Rect.fromLTWH(209, 481, 772, 771),
  );
  static const scoreDuo = ArtRegion(
    'results-03',
    Rect.fromLTWH(395, 379, 405, 668),
  );
  static const chest = ArtRegion('lesson-16', Rect.fromLTWH(98, 655, 922, 733));
  static const streak = ArtRegion(
    'lesson-18',
    Rect.fromLTWH(427, 359, 329, 586),
  );
  static const friendsChest = ArtRegion(
    'lesson-20',
    Rect.fromLTWH(140, 613, 943, 730),
  );
  static const superDuo = ArtRegion(
    'lesson-21',
    Rect.fromLTWH(340, 326, 414, 429),
  );
  static const guideCharacter = ArtRegion(
    'guide-02',
    Rect.fromLTWH(414, 380, 345, 469),
  );
  static const lily = ArtRegion(
    'practice-04',
    Rect.fromLTWH(361, 351, 436, 408),
  );
  static const roleplay = ArtRegion(
    'practice-04',
    Rect.fromLTWH(879, 1361, 208, 151),
  );
  static const mistakes = ArtRegion(
    'practice-04',
    Rect.fromLTWH(890, 1589, 181, 165),
  );
  static const words = ArtRegion(
    'practice-04',
    Rect.fromLTWH(879, 1818, 198, 167),
  );
  static const listen = ArtRegion(
    'practice-04',
    Rect.fromLTWH(900, 2055, 165, 160),
  );
  static const speak = ArtRegion(
    'practice-05',
    Rect.fromLTWH(904, 1620, 150, 168),
  );
  static const singer = ArtRegion(
    'quests-02',
    Rect.fromLTWH(276, 731, 620, 665),
  );
  static const questSinger = ArtRegion(
    'quests-03',
    Rect.fromLTWH(775, 155, 300, 256),
  );
  static const questFriends = ArtRegion(
    'quests-03',
    Rect.fromLTWH(76, 956, 1030, 376),
  );
  static const trophy = ArtRegion(
    'league-05',
    Rect.fromLTWH(472, 402, 241, 306),
  );
  static const leagueLocked = ArtRegion(
    'league-02',
    Rect.fromLTWH(150, 713, 880, 578),
  );
  static const avatar = ArtRegion(
    'profile-06',
    Rect.fromLTWH(387, 353, 409, 416),
  );
  static const freeze = ArtRegion(
    'shop-02',
    Rect.fromLTWH(657, 1241, 195, 260),
  );
  static const maxDuo = ArtRegion('shop-02', Rect.fromLTWH(777, 425, 301, 298));
  static ArtRegion character(String? id) => switch (id) {
    'girl' => girl,
    'cat' => cat,
    'woman' => woman,
    'man' => man,
    'bear' => bear,
    _ => boy,
  };
}

const headingStyle = TextStyle(
  fontSize: 23,
  fontWeight: FontWeight.w700,
  height: 1.25,
);
const sectionStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w700,
  color: ReferenceColors.disabled,
  letterSpacing: .8,
);

Duration motionDuration(BuildContext context, [int milliseconds = 180]) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

class LearningHeader extends StatelessWidget {
  const LearningHeader({
    required this.title,
    required this.onClose,
    this.trailing,
    super.key,
  });
  final String title;
  final VoidCallback onClose;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: const BoxDecoration(
      border: Border(
        bottom: BorderSide(color: ReferenceColors.border, width: 2),
      ),
    ),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Close',
          onPressed: onClose,
          icon: const Icon(
            Icons.close_rounded,
            size: 30,
            color: ReferenceColors.disabled,
          ),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: headingStyle.copyWith(fontSize: 21),
          ),
        ),
        trailing ?? const SizedBox(width: 48),
      ],
    ),
  );
}

class LearningCard extends StatelessWidget {
  const LearningCard({
    required this.child,
    this.onTap,
    this.selected = false,
    this.correct,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });
  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final bool? correct;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    final border = selected
        ? correct == true
              ? const Color(0xFFA5ED6E)
              : correct == false
              ? LearningColors.red
              : ReferenceColors.blueBorder
        : ReferenceColors.border;
    final fill = selected
        ? correct == true
              ? LearningColors.correct
              : correct == false
              ? LearningColors.incorrect
              : ReferenceColors.blueFill
        : ReferenceColors.surface;
    return Semantics(
      selected: selected,
      button: onTap != null,
      child: AnimatedContainer(
        duration: motionDuration(context, 120),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 2),
          boxShadow: [BoxShadow(color: border, offset: const Offset(0, 3))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

Future<T?> learningSheet<T>(
  BuildContext context, {
  required String title,
  required Widget child,
  Widget? illustration,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (illustration != null) ...[
              illustration,
              const SizedBox(height: 20),
            ],
            Text(title, textAlign: TextAlign.center, style: headingStyle),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    ),
  ),
);

Future<void> showLearningNotice(
  BuildContext context,
  String title,
  String message,
) => learningSheet<void>(
  context,
  title: title,
  child: Column(
    children: [
      Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 17, color: ReferenceColors.muted),
      ),
      const SizedBox(height: 24),
      ReferenceButton(
        label: 'GOT IT',
        backgroundColor: LearningColors.blue,
        edgeColor: LearningColors.blueDark,
        onPressed: () => Navigator.pop(context),
      ),
    ],
  ),
);
