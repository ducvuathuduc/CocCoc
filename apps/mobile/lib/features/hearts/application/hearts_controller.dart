import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../learning/application/learning_controller.dart';
import '../../progress/application/preview_controller.dart';
import '../data/hearts_repository.dart';
import '../domain/hearts.dart';

final heartsRepositoryProvider = Provider<HeartsRepository>(
  (ref) => MockHeartsRepository(),
);
final heartsContentProvider = Provider<HeartsContent>(
  (ref) => ref.watch(heartsRepositoryProvider).content,
);
final heartsControllerProvider =
    NotifierProvider<HeartsController, HeartsState>(HeartsController.new);

class HeartsController extends Notifier<HeartsState> {
  @override
  HeartsState build() => ref.watch(heartsRepositoryProvider).load();
  Future<bool> startPractice() async {
    await ref
        .read(lessonControllerProvider.notifier)
        .start(nodeId: 'hearts-practice', guest: true);
    if (ref.read(lessonControllerProvider).error != null) return false;
    state = ref.read(heartsRepositoryProvider).beginPractice();
    return true;
  }

  void completePractice(String receipt) {
    if (!state.practicePending) return;
    state = ref.read(heartsRepositoryProvider).earn('practice-$receipt');
  }

  void earnFromAd(String receipt) =>
      state = ref.read(heartsRepositoryProvider).earn('ad-$receipt');
  bool refill(int cost) {
    if (state.balance >= state.capacity ||
        !ref.read(previewControllerProvider.notifier).spendRefillGems(cost)) {
      return false;
    }
    state = ref.read(heartsRepositoryProvider).refill();
    return true;
  }
}
