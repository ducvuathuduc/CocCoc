import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/duo_illustration.dart';
import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../application/onboarding_controller.dart';
import 'widgets/onboarding_motion.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({
    required this.onStart,
    required this.onLogin,
    super.key,
  });
  final VoidCallback onStart;
  final VoidCallback onLogin;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(onboardingContentProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 11, 16, 29),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const PopIn(
                            duration: OnboardingMotion.mascot,
                            alignment: Alignment.bottomCenter,
                            child: DuoIllustration(
                              ReferenceArtRegions.welcomeDuo,
                              width: 123,
                              height: 121,
                            ),
                          ),
                          const SizedBox(height: 28),
                          const DuoIllustration(
                            ReferenceArtRegions.wordmark,
                            width: 185,
                            height: 45,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            copy.welcomeTagline,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
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
                  ReferenceButton(
                    label: copy.getStartedLabel,
                    onPressed: onStart,
                  ),
                  const SizedBox(height: 14),
                  ReferenceButton(
                    label: copy.haveAccountLabel,
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
}
