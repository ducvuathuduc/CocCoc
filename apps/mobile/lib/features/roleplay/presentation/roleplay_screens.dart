import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../practice/application/journey_controller.dart';
import '../application/roleplay_controller.dart';
import '../domain/roleplay_models.dart';
import 'roleplay_widgets.dart';

void _back(BuildContext context, String fallback) =>
    context.canPop() ? context.pop() : context.go(fallback);

const _heroGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    RoleplayColors.heroTop,
    RoleplayColors.heroMid,
    RoleplayColors.heroBottom,
  ],
  stops: [0, .5, 1],
);

String _cta(RoleplayProgress p) =>
    p.completed ? 'REVIEW +40 XP' : 'START +40 XP';

class _HeroButton extends StatelessWidget {
  const _HeroButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => ReferenceButton(
    label: label,
    backgroundColor: Colors.white,
    edgeColor: RoleplayColors.buttonEdge,
    foregroundColor: RoleplayColors.ink,
    minHeight: 46,
    textStyle: const TextStyle(fontSize: 17, letterSpacing: 1),
    onPressed: onPressed,
  );
}

class _BackArrow extends StatelessWidget {
  const _BackArrow({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Back',
    onPressed: onTap,
    icon: const ReferenceBackIcon(),
  );
}

/// Roleplay library: featured scenario hero + topic grid (refs6/Roleplay).
class RoleplayLibraryScreen extends ConsumerStatefulWidget {
  const RoleplayLibraryScreen({super.key});
  @override
  ConsumerState<RoleplayLibraryScreen> createState() => _LibraryState();
}

class _LibraryState extends ConsumerState<RoleplayLibraryScreen> {
  bool collapsed = false;
  void _start(RoleplayScenario s) =>
      context.push('/roleplay/scenarios/${s.id}');
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roleplayLibraryControllerProvider);
    final vm = ref.read(roleplayLibraryControllerProvider.notifier);
    final featured = vm.featured;
    final progress = state.progressOf(featured.id);
    final topics = vm.topics;
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.white,
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.axis == Axis.vertical) {
            final next = n.metrics.pixels > 200;
            if (next != collapsed) setState(() => collapsed = next);
          }
          return false;
        },
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(gradient: _heroGradient),
                    padding: EdgeInsets.fromLTRB(16, top + 6, 16, 18),
                    child: Stack(
                      children: [
                        const Positioned(
                          right: 47,
                          top: 95,
                          child: ReferenceArt(
                            RoleplayArt.hero,
                            width: 150,
                            height: 111,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Transform.translate(
                              offset: const Offset(-12, 0),
                              child: _BackArrow(
                                onTap: () => _back(context, '/practice'),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: RoleplayColors.tagFill,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                progress.completed
                                    ? 'TIME TO REVIEW'
                                    : 'NEW FOR YOU',
                                style: const TextStyle(
                                  color: RoleplayColors.tagText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: .9,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: 190,
                              child: Text(
                                featured.title,
                                key: const ValueKey('roleplay-featured'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w700,
                                  height: 1.45,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            RoleplayStars(
                              stars: progress.stars,
                              size: 31,
                              gap: 3,
                            ),
                            const SizedBox(height: 14),
                            _HeroButton(
                              label: _cta(progress),
                              onPressed: () => _start(featured),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(28, 36, 28, 40),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 32,
                      mainAxisExtent:
                          148 +
                          MediaQuery.textScalerOf(context).scale(16) * 1.3,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      childCount: topics.length,
                      (context, i) => _TopicTile(topic: topics[i]),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: IgnorePointer(
                ignoring: !collapsed,
                child: AnimatedOpacity(
                  opacity: collapsed ? 1 : 0,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 160),
                  child: Container(
                    decoration: const BoxDecoration(gradient: _heroGradient),
                    padding: EdgeInsets.fromLTRB(16, top + 6, 16, 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Transform.translate(
                              offset: const Offset(-12, 0),
                              child: _BackArrow(
                                onTap: () => _back(context, '/practice'),
                              ),
                            ),
                            const Expanded(
                              child: Text(
                                'Roleplays',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 36),
                          ],
                        ),
                        _HeroButton(
                          label: _cta(progress),
                          onPressed: () => _start(featured),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicTile extends ConsumerWidget {
  const _TopicTile({required this.topic});
  final RoleplayTopic topic;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(roleplayLibraryControllerProvider);
    final (done, total) = ref
        .read(roleplayLibraryControllerProvider.notifier)
        .topicProgress(topic.id);
    return Semantics(
      button: true,
      label: '${topic.title}, $done of $total complete',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => context.push('/roleplay/topics/${topic.id}'),
        child: Column(
          children: [
            ReferenceArt(
              RoleplayArt.topics[topic.id] ?? RoleplayArt.topics['daily']!,
              width: 146,
              height: 139,
            ),
            const SizedBox(height: 6),
            Text(
              topic.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ReferenceColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scenario list for one topic, with per-scenario stars and completion.
class RoleplayTopicScreen extends ConsumerWidget {
  const RoleplayTopicScreen({required this.topicId, super.key});
  final String topicId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(roleplayLibraryControllerProvider);
    final vm = ref.read(roleplayLibraryControllerProvider.notifier);
    final topic = vm.topics.firstWhere(
      (t) => t.id == topicId,
      orElse: () => vm.topics.first,
    );
    final scenarios = vm.scenariosFor(topic.id);
    final (done, total) = vm.topicProgress(topic.id);
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            decoration: const BoxDecoration(gradient: _heroGradient),
            padding: EdgeInsets.fromLTRB(16, top + 6, 16, 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Transform.translate(
                        offset: const Offset(-12, 0),
                        child: _BackArrow(
                          onTap: () => _back(context, '/roleplay'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        topic.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$done of $total roleplays complete',
                        style: const TextStyle(
                          color: RoleplayColors.tagText,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: total == 0 ? 0 : done / total,
                          minHeight: 10,
                          color: RoleplayColors.starOn,
                          backgroundColor: RoleplayColors.starOff,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ReferenceArt(
                  RoleplayArt.topics[topic.id] ?? RoleplayArt.topics['daily']!,
                  width: 112,
                  height: 107,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (final s in scenarios)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: _ScenarioCard(
                scenario: s,
                progress: state.progressOf(s.id),
                onTap: () {
                  vm.feature(s.id);
                  context.push('/roleplay/scenarios/${s.id}');
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.scenario,
    required this.progress,
    required this.onTap,
  });
  final RoleplayScenario scenario;
  final RoleplayProgress progress;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ReferenceColors.border, width: 2),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                scenario.title,
                style: const TextStyle(
                  color: ReferenceColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            RoleplayStars(
              stars: progress.stars,
              size: 20,
              gap: 2,
              off: ReferenceColors.border,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          progress.completed
              ? 'Completed · best ${progress.bestWords} words'
              : 'New',
          style: TextStyle(
            color: progress.completed
                ? const Color(0xFF9B5DE0)
                : ReferenceColors.muted,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ReferenceButton(
          label: _cta(progress),
          backgroundColor: const Color(0xFF9B5DE0),
          edgeColor: const Color(0xFF6E3DB5),
          minHeight: 40,
          onPressed: onTap,
        ),
      ],
    ),
  );
}

/// Max intro before a scenario ("Use more words to earn up to 40 XP…").
class RoleplayMaxIntroScreen extends ConsumerWidget {
  const RoleplayMaxIntroScreen({required this.scenarioId, super.key});
  final String scenarioId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const cyan = TextStyle(
      color: RoleplayColors.maxCyan,
      fontWeight: FontWeight.w700,
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => _back(context, '/roleplay'),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const ReferenceArt(RoleplayArt.maxLogo, width: 327, height: 107),
            const SizedBox(height: 70),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 62),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: RoleplayColors.maxBubble, width: 2),
              ),
              child: const Text.rich(
                TextSpan(
                  text: 'Use more words to earn ',
                  children: [
                    TextSpan(text: 'up to 40 XP', style: cyan),
                    TextSpan(text: ' and 3 stars!'),
                  ],
                ),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.35,
                ),
              ),
            ),
            const CustomPaint(size: Size(20, 12), painter: _TailPainter()),
            const SizedBox(height: 4),
            const ReferenceArt(
              RoleplayArt.maxCharacter,
              width: 240,
              height: 121,
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 18),
              child: MaxGradientButton(
                label: 'CONTINUE',
                onPressed: () {
                  final vm = ref.read(
                    journeyControllerProvider('roleplay').notifier,
                  );
                  if (!vm.pickScenario(scenarioId)) return;
                  vm.start();
                  context.pushReplacement('/journeys/roleplay/session');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dark Max results: stars, WORDS USED, XP EARNED (refs Completing/17).
class RoleplayResultsScreen extends ConsumerWidget {
  const RoleplayResultsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(roleplayLibraryControllerProvider).lastResult;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: RoleplayColors.maxBlack,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            const ReferenceArt(RoleplayArt.resultRing, width: 173, height: 163),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  Transform.translate(
                    offset: Offset(0, i == 1 ? 10 : 0),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: reduce ? 1 : 0, end: 1),
                      duration: reduce
                          ? Duration.zero
                          : Duration(milliseconds: 420 + 160 * i),
                      curve: Curves.elasticOut,
                      builder: (context, t, child) =>
                          Transform.scale(scale: t, child: child),
                      child: Icon(
                        Icons.star_rounded,
                        size: 46,
                        color: i < (result?.stars ?? 0)
                            ? RoleplayColors.maxTeal
                            : const Color(0xFF4A4A4C),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 34),
            _StatRow(
              label: 'WORDS USED',
              icon: RoleplayArt.wordsIcon,
              value: '${result?.wordsUsed ?? 0}',
              badge: result?.newRecord == true ? 'NEW RECORD' : null,
            ),
            const SizedBox(height: 40),
            _StatRow(
              label: 'XP EARNED',
              icon: RoleplayArt.xpIcon,
              value: '${result?.xp ?? 0}',
            ),
            const Spacer(flex: 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 18),
              child: MaxGradientButton(
                label: 'CONTINUE',
                onPressed: () => context.go('/roleplay'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.icon,
    required this.value,
    this.badge,
  });
  final String label, value;
  final ArtRegion icon;
  final String? badge;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [RoleplayColors.statTop, RoleplayColors.statBottom],
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .8,
                  ),
                ),
              ),
              ReferenceArt(icon, width: 30, height: 30),
              const SizedBox(width: 8),
              SizedBox(
                width: 36,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (badge != null)
          Positioned(
            right: 0,
            top: -12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              decoration: BoxDecoration(
                color: RoleplayColors.maxCyan,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: RoleplayColors.statTop, width: 2),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: RoleplayColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _TailPainter extends CustomPainter {
  const _TailPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, -2)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, -2);
    canvas.drawPath(path, Paint()..color = Colors.black);
    canvas.drawPath(
      path,
      Paint()
        ..color = RoleplayColors.maxBubble
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
