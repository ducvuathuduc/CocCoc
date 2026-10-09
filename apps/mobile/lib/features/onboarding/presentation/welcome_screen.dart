import 'package:flutter/material.dart';

import '../../../core/design/duo_illustration.dart';
import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    required this.onStart,
    required this.onLogin,
    super.key,
  });
  final VoidCallback onStart;
  final VoidCallback onLogin;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 11, 16, 29),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const DuoIllustration(
                          ReferenceArtRegions.welcomeDuo,
                          width: 123,
                          height: 121,
                        ),
                        const SizedBox(height: 28),
                        const DuoIllustration(
                          ReferenceArtRegions.wordmark,
                          width: 185,
                          height: 45,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Learn for free. Forever.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            color: ReferenceColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                ReferenceButton(label: 'GET STARTED', onPressed: onStart),
                const SizedBox(height: 14),
                ReferenceButton(
                  label: 'I ALREADY HAVE AN ACCOUNT',
                  outlined: true,
                  onPressed: onLogin,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
