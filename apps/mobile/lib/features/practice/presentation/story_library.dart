import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/journey_controller.dart';
import '../data/stories_repository.dart';

const storyCovers = {
  'morning': ArtRegion('stories-library', Rect.fromLTWH(850, 325, 290, 270)),
  'want': ArtRegion('stories-library', Rect.fromLTWH(115, 1040, 395, 430)),
  'jacket': ArtRegion('stories-library', Rect.fromLTWH(655, 1070, 420, 382)),
  'student': ArtRegion('stories-library', Rect.fromLTWH(110, 1595, 410, 390)),
  'art': ArtRegion('stories-library', Rect.fromLTWH(657, 1585, 440, 420)),
  'dog': ArtRegion('stories-scrolled', Rect.fromLTWH(665, 880, 400, 420)),
  'ticket': ArtRegion('stories-scrolled', Rect.fromLTWH(110, 1430, 400, 415)),
  'family': ArtRegion('story-complete', Rect.fromLTWH(348, 755, 520, 605)),
};

class StoryLibraryScreen extends ConsumerWidget {
  const StoryLibraryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(journeyControllerProvider('story').notifier);
    void open(String id) {
      if (vm.pickStory(id)) context.push('/journeys/story');
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            LearningHeader(
              title: 'Stories',
              onClose: () =>
                  context.canPop() ? context.pop() : context.go('/practice'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Good Morning', style: headingStyle),
                              SizedBox(height: 12),
                              Text(
                                'Review words like “coffee” with Eddy',
                                style: TextStyle(fontSize: 20, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ReferenceArt(
                          storyCovers['morning']!,
                          width: 90,
                          height: 90,
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    ReferenceButton(
                      label: 'REVIEW +20 XP',
                      backgroundColor: LearningColors.blue,
                      edgeColor: LearningColors.blueDark,
                      onPressed: () => open('morning'),
                    ),
                    const SizedBox(height: 24),
                    const Divider(thickness: 2),
                    const SizedBox(height: 20),
                    const Text('Your library', style: headingStyle),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) => Wrap(
                        spacing: 16,
                        runSpacing: 25,
                        children: [
                          for (final story in englishStoryLibrary.values.where(
                            (story) => story.id != 'morning',
                          ))
                            SizedBox(
                              width: (constraints.maxWidth - 16) / 2,
                              child: Semantics(
                                button: true,
                                label: story.title,
                                excludeSemantics: true,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () => open(story.id),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    child: Column(
                                      children: [
                                        ReferenceArt(
                                          storyCovers[story.id]!,
                                          width: 145,
                                          height: 155,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          story.title,
                                          textAlign: TextAlign.center,
                                          style: headingStyle.copyWith(
                                            fontSize: 17,
                                          ),
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
                    const SizedBox(height: 25),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
