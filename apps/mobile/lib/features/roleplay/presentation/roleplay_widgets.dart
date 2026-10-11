import 'package:flutter/material.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../domain/roleplay_models.dart';

/// Colours sampled from the Duolingo Roleplay references (refs6).
abstract final class RoleplayColors {
  static const heroTop = Color(0xFF000001);
  static const heroMid = Color(0xFF210527);
  static const heroBottom = Color(0xFF301060);
  static const tagFill = Color(0xFF41236E);
  static const tagText = Color(0xFFDDA3FA);
  static const starOn = Color(0xFFCE82FF);
  static const starOff = Color(0xFF513A64);
  static const buttonEdge = Color(0xFFD5CFDE);
  static const ink = Color(0xFF0A0A0A);
  static const maxBlack = Color(0xFF020002);
  static const maxCyan = Color(0xFF38EFFF);
  static const maxGreen = Color(0xFF30F3B3);
  static const maxEdge = Color(0xFF17DBEC);
  static const maxTeal = Color(0xFF34F2CE);
  static const maxBubble = Color(0xFF37464F);
  static const statTop = Color(0xFF0D363B);
  static const statBottom = Color(0xFF010507);
  static const sessionTeal = Color(0xFF2ACCB8);
  static const cardBorder = ReferenceColors.border;
}

/// Illustration rectangles from the byte-intact reference PNGs.
abstract final class RoleplayArt {
  static const hero = ArtRegion(
    'roleplay-library',
    Rect.fromLTWH(540, 470, 450, 332),
  );
  static const topics = <String, ArtRegion>{
    'daily': ArtRegion('roleplay-library', Rect.fromLTWH(100, 1120, 440, 420)),
    'travel': ArtRegion('roleplay-library', Rect.fromLTWH(630, 1120, 460, 420)),
    'food': ArtRegion('roleplay-library', Rect.fromLTWH(95, 1675, 440, 410)),
    'hobbies': ArtRegion(
      'roleplay-library',
      Rect.fromLTWH(630, 1650, 470, 435),
    ),
    'work': ArtRegion(
      'roleplay-library-more',
      Rect.fromLTWH(95, 1205, 460, 410),
    ),
    'around': ArtRegion(
      'roleplay-library-more',
      Rect.fromLTWH(630, 1190, 470, 425),
    ),
    'friends': ArtRegion(
      'roleplay-library-more',
      Rect.fromLTWH(90, 1745, 460, 405),
    ),
    'yourself': ArtRegion(
      'roleplay-library-more',
      Rect.fromLTWH(640, 1745, 445, 405),
    ),
  };
  static const maxLogo = ArtRegion(
    'roleplay-max-intro',
    Rect.fromLTWH(100, 390, 980, 320),
  );
  static const maxCharacter = ArtRegion(
    'roleplay-max-intro',
    Rect.fromLTWH(230, 1260, 720, 362),
  );
  static const station = ArtRegion(
    'roleplay-station',
    Rect.fromLTWH(0, 700, 1180, 1060),
  );
  static const restaurant = ArtRegion(
    'roleplay-scene',
    Rect.fromLTWH(0, 1005, 1180, 1170),
  );
  static const resultRing = ArtRegion(
    'roleplay-results',
    Rect.fromLTWH(330, 570, 520, 490),
  );
  static const wordsIcon = ArtRegion(
    'roleplay-results',
    Rect.fromLTWH(835, 1380, 100, 95),
  );
  static const xpIcon = ArtRegion(
    'roleplay-results',
    Rect.fromLTWH(850, 1665, 85, 100),
  );
  static const lilyAvatar = ArtRegion(
    'roleplay-feedback',
    Rect.fromLTWH(45, 1425, 135, 140),
  );
  static const stationCloseUp = ArtRegion(
    'roleplay-station',
    Rect.fromLTWH(291, 727, 623, 885),
  );
  static const restaurantCloseUp = ArtRegion(
    'roleplay-scene',
    Rect.fromLTWH(291, 727, 623, 885),
  );
  static ArtRegion closeUp(RoleplayScene scene) =>
      scene == RoleplayScene.restaurant ? restaurantCloseUp : stationCloseUp;
  static ArtRegion scene(RoleplayScene scene) =>
      scene == RoleplayScene.restaurant ? restaurant : station;
  static const files = [
    'roleplay-library',
    'roleplay-library-more',
    'roleplay-max-intro',
    'roleplay-station',
    'roleplay-scene',
    'roleplay-results',
    'roleplay-feedback',
  ];
}

