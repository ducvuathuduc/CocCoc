import 'package:flutter/material.dart';

import '../../../core/design/duo_illustration.dart';
import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_widgets.dart';

class FlowBoundaryScreen extends StatelessWidget {
  const FlowBoundaryScreen({required this.onBack, super.key});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) onBack();
    },
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            FlowHeader(onBack: onBack),
            const Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DuoIllustration(
                        ReferenceArtRegions.writing,
                        width: 150,
                        height: 142,
                      ),
                      SizedBox(height: 24),
                      Text(
                        'You’re ready for your first lesson!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Your learning preferences are saved. Lessons are coming next.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ReferenceButton(
                label: 'REVIEW MY CHOICES',
                onPressed: onBack,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
