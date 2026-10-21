import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/client/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../application/real_learning_session.dart';

class RealConnectionScreen extends ConsumerWidget {
  const RealConnectionScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(authStartupProvider);
    final prepared = ref.watch(realLearningSessionProvider);
    final error = startup.error ?? prepared.error;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error == null) ...[
                  const CircularProgressIndicator(
                    semanticsLabel: 'Connecting to your account',
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Loading your saved learning progress…',
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  Text(
                    error is ApiException ? error.userMessage : 'Could not load your learning progress. Please retry.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      if (startup.hasError) ref.invalidate(authStartupProvider);
                      ref.invalidate(realLearningSessionProvider);
                    },
                    child: const Text('RETRY'),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).signOut(),
                    child: const Text('SIGN OUT'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