class RoleplayStars extends StatelessWidget {
  const RoleplayStars({
    required this.stars,
    this.size = 26,
    this.on = RoleplayColors.starOn,
    this.off = RoleplayColors.starOff,
    this.gap = 10,
    super.key,
  });
  final int stars;
  final double size, gap;
  final Color on, off;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$stars of 3 stars',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Icon(Icons.star_rounded, size: size, color: i < stars ? on : off),
        ],
      ],
    ),
  );
}

/// Cyan→green Max button with the Duolingo press-down edge.
class MaxGradientButton extends StatefulWidget {
  const MaxGradientButton({
    required this.label,
    required this.onPressed,
    super.key,
  });
  final String label;
  final VoidCallback onPressed;
  @override
  State<MaxGradientButton> createState() => _MaxGradientButtonState();
}

class _MaxGradientButtonState extends State<MaxGradientButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 100);
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedPadding(
          duration: duration,
          padding: EdgeInsets.only(
            top: _pressed ? 4 : 0,
            bottom: _pressed ? 0 : 4,
          ),
          child: AnimatedContainer(
            duration: duration,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [RoleplayColors.maxCyan, RoleplayColors.maxGreen],
              ),
              boxShadow: _pressed
                  ? null
                  : const [
                      BoxShadow(
                        color: RoleplayColors.maxEdge,
                        offset: Offset(0, 4),
                      ),
                    ],
            ),
            child: Text(
              widget.label,
              style: const TextStyle(
                color: RoleplayColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// White, rounded card used for the scenario intro and "Well done!" cards.
class RoleplaySheetCard extends StatelessWidget {
  const RoleplaySheetCard({
    required this.title,
    required this.body,
    required this.onContinue,
    super.key,
  });
  final String title, body;
  final VoidCallback onContinue;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 1, end: 0),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 320),
    curve: Curves.easeOutCubic,
    builder: (context, t, child) =>
        Transform.translate(offset: Offset(0, 120 * t), child: child),
    child: Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RoleplayColors.cardBorder, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ReferenceColors.ink,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ReferenceColors.ink,
              fontSize: 18,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 16),
          ReferenceButton(
            label: 'CONTINUE',
            backgroundColor: const Color(0xFF1CB0F6),
            edgeColor: const Color(0xFF1899D6),
            onPressed: onContinue,
          ),
        ],
      ),
    ),
  );
}

/// Word suggestions above the reply field (gloss on top, phrase below).
class RoleplayHintRow extends StatelessWidget {
  const RoleplayHintRow({required this.hints, required this.onPick, super.key});
  final List<RoleplayHint> hints;
  final ValueChanged<String> onPick;
  @override
  Widget build(BuildContext context) => SizedBox(
    height:
        10 +
        MediaQuery.textScalerOf(context).scale(11) * 1.3 +
        MediaQuery.textScalerOf(context).scale(16) * 1.3,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: hints.length,
      separatorBuilder: (_, _) => const VerticalDivider(
        width: 20,
        indent: 8,
        endIndent: 8,
        color: ReferenceColors.border,
      ),
      itemBuilder: (context, i) => InkWell(
        onTap: () => onPick(hints[i].phrase),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              hints[i].gloss,
              style: const TextStyle(
                fontSize: 11,
                color: ReferenceColors.muted,
              ),
            ),
            Text(
              hints[i].phrase,
              style: const TextStyle(fontSize: 16, color: ReferenceColors.ink),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Native "MAX" badge (black, cyan outline, italic white wordmark).
class MaxBadge extends StatelessWidget {
  const MaxBadge({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: Colors.black,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: RoleplayColors.maxCyan, width: 2),
    ),
    child: const Text(
      'MAX',
      style: TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        letterSpacing: 1.5,
        height: 1.15,
      ),
    ),
  );
}
