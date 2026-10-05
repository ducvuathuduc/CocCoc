import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import 'learning_visuals.dart';

const _sectionPhrases = [
  'I am learning English.',
  'I know a few words.',
  'I can describe my day.',
  'I can share my opinion.',
];

class SectionsScreen extends StatelessWidget {
  const SectionsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          LearningHeader(
            title: 'English',
            onClose: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                for (var i = 0; i < _sectionPhrases.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: ReferenceColors.border,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          SizedBox(
                            height:
                                173 *
                                MediaQuery.textScalerOf(context)
                                    .scale(1)
                                    .clamp(1, 2),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Container(
                                    color: ReferenceColors.blueFill,
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: ReferenceArt(
                                    const ArtRegion(
                                      'sections-01',
                                      Rect.fromLTWH(800, 918, 330, 340),
                                    ),
                                    width: 113,
                                    height: 117,
                                  ),
                                ),
                                Positioned(
                                  top: 20,
                                  left: 20,
                                  right: 60,
                                  child: SpeechBubble(
                                    child: Text(
                                      _sectionPhrases[i],
                                      style: const TextStyle(fontSize: 21),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Section ${i + 1}',
                                        style: headingStyle.copyWith(
                                          fontSize: 27,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Section ${i + 1} details',
                                      onPressed: () =>
                                          context.push('/sections/${i + 1}'),
                                      icon: const Icon(
                                        Icons.info_outline,
                                        color: LearningColors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (i == 0) ...[
                                  LinearProgressIndicator(
                                    value: .12,
                                    color: LearningColors.green,
                                    backgroundColor: ReferenceColors.border,
                                    minHeight: 16,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  const SizedBox(height: 14),
                                  TextButton(
                                    onPressed: () => context.go('/home'),
                                    child: const Text(
                                      'CONTINUE',
                                      style: TextStyle(
                                        color: LearningColors.green,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ] else
                                  TextButton(
                                    onPressed: () => context.push('/placement'),
                                    child: const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'JUMP HERE',
                                        style: TextStyle(
                                          color: LearningColors.blue,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 17,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class SectionDetailScreen extends StatelessWidget {
  const SectionDetailScreen({required this.section, super.key});
  final int section;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        children: [
          Container(
            color: LearningColors.blue,
            child: Stack(
              children: [
                const Positioned(
                  right: 0,
                  bottom: 0,
                  child: ReferenceArt(
                    ArtRegion('sections-02', Rect.fromLTWH(860, 320, 319, 325)),
                    width: 110,
                    height: 112,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => context.pop(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'Section $section',
                        style: headingStyle.copyWith(
                          color: Colors.white,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const ReferenceArt(
                            LearningArt.english,
                            width: 22,
                            height: 17,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            section <= 2 ? 'CEFR A1' : 'CEFR A2',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'You will start with essential phrases and simple grammar concepts.\n\nHere’s how someone at this level might communicate:',
              style: TextStyle(fontSize: 21, height: 1.4),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(30, 0, 16, 14),
            child: SpeechBubble(
              child: Text(
                'I am from Vietnam. I speak Vietnamese.',
                style: TextStyle(fontSize: 21),
              ),
            ),
          ),
          const ExpansionTile(
            title: Text('All CEFR levels', style: headingStyle),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'A1 and A2: basic communication\nB1 and B2: independent communication\nC1 and C2: proficient communication',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          const Divider(thickness: 2),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Grammar concepts', style: headingStyle),
          ),
          for (final topic in const [
            (
              'Articles',
              'Use a or an for one thing: a cat, an apple. Use the for a specific thing.',
            ),
            ('Verbs', 'I am, you are, she is. Match the verb to the subject.'),
            (
              'Pronouns',
              'I, you, he, she, it, we and they replace names in a sentence.',
            ),
          ])
            ExpansionTile(
              title: Text(topic.$1, style: headingStyle.copyWith(fontSize: 21)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(topic.$2, style: const TextStyle(fontSize: 19)),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ReferenceButton(
              label: section == 1 ? 'CONTINUE' : 'TAKE A LEVEL CHECK',
              onPressed: () => section == 1
                  ? context.go('/home')
                  : context.push('/placement'),
            ),
          ),
        ],
      ),
    ),
  );
}
