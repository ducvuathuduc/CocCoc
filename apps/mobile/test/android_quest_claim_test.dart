import 'dart:async';

import 'package:cocenglish/core/config/app_config.dart';
import 'package:cocenglish/features/auth/application/auth_controller.dart';
import 'package:cocenglish/features/auth/domain/auth_state.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/quests/application/quests_controller.dart';
import 'package:cocenglish/features/quests/data/quests_repository.dart';
import 'package:cocenglish/features/quests/domain/quest_models.dart';
import 'package:cocenglish/features/quests/domain/upgrade_chest.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Learning extends LearningStateController {
  @override
  LearningState build() => const LearningState();
}

class _Repository extends MockQuestsRepository implements QuestRewardCommands {
  final pending = Completer<UpgradeChestReward?>();
  int calls = 0;
  @override
  Future<UpgradeChestReward?> claimReward(String questId) {
    calls++;
    return pending.future;
  }

  @override
  QuestsTabState loadQuests({
    QuestSectionType sectionType = QuestSectionType.friends,
  }) => super.loadQuests().copyWith(
    dailyQuests: const [
      DailyQuest(
        id: 'daily_lessons',
        title: 'Complete lessons',
        current: 2,
        target: 2,
      ),
    ],
  );
}

class _Auth extends AuthController {
  @override
  AuthState build() => const AuthState(
    user: AuthUser(id: 'a', email: 'a@example.test', name: 'A'),
  );
  void switchAccount() => state = const AuthState(
    user: AuthUser(id: 'b', email: 'b@example.test', name: 'B'),
  );
}

void main() {
  test(
    'an old account claim cannot leave the new account quest stuck',
    () async {
      late _Repository repository;
      final c = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(dataSource: DataSource.api, mockAuthOverride: true),
          ),
          authControllerProvider.overrideWith(_Auth.new),
          learningStateProvider.overrideWith(_Learning.new),
          questsRepositoryProvider.overrideWith((ref) {
            ref.watch(authControllerProvider.select((s) => s.user?.id));
            return repository = _Repository();
          }),
        ],
      );
      final vm = c.read(questsControllerProvider.notifier);
      final oldRepository = repository;
      final old = vm.claimReward('daily_lessons');
      (c.read(authControllerProvider.notifier) as _Auth).switchAccount();
      expect(
        c.read(questsControllerProvider).dailyQuests.single.canClaim,
        isTrue,
      );
      oldRepository.pending.complete(null);
      expect(await old, isNull);
      expect(
        c.read(questsControllerProvider).dailyQuests.single.isClaiming,
        isFalse,
      );
      c.dispose();
    },
  );
  for (final success in [false, true]) {
    test(
      'API quest has no optimistic gems; concurrent/failure/retry success=$success',
      () async {
        final repo = _Repository();
        final c = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(
                dataSource: DataSource.api,
                mockAuthOverride: true,
              ),
            ),
            learningStateProvider.overrideWith(_Learning.new),
            questsRepositoryProvider.overrideWithValue(repo),
          ],
        );
        final vm = c.read(questsControllerProvider.notifier);
        final before = c.read(previewWalletProvider);
        final result = vm.claimReward('daily_lessons');
        expect(await vm.claimReward('daily_lessons'), isNull);
        expect(repo.calls, 1);
        expect(c.read(previewWalletProvider), before);
        if (success) {
          repo.pending.complete(
            const UpgradeChestReward(
              receiptId: 'server',
              tiers: [
                ChestRarity.common,
                ChestRarity.rare,
                ChestRarity.rare,
                ChestRarity.epic,
              ],
              gems: 20,
            ),
          );
        } else {
          repo.pending.completeError(StateError('offline'));
        }
        expect((await result)?.gems, success ? 20 : null);
        expect(c.read(previewWalletProvider), before);
        expect(
          c.read(questsControllerProvider).dailyQuests.single.isClaimed,
          success,
        );
        c.dispose();
      },
    );
  }
}
