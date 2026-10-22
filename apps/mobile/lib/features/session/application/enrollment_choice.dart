import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../learning/application/learning_controller.dart';
import '../../learning/data/learning_repository.dart';
import 'real_learning_session.dart';

final enrollmentChoiceProvider =
    NotifierProvider<EnrollmentChoiceController, AsyncValue<void>>(
      EnrollmentChoiceController.new,
    );

class EnrollmentChoiceController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    ref.watch(authControllerProvider.select((s) => s.user?.id));
    return const AsyncData(null);
  }

  Future<void> beginner() async {
    if (state.isLoading) return;
    final user = ref.read(authControllerProvider).user?.id;
    if (user == null) return;
    final repository = ref.read(realLearningSessionRepositoryProvider);
    final journal = ref.read(lessonJournalProvider);
    state = const AsyncLoading();
    try {
      if (await journal.active() != null) {
        throw const LearningFailure(
          'Resume your saved test or lesson before choosing a starting point.',
        );
      }
      await repository.enrollBeginner();
      if (!ref.mounted || ref.read(authControllerProvider).user?.id != user) {
        return;
      }
      ref.invalidate(realLearningSessionProvider);
      state = const AsyncData(null);
    } catch (error, stack) {
      if (ref.mounted && ref.read(authControllerProvider).user?.id == user) {
        state = AsyncError(error, stack);
      }
    }
  }
}
