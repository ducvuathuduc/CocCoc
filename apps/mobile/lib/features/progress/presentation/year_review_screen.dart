import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../application/year_review_controller.dart';
import '../domain/year_review.dart';

const _introArt = ArtRegion(
  'year-review-intro',
  Rect.fromLTWH(0, 310, 1180, 1350),
);
const _lessonsArt = ArtRegion(
  'year-review-lessons',
  Rect.fromLTWH(0, 310, 1180, 690),
);
const _xpArt = ArtRegion('year-review-xp', Rect.fromLTWH(80, 300, 1020, 1080));
const _leagueArt = ArtRegion(
  'year-review-league',
  Rect.fromLTWH(205, 300, 770, 1060),
);
const _gateArt = ArtRegion(
  'year-review-gate',
  Rect.fromLTWH(0, 1190, 1180, 1000),
);
const _studentArt = ArtRegion(
  'year-review-student',
  Rect.fromLTWH(150, 180, 880, 1050),
);
const _summaryArt = ArtRegion(
  'year-review-summary',
  Rect.fromLTWH(120, 840, 940, 560),
);

class YearReviewScreen extends ConsumerStatefulWidget {
  const YearReviewScreen({super.key});

  @override
  ConsumerState<YearReviewScreen> createState() => _YearReviewScreenState();
}

class _YearReviewScreenState extends ConsumerState<YearReviewScreen> {
  late final PageController _pages;

