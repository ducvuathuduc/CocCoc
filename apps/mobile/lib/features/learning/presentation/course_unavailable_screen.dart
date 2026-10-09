import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_widgets.dart';
import 'learning_visuals.dart';

class CourseUnavailableScreen extends StatelessWidget {
  const CourseUnavailableScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            LearningHeader(
              title: 'English',
              onClose: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'This lesson is unavailable.',
                  textAlign: TextAlign.center,
                  style: headingStyle,
                ),
              ),
            ),
            ReferenceButton(
              label: 'BACK TO LEARNING',
              onPressed: () => context.go('/home'),
            ),
          ],
        ),
      ),
    ),
  );
}
