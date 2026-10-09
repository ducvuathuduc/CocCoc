import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../domain/course_catalog.dart';
import 'learning_visuals.dart';
import 'course_unavailable_screen.dart';

class UnitGuideScreen extends StatelessWidget {
  const UnitGuideScreen({this.target = const CourseTarget(1, 1), super.key});
  final CourseTarget? target;
  @override
  Widget build(BuildContext context) {
    final selected = target;
    if (selected == null || !selected.valid) {
      return const CourseUnavailableScreen();
    }
    final guide = unitGuide(selected);
    final title = 'SECTION ${selected.section}, UNIT ${selected.unit}';
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _GuideHeader(
                title: title,
                extent:
                    66 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 30),
                  const Center(
                    child: ReferenceArt(
                      ArtRegion(
                        'guide-header-source',
                        Rect.fromLTWH(430, 378, 320, 469),
                      ),
                      width: 125,
                      height: 183.2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: sectionStyle,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      guide.title,
                      textAlign: TextAlign.center,
                      style: headingStyle.copyWith(fontSize: 28),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Divider(thickness: 2, height: 2),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 28, 16, 16),
                    child: Text(
                      'KEY PHRASES',
                      style: TextStyle(
                        color: LearningColors.blue,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: Text(
                      guide.title,
                      style: headingStyle.copyWith(fontSize: 26),
                    ),
                  ),
                  for (final phrase in guide.phrases)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                      child: GuidePhraseBubble(phrase: phrase),
                    ),
                  const SizedBox(height: 14),
                  Container(
                    color: ReferenceColors.blueFill,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'TIP',
                          style: TextStyle(
                            color: LearningColors.blue,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          guide.tipTitle,
                          style: headingStyle.copyWith(fontSize: 27),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          guide.tip,
                          style: const TextStyle(fontSize: 20, height: 1.5),
                        ),
                        const SizedBox(height: 20),
                        GuidePhraseBubble(phrase: guide.phrases.first),
                        const SizedBox(height: 24),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth.clamp(
                              0.0,
                              300.0,
                            );
                            return Center(
                              child: ReferenceArt(
                                const ArtRegion(
                                  'guide-tips-source',
                                  Rect.fromLTWH(55, 1457, 1076, 612),
                                ),
                                width: width,
                                height: width * 612 / 1076,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GuidePhraseBubble extends StatelessWidget {
  const GuidePhraseBubble({
    required this.phrase,
    this.showTranslation = true,
    super.key,
  });
  final GuidePhrase phrase;
  final bool showTranslation;
  @override
  Widget build(BuildContext context) => SpeechBubble(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          tooltip: 'Listen to ${phrase.english}',
          onPressed: () => showLearningNotice(
            context,
            'Audio unavailable',
            'Audio isn’t available right now. You can still review the phrase below.',
          ),
          icon: const Icon(
            Icons.volume_up_rounded,
            color: LearningColors.blue,
            size: 28,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => showLearningNotice(
                  context,
                  phrase.english,
                  phrase.vietnamese,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Text(
                    phrase.english,
                    style: const TextStyle(
                      fontSize: 20,
                      height: 1.25,
                      decoration: TextDecoration.underline,
                      decorationStyle: TextDecorationStyle.dotted,
                      decorationColor: ReferenceColors.disabled,
                    ),
                  ),
                ),
              ),
              if (showTranslation)
                Text(
                  phrase.vietnamese,
                  style: const TextStyle(
                    fontSize: 18,
                    color: ReferenceColors.disabled,
                    height: 1.3,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _GuideHeader extends SliverPersistentHeaderDelegate {
  _GuideHeader({required this.title, required this.extent});
  final String title;
  final double extent;
  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox.expand(
    child: Container(
      color: ReferenceColors.surface,
      alignment: Alignment.topCenter,
      child: LearningHeader(
        title: overlapsContent ? title : '',
        onClose: () => context.canPop() ? context.pop() : context.go('/home'),
      ),
    ),
  );
  @override
  bool shouldRebuild(_GuideHeader oldDelegate) =>
      title != oldDelegate.title || extent != oldDelegate.extent;
}