  @override
  void initState() {
    super.initState();
    _pages = PageController(
      initialPage: ref.read(yearReviewControllerProvider).index,
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _moveTo(int index) async {
    ref.read(yearReviewControllerProvider.notifier).setIndex(index);
    final target = ref.read(yearReviewControllerProvider).index;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(target);
      return;
    }
    await _pages.animateToPage(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(yearReviewControllerProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF19559A),
      body: Stack(
        children: [
          PageView(
            controller: _pages,
            scrollDirection: Axis.vertical,
            onPageChanged: ref
                .read(yearReviewControllerProvider.notifier)
                .setIndex,
            children: [
              _IntroPage(onNext: () => _moveTo(1)),
              _LessonsPage(onNext: () => _moveTo(2)),
              _XpPage(onNext: () => _moveTo(3)),
              _LeaguePage(onNext: () => _moveTo(4)),
              _GatePage(onNext: () => _moveTo(5)),
              _StudentPage(onNext: () => _moveTo(6)),
              const _SummaryPage(),
            ],
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Semantics(
                button: true,
                label: 'Close Year in Review',
                onTap: () => Navigator.maybePop(context),
                excludeSemantics: true,
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: IconButton(
                    tooltip: 'Close Year in Review',
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (state.index > 0)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: IconButton(
                    tooltip: 'Previous review page',
                    onPressed: () => _moveTo(state.index - 1),
                    icon: const Icon(
                      Icons.keyboard_arrow_up,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => _ReviewPage(
    colors: const [Color(0xFF16509A), Color(0xFF54CEFA), Colors.white],
    child: Column(
      children: [
        const SizedBox(height: 24),
        const _ReviewArt(
          _introArt,
          aspectRatio: 1180 / 1350,
          fullBleed: true,
          maxHeight: 450,
        ),
        const SizedBox(height: 12),
        const Text(
          'Look back on your year of learning!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF07549A),
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 22),
        _RoundNext(label: 'START', onPressed: onNext),
      ],
    ),
  );
}

class _LessonsPage extends StatelessWidget {
  const _LessonsPage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => _ReviewPage(
    colors: const [Color(0xFF27B4EE), Color(0xFFDDF7FF), Colors.white],
    child: Column(
      children: [
        const SizedBox(height: 24),
        const _ReviewArt(
          _lessonsArt,
          aspectRatio: 1180 / 690,
          fullBleed: true,
          maxHeight: 230,
        ),
        const SizedBox(height: 12),
        const Icon(Icons.menu_book_rounded, color: Color(0xFF20A2CF), size: 54),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'You did '),
              TextSpan(
                text: '${historical2025.lessons} lessons',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: ' in ${historical2025.course}.\n'),
              const TextSpan(text: 'That’s twice the fun!'),
            ],
          ),
          textAlign: TextAlign.center,
          style: _bodyStyle,
        ),
        const SizedBox(height: 24),
        _RoundNext(label: 'NEXT', onPressed: onNext),
      ],
    ),
  );
}

class _XpPage extends StatelessWidget {
  const _XpPage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => _ReviewPage(
    colors: const [Color(0xFFFFCC00), Color(0xFFFFF3BC), Colors.white],
    child: Column(
      children: [
        const SizedBox(height: 24),
        const _ReviewArt(_xpArt, aspectRatio: 1020 / 1080),
        const SizedBox(height: 18),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'You earned '),
              TextSpan(
                text: '${historical2025.totalXp} XP',
                style: const TextStyle(
                  color: Color(0xFFE6A900),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const TextSpan(text: ' in total,\nmore than '),
              TextSpan(
                text: '${historical2025.percentile}%',
                style: const TextStyle(
                  color: Color(0xFFE6A900),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const TextSpan(
                text: ' of learners!\nYou put in the work. It shows.',
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: _bodyStyle,
        ),
        const SizedBox(height: 24),
        _RoundNext(label: 'NEXT', onPressed: onNext),
      ],
    ),
  );
}

class _LeaguePage extends StatelessWidget {
  const _LeaguePage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => _ReviewPage(
    colors: const [Color(0xFFF05ABB), Color(0xFFFFD8F0), Colors.white],
    child: Column(
      children: [
        const SizedBox(height: 24),
        const _ReviewArt(_leagueArt, aspectRatio: 770 / 1060),
        const SizedBox(height: 16),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'You competed in the '),
              TextSpan(
                text: '${historical2025.league} League',
                style: const TextStyle(
                  color: Color(0xFFE747AA),
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(text: '\nfor ${historical2025.leagueWeeks} weeks!'),
            ],
          ),
          textAlign: TextAlign.center,
          style: _bodyStyle,
        ),
        const SizedBox(height: 10),
        const Text('Duo’s so proud, he could cry.', style: _bodyStyle),
        const SizedBox(height: 24),
        _RoundNext(label: 'NEXT', onPressed: onNext),
      ],
    ),
  );
}

class _GatePage extends StatelessWidget {
  const _GatePage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => _ReviewPage(
    colors: const [Color(0xFF174B8E), Color(0xFF2377CE)],
    foreground: Colors.white,
    child: Column(
      children: [
        const SizedBox(height: 24),
        const Text(
          'Ready for the grand finale?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        const Text('Swipe up to see!', style: TextStyle(fontSize: 20)),
        const SizedBox(height: 18),
        const _ReviewArt(_gateArt, aspectRatio: 1180 / 1000, fullBleed: true),
        const SizedBox(height: 24),
        _RoundNext(label: 'NEXT', onPressed: onNext),
      ],
    ),
  );
}

class _StudentPage extends ConsumerWidget {
  const _StudentPage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _ReviewPage(
    colors: const [Color(0xFF29B7F1), Color(0xFF174B8E)],
    foreground: Colors.white,
    child: Column(
      children: [
        const SizedBox(height: 24),
        const _ReviewArt(_studentArt, aspectRatio: 880 / 1050, fullBleed: true),
        const Text('You’re a', style: TextStyle(fontSize: 24)),
        const Text(
          'Stellar Student',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF8FF4E8),
            fontSize: 34,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'You’re in the top ${historical2025.studentTopPercent}% of global learners. Brilliant effort!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, height: 1.35),
        ),
        const SizedBox(height: 24),
        _ShareButton(ref: ref),
        const SizedBox(height: 12),
        _RoundNext(label: 'NEXT', onPressed: onNext),
      ],
    ),
  );
}

class _SummaryPage extends ConsumerWidget {
  const _SummaryPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) => _ReviewPage(
    colors: const [Color(0xFF174B8E), Color(0xFF174B8E)],
    foreground: Colors.white,
    child: Column(
      children: [
        const Text(
          'Share your progress and keep learning next year!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF8DE6F5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 4,
                spacing: 12,
                children: [
                  Text(
                    'cocenglish',
                    style: TextStyle(
                      color: Color(0xFF07549A),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '2025 YEAR IN REVIEW',
                    style: TextStyle(
                      color: Color(0xFF07549A),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const _ReviewArt(_summaryArt, aspectRatio: 940 / 560),
              Text(
                'I’m a top ${historical2025.studentTopPercent}% learner!',
                style: const TextStyle(
                  color: ReferenceColors.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const _SummaryStats(),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text('Your stats as of Nov. 30, 2025'),
        const SizedBox(height: 16),
        _ShareButton(ref: ref),
      ],
    ),
  );
}

class _ReviewPage extends StatelessWidget {
  const _ReviewPage({
    required this.colors,
    required this.child,
    this.foreground = ReferenceColors.ink,
  });

  final List<Color> colors;
  final Widget child;
  final Color foreground;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ),
    ),
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final needsInnerScroll =
              constraints.maxHeight < 640 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3;
          return SingleChildScrollView(
            physics: needsInnerScroll
                ? const ClampingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 64, 20, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(0, constraints.maxHeight - 84),
              ),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: foreground),
                child: child,
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _ReviewArt extends StatelessWidget {
  const _ReviewArt(
    this.region, {
    required this.aspectRatio,
    this.fullBleed = false,
    this.maxHeight,
  });

  final ArtRegion region;
  final double aspectRatio;
  final bool fullBleed;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Duo Year in Review illustration',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = fullBleed
            ? MediaQuery.sizeOf(context).width
            : constraints.maxWidth;
        final naturalHeight = availableWidth / aspectRatio;
        final height = math.min(naturalHeight, maxHeight ?? naturalHeight);
        final width = height * aspectRatio;
        return SizedBox(
          height: height,
          child: OverflowBox(
            alignment: Alignment.center,
            minWidth: width,
            maxWidth: width,
            minHeight: height,
            maxHeight: height,
            child: _FadedReferenceArt(
              region: region,
              width: width,
              height: height,
            ),
          ),
        );
      },
    ),
  );
}

class _FadedReferenceArt extends StatelessWidget {
  const _FadedReferenceArt({
    required this.region,
    required this.width,
    required this.height,
  });

  final ArtRegion region;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (bounds) => const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        Colors.white,
        Colors.white,
        Colors.transparent,
      ],
      stops: [0, .025, .975, 1],
    ).createShader(bounds),
    child: ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        stops: [0, .025, .975, 1],
      ).createShader(bounds),
      child: ReferenceArt(region, width: width, height: height),
    ),
  );
}

class _RoundNext extends StatelessWidget {
  const _RoundNext({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    onTap: onPressed,
    excludeSemantics: true,
    child: Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF20A2CF),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        IconButton.filled(
          onPressed: onPressed,
          iconSize: 30,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF20A2CF),
            foregroundColor: Colors.white,
            minimumSize: const Size(52, 52),
          ),
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
      ],
    ),
  );
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(yearReviewControllerProvider);
    final retry = state.shareError != null;
    return Column(
      children: [
        ReferenceButton(
          label: retry ? 'RETRY SHARE' : 'SHARE FOR A REWARD',
          outlined: true,
          foregroundColor: const Color(0xFF20A2CF),
          leading: state.sharing
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.ios_share_outlined),
          onPressed: state.sharing
              ? null
              : () => ref.read(yearReviewControllerProvider.notifier).share(),
        ),
        if (state.shareError != null) ...[
          const SizedBox(height: 8),
          Text(state.shareError!, style: const TextStyle(color: Colors.white)),
        ],
        if (state.copied) ...[
          const SizedBox(height: 8),
          const Text('Copied', style: TextStyle(color: Colors.white)),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: ReferenceColors.ink,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: ReferenceColors.muted),
        ),
      ],
    ),
  );
}

class _SummaryStats extends StatelessWidget {
  const _SummaryStats();

  @override
  Widget build(BuildContext context) {
    final stats = [
      _Stat('${historical2025.englishScore}', 'English Score'),
      _Stat('${historical2025.longestStreak}', 'longest streak'),
      _Stat('${historical2025.totalXp}', 'total XP'),
      _Stat('${historical2025.minutesSpent}', 'minutes spent'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final oneColumn =
            constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        if (oneColumn) {
          return Column(
            children: [
              for (var index = 0; index < stats.length; index++) ...[
                stats[index],
                if (index != stats.length - 1) const SizedBox(height: 8),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (var index = 0; index < stats.length; index += 2) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: stats[index]),
                  const SizedBox(width: 8),
                  Expanded(child: stats[index + 1]),
                ],
              ),
              if (index + 2 < stats.length) const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

const _bodyStyle = TextStyle(fontSize: 21, height: 1.45);
