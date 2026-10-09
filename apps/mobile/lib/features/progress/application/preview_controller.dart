import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/preview_state.dart';
import '../../learning/application/learning_controller.dart';

final previewControllerProvider =
    NotifierProvider<PreviewController, PreviewState>(PreviewController.new);

final previewWalletProvider = Provider<int>((ref) {
  final preview = ref.watch(previewControllerProvider);
  return ref.watch(learningStateProvider).gems +
      preview.bonusGems -
      preview.spentGems;
});

const timerBoostPrices = {1: 450, 5: 1800, 15: 4500};

// In-memory preview commands only. Production rewards/account changes remain
// service-owned; this controller never calls an SDK or authorizes real XP.
class PreviewController extends Notifier<PreviewState> {
  @override
  PreviewState build() => const PreviewState();
  int get _wallet =>
      ref.read(learningStateProvider).gems + state.bonusGems - state.spentGems;
  // Explicit, once-only mock funding. This never represents earned rewards.
  void useDemoBalance() {
    if (state.demoBalanceUsed) return;
    final topUp = (1035 - _wallet).clamp(0, 1035).toInt();
    state = state.copyWith(
      bonusGems: state.bonusGems + topUp,
      demoBalanceUsed: true,
    );
  }

  bool buyTimerBoost(String receipt, int count) {
    final price = timerBoostPrices[count];
    if (price == null ||
        receipt.isEmpty ||
        state.purchases.contains(receipt) ||
        _wallet < price) {
      return false;
    }
    state = state.copyWith(
      timerBoosts: state.timerBoosts + count,
      spentGems: state.spentGems + price,
      purchases: {...state.purchases, receipt},
    );
    return true;
  }

  bool consumeTimerBoost() {
    if (state.timerBoosts <= 0) return false;
    state = state.copyWith(timerBoosts: state.timerBoosts - 1);
    return true;
  }

  bool buyStreakShield() {
    const receipt = 'streak-shield-local';
    if (_wallet < 3000 || state.purchases.contains(receipt)) return false;
    state = state.copyWith(
      spentGems: state.spentGems + 3000,
      purchases: {...state.purchases, receipt},
    );
    return true;
  }

  // Historical mobile price, used only as a fixed local preview tariff.
  bool buyStatusIcon(String id) {
    const paid = {'cool', 'party', 'flex', 'eyes'};
    final receipt = 'status-$id';
    if (!paid.contains(id) ||
        _wallet < 500 ||
        state.purchases.contains(receipt)) {
      return false;
    }
    state = state.copyWith(
      spentGems: state.spentGems + 500,
      purchases: {...state.purchases, receipt},
    );
    return true;
  }

  void dismissQuestIntro() => state = state.copyWith(questIntroSeen: true);
  bool claimQuest(String id, {required bool eligible}) {
    if (!eligible ||
        state.claims.contains(id) ||
        !{'daily-2', 'daily-xp', 'monthly'}.contains(id)) {
      return false;
    }
    state = state.copyWith(
      bonusGems: state.bonusGems + 10,
      claims: {...state.claims, id},
    );
    return true;
  }

  bool buyFreeze(String id) {
    if (id.isEmpty ||
        _wallet < 200 ||
        state.freezes >= 2 ||
        state.purchases.contains(id)) {
      return false;
    }
    state = state.copyWith(
      freezes: state.freezes + 1,
      spentGems: state.spentGems + 200,
      purchases: {...state.purchases, id},
    );
    return true;
  }

  void follow(String id) {
    final people = {...state.following};
    people.contains(id) ? people.remove(id) : people.add(id);
    state = state.copyWith(following: people);
  }

  void report(String category) =>
      state = state.copyWith(reports: [...state.reports, category]);
  String? saveProfile(String name, String email, {bool register = false}) {
    if (name.trim().isEmpty || name.trim().length > 60) {
      return 'Enter a name between 1 and 60 characters.';
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim())) {
      return 'Enter a valid email address.';
    }
    if (register && email.trim().toLowerCase() == 'demo@cocenglish.test') {
      return 'An account with this email already exists. Log in instead.';
    }
    state = state.copyWith(
      name: name.trim(),
      email: email.trim(),
      registered: register || state.registered,
      verified: email.trim() == state.email && state.verified,
    );
    return null;
  }

  void verify() => state = state.copyWith(verified: true);
  void chooseCourse(String course) {
    if (course == 'English') {
      state = state.copyWith(course: course);
    }
  }

  void setSound(bool value) => state = state.copyWith(sound: value);
  void setPrivate(bool value) => state = state.copyWith(private: value);
  void optIntoLeague() => state = state.copyWith(leagueOptIn: true);
  void reminder({required bool enabled, String? time}) =>
      state = state.copyWith(reminder: enabled, reminderTime: time);
  void requestDeletion() => state = state.copyWith(deletionRequested: true);
}
