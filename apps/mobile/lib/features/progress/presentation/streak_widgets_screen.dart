import 'package:flutter/material.dart';

import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/application/learning_controller.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/streak_widgets_controller.dart';
import '../domain/streak_widget.dart';

class StreakWidgetsScreen extends ConsumerWidget {
  const StreakWidgetsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(streakWidgetsProvider);
    final style = streakWidgetStyles.singleWhere(
      (style) => style.mood == selected,
    );
    final streak = ref.watch(
      learningStateProvider.select((state) => state.streak),
    );
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Streak widgets'),
        backgroundColor: Colors.white,
        foregroundColor: ReferenceColors.ink,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StreakWidgetCard(
            key: ValueKey('widget-medium-${selected.name}'),
            style: style,
            streak: streak,
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 162,
              child: StreakWidgetCard(
                key: ValueKey('widget-small-${selected.name}'),
                style: style,
                streak: streak,
                small: true,
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text('CHOOSE A LOOK', style: sectionStyle),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in streakWidgetStyles)
                Semantics(
                  button: true,
                  selected: option.mood == selected,
                  label: option.title,
                  onTap: () => ref
                      .read(streakWidgetsProvider.notifier)
                      .select(option.mood),
                  excludeSemantics: true,
                  child: ChoiceChip(
                    label: Text(option.title),
                    selected: option.mood == selected,
                    onSelected: (_) => ref
                        .read(streakWidgetsProvider.notifier)
                        .select(option.mood),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),
          ReferenceButton(
            label: 'HOW TO ADD A WIDGET',
            outlined: true,
            foregroundColor: LearningColors.blue,
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: Colors.white,
              builder: (_) => const _WidgetInstructions(),
            ),
          ),
        ],
      ),
    );
  }
}

class StreakWidgetCard extends StatelessWidget {
  const StreakWidgetCard({
    required this.style,
    required this.streak,
    this.small = false,
    super.key,
  });
  final StreakWidgetStyle style;
  final int streak;
  final bool small;
  @override
  Widget build(BuildContext context) {
    final region = small ? style.smallArt : style.mediumArt;
    final scaled = MediaQuery.textScalerOf(context).scale(20) > 28;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label:
          '${small ? 'Small' : 'Medium'} widget, $streak day streak, ${small ? style.smallTitle : style.title}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(style.startColor), Color(style.endColor)],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final artWidth = small
                  ? c.maxWidth
                  : math.min(c.maxWidth * .38, 95 * region.$3 / region.$4);
              final artHeight = artWidth * region.$4 / region.$3;
              final art = ExcludeSemantics(
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.white, Colors.white],
                    stops: [0, .12, 1],
                  ).createShader(bounds),
                  child: ReferenceArt(
                    ArtRegion(
                      style.asset,
                      Rect.fromLTWH(region.$1, region.$2, region.$3, region.$4),
                    ),
                    width: artWidth,
                    height: artHeight,
                  ),
                ),
              );
              if (scaled) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (style.mood != StreakWidgetMood.ready)
                            Text(
                              '$streak days',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          Text(
                            small ? style.smallTitle : style.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Align(alignment: Alignment.bottomRight, child: art),
                  ],
                );
              }
              final labelStyle = DefaultTextStyle.of(context).style.copyWith(
                fontSize: style.mood == StreakWidgetMood.ready ? 21 : 17,
                fontWeight: style.mood == StreakWidgetMood.ready
                    ? FontWeight.w700
                    : FontWeight.w400,
              );
              final label = TextPainter(
                text: TextSpan(
                  text: small ? style.smallTitle : style.title,
                  style: labelStyle,
                ),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout(maxWidth: small ? c.maxWidth - 36 : c.maxWidth * .55);
              final labelHeight = label.height;
              label.dispose();
              final hasCount = style.mood != StreakWidgetMood.ready;
              final counter =
                  TextPainter(
                    text: TextSpan(
                      text: small ? '$streak' : '$streak days',
                      style: DefaultTextStyle.of(context).style
                          .copyWith(fontSize: 26, fontWeight: FontWeight.w700),
                    ),
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout(
                    maxWidth: (small ? c.maxWidth - 36 : c.maxWidth * .55) - 28,
                  );
              final counterHeight = math.max(24, counter.height);
              counter.dispose();
              final hasWeekdays = widgetWeekdays[style.mood]!.isNotEmpty;
              final contentHeight =
                  labelHeight +
                  (hasCount ? counterHeight : 0) +
                  36 +
                  (small
                      ? artHeight
                      : hasWeekdays
                      ? 52
                      : 0);
              return SizedBox(
                width: c.maxWidth,
                height: math.max(small ? 162 : 164, contentHeight),
                child: Stack(
                  children: [
                    Positioned(right: 0, bottom: 0, child: art),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: SizedBox(
                        width: small ? null : c.maxWidth * .55,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (style.mood != StreakWidgetMood.ready)
                              Row(
                                children: [
                                  const Icon(
                                    Icons.local_fire_department,
                                    color: Color(0xFFFFD25A),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      small ? '$streak' : '$streak days',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            Text(
                              small ? style.smallTitle : style.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: style.mood == StreakWidgetMood.ready
                                    ? 21
                                    : 17,
                                fontWeight: style.mood == StreakWidgetMood.ready
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                            if (!small && !scaled && hasWeekdays) ...[
                              const SizedBox(height: 12),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final (day, checked)
                                      in widgetWeekdays[style.mood]!)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: Column(
                                        children: [
                                          Text(
                                            day,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          SizedBox.square(
                                            dimension: 16,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: checked
                                                    ? Colors.white
                                                    : Colors.white30,
                                                shape: BoxShape.circle,
                                              ),
                                              child: checked
                                                  ? Icon(
                                                      Icons.check,
                                                      size: 12,
                                                      color: Color(
                                                        style.startColor,
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WidgetInstructions extends StatefulWidget {
  const _WidgetInstructions();
  @override
  State<_WidgetInstructions> createState() => _WidgetInstructionsState();
}

class _WidgetInstructionsState extends State<_WidgetInstructions> {
  bool _android = false;
  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .9,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Add a widget',
            style: headingStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            children: [
              ChoiceChip(
                label: const Text('iPhone'),
                selected: !_android,
                onSelected: (_) => setState(() => _android = false),
              ),
              ChoiceChip(
                label: const Text('Android'),
                selected: _android,
                onSelected: (_) => setState(() => _android = true),
              ),
            ],
          ),
          const SizedBox(height: 24),
          for (final (index, text)
              in (_android
                      ? [
                          'Touch and hold an empty space on your home screen.',
                          'Tap Widgets to see the available apps.',
                          'Touch and hold the widget, then place it on your home screen.',
                        ]
                      : [
                          'Touch and hold your home screen until the apps jiggle.',
                          'Tap Edit, then Add Widget.',
                          'Choose an available widget, select a size, and tap Add Widget.',
                        ])
                  .indexed) ...[
            Text(
              '${index + 1}. $text',
              style: const TextStyle(fontSize: 19, height: 1.4),
            ),
            const SizedBox(height: 18),
          ],
          ReferenceButton(
            label: 'DONE',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}
