import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/client/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../application/real_learning_session.dart';
import '../application/enrollment_choice.dart';
import '../../learning/data/learning_repository.dart';

class RealConnectionScreen extends ConsumerWidget {
  const RealConnectionScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(authStartupProvider);
    final prepared = ref.watch(realLearningSessionProvider);
    final error = startup.error ?? prepared.error;
    final choice = ref.watch(enrollmentChoiceProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error == null &&
                    !prepared.isLoading &&
                    prepared.value?.needsEnrollment == true) ...[
                  const Text(
                    'Where would you like to start?',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Start with the basics or take a 10-question placement test.',
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: choice.isLoading
                        ? null
                        : () => context.go('/placement'),
                    child: const Text('CHECK MY LEVEL'),
                  ),
                  TextButton(
                    onPressed: choice.isLoading
                        ? null
                        : () => ref
                              .read(enrollmentChoiceProvider.notifier)
                              .beginner(),
                    child: Text(
                      choice.isLoading ? 'SAVING…' : 'START FROM THE BEGINNING',
                    ),
                  ),
                  if (choice.hasError)
                    Text(
                      choice.error is LearningFailure
                          ? (choice.error as LearningFailure).message
                          : choice.error is ApiException
                          ? (choice.error as ApiException).userMessage
                          : 'Could not save your choice. Please retry.',
                    ),
                ] else if (error == null) ...[
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
