import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/adventure_controller.dart';

const _airportScenes = [
  ArtRegion('adventure-intro', Rect.fromLTWH(0, 365, 1180, 1570)),
  ArtRegion('adventure-explore', Rect.fromLTWH(0, 365, 1180, 2000)),
  ArtRegion('adventure-identify', Rect.fromLTWH(0, 365, 1180, 1620)),
  ArtRegion('adventure-collected', Rect.fromLTWH(0, 365, 1180, 2000)),
  ArtRegion('adventure-return', Rect.fromLTWH(0, 365, 1180, 1000)),
  ArtRegion('adventure-return', Rect.fromLTWH(0, 365, 1180, 1000)),
];
const _objects = {
  'sandwich': ArtRegion(
    'adventure-objects',
    Rect.fromLTWH(175, 1495, 325, 350),
  ),
  'phone': ArtRegion('adventure-objects', Rect.fromLTWH(725, 1495, 260, 350)),
  'pizza': ArtRegion('adventure-objects', Rect.fromLTWH(180, 2045, 330, 305)),
  'passport': ArtRegion(
    'adventure-objects',
    Rect.fromLTWH(750, 2045, 205, 300),
  ),
};

class AdventureScreen extends ConsumerWidget {
  const AdventureScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adventureControllerProvider);
    final vm = ref.read(adventureControllerProvider.notifier);
    if (state.complete) return _AdventureComplete(state: state);
    return Scaffold(
      backgroundColor: const Color(0xFFB5E1F2),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
              child: Row(
                children: [
                  _RoundControl(
                    label: 'Close adventure',
                    icon: Icons.close_rounded,
                    onPressed: () => _pause(context),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.favorite_rounded,
                    size: 36,
                    color: LearningColors.purple,
                  ),
                  const Text(
                    '∞',
                    style: TextStyle(
                      fontSize: 30,
                      color: LearningColors.purple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  fit: StackFit.expand,
                  children: [
                    ReferenceArt(
                      _airportScenes[state.stage],
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                    ),
                    if (state.stage == 1 || state.stage == 4)
                      Align(
                        alignment: state.stage == 1
                            ? const Alignment(.57, .1)
                            : const Alignment(-.25, .1),
                        child: _RoundControl(
                          label: state.stage == 1
                              ? 'Pick up the passport'
                              : 'Return the passport to Lucy',
                          icon: state.stage == 1
                              ? Icons.priority_high_rounded
                              : Icons.chat_bubble_outline_rounded,
                          onPressed: vm.explore,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (state.stage != 1 && state.stage != 4)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .53,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: ReferenceColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: ReferenceColors.border,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        if (state.stage == 0) ...[
                          const Text(
                            'Help Oscar return a\nlost passport',
                            textAlign: TextAlign.center,
                            style: headingStyle,
                          ),
                          const SizedBox(height: 20),
                          _BlueButton('START', vm.start),
                        ] else if (state.stage == 3) ...[
                          const Text(
                            'You found the passport!',
                            textAlign: TextAlign.center,
                            style: headingStyle,
                          ),
                          const SizedBox(height: 20),
                          _BlueButton('CONTINUE', vm.next),
                        ] else ...[
                          if (state.stage == 5) ...[
                            const Text('LUCY', style: sectionStyle),
                            const Text(
                              'Ah, my passport!',
                              textAlign: TextAlign.center,
                              style: headingStyle,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final option in vm.options)
                                  SizedBox(
                                    width:
                                        (MediaQuery.sizeOf(context).width -
                                            96) /
                                        2,
                                    child: Semantics(
                                      label: option,
                                      child: LearningCard(
                                        padding: const EdgeInsets.all(12),
                                        selected: state.selected == option,
                                        correct: state.selected == option
                                            ? state.feedback
                                            : null,
                                        onTap: state.feedback == null
                                            ? () => vm.select(option)
                                            : null,
                                        child: ReferenceArt(
                                          _objects[option]!,
                                          width: 100,
                                          height: 115,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ] else
                            for (final option in vm.options) ...[
                              LearningCard(
                                selected: state.selected == option,
                                correct: state.selected == option
                                    ? state.feedback
                                    : null,
                                onTap: state.feedback == null
                                    ? () => vm.select(option)
                                    : null,
                                child: Center(
                                  child: Text(
                                    option,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          if (state.feedback != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              state.feedback! ? 'Great job!' : 'Try again',
                              style: headingStyle,
                            ),
                          ],
                          const SizedBox(height: 12),
                          _BlueButton(
                            state.feedback == null ? 'CHECK' : 'CONTINUE',
                            state.feedback != null
                                ? vm.next
                                : state.selected == null
                                ? null
                                : vm.check,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            if (state.stage == 1 || state.stage == 4)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  state.stage == 1
                      ? 'Tap the passport.'
                      : 'Tap Lucy to return the passport.',
                  textAlign: TextAlign.center,
                  style: headingStyle.copyWith(fontSize: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> _pause(BuildContext context) => learningSheet<void>(
  context,
  title: 'End adventure?',
  child: Column(
    children: [
      const Text(
        'Your place is saved so you can continue later.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 18),
      _BlueButton('KEEP LEARNING', () => context.pop()),
      TextButton(
        onPressed: () {
          context.pop();
          context.go('/practice');
        },
        child: const Text('END ADVENTURE'),
      ),
    ],
  ),
);

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Material(
    color: ReferenceColors.surface,
    shape: const CircleBorder(
      side: BorderSide(color: ReferenceColors.border, width: 2),
    ),
    child: IconButton(
      tooltip: label,
      iconSize: 32,
      onPressed: onPressed,
      icon: Icon(icon, color: ReferenceColors.ink),
    ),
  );
}

class _BlueButton extends StatelessWidget {
  const _BlueButton(this.label, this.onPressed);
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => ReferenceButton(
    label: label,
    backgroundColor: LearningColors.blue,
    edgeColor: LearningColors.blueDark,
    onPressed: onPressed,
  );
}

class _AdventureComplete extends ConsumerWidget {
  const _AdventureComplete({required this.state});
  final AdventureState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  const SizedBox(height: 65),
                  const ReferenceArt(
                    ArtRegion(
                      'adventure-complete',
                      Rect.fromLTWH(220, 610, 735, 610),
                    ),
                    width: 300,
                    height: 280,
                  ),
                  const SizedBox(height: 35),
                  Text(
                    'Adventure complete!',
                    textAlign: TextAlign.center,
                    style: headingStyle.copyWith(
                      fontSize: 29,
                      color: LearningColors.yellow,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      for (final stat in [
                        ('TOTAL XP', '20', LearningColors.yellow),
                        (
                          'ACCURACY',
                          '${state.accuracy}%',
                          LearningColors.green,
                        ),
                      ]) ...[
                        Expanded(
                          child: LearningCard(
                            child: Column(
                              children: [
                                Text(stat.$1, style: sectionStyle),
                                const SizedBox(height: 12),
                                Text(
                                  stat.$2,
                                  style: headingStyle.copyWith(color: stat.$3),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
            child: _BlueButton('CLAIM XP', () {
              ref.read(adventureControllerProvider.notifier).claim();
              context.go('/practice');
            }),
          ),
        ],
      ),
    ),
  );
}
